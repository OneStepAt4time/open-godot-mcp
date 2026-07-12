# Open Godot MCP — AI Assistant for Godot Development

Open Godot MCP turns Kimi Code, Claude Code, Cursor, or any MCP-compatible assistant into a hands-on collaborator for Godot Engine 4 game development.

Instead of just reading code, the assistant can inspect the running Godot Editor, modify scenes, create scripts, test gameplay, and capture screenshots — all through a safe, local, open-source bridge.

## What the AI assistant can do

With the plugin active and the Rust server connected, an AI assistant can:

- **Inspect the project**: read project settings, list files, search scripts.
- **Navigate the scene tree**: see nodes, properties, and relationships in real time.
- **Edit scenes**: add, delete, move, rename, and reparent nodes; update properties including `Vector2`, `Vector3`, and `Color`.
- **Write GDScript**: create, read, edit, validate, and attach scripts.
- **Run the game**: play/stop scenes and simulate keyboard/mouse input.
- **Inspect 3D setups**: query cameras, environment, and rendering settings.
- **Manage input**: list and configure input actions and key bindings.
- **Capture the editor**: take PNG screenshots of the active viewport.

## Quick setup for Kimi Code / Claude Code

1. Build or download the server binary:
   ```bash
   cargo build --release
   # or download from GitHub Releases
   ```

2. Install the Godot plugin:
   ```bash
   cp -r godot_plugin/addons/open_godot_mcp /path/to/your/godot/project/addons/
   ```
   Then enable **Open Godot MCP** in `Project Settings → Plugins`.

3. Configure your assistant. Add to your `.mcp.json`:
   ```json
   {
     "mcpServers": {
       "open-godot-mcp": {
         "command": "/path/to/open-godot-mcp-server"
       }
     }
   }
   ```

4. Open Godot Editor. The plugin logs:
   ```
   OpenGodotMCP: listening on port 6505
   ```

5. Start a new Kimi / Claude session. The server connects automatically and the assistant receives the full tool list.

## Example prompts

### Scene editing

> "Create a new 2D scene called `game.tscn` with a `CharacterBody2D` player that has a `Sprite2D` and a `CollisionShape2D` child."

> "Add a `Camera2D` node as a child of the Player node and make it the current camera."

> "Move the Player node to position (100, 200)."

### Scripting

> "Create a `player.gd` script with movement using `Input.get_vector` and attach it to the Player node."

> "Refactor the Player script to use `@export var speed: float = 300.0` and call `move_and_slide()`."

> "Validate the current player.gd file for syntax errors."

### Runtime testing

> "Run the current scene and simulate pressing the Right arrow key for 2 seconds."

> "Stop the running game."

### 3D development

> "Find the first Camera3D in the scene and print its position, rotation, and FOV."

> "Move the main camera to position (0, 5, 10) and point it toward the origin."

### Input & project settings

> "List all input actions and add a new action called `jump` bound to the Space key."

> "Set the project viewport width to 1920 and height to 1080, then save the project settings."

## Best practices

- **Save often**: ask the assistant to call `save_scene` after meaningful edits.
- **Inspect before editing**: ask for `get_scene_tree` or `get_node_properties` before changing nodes.
- **Use relative node paths**: paths like `Player/Sprite` are easier to reason about than full editor-internal paths.
- **Validate scripts**: use `validate_script` before attaching new GDScript files.
- **Reload the plugin when editing its code**: if you modify `command_router.gd` or other plugin files, call `reload_plugin` so Godot picks up the changes without restarting the editor.
- **One change at a time**: complex refactors are safer when split into small, verifiable steps.

## Safety & limitations

- The assistant operates inside your local Godot Editor. It cannot access the internet or modify files outside the project.
- Mutating scene operations currently do **not** go through Godot's `UndoRedoManager`. Save/commit your project before heavy AI-assisted editing.
- `get_game_screenshot` and full runtime scene inspection are limited because the running game is usually a separate process.
- Editor error/output logs are not exposed by Godot's public API, so the assistant cannot read them directly.

## Next steps

See [`EXAMPLES.md`](EXAMPLES.md) for a complete, copy-pasteable walkthrough that creates a small playable scene from scratch.
