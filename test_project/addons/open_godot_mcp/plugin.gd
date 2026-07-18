@tool
extends EditorPlugin

const WebSocketServer = preload("res://addons/open_godot_mcp/websocket_server.gd")
const EventMonitor = preload("res://addons/open_godot_mcp/event_monitor.gd")

var server: WebSocketServer
var monitor: EventMonitor


func _enter_tree() -> void:
	# The bridge relies on EditorInterface.get_editor_undo_redo(), available since Godot 4.3.
	var version := Engine.get_version_info()
	if version.major < 4 or (version.major == 4 and version.minor < 3):
		push_error("OpenGodotMCP: Godot 4.3 or newer is required (detected %s). The MCP bridge was not started." % version.string)
		return

	# Ensure file logging is enabled in project settings so logs are written to disk
	if not ProjectSettings.get_setting("debug/settings/logging/enable_file_logging"):
		ProjectSettings.set_setting("debug/settings/logging/enable_file_logging", true)
		ProjectSettings.save()
		print("OpenGodotMCP: auto-enabled file logging in project settings.")

	server = WebSocketServer.new()
	add_child(server)
	server.start(6505)

	monitor = EventMonitor.new(server)
	add_child(monitor)

	# Forward editor scene switches to the MCP client as proactive events.
	scene_changed.connect(_scene_changed)


func _exit_tree() -> void:
	if monitor:
		monitor.queue_free()
	if server:
		server.stop()
		server.queue_free()


func _scene_changed(scene_root: Node) -> void:
	if monitor:
		monitor.notify_scene_changed(scene_root)
