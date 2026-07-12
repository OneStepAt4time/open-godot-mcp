@tool
extends EditorPlugin

const WebSocketServer = preload("res://addons/open_godot_mcp/websocket_server.gd")
const EventMonitor = preload("res://addons/open_godot_mcp/event_monitor.gd")

var server: WebSocketServer
var monitor: EventMonitor


func _enter_tree() -> void:
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


func _exit_tree() -> void:
	if monitor:
		monitor.queue_free()
	if server:
		server.stop()
		server.queue_free()


func _scene_changed(scene_root: Node) -> void:
	if monitor:
		monitor.notify_scene_changed(scene_root)
