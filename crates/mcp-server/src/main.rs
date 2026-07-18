#![recursion_limit = "512"]

use anyhow::{Context, Result};
use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::sync::{mpsc, Mutex, oneshot};
use tokio_tungstenite::tungstenite::Message;

#[derive(Parser, Debug)]
#[command(name = "open-godot-mcp-server")]
#[command(about = "Open-source MCP server for Godot Editor")]
struct Args {
    #[arg(long, default_value_t = 6505)]
    godot_port: u16,

    /// Path to a Godot editor log file to tail and forward as MCP notifications.
    /// If omitted, the server asks the Godot plugin for the log path.
    #[arg(long)]
    log_file: Option<String>,
}

#[derive(Debug, Deserialize)]
struct JsonRpcRequest {
    #[allow(dead_code)]
    jsonrpc: String,
    id: Option<Value>,
    method: String,
    #[serde(default)]
    params: Option<Value>,
}

#[derive(Debug, Serialize)]
struct JsonRpcResponse {
    jsonrpc: String,
    id: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<JsonRpcError>,
}

#[derive(Debug, Serialize)]
struct JsonRpcError {
    code: i32,
    message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    data: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct GodotRequest {
    request_id: String,
    method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    params: Option<Value>,
}

#[derive(Debug, Clone, Deserialize)]
struct GodotResponse {
    request_id: String,
    #[serde(default)]
    result: Option<Value>,
    #[serde(default)]
    error: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
struct GodotEvent {
    event: String,
    #[serde(default)]
    payload: Option<Value>,
}

/// Outcome of a request to the Godot plugin. The plugin reports tool failures
/// as {"error": "..."} payloads inside `result`; `is_error` surfaces them so
/// they can be mapped to MCP tool errors instead of fake successes.
#[derive(Debug)]
struct GodotReply {
    result: Value,
    is_error: bool,
}

type PendingMap = Arc<Mutex<HashMap<String, oneshot::Sender<GodotReply>>>>;

async fn send_godot_request(
    pending: &PendingMap,
    out_tx: &mpsc::UnboundedSender<String>,
    method: &str,
    params: Option<Value>,
) -> Result<GodotReply> {
    let request_id = uuid::Uuid::new_v4().to_string();
    let godot_req = GodotRequest {
        request_id: request_id.clone(),
        method: method.into(),
        params,
    };
    let payload = serde_json::to_string(&godot_req)
        .with_context(|| format!("failed to serialize {} request", method))?;

    let (tx, rx) = oneshot::channel::<GodotReply>();
    pending.lock().await.insert(request_id.clone(), tx);

    out_tx
        .send(payload)
        .map_err(|_| anyhow::anyhow!("websocket sender closed"))?;

    match tokio::time::timeout(Duration::from_secs(10), rx).await {
        Ok(Ok(reply)) => Ok(reply),
        Ok(Err(_)) => Err(anyhow::anyhow!("response channel dropped")),
        Err(_) => {
            pending.lock().await.remove(&request_id);
            Err(anyhow::anyhow!("timeout waiting for Godot"))
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    loop {
        match run_once(&args).await {
            Ok(RunResult::StdinClosed) => break,
            Ok(RunResult::Disconnected) => {
                eprintln!("[open-godot-mcp] reconnecting in 2s...");
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
            Err(e) => {
                eprintln!("[open-godot-mcp] error: {}", e);
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
        }
    }

    Ok(())
}

enum RunResult {
    StdinClosed,
    Disconnected,
}

async fn run_once(args: &Args) -> Result<RunResult> {
    let url = format!("ws://127.0.0.1:{}/mcp", args.godot_port);
    eprintln!("[open-godot-mcp] connecting to Godot at {}", url);

    let (ws_stream, _) = tokio_tungstenite::connect_async(&url)
        .await
        .with_context(|| format!("failed to connect to Godot plugin at {}", url))?;
    eprintln!("[open-godot-mcp] connected to Godot plugin");

    // Notify the MCP client that the tool list is available (or may have changed
    // after a reconnection). Some clients ignore this, but well-behaved ones will
    // refresh their tool cache.
    send_notification("notifications/tools/list_changed").await?;

    let (mut ws_tx, mut ws_rx) = ws_stream.split();
    let pending: PendingMap = Arc::new(Mutex::new(HashMap::new()));

    // Channel to send outgoing WebSocket messages from the stdio loop.
    let (out_tx, mut out_rx) = mpsc::unbounded_channel::<String>();

    let disconnected = Arc::new(AtomicBool::new(false));
    let disconnected_for_reader = disconnected.clone();
    let disconnected_for_writer = disconnected.clone();

    // WebSocket reader task: route incoming Godot responses to pending stdio requests
    // and forward unsolicited Godot events to the MCP client as notifications.
    let pending_for_reader = pending.clone();
    tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_rx.next().await {
            if let Ok(text) = msg.into_text() {
                if let Ok(resp) = serde_json::from_str::<GodotResponse>(&text) {
                    let mut map = pending_for_reader.lock().await;
                    if let Some(tx) = map.remove(&resp.request_id) {
                        let reply = match (resp.result, resp.error) {
                            (Some(result), _) => {
                                // The Godot plugin signals tool failures as
                                // {"error": "..."} inside the result payload.
                                let is_error =
                                    result.get("error").and_then(|e| e.as_str()).is_some();
                                GodotReply { result, is_error }
                            }
                            (None, Some(err)) => GodotReply {
                                result: Value::String(err),
                                is_error: true,
                            },
                            (None, None) => GodotReply {
                                result: Value::Null,
                                is_error: false,
                            },
                        };
                        let _ = tx.send(reply);
                    }
                } else if let Ok(evt) = serde_json::from_str::<GodotEvent>(&text) {
                    if let Err(e) = forward_event(evt).await {
                        eprintln!("[open-godot-mcp] failed to forward event: {}", e);
                    }
                }
            }
        }
        disconnected_for_reader.store(true, Ordering::SeqCst);
        eprintln!("[open-godot-mcp] Godot WebSocket closed");
    });

    // WebSocket writer task.
    tokio::spawn(async move {
        while let Some(text) = out_rx.recv().await {
            if ws_tx.send(Message::Text(text)).await.is_err() {
                break;
            }
        }
        disconnected_for_writer.store(true, Ordering::SeqCst);
    });

    // Discover the editor log path and start a background tailer.
    let log_path: Option<String> = if let Some(path) = &args.log_file {
        Some(path.clone())
    } else {
        match send_godot_request(&pending, &out_tx, "get_project_info", None).await {
            Ok(info) => info
                .result
                .get("log_path")
                .and_then(|v| v.as_str())
                .map(String::from),
            Err(e) => {
                eprintln!("[open-godot-mcp] failed to get project info: {}", e);
                None
            }
        }
    };
    // The tailer runs until it is aborted on exit; without the abort, every
    // reconnection would stack one more duplicate log tailer.
    let tailer = match log_path {
        Some(path) if !path.is_empty() => {
            eprintln!("[open-godot-mcp] tailing log file: {}", path);
            Some(tokio::spawn(tail_log_file(path)))
        }
        _ => None,
    };

    // Stdin reader loop.
    let stdin = tokio::io::stdin();
    let reader = BufReader::new(stdin);
    let mut lines = reader.lines();
    let mut stdout = tokio::io::stdout();

    while let Ok(Some(line)) = lines.next_line().await {
        if line.trim().is_empty() {
            continue;
        }
        let req: JsonRpcRequest = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                send_response(
                    &mut stdout,
                    JsonRpcResponse {
                        jsonrpc: "2.0".into(),
                        id: None,
                        result: None,
                        error: Some(JsonRpcError {
                            code: -32700,
                            message: format!("parse error: {}", e),
                            data: None,
                        }),
                    },
                )
                .await?;
                continue;
            }
        };

        if let Some(response) = handle_request(req, &pending, &out_tx).await {
            send_response(&mut stdout, response).await?;
        }

        if disconnected.load(Ordering::SeqCst) {
            if let Some(handle) = &tailer {
                handle.abort();
            }
            return Ok(RunResult::Disconnected);
        }
    }

    if let Some(handle) = &tailer {
        handle.abort();
    }
    Ok(RunResult::StdinClosed)
}

async fn handle_request(
    req: JsonRpcRequest,
    pending: &PendingMap,
    out_tx: &mpsc::UnboundedSender<String>,
) -> Option<JsonRpcResponse> {
    // JSON-RPC notifications (messages without an id) must never be answered.
    if req.id.is_none() {
        return None;
    }

    let base = JsonRpcResponse {
        jsonrpc: "2.0".into(),
        id: req.id.clone(),
        result: None,
        error: None,
    };

    match req.method.as_str() {
        "initialize" => Some(JsonRpcResponse {
            result: Some(json!({
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "open-godot-mcp-server",
                    "version": env!("CARGO_PKG_VERSION")
                }
            })),
            ..base
        }),
        "ping" => Some(JsonRpcResponse {
            result: Some(json!({})),
            ..base
        }),
        "tools/list" => Some(JsonRpcResponse {
            result: Some(json!({
                "tools": [
                    {
                        "name": "get_project_info",
                        "description": "Return Godot project metadata (name, version, renderer, viewport).",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "get_project_settings",
                        "description": "Read one or more project settings by key.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "keys": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["keys"]
                        }
                    },
                    {
                        "name": "set_project_setting",
                        "description": "Set a project setting and optionally save project.godot.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "key": {"type": "string"},
                                "value": {},
                                "save": {"type": "boolean"}
                            },
                            "required": ["key", "value"]
                        }
                    },
                    {
                        "name": "get_filesystem_tree",
                        "description": "Return the res:// file tree (optionally from a sub-path).",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "recursive": {"type": "boolean"}
                            }
                        }
                    },
                    {
                        "name": "search_files",
                        "description": "Search project files by name substring.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "query": {"type": "string"},
                                "pattern": {"type": "string"}
                            }
                        }
                    },
                    {
                        "name": "get_scene_tree",
                        "description": "Return the node tree of the currently edited scene.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "get_open_scenes",
                        "description": "List currently open scene file paths.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "open_scene",
                        "description": "Open a scene file in the editor.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "save_scene",
                        "description": "Save the currently edited scene.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "create_scene",
                        "description": "Create a new scene file with a root node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "root_type": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "add_scene_instance",
                        "description": "Instance a PackedScene as a child of a node in the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "scene_path": {"type": "string"},
                                "parent_path": {"type": "string"},
                                "node_name": {"type": "string"}
                            },
                            "required": ["scene_path"]
                        }
                    },
                    {
                        "name": "add_node",
                        "description": "Add a new node to the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "parent_path": {"type": "string"},
                                "type": {"type": "string"},
                                "name": {"type": "string"}
                            },
                            "required": ["type"]
                        }
                    },
                    {
                        "name": "delete_node",
                        "description": "Delete a node from the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "duplicate_node",
                        "description": "Duplicate a node in the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "move_node",
                        "description": "Reparent a node to a new parent in the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "new_parent_path": {"type": "string"},
                                "new_index": {"type": "integer"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "rename_node",
                        "description": "Rename a node in the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "new_name": {"type": "string"}
                            },
                            "required": ["path", "new_name"]
                        }
                    },
                    {
                        "name": "update_property",
                        "description": "Set a property on a node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "property": {"type": "string"},
                                "value": {}
                            },
                            "required": ["path", "property", "value"]
                        }
                    },
                    {
                        "name": "get_node_properties",
                        "description": "Read common properties of a node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "get_editor_selection",
                        "description": "Return the nodes currently selected in the editor.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "select_nodes",
                        "description": "Select nodes in the editor by path.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "paths": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["paths"]
                        }
                    },
                    {
                        "name": "find_nodes_by_type",
                        "description": "Find all nodes of a given class in the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"}
                            },
                            "required": ["type"]
                        }
                    },
                    {
                        "name": "connect_signal",
                        "description": "Connect a signal on a source node to a method on a target node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "source_path": {"type": "string"},
                                "signal_name": {"type": "string"},
                                "target_path": {"type": "string"},
                                "method_name": {"type": "string"}
                            },
                            "required": ["source_path", "signal_name", "target_path", "method_name"]
                        }
                    },
                    {
                        "name": "disconnect_signal",
                        "description": "Disconnect a signal connection between two nodes.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "source_path": {"type": "string"},
                                "signal_name": {"type": "string"},
                                "target_path": {"type": "string"},
                                "method_name": {"type": "string"}
                            },
                            "required": ["source_path", "signal_name", "target_path", "method_name"]
                        }
                    },
                    {
                        "name": "get_node_groups",
                        "description": "Return the groups a node belongs to.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "set_node_groups",
                        "description": "Set the groups a node belongs to (replaces existing groups).",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "groups": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["path", "groups"]
                        }
                    },
                    {
                        "name": "list_scripts",
                        "description": "List all GDScript files in the project (or under a path).",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            }
                        }
                    },
                    {
                        "name": "read_script",
                        "description": "Read the content of a GDScript file.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "create_script",
                        "description": "Create a new GDScript file.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "content": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "edit_script",
                        "description": "Apply search/replace replacements to a GDScript file.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "replacements": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "search": {"type": "string"},
                                            "replace": {"type": "string"}
                                        },
                                        "required": ["search", "replace"]
                                    }
                                }
                            },
                            "required": ["path", "replacements"]
                        }
                    },
                    {
                        "name": "attach_script",
                        "description": "Attach a GDScript file to a node in the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "node_path": {"type": "string"},
                                "script_path": {"type": "string"}
                            },
                            "required": ["node_path", "script_path"]
                        }
                    },
                    {
                        "name": "validate_script",
                        "description": "Validate a GDScript snippet or file without running it.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "content": {"type": "string"}
                            }
                        }
                    },
                    {
                        "name": "get_open_scripts",
                        "description": "List scripts currently open in the script editor.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "search_in_files",
                        "description": "Search a text substring across project files.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "query": {"type": "string"},
                                "pattern": {"type": "string"}
                            },
                            "required": ["query"]
                        }
                    },
                    {
                        "name": "get_editor_errors",
                        "description": "Return recent editor errors (best-effort; Godot does not expose the full error log).",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "get_output_log",
                        "description": "Return the editor output log (best-effort; Godot does not expose the full output log).",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "execute_editor_script",
                        "description": "Execute an EditorScript in the editor context by path or inline content.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "content": {"type": "string"}
                            }
                        }
                    },
                    {
                        "name": "get_editor_screenshot",
                        "description": "Capture a PNG screenshot of the 2D or 3D editor viewport and return it as base64.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "viewport": {"type": "string", "enum": ["2d", "3d"], "description": "Which editor viewport to capture (default: 3d)"}
                            }
                        }
                    },
                    {
                        "name": "play_scene",
                        "description": "Start playing the current scene or the main scene from the editor.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "mode": {"type": "string", "enum": ["current", "main"], "description": "Play the current edited scene or the project's main scene."}
                            }
                        }
                    },
                    {
                        "name": "stop_scene",
                        "description": "Stop the running game instance launched from the editor.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "get_game_screenshot",
                        "description": "Capture a PNG screenshot of the running game and return it as base64 (when available).",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "simulate_key",
                        "description": "Simulate a keyboard key press/release in the editor/game input queue.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "keycode": {"type": "integer", "description": "Godot Key enum value"},
                                "pressed": {"type": "boolean"},
                                "ctrl": {"type": "boolean"},
                                "shift": {"type": "boolean"},
                                "alt": {"type": "boolean"},
                                "meta": {"type": "boolean"}
                            },
                            "required": ["keycode"]
                        }
                    },
                    {
                        "name": "simulate_mouse_click",
                        "description": "Simulate a mouse button click in the editor/game input queue.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "button": {"type": "integer", "description": "MouseButton enum value (1=left, 2=right, 3=middle)"},
                                "position": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}}},
                                "pressed": {"type": "boolean"},
                                "double_click": {"type": "boolean"}
                            },
                            "required": ["button"]
                        }
                    },
                    {
                        "name": "list_input_actions",
                        "description": "List all input actions defined in the project input map.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "add_input_action",
                        "description": "Add a new input action to the project input map.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "action": {"type": "string"},
                                "deadzone": {"type": "number"}
                            },
                            "required": ["action"]
                        }
                    },
                    {
                        "name": "remove_input_action",
                        "description": "Remove an input action from the project input map.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "action": {"type": "string"}
                            },
                            "required": ["action"]
                        }
                    },
                    {
                        "name": "set_input_key",
                        "description": "Bind a keyboard key to an input action.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "action": {"type": "string"},
                                "keycode": {"type": "integer"},
                                "remove_existing": {"type": "boolean"}
                            },
                            "required": ["action", "keycode"]
                        }
                    },
                    {
                        "name": "get_input_map",
                        "description": "Return the full input map with events for each action.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "get_camera_3d_info",
                        "description": "Return information about the first Camera3D in the current scene.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "set_camera_3d_transform",
                        "description": "Set position/rotation of the first Camera3D in the current scene.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "position": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}},
                                "rotation": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}},
                                "fov": {"type": "number"}
                            }
                        }
                    },
                    {
                        "name": "get_environment_info",
                        "description": "Return information about the current scene's WorldEnvironment if present.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "set_render_setting",
                        "description": "Set a rendering project setting by key.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "key": {"type": "string"},
                                "value": {}
                            },
                            "required": ["key", "value"]
                        }
                    },
                    {
                        "name": "list_animations",
                        "description": "List AnimationPlayer nodes in the current scene.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "play_animation",
                        "description": "Play an animation by name on an AnimationPlayer node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "node_path": {"type": "string"},
                                "animation": {"type": "string"}
                            },
                            "required": ["node_path", "animation"]
                        }
                    },
                    {
                        "name": "list_audio_streams",
                        "description": "List audio stream resources in the project.",
                        "inputSchema": {"type": "object", "properties": {"path": {"type": "string"}}}
                    },
                    {
                        "name": "play_audio_preview",
                        "description": "Preview an audio stream file by path (non-blocking).",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "list_resources",
                        "description": "List resource files in the project by extension filter.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "extensions": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    },
                    {
                        "name": "get_resource_info",
                        "description": "Return metadata for a resource file.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "set_control_anchors",
                        "description": "Set anchors and layout preset for a Control node (UI).",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the Control node."},
                                "preset": {"type": "integer", "description": "LayoutPreset enum value (0-15). e.g., 15 for full rect, 8 for center, 0 for top-left."},
                                "keep_offsets": {"type": "boolean", "description": "Whether to keep existing offsets."}
                            },
                            "required": ["path", "preset"]
                        }
                    },
                    {
                        "name": "set_theme_override",
                        "description": "Set theme override (color, font, font_size, stylebox, constant) for a Control node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the Control node."},
                                "override_type": {"type": "string", "enum": ["color", "font", "font_size", "stylebox", "constant"], "description": "Type of override."},
                                "name": {"type": "string", "description": "Name of the theme item (e.g., 'font_color', 'normal', 'font_size')."},
                                "value": {"description": "The override value. Color expects a color dict. Font/StyleBox expects a file path."}
                            },
                            "required": ["path", "override_type", "name", "value"]
                        }
                    },
                    {
                        "name": "modify_stylebox",
                        "description": "Modify a property of a StyleBoxFlat resource (standalone or inside a Theme).",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the .tres resource (StyleBox or Theme file)."},
                                "theme_item_name": {"type": "string", "description": "Name of the stylebox inside the Theme (only if path is a Theme file)."},
                                "theme_type_name": {"type": "string", "description": "Type of control inside the Theme (only if path is a Theme file)."},
                                "property": {"type": "string", "description": "StyleBoxFlat property to edit (e.g. 'bg_color', 'corner_radius_top_left')."},
                                "value": {"description": "New value to assign."}
                            },
                            "required": ["path", "property", "value"]
                        }
                    },
                    {
                        "name": "set_tilemap_cell",
                        "description": "Set or clear a cell on a TileMap or TileMapLayer node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the TileMap or TileMapLayer node."},
                                "layer": {"type": "integer", "description": "The TileMap layer index (ignored for TileMapLayer). Default is 0."},
                                "x": {"type": "integer", "description": "Cell coordinate X."},
                                "y": {"type": "integer", "description": "Cell coordinate Y."},
                                "source_id": {"type": "integer", "description": "The TileSet source ID to paint. Use -1 to clear the cell."},
                                "atlas_x": {"type": "integer", "description": "X coordinate in the TileSet atlas. Default is -1."},
                                "atlas_y": {"type": "integer", "description": "Y coordinate in the TileSet atlas. Default is -1."},
                                "alternative_tile": {"type": "integer", "description": "Alternative tile ID. Default is 0."}
                            },
                            "required": ["path", "x", "y"]
                        }
                    },
                    {
                        "name": "get_tilemap_cells",
                        "description": "Return coordinates of all used cells on a TileMap or TileMapLayer.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the TileMap or TileMapLayer node."},
                                "layer": {"type": "integer", "description": "The TileMap layer index (ignored for TileMapLayer). Default is 0."}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "list_tilemap_layers",
                        "description": "Return the list of layers inside a TileMap (or info for a TileMapLayer).",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the TileMap or TileMapLayer node."}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "configure_animation_tree",
                        "description": "Configure an AnimationTree node, linking it to an AnimationPlayer.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the AnimationTree node."},
                                "anim_player_path": {"type": "string", "description": "Path to the AnimationPlayer node (relative or absolute)."},
                                "active": {"type": "boolean", "description": "Whether to activate the tree. Default is true."}
                            },
                            "required": ["path", "anim_player_path"]
                        }
                    },
                    {
                        "name": "set_animation_tree_parameter",
                        "description": "Set a parameter inside an AnimationTree node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the AnimationTree node."},
                                "parameter": {"type": "string", "description": "Name of the parameter (with or without 'parameters/' prefix)."},
                                "value": {"description": "The value to set."}
                            },
                            "required": ["path", "parameter", "value"]
                        }
                    },
                    {
                        "name": "create_animation_state_transition",
                        "description": "Connect two animation states inside an AnimationNodeStateMachine.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the AnimationTree node."},
                                "from_state": {"type": "string", "description": "Name of the starting animation state."},
                                "to_state": {"type": "string", "description": "Name of the destination animation state."},
                                "switch_mode": {"type": "integer", "description": "Switch mode (0 = Immediate, 1 = AtEnd, 2 = Sync). Default is 0."},
                                "advance_mode": {"type": "integer", "description": "Advance mode (0 = Disabled, 1 = Enabled/Condition, 2 = Auto). Default is 1."},
                                "advance_condition": {"type": "string", "description": "Optional condition name to trigger the transition (e.g. 'is_moving')."},
                                "xfade_time": {"type": "number", "description": "Crossfade transition time in seconds. Default is 0.0."}
                            },
                            "required": ["path", "from_state", "to_state"]
                        }
                    },
                    {
                        "name": "set_material_shader",
                        "description": "Connect a shader file (.gdshader) to a ShaderMaterial.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "material_path": {"type": "string", "description": "Path to the .tres material resource or a node path containing a material."},
                                "shader_path": {"type": "string", "description": "Path to the .gdshader resource."}
                            },
                            "required": ["material_path", "shader_path"]
                        }
                    },
                    {
                        "name": "set_shader_parameter",
                        "description": "Modify a custom shader uniform parameter in a ShaderMaterial.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "material_path": {"type": "string", "description": "Path to the .tres material resource or a node path containing a material."},
                                "parameter_name": {"type": "string", "description": "Name of the uniform parameter to modify."},
                                "value": {"description": "New value to assign. Color/Vector expects dict format."}
                            },
                            "required": ["material_path", "parameter_name", "value"]
                        }
                    },
                    {
                        "name": "configure_particle_system",
                        "description": "Configure particle properties on a GPU or CPU particles node and its process material.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the particle system node."},
                                "settings": {
                                    "type": "object",
                                    "description": "Dict of properties to configure (e.g. 'amount', 'lifetime', 'gravity', 'initial_velocity_min')."
                                }
                            },
                            "required": ["path", "settings"]
                        }
                    },
                    {
                        "name": "perform_raycast_query_3d",
                        "description": "Perform a 3D raycast query in the editor physics space and return hit results.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "from": {"description": "Start position vector dictionary {'x': float, 'y': float, 'z': float}."},
                                "to": {"description": "End position vector dictionary {'x': float, 'y': float, 'z': float}."},
                                "exclude_paths": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "List of node paths to exclude from the collision query."
                                }
                            },
                            "required": ["from", "to"]
                        }
                    },
                    {
                        "name": "get_overlapping_bodies",
                        "description": "Query overlapping body paths for an Area2D or Area3D node in the editor physics space.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the Area2D or Area3D node."}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "create_audio_bus",
                        "description": "Create a new audio bus in the editor mixer, supporting UndoRedo.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "description": "The name of the new audio bus."},
                                "index": {"type": "integer", "description": "Optional insertion index. Defaults to the end."}
                            },
                            "required": ["name"]
                        }
                    },
                    {
                        "name": "set_audio_bus_effect",
                        "description": "Add an audio effect to a bus in the editor mixer, supporting UndoRedo.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "bus_name": {"type": "string", "description": "The name of the audio bus."},
                                "effect_type": {"type": "string", "description": "The ClassDB name of the audio effect (e.g. 'AudioEffectReverb', 'AudioEffectPitchShift')."},
                                "index": {"type": "integer", "description": "Optional effect slot index. Defaults to the end."}
                            },
                            "required": ["bus_name", "effect_type"]
                        }
                    },
                    {
                        "name": "set_audio_bus_volume",
                        "description": "Set the volume in dB for an audio bus in the editor mixer, supporting UndoRedo.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "bus_name": {"type": "string", "description": "The name of the audio bus."},
                                "volume_db": {"type": "number", "description": "The target volume in decibels (dB)."}
                            },
                            "required": ["bus_name", "volume_db"]
                        }
                    },
                    {
                        "name": "list_export_presets",
                        "description": "Parse export_presets.cfg and list configured build presets.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "run_project_export",
                        "description": "Trigger a headless project build and export for a configured preset.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "preset_name": {"type": "string", "description": "The name of the configured export preset."},
                                "output_path": {"type": "string", "description": "The output file path (e.g. 'build/game.exe' or 'build/index.html')."},
                                "release": {"type": "boolean", "description": "Whether to build in release mode. Default is true."}
                            },
                            "required": ["preset_name", "output_path"]
                        }
                    },
                    {
                        "name": "scatter_prefabs",
                        "description": "Scatter instances of a prefab scene randomly within a 2D or 3D bounding box.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "prefab_path": {"type": "string", "description": "Path to the prefab scene (.tscn) to instantiate."},
                                "parent_path": {"type": "string", "description": "Path to the parent node to add instances to."},
                                "count": {"type": "integer", "description": "Number of instances to scatter. Default is 1."},
                                "bounds": {
                                    "type": "object",
                                    "description": "Bounding box: For 2D: {'x', 'y', 'width', 'height'}. For 3D: {'x', 'y', 'z', 'size_x', 'size_y', 'size_z'}."
                                },
                                "min_scale": {"type": "number", "description": "Minimum scale multiplier. Default is 1.0."},
                                "max_scale": {"type": "number", "description": "Maximum scale multiplier. Default is 1.0."},
                                "min_rotation": {"description": "Min rotation: float (degrees) for 2D, dict {'x', 'y', 'z'} for 3D."},
                                "max_rotation": {"description": "Max rotation: float (degrees) for 2D, dict {'x', 'y', 'z'} for 3D."}
                            },
                            "required": ["prefab_path", "parent_path", "bounds"]
                        }
                    },
                    {
                        "name": "generate_collision_from_mesh",
                        "description": "Generate a static collision shape from a MeshInstance3D node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the MeshInstance3D node."},
                                "collision_type": {"type": "string", "enum": ["trimesh", "convex"], "description": "Type of collision shape: trimesh (concave) or convex."}
                            },
                            "required": ["path", "collision_type"]
                        }
                    },
                    {
                        "name": "bake_navigation",
                        "description": "Bake the navigation mesh/polygon on a NavigationRegion2D or NavigationRegion3D node.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "path": {"type": "string", "description": "Path to the NavigationRegion2D or NavigationRegion3D node."}
                            },
                            "required": ["path"]
                        }
                    },
                    {
                        "name": "get_performance_diagnostics",
                        "description": "Retrieve active editor and engine performance metrics (FPS, draw calls, memory, active bodies).",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "undo",
                        "description": "Undo the last action in the Godot Editor.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "redo",
                        "description": "Redo the previously undone action in the Godot Editor.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "reload_plugin",
                        "description": "Restart the Open Godot MCP plugin bridge (WebSocket) and reconnect. Does not re-parse GDScript: restart the editor to pick up plugin code changes.",
                        "inputSchema": {"type": "object", "properties": {}}
                    },
                    {
                        "name": "ping",
                        "description": "Ping the Godot editor and return the current editor uptime in seconds.",
                        "inputSchema": {"type": "object", "properties": {}}
                    }
                ]
            })),
            ..base
        }),
        "tools/call" => {
            let params = req.params.as_ref().cloned().unwrap_or(Value::Null);
            let name = params.get("name").and_then(|v| v.as_str()).unwrap_or("");
            let arguments = params.get("arguments").cloned();

            let request_id = uuid::Uuid::new_v4().to_string();
            let godot_req = GodotRequest {
                request_id: request_id.clone(),
                method: name.into(),
                params: arguments,
            };

            let payload = match serde_json::to_string(&godot_req) {
                Ok(s) => s,
                Err(e) => {
                    return Some(JsonRpcResponse {
                        error: Some(JsonRpcError {
                            code: -32603,
                            message: format!("internal error: {}", e),
                            data: None,
                        }),
                        ..base
                    });
                }
            };

            let (tx, rx) = oneshot::channel::<GodotReply>();
            pending.lock().await.insert(request_id, tx);

            if out_tx.send(payload).is_err() {
                pending.lock().await.remove(&godot_req.request_id);
                return Some(JsonRpcResponse {
                    error: Some(JsonRpcError {
                        code: -32603,
                        message: "websocket sender closed".into(),
                        data: None,
                    }),
                    ..base
                });
            }

            // Most calls answer in milliseconds; a headless project export can
            // take several minutes, so it gets a dedicated timeout.
            let timeout_secs = if name == "run_project_export" { 600 } else { 60 };
            match tokio::time::timeout(tokio::time::Duration::from_secs(timeout_secs), rx).await {
                Ok(Ok(reply)) => {
                    let mut tool_result = json!({
                        "content": [{ "type": "text", "text": reply.result.to_string() }]
                    });
                    if reply.is_error {
                        tool_result["isError"] = Value::Bool(true);
                    }
                    Some(JsonRpcResponse {
                        result: Some(tool_result),
                        ..base
                    })
                }
                Ok(Err(_)) => Some(JsonRpcResponse {
                    error: Some(JsonRpcError {
                        code: -32603,
                        message: "response channel dropped".into(),
                        data: None,
                    }),
                    ..base
                }),
                Err(_) => {
                    pending.lock().await.remove(&godot_req.request_id);
                    Some(JsonRpcResponse {
                        error: Some(JsonRpcError {
                            code: -32603,
                            message: "timeout waiting for Godot".into(),
                            data: None,
                        }),
                        ..base
                    })
                }
            }
        }
        _ => Some(JsonRpcResponse {
            error: Some(JsonRpcError {
                code: -32601,
                message: format!("method not found: {}", req.method),
                data: None,
            }),
            ..base
        }),
    }
}

