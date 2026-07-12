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
- [~] Inspect the runtime scene tree — partially limited by Godot's process model.
- [~] Capture editor and game screenshots — editor screenshot implemented; game screenshot is blocked by separate game process.
- [~] Read editor errors and output logs — stubbed because Godot does not expose these logs through public API.

### Should-have capabilities (P1)

- [x] 3D helpers: camera transform, environment info, rendering settings.
- [~] Add mesh instances, lights, collision — not yet implemented.
- [~] UI/theme helpers — basic resource listing only.
- [x] Animation and AnimationTree tools — list + play via AnimationPlayer.
- [~] Audio bus/player setup — stream preview implemented.
- [~] Shader/material editing — not yet implemented.
- [~] Export preset helpers — not yet implemented.
- [x] Resource management — list + info.

### Nice-to-have capabilities (P2)

- [ ] TileMap tools.
- [ ] Navigation baking.
- [ ] Performance profiling monitors.
- [ ] Automated test scenarios and assertions.

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
- Godot-side operations currently mutate scenes directly; future work will route changes through `EditorUndoRedoManager`.

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

### Phase 10 — Polish (in progress)

- [x] README and PLAN refresh.
- [x] Integration test project.
- [ ] UndoRedo integration for mutating scene operations.
- [ ] Automated integration test harness.
- [ ] Plugin artifact packaging in CI.
- [ ] GitHub Release workflow.

## 4. Testing strategy

- **Rust unit tests**: JSON-RPC parsing, pending request map, tool schema generation.
- **Godot-side validation**: Each tool handler runs inside the editor and validates arguments before acting.
- **Integration tests**: a headless Godot project loads the plugin; a Rust test client sends commands and asserts responses.
- **Manual QA checklist**: one run through every tool category before release.

Current status: manual end-to-end smoke tests pass for all implemented tools.

## 5. Release strategy

- GitHub Actions builds release binaries for `x86_64-pc-windows-msvc`, `x86_64-unknown-linux-gnu`, `x86_64-apple-darwin`, `aarch64-apple-darwin`.
- CI also packages `addons/open_godot_mcp/` as a zip artifact.
- GitHub Release contains:
  - platform binaries;
  - `open-godot-mcp-plugin.zip`;
  - `PLAN.md`, `README.md`, `PROTOCOL.md`.
- Versioning follows SemVer starting at `0.1.0`.
