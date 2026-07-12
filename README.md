# Open Godot MCP — AI Assistant for Godot Game Development

[![GitHub Sponsors](https://img.shields.io/github/sponsors/OneStepAt4time?color=ea4aaa&style=flat-square)](https://github.com/sponsors/OneStepAt4time)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-yellow?style=flat-square&logo=buy-me-a-coffee)](https://www.buymeacoffee.com/OneStepAt4time)

A free, open-source, Rust-powered [Model Context Protocol](https://modelcontextprotocol.io/) server for **Godot Engine 4**.

> **Goal**: turn Kimi Code, Claude Code, Cursor, or any MCP-compatible assistant into a hands-on collaborator for building Godot games — giving it the same deep editor control that commercial solutions lock behind a paywall, but as a downloadable, self-hostable, MIT-licensed binary.

With Open Godot MCP, an AI assistant can inspect scenes, create and edit nodes, write and attach GDScript, run the game, simulate input, query 3D cameras, and capture editor screenshots — all through a local WebSocket bridge.

The assistant also receives **proactive events** from Godot: editor errors, log output, scene changes, and play/stop state changes are pushed to the MCP client as notifications, so the AI notices problems without being asked.

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

Version **0.1.2** — all core tool categories are implemented, fully integrated with Godot's undo history, proactive event hooks, and thoroughly tested end-to-end against Godot 4.

Implemented MCP tools:

- **Project & filesystem**: `get_project_info`, `get_project_settings`, `set_project_setting`, `get_filesystem_tree`, `search_files`
- **Scene tree**: `get_scene_tree`, `get_open_scenes`, `open_scene`, `save_scene`, `create_scene`, `add_scene_instance`
- **Node CRUD**: `add_node`, `delete_node`, `duplicate_node`, `move_node`, `rename_node`, `update_property`, `get_node_properties`, `get_editor_selection`, `select_nodes`, `find_nodes_by_type`, `connect_signal`, `disconnect_signal`, `get_node_groups`, `set_node_groups`, `scatter_prefabs` (randomized layout scattering)
- **Undo / Redo**: `undo`, `redo` (mutations are fully undoable within the editor history)
- **Scripts**: `list_scripts`, `read_script`, `create_script`, `edit_script`, `attach_script`, `validate_script`, `get_open_scripts`, `search_in_files`
- **UI & Theme Layout**: `set_control_anchors`, `set_theme_override`, `modify_stylebox` (flat and themed StyleBox modifications)
- **TileMaps & Grid Design**: `set_tilemap_cell`, `get_tilemap_cells`, `list_tilemap_layers` (supports both `TileMap` and `TileMapLayer` nodes)
- **AnimationTree & Locomotion**: `configure_animation_tree`, `set_animation_tree_parameter`, `create_animation_state_transition` (custom state machines)
- **Shaders, Materials & VFX**: `set_material_shader`, `set_shader_parameter`, `configure_particle_system` (CPU/GPU particle material smarth-routing)
- **Spatial Queries & Physics**: `perform_raycast_query_3d`, `get_overlapping_bodies`, `generate_collision_from_mesh` (concave/convex mesh collision generation), `bake_navigation` (NavMesh/NavPoly baking)
- **Audio Mixer & Mixer**: `create_audio_bus`, `set_audio_bus_effect`, `set_audio_bus_volume`
- **Headless Build & Export**: `list_export_presets`, `run_project_export`
- **Editor inspection**: `get_editor_errors`, `get_output_log`, `execute_editor_script`, `get_editor_screenshot`
- **Runtime control**: `play_scene`, `stop_scene`, `get_game_screenshot`, `simulate_key`, `simulate_mouse_click`
- **Input map**: `list_input_actions`, `add_input_action`, `remove_input_action`, `set_input_key`, `get_input_map`
- **3D & rendering**: `get_camera_3d_info`, `set_camera_3d_transform`, `get_environment_info`, `set_render_setting`
- **Audio & Animations**: `list_animations`, `play_animation`, `list_audio_streams`, `play_audio_preview`, `list_resources`, `get_resource_info`
- **Diagnostics**: `ping`, `get_performance_diagnostics` (engine stats, FPS, memory, draw calls)

## Example: build a player scene with AI

A complete walkthrough that creates a playable `CharacterBody2D` player from scratch is available in [`docs/EXAMPLES.md`](docs/EXAMPLES.md). In a live Kimi / Claude session you can simply say:

> "Create a new 2D scene `game.tscn`, add a `CharacterBody2D` Player with a Sprite and Collision child, write a `player.gd` script for movement, attach it, and save."

The assistant will call the right sequence of MCP tools and the scene will appear inside Godot Editor in real time.

For prompt ideas, setup tips, and safety notes, see [`docs/AI_ASSISTANT.md`](docs/AI_ASSISTANT.md).

## Quick start

### 1. Install the Godot plugin

Copy `godot_plugin/addons/open_godot_mcp` into your Godot project's `addons/` folder, then enable it in **Project Settings → Plugins**.

The plugin starts a WebSocket server on port `6505` when the editor loads.

### 2. Get the Rust server

Download the pre-built binary for your platform from the [v0.1.2 release](https://github.com/OneStepAt4time/open-godot-mcp/releases/tag/v0.1.2), or build it locally:

```bash
cargo build --release
# binary: target/release/open-godot-mcp-server
```

### 3. Configure your AI client / editor

Here is how to configure the server for different popular tools:

#### A. Claude Desktop / Claude Code / Kimi Code

Create or edit your configuration file:
* **Windows (Claude Desktop)**: `%APPDATA%\Claude\claude_desktop_config.json`
* **macOS (Claude Desktop)**: `~/Library/Application Support/Claude/claude_desktop_config.json`
* **Claude Code / general**: `.mcp.json` in your project or home folder.

Add the following to the `mcpServers` object:

```json
{
  "mcpServers": {
    "open-godot-mcp": {
      "command": "C:/path/to/open-godot-mcp-server.exe",
      "args": []
    }
  }
}
```

*(Note: On Windows, use forward slashes `/` in the file path to avoid escape character errors).*

#### B. Cursor Editor

1. Open Cursor and go to **Settings → Features → MCP**.
2. Click **+ Add New MCP Server**.
3. Fill out the dialog:
   * **Name**: `open-godot-mcp`
   * **Type**: `command`
   * **Command**: `C:/path/to/open-godot-mcp-server.exe` (use absolute path)
4. Click **Save**.

#### C. Command Line Arguments (Optional)

The server supports the following CLI options:
* `--godot-port <PORT>`: The port the Godot Editor plugin WebSocket is running on (default: `6505`).
* `--log-file <PATH>`: Explicitly provide the absolute path to the Godot log file to tail, rather than auto-discovering it.

---

Open your Godot project with the plugin enabled, then start your AI assistant session. The server connects to the editor automatically, giving the AI full control!

### 4. Reloading the plugin after code changes

If you edit the plugin's GDScript files, Godot will not always pick up the changes while the editor is running. Use the MCP tool:

```json
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"reload_plugin","arguments":{}}}
```

The plugin disables and re-enables itself, the Rust server detects the temporary disconnect and reconnects automatically, and the AI client receives a `notifications/tools/list_changed` notification so it can refresh its tool cache.

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

## Proactive events

When the Godot plugin is enabled, it continuously monitors the editor and pushes events to the MCP client:

- **Scene changes** are reported as `notifications/godot/event` with the new scene path.
- **Play/stop** toggles are reported as `notifications/godot/event` with the current playing state.
- **Log/error lines** are tailed by the Rust server from the editor log file and forwarded as `notifications/message` with level `info`, `warning`, or `error`.

This lets the assistant react to errors and state changes as they happen, instead of relying on the user to notice and report them. Scene/play events require only the plugin. Log tailing works automatically when the editor log file is readable by the server process (e.g. when Godot is launched with its stdout/stderr redirected to a log file).

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
- [x] UndoRedo integration for all mutating scene operations
- [x] Material / shader / particle tools
- [x] Export helpers
- [x] Automated integration test harness
- [x] Plugin artifact packaging in CI
- [x] GitHub Release workflow with cross-platform binaries
- [ ] Asset import and resource pipeline helpers
- [ ] MCP resources / prompts for Godot documentation
- [ ] Editor refactoring tools (extract node, rename symbol across project)

## 💖 Support the Development

Open Godot MCP is a community-driven, 100% free and open-source project. Keeping it up-to-date with new Godot releases and adding advanced editor features takes time and dedication. 

If this tool has saved you time, improved your workflow, or wowed your game design process, please consider supporting its development:
- ⭐ **Star this repository** on GitHub — it's free and helps others discover the project!
- **[Sponsor via GitHub](https://github.com/sponsors/OneStepAt4time)** (Recurring or one-time)
- **[Buy Me a Coffee](https://www.buymeacoffee.com/OneStepAt4time)** (Fast & direct support)

Every bit of support helps keep this project free, fast, and open to everyone!

## 🤝 Contributions, Feedback & Testing

This project is **open for contributions**! Whether you are a veteran game developer, a rustacean, an AI researcher, or a hobbyist designer, you are highly welcome here.

How you can help and get involved:
- **Test the Server**: Download the plugin, run the server, and let us know how it works in your daily workflow.
- **Report Bugs & Suggest Issues**: Encountered a glitch or a crash? Open an issue on GitHub to report bugs.
- **Request Features**: Want support for new systems, C# script support, or custom asset importers? Open an issue or a discussion thread.
- **Submit Pull Requests**: Want to add code? Look at open issues or submit PRs directly. Every improvement is appreciated!
- **Ask Questions / Share Ideas**: Feel free to start discussions on anything, no matter how small. 

Let's build the ultimate AI assistant bridge for Godot Engine together!

## License

MIT — see [LICENSE](LICENSE).
