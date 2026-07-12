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

type PendingMap = Arc<Mutex<HashMap<String, oneshot::Sender<Value>>>>;

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

    // WebSocket reader task: route incoming Godot responses to pending stdio requests.
    let pending_for_reader = pending.clone();
    tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_rx.next().await {
            if let Ok(text) = msg.into_text() {
                if let Ok(resp) = serde_json::from_str::<GodotResponse>(&text) {
                    let mut map = pending_for_reader.lock().await;
                    if let Some(tx) = map.remove(&resp.request_id) {
                        let value = resp.result.unwrap_or_else(|| {
                            Value::String(resp.error.unwrap_or_else(|| "unknown error".into()))
                        });
                        let _ = tx.send(value);
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

        let response = handle_request(req, &pending, &out_tx).await;
        send_response(&mut stdout, response).await?;

        if disconnected.load(Ordering::SeqCst) {
            return Ok(RunResult::Disconnected);
        }
    }

    Ok(RunResult::StdinClosed)
}

async fn handle_request(
    req: JsonRpcRequest,
    pending: &PendingMap,
    out_tx: &mpsc::UnboundedSender<String>,
) -> JsonRpcResponse {
    let base = JsonRpcResponse {
        jsonrpc: "2.0".into(),
        id: req.id.clone(),
        result: None,
        error: None,
    };

    match req.method.as_str() {
        "initialize" => JsonRpcResponse {
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
        },
        "notifications/initialized" => JsonRpcResponse {
            result: Some(Value::Null),
            ..base
        },
        "tools/list" => JsonRpcResponse {
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
                        "name": "reload_plugin",
                        "description": "Reload the Open Godot MCP plugin in the editor to pick up script changes.",
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
        },
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
                    return JsonRpcResponse {
                        error: Some(JsonRpcError {
                            code: -32603,
                            message: format!("internal error: {}", e),
                            data: None,
                        }),
                        ..base
                    };
                }
            };

            let (tx, rx) = oneshot::channel::<Value>();
            pending.lock().await.insert(request_id, tx);

            if out_tx.send(payload).is_err() {
                return JsonRpcResponse {
                    error: Some(JsonRpcError {
                        code: -32603,
                        message: "websocket sender closed".into(),
                        data: None,
                    }),
                    ..base
                };
            }

            match tokio::time::timeout(tokio::time::Duration::from_secs(30), rx).await {
                Ok(Ok(value)) => JsonRpcResponse {
                    result: Some(json!({ "content": [{ "type": "text", "text": value.to_string() }] })),
                    ..base
                },
                Ok(Err(_)) => JsonRpcResponse {
                    error: Some(JsonRpcError {
                        code: -32603,
                        message: "response channel dropped".into(),
                        data: None,
                    }),
                    ..base
                },
                Err(_) => {
                    pending.lock().await.remove(&godot_req.request_id);
                    JsonRpcResponse {
                        error: Some(JsonRpcError {
                            code: -32603,
                            message: "timeout waiting for Godot".into(),
                            data: None,
                        }),
                        ..base
                    }
                }
            }
        }
        _ => JsonRpcResponse {
            error: Some(JsonRpcError {
                code: -32601,
                message: format!("method not found: {}", req.method),
                data: None,
            }),
            ..base
        },
    }
}

async fn send_notification(method: &str) -> Result<()> {
    let mut stdout = tokio::io::stdout();
    let line = serde_json::to_string(&json!({
        "jsonrpc": "2.0",
        "method": method,
    }))?;
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
