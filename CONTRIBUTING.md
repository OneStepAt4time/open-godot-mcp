# Contributing to Open Godot MCP

Thanks for your interest! Contributions of all kinds are welcome: bug reports, features, documentation, tests.

## Getting started

### Prerequisites

- Rust (stable) — https://rustup.rs
- Godot 4.3 or newer — https://godotengine.org/download

### Build

```bash
cargo build --release          # Rust server → target/release/
```

The Godot plugin needs no build step: copy `godot_plugin/addons/open_godot_mcp` into a Godot project's `addons/` folder and enable it in **Project Settings → Plugins**.

### Manual smoke test

1. Open `test_project/` in Godot with the plugin enabled.
2. Run the server and pipe MCP commands to its stdin (see the README "Integration test" section).

## Project layout & conventions

- `crates/mcp-server/` — Rust MCP server. stdout is reserved for the MCP protocol; always log to stderr.
- `godot_plugin/` — the canonical Godot addon (GDScript, tab indentation).
- `test_project/addons/` — a copy of the plugin used by the test project. **Keep it in sync** with `godot_plugin/`.
- Tool names are `snake_case`. Every new tool needs three things: a handler in `command_router.gd`, a declaration in `tools/list` in `main.rs`, and a line in the README tool list.
- Mutating editor operations must go through `EditorInterface.get_editor_undo_redo()` so users can revert AI edits with Ctrl+Z.

## Version bumps & releases

Versions live in several places that must stay in sync — CI enforces this on tags: `Cargo.toml` (`[workspace.package] version`), both `plugin.cfg` files, and user-facing docs. Releases are published by pushing a `vX.Y.Z` tag; see `PLAN.md` §5 and `CHANGELOG.md`.

## Pull requests

- Open an issue first for anything beyond a small fix, so we can align on the approach.
- Keep PRs focused; describe what you tested (Godot version, OS, MCP client).
- By contributing you agree that your work is licensed under the project's MIT license.
