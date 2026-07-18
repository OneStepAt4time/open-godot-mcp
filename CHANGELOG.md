# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-07-18

### Added
- Proactive event hooks: editor signals (`scene_changed`, `play_state_changed`, `selection_changed`) are pushed to the MCP client as notifications.
- Full undo/redo integration for all mutating scene operations via `EditorUndoRedoManager`.
- Full tool catalog of 84 tools across 15 categories, including input map, 3D/rendering helpers, resources, animation playback and editor diagnostics.
- `reload_plugin` hot-reload with automatic server reconnection and `notifications/tools/list_changed`.
- Editor and game screenshot tooling.
- CI: tag-vs-version consistency check (Cargo.toml + both plugin.cfg) and generated release notes.
- Docs: comparison table, troubleshooting section, SECURITY.md, CONTRIBUTING.md and this changelog.

### Changed
- **Security**: the plugin WebSocket now binds to `127.0.0.1` only (previously it listened on all interfaces).
- Godot tool failures are surfaced as MCP tool errors (`isError: true`) instead of fake successes.
- `undo`/`redo` use `EditorUndoRedoManager` directly instead of simulated keystrokes.
- `run_project_export` has an extended 10-minute timeout.
- The plugin requires Godot 4.3+ and reports a clear startup error on older versions.
- Release binaries are built with `--locked` from the committed `Cargo.lock`.

### Fixed
- `scene_changed` events were never emitted (the editor signal was never connected).
- `reload_plugin` used an invalid plugin identifier (full cfg path instead of the plugin directory name).
- The server no longer replies to JSON-RPC notifications; protocol-level `ping` is now implemented.
- Duplicate log tailers accumulated after each reconnection.
- A pending-request entry leaked when the WebSocket sender was closed.

## [0.1.1] - 2026-07-12

### Added
- Automatic reconnection of the MCP server when the editor or plugin restarts.
- `notifications/tools/list_changed` after reconnection.
- `reload_plugin` tool.

## [0.1.0] - 2026-07-12

### Added
- Initial release: Rust MCP server (stdio) plus Godot editor plugin (WebSocket bridge), cross-platform release binaries and packaged plugin zip.

[0.1.2]: https://github.com/OneStepAt4time/open-godot-mcp/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/OneStepAt4time/open-godot-mcp/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/OneStepAt4time/open-godot-mcp/releases/tag/v0.1.0
