# Open Godot MCP — AI Assistant for Godot Development

Open Godot MCP turns Kimi Code, Claude Code, Cursor, or any MCP-compatible assistant into a hands-on collaborator for Godot Engine 4.3+ game development.

Instead of just reading code, the assistant can inspect the running Godot Editor, modify scenes, create scripts, test gameplay, and capture screenshots — all through an open-source bridge bound to localhost.

## What the AI assistant can do

With the plugin active and the Rust server connected, an AI assistant can:

- **Edit scenes with Undo/Redo**: add, delete, move, rename, and reparent nodes; update properties (fully undoable); scatter prefab scene instances randomly in 2D/3D zones.
- **UI & Theme Layouts**: customize Control layout anchors, configure theme overrides, and edit flat/themed StyleBox configurations.
- **Paint TileMaps**: paint, clear, and read grid cell positions on both `TileMap` and `TileMapLayer` nodes.
- **Setup AnimTrees**: link AnimationTrees to players, update parameters, and connect states with transition blend conditions.
- **Write GDScript**: create, read, edit, validate, and attach scripts.
- **Shaders & VFX**: connect shaders, edit parameters/uniforms, and configure CPU/GPU particle systems (smart-routing node and material properties).
- **Physics & Navigation Queries**: run 3D raycasts, check Area2D/3D overlaps, generate concave (trimesh) or convex collision shapes from MeshInstance3D nodes, and bake 2D/3D navigation regions.
- **Audio Bus Mixers**: create channels, set volume levels, and insert bus effects.
- **Project Exporting**: list presets and compile release/debug packages headless.
- **Run the game**: play/stop scenes and simulate keyboard/mouse input.
- **Diagnostics & Profiling**: ping and retrieve active editor/engine performance diagnostics (FPS, static memory, draw calls, active physics bodies, process time).
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

3. Configure your assistant. Add to your MCP configuration file (`.mcp.json` for Claude Code, `.kimi-code/mcp.json` for Kimi Code, `~/.cursor/mcp.json` for Cursor):
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
   OpenGodotMCP: listening on 127.0.0.1:6505
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

- The bridge listens on **localhost only** (`127.0.0.1:6505`) and accepts no remote connections. Only connect AI clients you trust.
- **The assistant has the same powers as the editor.** Tools like `create_script`/`edit_script` write files in the project, and `execute_editor_script` runs arbitrary GDScript in the editor context — which can access the filesystem, network, and OS commands. Treat every AI session like a junior developer with full editor access: review destructive operations before approving them.
- **Full Undo/Redo**: All mutating scene operations (adding, deleting, duplicating, moving, renaming, updating properties, and changing signals/groups/scripts) go through Godot's `EditorUndoRedoManager`. You can safely undo (`Ctrl+Z`) or redo (`Ctrl+Y`) any modifications made by the AI directly inside the editor.
- **Active Log Interception**: Editor warnings and errors are actively monitored by the server and broadcast as asynchronous MCP notifications (`notifications/message`), making script error debugging highly automated.
- `get_game_screenshot` and full runtime scene inspection are limited because the running game is usually a separate process.

## Next steps

See [`EXAMPLES.md`](EXAMPLES.md) for a complete, copy-pasteable walkthrough that creates a small playable scene from scratch.
