First release of Open Godot MCP.

## What's included

- Rust MCP server binaries for Windows, Linux, and macOS (x86_64 + Apple Silicon)
- Godot Editor plugin zip (`open-godot-mcp-plugin.zip`)
- 40+ MCP tools covering project/filesystem, scene tree, node CRUD, scripts, editor inspection, runtime control, input map, 3D/rendering, UI/audio/animation/resources
- Documentation: README, AI_ASSISTANT guide, EXAMPLES walkthrough, PLAN, PROTOCOL

## Quick start

1. Download the plugin zip and extract `open_godot_mcp` into your Godot project's `addons/` folder.
2. Enable **Open Godot MCP** in `Project Settings → Plugins`.
3. Download the server binary for your platform and add it to your `.mcp.json`:

```json
{
  "mcpServers": {
    "open-godot-mcp": {
      "command": "/path/to/open-godot-mcp-server"
    }
  }
}
```

4. Open Godot Editor and start a new Kimi / Claude session.
