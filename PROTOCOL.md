# Open Godot MCP — WebSocket Protocol

This document defines the messages exchanged between the Rust MCP server and the Godot Editor plugin over WebSocket.

## Connection

- The plugin starts a WebSocket server on `ws://127.0.0.1:6505/mcp`, bound to loopback only. The port is currently fixed at 6505 on the plugin side; the Rust server can target a different port via `--godot-port` (useful with customized plugin builds).
- The Rust server connects to that endpoint as a client.
- The channel is plain-text JSON, one message per WebSocket text frame.

## Request (server → Godot)

```json
{
  "request_id": "<uuid>",
  "method": "get_project_info",
  "params": { }
}
```

- `request_id`: opaque UUID used to correlate the response.
- `method`: name of the Godot operation.
- `params`: method-specific arguments (optional).

## Response (Godot → server)

```json
{
  "request_id": "<uuid>",
  "result": { }
}
```

or, on a transport-level failure (e.g. an unparseable request):

```json
{
  "request_id": "<uuid>",
  "error": "human readable error message"
}
```

Tool-level failures are reported **inside** the result payload, following the plugin's convention:

```json
{
  "request_id": "<uuid>",
  "result": { "error": "node not found: Player/Sprite" }
}
```

The Rust server detects this shape and surfaces it to the MCP client as a tool error (`isError: true`) instead of a fake success.

## Methods

### `ping`

Health check.

**Result:**
```json
{ "ok": true, "uptime": 123.45 }
```

### `get_project_info`

Return project metadata.

**Result:**
```json
{
  "name": "My Game",
  "version": "1.0.0",
  "godot_version": { ... },
  "renderer": "forward_plus",
  "viewport_width": 1920,
  "viewport_height": 1080,
  "log_path": "C:/.../godot.log"
}
```

`log_path` is the best-effort absolute path to the editor log file. The Rust server uses it to tail errors and output lines and forward them as MCP `notifications/message`.

## Events (Godot → server → MCP client)

The plugin can also push **unsolicited events** to every connected WebSocket peer. The Rust server forwards them to the MCP client as server-to-client notifications.

### Event message

```json
{
  "event": "scene_changed",
  "payload": {
    "path": "res://house.tscn",
    "name": "House"
  }
}
```

Supported events:

| Event | Payload | MCP notification |
|-------|---------|------------------|
| `scene_changed` | `{path, name}` | `notifications/godot/event` |
| `play_state_changed` | `{playing}` | `notifications/godot/event` |
| `selection_changed` | `{selected_paths}` | `notifications/godot/event` |

### Log/error lines

Log tailing is performed by the Rust server rather than the plugin, because the editor log file is usually locked for writing by Godot itself and cannot be reopened from inside the editor process. After connecting, the server reads `log_path` from `get_project_info` and tails that file, forwarding each new line as:

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/message",
  "params": {
    "level": "error",
    "data": "SCRIPT ERROR: ...",
    "source": "C:/.../godot.log"
  }
}
```

## Adding a new method

1. Implement the handler in `godot_plugin/addons/open_godot_mcp/command_router.gd`.
2. Add the tool declaration in `crates/mcp-server/src/main.rs` under `tools/list`.
3. Optionally add JSON-schema validation in the Rust server.
