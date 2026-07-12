@tool
extends EditorPlugin

const WebSocketServer = preload("res://addons/open_godot_mcp/websocket_server.gd")

var server: WebSocketServer


func _enter_tree() -> void:
	server = WebSocketServer.new()
	add_child(server)
	server.start(6505)


func _exit_tree() -> void:
	server.stop()
	server.queue_free()