async fn tail_log_file(path: String) {
    use tokio::io::{AsyncBufReadExt, AsyncSeekExt};

    let mut file = loop {
        match tokio::fs::File::open(&path).await {
            Ok(f) => break f,
            Err(_) => {
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
        }
    };

    if let Err(e) = file.seek(std::io::SeekFrom::End(0)).await {
        eprintln!("[open-godot-mcp] cannot seek log file {}: {}", path, e);
        return;
    }

    let mut reader = tokio::io::BufReader::new(file);
    let mut line = String::new();

    loop {
        line.clear();
        match reader.read_line(&mut line).await {
            Ok(0) => {
                tokio::time::sleep(Duration::from_millis(250)).await;
            }
            Ok(_) => {
                let trimmed = line.trim_end();
                if !trimmed.is_empty() {
                    let level = classify_log_line(trimmed);
                    if let Err(e) = send_notification_with_params(
                        "notifications/message",
                        json!({
                            "level": level,
                            "data": trimmed,
                            "source": path,
                        }),
                    )
                    .await
                    {
                        eprintln!("[open-godot-mcp] log notification error: {}", e);
                    }
                }
            }
            Err(e) => {
                eprintln!("[open-godot-mcp] log read error: {}", e);
                tokio::time::sleep(Duration::from_secs(1)).await;
            }
        }
    }
}


fn classify_log_line(line: &str) -> &str {
    let trimmed = line.trim_start();
    if trimmed.starts_with("ERROR:")
        || trimmed.starts_with("SCRIPT ERROR:")
        || trimmed.starts_with("USER ERROR:")
    {
        "error"
    } else if trimmed.starts_with("WARNING:") || trimmed.starts_with("USER WARNING:") {
        "warning"
    } else {
        "info"
    }
}


async fn forward_event(evt: GodotEvent) -> Result<()> {
    match evt.event.as_str() {
        "log" => {
            let payload = evt.payload.unwrap_or_default();
            let level = payload
                .get("level")
                .and_then(|v| v.as_str())
                .unwrap_or("info");
            let message = payload
                .get("message")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            send_notification_with_params(
                "notifications/message",
                json!({
                    "level": level,
                    "data": message,
                }),
            )
            .await?;
        }
        _ => {
            send_notification_with_params(
                "notifications/godot/event",
                json!({
                    "event": evt.event,
                    "payload": evt.payload,
                }),
            )
            .await?;
        }
    }
    Ok(())
}


async fn send_notification(method: &str) -> Result<()> {
    send_notification_with_params(method, Value::Null).await
}


async fn send_notification_with_params(method: &str, params: Value) -> Result<()> {
    let mut stdout = tokio::io::stdout();
    let body = json!({
        "jsonrpc": "2.0",
        "method": method,
    });
    let line = if params.is_null() {
        serde_json::to_string(&body)?
    } else {
        let mut with_params = body.as_object().unwrap().clone();
        with_params.insert("params".to_string(), params);
        serde_json::to_string(&with_params)?
    };
    stdout.write_all(line.as_bytes()).await?;
    stdout.write_all(b"\n").await?;
    stdout.flush().await?;
    Ok(())
}


async fn send_response(stdout: &mut tokio::io::Stdout, resp: JsonRpcResponse) -> Result<()> {
    let line = serde_json::to_string(&resp)?;
    stdout.write_all(line.as_bytes()).await?;
    stdout.write_all(b"\n").await?;
    stdout.flush().await?;
    Ok(())
}
