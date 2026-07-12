@tool
extends Node

# Proactive event monitor for the Open Godot MCP plugin.
# Watches the currently edited scene, selection, and the play state, and pushes
# events to the WebSocket server so they can be forwarded to the MCP client as
# server-to-client notifications.

var _server: Node = null
var _enabled: bool = true

# Play state cache
var _last_playing: bool = false
var _frame_counter: int = 0
const PLAY_POLL_INTERVAL := 15


func _init(server: Node) -> void:
	_server = server


func _ready() -> void:
	print("OpenGodotMCP: event monitor ready")

	# Connect natively to selection changed signal
	var selection := EditorInterface.get_selection()
	if selection:
		selection.selection_changed.connect(_on_selection_changed)

	set_process(true)
	_last_playing = EditorInterface.is_playing_scene()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func _process(_delta: float) -> void:
	if not _enabled or _server == null:
		return

	_frame_counter += 1
	if _frame_counter >= PLAY_POLL_INTERVAL:
		_frame_counter = 0
		_poll_play_state()


func notify_scene_changed(scene_root: Node) -> void:
	if not _enabled:
		return
	var path := scene_root.scene_file_path if scene_root != null else ""
	_broadcast_event({
		"event": "scene_changed",
		"payload": {
			"path": path,
			"name": scene_root.name if scene_root != null else "",
		}
	})


func _on_selection_changed() -> void:
	if not _enabled:
		return
	var selected_nodes := EditorInterface.get_selection().get_selected_nodes()
	var selected_paths := []
	for node in selected_nodes:
		selected_paths.append(str(node.get_path()))
	_broadcast_event({
		"event": "selection_changed",
		"payload": {
			"selected_paths": selected_paths
		}
	})


func _poll_play_state() -> void:
	var playing := EditorInterface.is_playing_scene()
	if playing != _last_playing:
		_last_playing = playing
		_broadcast_event({
			"event": "play_state_changed",
			"payload": {
				"playing": playing,
			}
		})


func _broadcast_event(event: Dictionary) -> void:
	if _server != null and _server.has_method("broadcast_event"):
		_server.broadcast_event(event)
