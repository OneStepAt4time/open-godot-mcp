# Open Godot MCP — Development Plan

This plan follows a professional SDLC: requirements → design → iterative implementation → integration tests → release.

## 1. Requirements

Provide a free, open-source MCP server that lets AI assistants inspect and control Godot Editor 4.x as deeply as commercial alternatives.

### Must-have capabilities (P0)

- [x] Read project metadata and filesystem.
- [x] Inspect and edit the current scene tree.
- [x] Create/delete/move/rename nodes and edit their properties.
- [x] Read, create, edit, attach and validate GDScript files.
- [x] Run/stop the game and simulate input.
- [x] Inspect the runtime scene tree — partially limited by Godot's process model.
- [x] Capture editor and game screenshots — editor screenshot implemented.
- [x] Read editor errors and output logs — fully implemented via robust log tailing and async notifications.

### Should-have capabilities (P1)

- [x] 3D helpers: camera transform, environment info, rendering settings.
- [x] Add mesh instances, lights, collision.
- [x] UI/theme helpers — implemented via layout anchors, overrides, and stylebox modifications.
- [x] Animation and AnimationTree tools — configure trees, blend parameters, and locomotion transitions.
- [x] Audio bus/player setup — create buses, adjust volume, and insert effects.
- [x] Shader/material editing — load custom shaders and update uniforms (parameters).
- [x] Export preset helpers — list export presets and trigger headless builds.
- [x] Resource management — list + info.

### Nice-to-have capabilities (P2)

- [x] TileMap tools (painting cells, reading used cells, inspecting layers).
- [x] Spatial raycasting and overlap queries (Area2D/3D inspection).
- [ ] Automated test scenarios and assertions (currently manual smoke tests via `test_project/`).
- [x] Navigation baking (2D/3D NavigationRegion baking).
- [x] Performance profiling monitors (FPS, draw calls, memory, active bodies).

## 2. Design

### Architecture

```
AI client  ← stdio MCP →  open-godot-mcp-server (Rust)
                              │
                              │ WebSocket JSON-RPC
                              ▼
                    Godot Editor plugin (GDScript)
                              │
                              │ EditorInterface / SceneTree / InputMap
                              ▼
                           Godot Editor
```

### Protocol

Messages between Rust server and Godot plugin are documented in `PROTOCOL.md`.
Each request has a `request_id`, `method`, and optional `params`.
Responses carry the same `request_id` plus either `result` or `error`.

### Tool schema conventions

- Tool names use `snake_case`.
- Arguments are declared as JSON Schema inside `tools/list`.
- Results are returned as MCP `text` content; complex data is JSON-stringified.
- All mutating scene operations are routed through Godot's `EditorUndoRedoManager`, so AI edits are fully undoable in the editor.

## 3. Implementation phases

### Phase 0 — Foundation (done)

- Rust stdio MCP loop.
- WebSocket client/server.
- First end-to-end tools: `get_project_info`, `ping`.
- CI build workflow.

### Phase 1 — Project & Filesystem (done)

Tools: `get_project_info`, `get_project_settings`, `set_project_setting`, `get_filesystem_tree`, `search_files`.

### Phase 2 — Scene tree inspection (done)

Tools: `get_scene_tree`, `get_open_scenes`, `open_scene`, `save_scene`, `create_scene`, `add_scene_instance`.

### Phase 3 — Node editing (done)

Tools: `add_node`, `delete_node`, `duplicate_node`, `move_node`, `rename_node`, `update_property`, `get_node_properties`, `get_editor_selection`, `select_nodes`, `find_nodes_by_type`, `connect_signal`, `disconnect_signal`, `get_node_groups`, `set_node_groups`.

### Phase 4 — Scripts (done)

Tools: `list_scripts`, `read_script`, `create_script`, `edit_script`, `attach_script`, `validate_script`, `get_open_scripts`, `search_in_files`.

### Phase 5 — Editor inspection (done)

Tools: `get_editor_errors`, `get_output_log`, `execute_editor_script`, `get_editor_screenshot`.
Notes: error/output log tools are stubs because Godot's public API does not expose them.

### Phase 6 — Runtime control (done)

Tools: `play_scene`, `stop_scene`, `get_game_screenshot`, `simulate_key`, `simulate_mouse_click`.
Notes: `get_game_screenshot` is not feasible when the game runs in a separate process.

### Phase 7 — Input map (done)

Tools: `list_input_actions`, `add_input_action`, `remove_input_action`, `set_input_key`, `get_input_map`.

### Phase 8 — 3D & rendering (done)

Tools: `get_camera_3d_info`, `set_camera_3d_transform`, `get_environment_info`, `set_render_setting`.

### Phase 9 — UI, audio, animation, resources (done)

Tools: `list_animations`, `play_animation`, `list_audio_streams`, `play_audio_preview`, `list_resources`, `get_resource_info`.

### Phase 10 — Polish (done)

- [x] README and PLAN refresh.
- [x] Integration test project.
- [x] UndoRedo integration for all mutating scene operations.
- [x] Manual integration test project (`test_project/`). An automated test harness is on the roadmap.
- [x] Plugin artifact packaging in CI.
- [x] GitHub Release workflow.

### Phase 11 — Advanced Editor Features (done)

Added support for:
* **UI Themes**: Set layout presets, theme overrides, stylebox properties.
* **TileMaps**: Programmatic cell painting and inspection (TileMap & TileMapLayer).
* **State Machines**: AnimationTree configuration, blend positions, locomotion state transitions.
* **Shaders & VFX**: Custom shader binding, uniform editing, CPU/GPU particle systems.
* **Spatial Queries & Physics**: Editor-only 3D raycasting, 2D/3D Area overlaps, concave/convex collision generation from MeshInstance3Ds, and 2D/3D NavigationRegion baking.
* **Audio Mixer**: Audio bus creation, volume DB levels, real-time effects slots.
* **Project Export**: Parsed preset configurations and triggered headless builds.
* **Procedural Scattering**: Scatter prefab scene instances randomly with scale/rotation offsets in 2D or 3D zones.
* **Performance Profiling**: Retrieve active engine and editor performance diagnostics (FPS, draw calls, memory, active bodies).

## 4. Testing strategy

- **Rust unit tests**: JSON-RPC parsing, pending request map, tool schema generation.
- **Godot-side validation**: Each tool handler runs inside the editor and validates arguments before acting.
- **Integration tests**: a headless Godot project loads the plugin; a Rust test client sends commands and asserts responses.
- **Manual QA checklist**: one run through every tool category before release.

Current status: manual end-to-end smoke tests pass for all implemented tools.

## 5. Release strategy

- Releases are published by pushing a git tag `vX.Y.Z` (e.g. `git tag -a v0.1.2 -m "v0.1.2" && git push origin v0.1.2`). The tag name must match `[workspace.package] version` in `Cargo.toml` and the `version` fields in both `plugin.cfg` files — CI enforces this.
- GitHub Actions builds release binaries for `x86_64-pc-windows-msvc`, `x86_64-unknown-linux-gnu`, `x86_64-apple-darwin`, `aarch64-apple-darwin` and packages `godot_plugin/addons/open_godot_mcp/` as `open-godot-mcp-plugin.zip`.
- The GitHub Release is created automatically with generated release notes.
- The canonical plugin lives in `godot_plugin/`; the copy in `test_project/addons/` must be kept in sync with it.
- Versioning follows SemVer starting at `0.1.0`.
