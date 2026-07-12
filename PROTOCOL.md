# Open Godot MCP — WebSocket Protocol

This document defines the messages exchanged between the Rust MCP server and the Godot Editor plugin over WebSocket.

## Connection

- The plugin starts a WebSocket server on `ws://127.0.0.1:6505/mcp` (port configurable).
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

or, on error:

```json
{
  "request_id": "<uuid>",
  "error": "human readable error message"
}
```

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
  "viewport_height": 1080
}
```

## Adding a new method

1. Implement the handler in `godot_plugin/addons/open_godot_mcp/command_router.gd`.
2. Add the tool declaration in `crates/mcp-server/src/main.rs` under `tools/list`.
3. Optionally add JSON-schema validation in the Rust server.
