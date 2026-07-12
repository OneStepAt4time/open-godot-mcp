@tool
extends Node

const CommandRouter = preload("res://addons/open_godot_mcp/command_router.gd")

var _tcp_server: TCPServer
var _peers: Dictionary # peer_id -> WebSocketPeer
var _router: CommandRouter
var _next_id := 1


func _ready() -> void:
	_router = CommandRouter.new()


func start(port: int) -> void:
	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(port)
	if err != OK:
		push_error("OpenGodotMCP: failed to listen on port %d (err %d)" % [port, err])
		return
	print("OpenGodotMCP: listening on port ", port)


func stop() -> void:
	if _tcp_server:
		_tcp_server.stop()
	for peer in _peers.values():
		peer.close()
	_peers.clear()


# Broadcast an unsolicited event to every connected MCP peer.
func broadcast_event(event: Dictionary) -> void:
	if _peers.is_empty():
		return
	var text := JSON.stringify(event)
	for peer in _peers.values():
		peer.send_text(text)


func _process(_delta: float) -> void:
	if _tcp_server == null:
		return

	while _tcp_server.is_connection_available():
		var conn := _tcp_server.take_connection()
		var peer := WebSocketPeer.new()
		var err := peer.accept_stream(conn)
		if err != OK:
			push_error("OpenGodotMCP: WebSocket accept failed: ", err)
			continue
		var id := _next_id
		_next_id += 1
		_peers[id] = peer
		print("OpenGodotMCP: client connected id=", id)

	var to_remove := []
	for id in _peers.keys():
		var peer: WebSocketPeer = _peers[id]
		peer.poll()
		var state := peer.get_ready_state()
		if state == WebSocketPeer.STATE_CLOSED:
			to_remove.append(id)
			continue
		while peer.get_available_packet_count() > 0:
			var pkt := peer.get_packet()
			var text := pkt.get_string_from_utf8()
			_handle_message(peer, text)
	for id in to_remove:
		_peers.erase(id)


func _handle_message(peer: WebSocketPeer, text: String) -> void:
	var data := JSON.parse_string(text)
	if data == null or not data is Dictionary:
		_send(peer, {"error": "invalid JSON"})
		return
	var req := data as Dictionary
	var request_id := req.get("request_id", "")
	var method := req.get("method", "")
	var params := req.get("params", null)
	if method == "reload_plugin":
		_send(peer, {"request_id": request_id, "result": _reload_plugin()})
		return
	var result := _router.handle(method, params)
	_send(peer, {"request_id": request_id, "result": result})


func _send(peer: WebSocketPeer, data: Dictionary) -> void:
	var text := JSON.stringify(data)
	peer.send_text(text)


func _reload_plugin() -> Dictionary:
	var plugin_cfg := "res://addons/open_godot_mcp/plugin.cfg"
	# Schedule the actual reload after this response has been flushed.
	call_deferred("_do_plugin_reload", plugin_cfg)
	return {"ok": true, "reloaded": plugin_cfg, "note": "MCP server will reconnect automatically"}


func _do_plugin_reload(plugin_cfg: String) -> void:
	EditorInterface.set_plugin_enabled(plugin_cfg, false)
	EditorInterface.set_plugin_enabled(plugin_cfg, true)
