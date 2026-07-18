# Open Godot MCP — Example Walkthrough

This document shows a complete, copy-pasteable session that creates a small playable 2D scene using the MCP tools.

## Prerequisites

- Godot Editor 4.3+ is open with the Open Godot MCP plugin enabled.
- The Rust server `open-godot-mcp-server` is running and connected.
- You are in the `test_project/` directory of this repository or your own Godot project.

## Goal

Create a `game.tscn` scene with:

- A `Node2D` root named `game`
- A `CharacterBody2D` named `Player`
- A `Sprite2D` child named `Sprite`
- A `CollisionShape2D` child named `Collision`
- A `player.gd` script attached to `Player` that handles movement

## MCP commands

Send these lines to the server's stdin (one JSON object per line):

```json
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_project_info","arguments":{}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_scene","arguments":{"path":"res://game.tscn","root_type":"Node2D"}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add_node","arguments":{"parent_path":".","type":"CharacterBody2D","name":"Player"}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"add_node","arguments":{"parent_path":"Player","type":"Sprite2D","name":"Sprite"}}}
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"add_node","arguments":{"parent_path":"Player","type":"CollisionShape2D","name":"Collision"}}}
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"create_script","arguments":{"path":"res://player.gd","content":"extends CharacterBody2D\n\n@export var speed: float = 300.0\n\nfunc _physics_process(delta: float) -> void:\n    var direction := Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")\n    velocity = direction * speed\n    move_and_slide()\n"}}}
{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"attach_script","arguments":{"node_path":"Player","script_path":"res://player.gd"}}}
{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"save_scene","arguments":{}}}
{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"get_scene_tree","arguments":{}}}
{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"get_editor_screenshot","arguments":{}}}
```

## What happens

1. `get_project_info` confirms the connection.
2. `create_scene` creates `res://game.tscn` and opens it in the editor.
3. `add_node` builds the `Player` hierarchy.
4. `create_script` writes `res://player.gd`.
5. `attach_script` links the script to the `Player` node.
6. `save_scene` persists the scene.
7. `get_scene_tree` returns the final node tree.
8. `get_editor_screenshot` captures the active editor viewport as a base64 PNG.

## Resulting files

### `game.tscn`

```ini
[gd_scene format=3 uid="uid://yi87v0io7jxe"]

[ext_resource type="Script" uid="uid://cs6qdrcovm4mc" path="res://player.gd" id="1_80nbo"]

[node name="game" type="Node2D" unique_id=1956682738]

[node name="Player" type="CharacterBody2D" parent="." unique_id=412308775]
script = ExtResource("1_80nbo")

[node name="Sprite" type="Sprite2D" parent="Player" unique_id=603275405]

[node name="Collision" type="CollisionShape2D" parent="Player" unique_id=1320493549]
```

### `player.gd`

```gdscript
extends CharacterBody2D

@export var speed: float = 300.0

func _physics_process(delta: float) -> void:
    var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = direction * speed
    move_and_slide()
```

## Next steps

- Add a texture to the `Sprite` node using `update_property` or the Godot inspector.
- Assign a `RectangleShape2D` to `Player/Collision`.
- Press `Play Scene` and use the arrow keys to move the player.
- Ask the AI assistant: "Add a Camera2D that follows the Player."
