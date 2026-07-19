# Open Godot MCP — AI Assistant for Godot Game Development

[![CI](https://github.com/OneStepAt4time/open-godot-mcp/actions/workflows/release.yml/badge.svg)](https://github.com/OneStepAt4time/open-godot-mcp/actions/workflows/release.yml)
[![Latest release](https://img.shields.io/github/v/release/OneStepAt4time/open-godot-mcp?display_name=tag)](https://github.com/OneStepAt4time/open-godot-mcp/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Godot 4.3+](https://img.shields.io/badge/Godot-4.3%2B-478CBF?logo=godot-engine&logoColor=white)](https://godotengine.org)

A free, open-source, Rust-powered [Model Context Protocol](https://modelcontextprotocol.io/) server for **Godot Engine 4.3+**.

> **Goal**: turn Kimi Code, Claude Code, Cursor, or any MCP-compatible assistant into a hands-on collaborator for building Godot games — with the deep editor control that commercial solutions lock behind a paywall, as a downloadable, self-hostable, MIT-licensed binary.

With Open Godot MCP, an AI assistant can inspect scenes, create and edit nodes, write and attach GDScript, run the game, simulate input, query 3D cameras, and capture editor screenshots — all through a local WebSocket bridge.

The assistant also receives **proactive events** from Godot: editor errors, log output, scene changes, and play/stop state changes are pushed to the MCP client as notifications, so the AI notices problems without being asked.

![Open Godot MCP trailer: a 3D scene designed, built and animated entirely through MCP tools, rendered in-engine](docs/media/open-godot-mcp-demo.gif)

*Everything you see — the clay robot, the lighting rig, the environment, the animation — was designed, assembled and scripted through Open Godot MCP tools, then rendered in-engine (Godot Movie Maker). The scene (`test_project/kimi3d_final5.tscn`) rebuilds itself live when opened.*

**Watch it happen live in the editor**: [screen recording of an AI driving the Godot editor through MCP](docs/media/open-godot-mcp-editor-demo.gif) — parts created one by one, undo/redo reverting and restoring the work in real time.

**Contents**: [Why Open Godot MCP](#why-open-godot-mcp) · [How it compares](#how-it-compares) · [Quick start](#quick-start) · [Architecture](#architecture) · [Tools (84)](#available-mcp-tools--capabilities) · [Troubleshooting](#troubleshooting) · [Roadmap](#roadmap) · [Support](#-support-the-development) · [Contributing](#-contributions-feedback--testing)

## Why Open Godot MCP?

Unlike basic node-manipulation bridges or commercial plugins, **Open Godot MCP** is designed to give AI assistants a professional developer's workspace:

1. **100% Free & MIT Licensed**: No subscriptions, no telemetry, no seats, no paywalls. It runs entirely locally on your machine.
2. **First-Class Undo/Redo Integration**: All mutating scene operations (adding, deleting, moving, renaming, updating properties, changing signals/groups/scripts) are registered inside Godot's `EditorUndoRedoManager`. If the AI makes a mistake, revert it instantly with `Ctrl+Z` in the editor. Among free servers, this level of undo integration is unique — elsewhere it is a paid feature.
3. **Proactive Event Hooking (Self-Healing)**: It does not just wait for instructions. The server tails editor logs and listens to editor signals (`selection_changed`, `scene_changed`, `play_state_changed`) to push warning/error lines and selection updates to the AI. If the AI writes a script with compile warnings, it gets notified instantly and can auto-heal the code.
4. **Smart Design Helpers**: High-level tools instead of dozens of low-level commands:
   - **Procedural Scattering**: Scatter prefab scenes with scale and rotation offsets in 2D or 3D zones in one step.
   - **Mesh-to-Collision**: Create concave/convex collision shapes for 3D meshes natively in the editor.
   - **UI Themes**: Set layout presets, theme overrides, and edit flat/nested StyleBoxes.
   - **Navigation & Audio**: Bake NavMeshes/NavPolygons and mix audio buses with ClassDB effects directly.
5. **In-Editor Physics Queries**: Execute 3D raycasting and 2D/3D Area overlaps inside the editor physics space without launching a playtest.
6. **No Runtime Dependencies (Powered by Rust)**: A single compiled binary of only a few MBs. No Node.js runtime, no Python environment, no .NET/Mono build of Godot required.

## How it compares

The Godot + MCP space is active and there are several good projects. Here is how Open Godot MCP positions itself, based on the projects' public documentation (July 2026 — these projects evolve, so check their repos):

| | Price | License | Runtime required | Full undo/redo | Proactive events | Tools |
|---|---|---|---|---|---|---|
| **Open Godot MCP** | Free | MIT | **None** (single Rust binary) | ✅ | ✅ | 84 |
| [GDAI MCP](https://gdaimcp.com/) | $19 | Proprietary | None (closed binary) | ✅ | — | ~30 |
| [Godot MCP Pro](https://github.com/youichi-uda/godot-mcp-pro) | $15 | Proprietary | Node.js (closed server) | ✅ | — | 175 |
| [godot-ai](https://github.com/hi-godot/godot-ai) | Free | MIT | Python (uv) | — | — | ~43 |
| [GoPeak](https://github.com/HaD0Yun/doyunha-gopeak) | Free | MIT | Node.js | — | — | 95+ |
| [godot-mcp](https://github.com/Coding-Solo/godot-mcp) | Free | MIT | Node.js | — | — | ~13 |

*"—" = not advertised in the project's public documentation. Tool counts as advertised by each project.*

In short: Open Godot MCP is the **only free option with full undo/redo and proactive editor events**, and the **only one shipped as a single Rust binary** with zero runtime dependencies. If you specifically need an LSP or DAP debugger integration, take a look at GoPeak — we focus on deep editor automation instead.

## Quick start

**Prerequisites**: Godot **4.3 or newer** (the plugin uses `EditorInterface.get_editor_undo_redo()` and `TileMapLayer`, both added in 4.3), and an MCP-compatible client. A Rust toolchain is only needed if you build the server from source.

### 1. Install the Godot plugin

Download `open-godot-mcp-plugin.zip` from the [latest release](https://github.com/OneStepAt4time/open-godot-mcp/releases/latest) and extract it into your project's `addons/` folder (or copy `godot_plugin/addons/open_godot_mcp` from this repository). Then enable it in **Project Settings → Plugins**.

The plugin starts a WebSocket server on `127.0.0.1:6505` (localhost only) when the editor loads.

> Note: on first activation the plugin enables file logging in your project settings (required for error notifications) and saves `project.godot`. This is expected.

### 2. Get the Rust server

Download the pre-built binary for your platform (Windows, macOS x86_64/ARM, Linux) from the [latest release](https://github.com/OneStepAt4time/open-godot-mcp/releases/latest), or build it locally:

```bash
cargo build --release
# binary: target/release/open-godot-mcp-server (.exe on Windows)
```

### 3. Configure your AI client / editor

#### A. Claude Desktop / Claude Code

Create or edit your configuration file:
* **Windows (Claude Desktop)**: `%APPDATA%\Claude\claude_desktop_config.json`
* **macOS (Claude Desktop)**: `~/Library/Application Support/Claude/claude_desktop_config.json`
* **Claude Code**: `.mcp.json` in your project or home folder.

#### B. Kimi Code

Create or edit `.kimi-code/mcp.json` in your project (or `~/.kimi-code/mcp.json` globally).

#### C. Cursor

Edit `~/.cursor/mcp.json`, or use **Settings → Features → MCP → + Add New MCP Server** with type `command`.

#### Configuration (all clients)

Add the following to the `mcpServers` object, adjusting the path to where you put the binary:

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

*(On Windows, use forward slashes `/` in the path to avoid escape errors. On macOS/Linux, point to the bare binary, e.g. `/usr/local/bin/open-godot-mcp-server`.)*

#### D. Command Line Arguments (Optional)

* `--godot-port <PORT>`: The port the Godot Editor plugin WebSocket is running on (default: `6505`).
* `--log-file <PATH>`: Explicitly provide the absolute path to the Godot log file to tail, rather than auto-discovering it.

---

Open your Godot project with the plugin enabled, then start your AI assistant session. The server connects to the editor automatically.

> **One editor at a time**: the plugin listens on a fixed port, so if you run multiple Godot editor instances, the first one wins and the AI will connect to that project. See [Troubleshooting](#troubleshooting).

### 4. Reloading the plugin after code changes

If you edit the plugin's GDScript files, use the `reload_plugin` MCP tool (or just ask your assistant to reload the plugin). The plugin disables and re-enables itself, the Rust server detects the temporary disconnect and reconnects automatically, and the AI client receives a `notifications/tools/list_changed` notification so it can refresh its tool cache.

## Architecture

```
AI assistant  ← stdio MCP →  open-godot-mcp-server (Rust)  ← WebSocket (localhost) →  Godot Editor plugin (GDScript)
```

- **Rust server**: single binary, cross-platform, speaks MCP over stdio. Auto-reconnects if the editor or plugin restarts.
- **Godot plugin**: runs inside the editor, exposes the scene tree, project settings, scripts, runtime inspection, input simulation, etc. through a WebSocket API bound to `127.0.0.1`.

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

Version **0.1.2** — all core tool categories are implemented, fully integrated with Godot's undo history, with proactive event hooks, and manually smoke-tested end-to-end against Godot 4.x. An automated test suite in CI is on the [roadmap](#roadmap).

## Available MCP Tools & Capabilities

Open Godot MCP exposes **84 specialized tools** grouped by category:

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
* `scatter_prefabs`: Scatter prefab scene instances with scale/rotation offsets in 2D or 3D zones in one step.

### ↩️ History Control (Undo/Redo)
* `undo` / `redo`: Undo or redo editor actions (including AI changes) directly inside the Godot history stack.

### 📝 GDScript Integration
* `list_scripts` / `get_open_scripts`*: Inspect script files.
* `read_script` / `create_script` / `edit_script`: Full script CRUD.
* `attach_script`: Link a script to a node.
* `validate_script`: Dry-run compile check for syntax errors.
* `search_in_files`: Grep across script contents.
* `execute_editor_script`: Execute arbitrary GDScript in the editor context — the most powerful escape hatch. **Handle with care**: it can do anything the editor can do.

### 🎨 UI & Theme Layouts
* `set_control_anchors`: Configure responsive anchoring (Full Rect, Center, etc.) for Control nodes.
* `set_theme_override`: Add color, font, size overrides to Control nodes.
* `modify_stylebox`: Edit border radii, border widths, background colors on flat/nested StyleBoxes.

### 🧱 TileMaps & Grid Design
* `set_tilemap_cell`: Paint or clear grid cells (supports both `TileMap` and `TileMapLayer` nodes).
* `get_tilemap_cells`: Read the coordinates of painted grid cells.
* `list_tilemap_layers`: List grid layers and their names/visibilities.

### 🏃 Animation
* `configure_animation_tree`: Connect an `AnimationTree` to an `AnimationPlayer` and activate it.
* `set_animation_tree_parameter`: Update blend positions, states, or parameter conditions.
* `create_animation_state_transition`: Connect animation states inside an `AnimationNodeStateMachine` with crossfades.
* `list_animations`: List animations available on a node.
* `play_animation`: Play an animation in the editor.

### 🔮 Shaders, Materials & VFX
* `set_material_shader`: Link a custom shader `.gdshader` to a `ShaderMaterial`.
* `set_shader_parameter`: Calibrate uniform parameters in real time.
* `configure_particle_system`: Configure properties on GPU/CPU particle systems (routes node vs material parameters automatically).

### 🌐 3D & Rendering
* `get_camera_3d_info` / `set_camera_3d_transform`: Inspect and position editor 3D cameras.
* `get_environment_info`: Read WorldEnvironment settings.
* `set_render_setting`: Change rendering settings.

### 📐 Spatial Queries & Physics
* `perform_raycast_query_3d`: Run 3D raycast queries in the editor physics space (returns hit position, normal, collider path).
* `get_overlapping_bodies`: Query Area2D/3D overlapping bodies inside the editor physics state.
* `generate_collision_from_mesh`: Create trimesh (concave) or convex collision shapes from MeshInstance3D nodes.
* `bake_navigation`: Bake NavMesh or NavPolygon synchronously.

### 🔊 Audio
* `create_audio_bus`: Create new audio buses.
* `set_audio_bus_effect`: Attach ClassDB effects (Reverb, Delay, etc.) to mixer slots.
* `set_audio_bus_volume`: Set bus DB volume levels.
* `list_audio_streams`: List audio streams in the project.
* `play_audio_preview`: Preview an audio stream in the editor.

### ⌨️ Input Map
* `list_input_actions` / `get_input_map`: Inspect the project's input map.
* `add_input_action` / `remove_input_action`: Manage input actions.
* `set_input_key`: Bind keys to input actions.

### 📦 Resources
* `list_resources`: List resources in the project.
* `get_resource_info`: Inspect a resource's properties.

### 🚀 Headless Build & Export
* `list_export_presets`: List build presets.
* `run_project_export`: Trigger headless release/debug builds (long-running; has an extended timeout).

### 🎮 Runtime Control & Diagnostics
* `play_scene` / `stop_scene`: Playtest active scenes.
* `simulate_key` / `simulate_mouse_click`: Send keyboard/mouse inputs for automated playtesting.
* `get_editor_screenshot`: Capture active editor viewport as a PNG.
* `get_game_screenshot`*: Capture the running game viewport.
* `get_performance_diagnostics`: Query engine stats (FPS, memory, draw calls, active bodies).
* `get_editor_errors`* / `get_output_log`*: Read recent editor errors and output (best-effort, via log tailing).
* `reload_plugin`: Hot-reload the Open Godot MCP plugin after script changes.
* `ping`: Server status check.

*\* These tools are currently limited or best-effort; see their descriptions via `tools/list` for details.*

## Example: build a player scene with AI

A complete walkthrough that creates a playable `CharacterBody2D` player from scratch is available in [`docs/EXAMPLES.md`](docs/EXAMPLES.md). In a live Kimi / Claude session you can simply say:

> "Create a new 2D scene `game.tscn`, add a `CharacterBody2D` Player with a Sprite and Collision child, write a `player.gd` script for movement, attach it, and save."

The assistant will call the right sequence of MCP tools and the scene will appear inside Godot Editor in real time.

For prompt ideas, setup tips, and safety notes, see [`docs/AI_ASSISTANT.md`](docs/AI_ASSISTANT.md).

## Proactive events

When the Godot plugin is enabled, it continuously monitors the editor and pushes events to the MCP client:

- **Scene changes** are reported as `notifications/godot/event` with the new scene path.
- **Play/stop** toggles are reported as `notifications/godot/event` with the current playing state.
- **Log/error lines** are tailed by the Rust server from the editor log file and forwarded as `notifications/message` with level `info`, `warning`, or `error`.

This lets the assistant react to errors and state changes as they happen, instead of relying on the user to notice and report them. Scene/play events require only the plugin. Log tailing works automatically when the editor log file is readable by the server process (e.g. when Godot is launched with its stdout/stderr redirected to a log file).

## Troubleshooting

* **"Failed to listen on port 6505" in the Godot Debugger panel**: another process (often a second Godot editor) already holds the port. Only one editor instance can serve the bridge at a time — close the other instance or the application using the port.
* **The AI does not see any Godot tools / the server cannot connect**: make sure the plugin is enabled (**Project Settings → Plugins**) and that you are running Godot **4.3 or newer**. On older versions the plugin logs a clear startup error and does not start the bridge.
* **The AI modified the wrong project**: with multiple editor instances open, the first one to grab port 6505 wins. Work with one Godot editor at a time for now.
* **No error/log notifications**: log tailing requires the editor log file to be readable by the server process (launch Godot with stdout/stderr redirected to a file, or rely on the file logging the plugin auto-enables).
* **Windows firewall / antivirus warnings**: the bridge uses a localhost-only WebSocket (`127.0.0.1:6505`); allow local connections for the server binary.
* **Client config issues on Windows**: use forward slashes (`C:/path/to/...`) in JSON configuration files.

## Security

The bridge is bound to **localhost only** (`127.0.0.1`) and accepts no remote connections. Be aware that it gives the connected AI client **full control of the editor** — including `execute_editor_script`, which can run arbitrary GDScript. Only connect clients you trust, and never expose port 6505 to a network. See [SECURITY.md](SECURITY.md) for details and for how to report vulnerabilities.

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
- [x] UndoRedo integration for all mutating scene operations
- [x] Material / shader / particle tools
- [x] Export helpers
- [x] Plugin artifact packaging in CI
- [x] GitHub Release workflow with cross-platform binaries
- [ ] Automated test suite in CI (unit + integration)
- [ ] Configurable bridge port and multi-editor support
- [ ] Status dock inside the Godot editor (connection state, client info)
- [ ] Asset import and resource pipeline helpers
- [ ] MCP resources / prompts for Godot documentation
- [ ] Editor refactoring tools (extract node, rename symbol across project)

## 💖 Support the Development

Open Godot MCP is a community-driven, 100% free and open-source project. Keeping it up-to-date with new Godot releases and adding advanced editor features takes time and dedication.

If this tool has saved you time, improved your workflow, or wowed your game design process, please consider supporting its development:
- ⭐ **Star this repository** on GitHub — it costs nothing, takes one second, and is the easiest way to help others discover the project. Every star genuinely makes a difference!
- **[Sponsor via GitHub](https://github.com/sponsors/OneStepAt4time)** (Recurring or one-time)
- **[Buy Me a Coffee](https://www.buymeacoffee.com/OneStepAt4time)** (Fast & direct support)

[![GitHub Sponsors](https://img.shields.io/github/sponsors/OneStepAt4time?color=ea4aaa&style=flat-square)](https://github.com/sponsors/OneStepAt4time)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-yellow?style=flat-square&logo=buy-me-a-coffee)](https://www.buymeacoffee.com/OneStepAt4time)

Every bit of support helps keep this project free, fast, and open to everyone!

## 🤝 Contributions, Feedback & Testing

This project is **open for contributions**! Whether you are a veteran game developer, a rustacean, an AI researcher, or a hobbyist designer, you are highly welcome here.

How you can help and get involved:
- **Test the Server**: Download the plugin, run the server, and let us know how it works in your daily workflow.
- **Report Bugs**: Encountered a glitch or a crash? [Open an issue](https://github.com/OneStepAt4time/open-godot-mcp/issues) on GitHub.
- **Request Features**: Want support for new systems, C# script support, or custom asset importers? Open an issue describing your use case.
- **Submit Pull Requests**: Want to add code? Look at open issues or submit PRs directly — see [CONTRIBUTING.md](CONTRIBUTING.md). Every improvement is appreciated!

Let's build the ultimate AI assistant bridge for Godot Engine together!

## License

MIT — see [LICENSE](LICENSE).
