# Open Godot MCP — AI Assistant for Godot Game Development

A free, open-source, Rust-powered [Model Context Protocol](https://modelcontextprotocol.io/) server for **Godot Engine 4**.

> **Goal**: turn Kimi Code, Claude Code, Cursor, or any MCP-compatible assistant into a hands-on collaborator for building Godot games — giving it the same deep editor control that commercial solutions lock behind a paywall, but as a downloadable, self-hostable, MIT-licensed binary.

With Open Godot MCP, an AI assistant can inspect scenes, create and edit nodes, write and attach GDScript, run the game, simulate input, query 3D cameras, and capture editor screenshots — all through a local WebSocket bridge.

## Architecture

```
AI assistant  ← stdio MCP →  open-godot-mcp-server (Rust)  ← WebSocket →  Godot Editor plugin (GDScript)
```

- **Rust server**: single static binary, cross-platform, speaks MCP over stdio.
- **Godot plugin**: runs inside the editor, exposes the scene tree, project settings, scripts, runtime inspection, input simulation, etc. through a WebSocket API.

## Why Rust?

- **Single binary**: no Node.js runtime to install, no `npm install`, no dependency hell.
- **Small & fast**: release binaries are ~few MB and start instantly.
- **Cross-platform**: Windows, Linux, macOS from one codebase.
- **Distributable**: GitHub Actions can build signed releases automatically.

## Project layout

```
.
├── crates/mcp-server/      # Rust MCP server
├── godot_plugin/           # Godot addon (drop into your project)
├── test_project/           # Minimal Godot project used for integration tests
├── docs/                   # AI assistant guides and examples
│   ├── AI_ASSISTANT.md     # How to use the assistant with Kimi/Claude
│   └── EXAMPLES.md         # Copy-pasteable MCP walkthroughs
├── PROTOCOL.md             # WebSocket protocol between server and plugin
├── PLAN.md                 # Development plan and roadmap
└── .github/workflows/      # Release builds
```

## Current status

Version **0.1.0** — all core tool categories are implemented and manually tested end-to-end against Godot 4.7.

Implemented MCP tools:

- **Project & filesystem**: `get_project_info`, `get_project_settings`, `set_project_setting`, `get_filesystem_tree`, `search_files`
- **Scene tree**: `get_scene_tree`, `get_open_scenes`, `open_scene`, `save_scene`, `create_scene`, `add_scene_instance`
- **Node CRUD**: `add_node`, `delete_node`, `duplicate_node`, `move_node`, `rename_node`, `update_property`, `get_node_properties`, `get_editor_selection`, `select_nodes`, `find_nodes_by_type`, `connect_signal`, `disconnect_signal`, `get_node_groups`, `set_node_groups`
- **Scripts**: `list_scripts`, `read_script`, `create_script`, `edit_script`, `attach_script`, `validate_script`, `get_open_scripts`, `search_in_files`
- **Editor inspection**: `get_editor_errors`, `get_output_log`, `execute_editor_script`, `get_editor_screenshot`
- **Runtime control**: `play_scene`, `stop_scene`, `get_game_screenshot`, `simulate_key`, `simulate_mouse_click`
- **Input map**: `list_input_actions`, `add_input_action`, `remove_input_action`, `set_input_key`, `get_input_map`
- **3D & rendering**: `get_camera_3d_info`, `set_camera_3d_transform`, `get_environment_info`, `set_render_setting`
- **UI / audio / animation / resources**: `list_animations`, `play_animation`, `list_audio_streams`, `play_audio_preview`, `list_resources`, `get_resource_info`
- **Diagnostics**: `ping`

## Example: build a player scene with AI

A complete walkthrough that creates a playable `CharacterBody2D` player from scratch is available in [`docs/EXAMPLES.md`](docs/EXAMPLES.md). In a live Kimi / Claude session you can simply say:

> "Create a new 2D scene `game.tscn`, add a `CharacterBody2D` Player with a Sprite and Collision child, write a `player.gd` script for movement, attach it, and save."

The assistant will call the right sequence of MCP tools and the scene will appear inside Godot Editor in real time.

For prompt ideas, setup tips, and safety notes, see [`docs/AI_ASSISTANT.md`](docs/AI_ASSISTANT.md).

## Quick start

### 1. Install the Godot plugin

Copy `godot_plugin/addons/open_godot_mcp` into your Godot project's `addons/` folder, then enable it in **Project Settings → Plugins**.

The plugin starts a WebSocket server on port `6505` when the editor loads.

### 2. Build the Rust server

```bash
cargo build --release
# binary: target/release/open-godot-mcp-server
```

### 3. Configure your AI assistant

Add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "open-godot-mcp": {
      "command": "/path/to/open-godot-mcp-server"
    }
  }
}
```

Open Godot Editor with the plugin enabled, then start a new AI session. The server will connect to Godot automatically on port `6505`.

## Integration test

A minimal test project lives in `test_project/`. To run the end-to-end smoke test manually:

```bash
# 1. Open the test project in Godot Editor with the plugin enabled.
# 2. In another terminal, run the server and send MCP commands:
cd test_project
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"ping"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_project_info"}}' \
| ../target/release/open-godot-mcp-server
```

## Roadmap

- [x] Project & filesystem tools
- [x] Scene tree inspection and editing
- [x] Node CRUD
- [x] Script read / create / edit / validate
- [x] Editor inspection
- [x] Play/stop scene and runtime input simulation
- [x] Input map tools
- [x] 3D helpers (camera, environment, rendering settings)
- [x] UI / audio / animation / resource tools
- [x] AI assistant docs and examples
- [ ] UndoRedo integration for all mutating scene operations
- [ ] Material / shader / particle tools
- [ ] Export helpers
- [ ] Automated integration test harness

## License

MIT — see [LICENSE](LICENSE).
