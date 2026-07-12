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

## Why Open Godot MCP? (Key Advantages vs. Competitors)

Unlike basic node-manipulation bridges or commercial plugins, **Open Godot MCP** is designed specifically to give AI assistants a professional developer's workspace. Here is why it stands out:

1. **100% Free & MIT Licensed**: No subscriptions, no telemetry, no seats, and no paywalls. It runs entirely locally on your machine.
2. **First-Class Undo/Redo Integration**: All mutating scene operations (adding, deleting, moving, renaming, updating properties, and changing signals/groups/scripts) are registered inside Godot's `EditorUndoRedoManager`. If the AI makes a mistake, you can revert it instantly with `Ctrl+Z` in the editor.
3. **Proactive Event Hooking (Self-Healing)**: It does not just wait for instructions. The server tails editor logs and connects to signals (`selection_changed`, `scene_changed`, `play_state_changed`) to push warning/error lines and selection updates to the AI. If the AI writes a script with compile warnings, it gets notified instantly and can auto-heal the code.
4. **Smart Design Helpers**: We build high-level abstract tools instead of forcing the AI to execute dozens of low-level commands:
   - **Procedural Scattering**: Scatter prefab scenes randomly with scale and rotation offsets in 2D or 3D zones in one step.
   - **Mesh-to-Collision**: Create concave/convex collision shapes for 3D meshes natively in the editor.
   - **UI Themes**: Set layout presets, theme overrides, and edit flat/nested StyleBoxes.
   - **Navigation & Audio**: Bake NavMeshes/NavPolygons and mix audio buses with ClassDB effects directly.
5. **In-Editor Physics Queries**: Execute 3D raycasting and 2D/3D Area overlaps inside the editor physics space without needing to launch a playtest.
6. **No Runtime Dependencies (Powered by Rust)**: Distributed as a single compiled binary (only few MBs). No Node.js runtime to install, no `npm install` dependency hell, and no giant `node_modules` bloating your project.

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

## Available MCP Tools & Capabilities

Open Godot MCP exposes **84 specialized tools** grouped by category to give AI assistants total engine control:

### 📁 Project & Filesystem
* `get_project_info`: Return metadata, Godot version, viewport size, and editor log path.
* `get_project_settings`: Read current `project.godot` settings.
* `set_project_setting`: Update and save project configuration.
* `get_filesystem_tree`: Retrieve directory structure recursively.
* `search_files`: Find files using glob/pattern match.

### 🌿 Scene Tree & Node CRUD
* `get_scene_tree`: Get structural JSON of the active scene tree.
* `get_open_scenes`: List currently open tabs.
* `open_scene`: Switch active tab to a specific scene.
* `save_scene`: Save the active scene on disk.
* `create_scene`: Create a new scene with custom root type.
* `add_scene_instance`: Instantiate a sub-scene.
* `add_node` / `delete_node`: Manage node life cycle.
* `duplicate_node` / `move_node` / `rename_node`: Reorganize scene structures.
* `update_property` / `get_node_properties`: Read and write node properties (handles `Vector2/3`, `Color`, etc.).
* `select_nodes` / `get_editor_selection`: Get/set selected nodes in the editor hierarchy.
* `find_nodes_by_type`: Query nodes by class type.
* `connect_signal` / `disconnect_signal`: Bind scene events to GDScript methods.
* `get_node_groups` / `set_node_groups`: Categorize nodes using groups.
* `scatter_prefabs`: Scatter prefab scene instances randomly with scale/rotation offsets in 2D or 3D zones in one step.

### ↩️ History Control (Undo/Redo)
* `undo` / `redo`: Undo or redo editor actions (including AI changes) directly inside the Godot history stack.

### 📝 GDScript Integration
* `list_scripts` / `get_open_scripts`: Inspect script files.
* `read_script` / `create_script` / `edit_script`: Full script CRUD.
* `attach_script`: Link a script to a node.
* `validate_script`: Dry-run compile check for syntax errors.
* `search_in_files`: Grep across script contents.

### 🎨 UI & Theme Layouts
* `set_control_anchors`: Configure responsive anchoring (Full Rect, Center, etc.) for Control nodes.
* `set_theme_override`: Add color, font, size overrides to Control nodes.
* `modify_stylebox`: Edit border radii, border widths, background colors on flat/nested StyleBoxes.

### 🧱 TileMaps & Grid Design
* `set_tilemap_cell`: Paint or clear grid cells (supports both `TileMap` and `TileMapLayer` nodes).
* `get_tilemap_cells`: Read the coordinates of painted grid cells.
* `list_tilemap_layers`: List grid layers and their names/visibilities.

### 🏃 AnimationTree & Locomotion
* `configure_animation_tree`: Connect an `AnimationTree` to an `AnimationPlayer` and activate it.
* `set_animation_tree_parameter`: Update blend positions, states, or parameter conditions.
* `create_animation_state_transition`: Connect animation states inside an `AnimationNodeStateMachine` with crossfades.

### 🔮 Shaders, Materials & VFX
* `set_material_shader`: Link a custom shader `.gdshader` to a `ShaderMaterial`.
* `set_shader_parameter`: Calibrate uniform parameters in real time.
* `configure_particle_system`: Configure properties on GPU/CPU particle systems (routes node vs material parameters automatically).

### 📐 Spatial Queries & Physics
* `perform_raycast_query_3d`: Run 3D raycast queries in the editor physics space (returns hit position, normal, collider path).
* `get_overlapping_bodies`: Query Area2D/3D overlapping bodies inside the editor physics state.
* `generate_collision_from_mesh`: Create trimesh (concave) or convex collision shapes from MeshInstance3D nodes.
* `bake_navigation`: Bake NavMesh or NavPolygon synchronously.

### 🔊 Audio Mixer
* `create_audio_bus`: Create new audio buses.
* `set_audio_bus_effect`: Attach ClassDB effects (Reverb, Delay, etc.) to mixer slots.
* `set_audio_bus_volume`: Set bus DB volume levels.

### 🚀 Headless Build & Export
* `list_export_presets`: List build presets.
* `run_project_export`: Trigger headless release/debug builds.

### 🎮 Runtime Control & Diagnostics
* `play_scene` / `stop_scene`: Playtest active scenes.
* `simulate_key` / `simulate_mouse_click`: Send keyboard/mouse inputs for automated playtesting.
* `get_editor_screenshot`: Capture active editor viewport as a PNG.
* `get_performance_diagnostics`: Query engine stats (FPS, memory, draw calls, active bodies).
* `ping`: Server status check.

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
