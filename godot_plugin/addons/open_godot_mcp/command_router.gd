@tool
extends RefCounted

func handle(method: String, params: Variant) -> Variant:
	match method:
		"get_project_info":
			return _get_project_info()
		"get_project_settings":
			return _get_project_settings(params)
		"set_project_setting":
			return _set_project_setting(params)
		"get_filesystem_tree":
			return _get_filesystem_tree(params)
		"search_files":
			return _search_files(params)
		"get_scene_tree":
			return _get_scene_tree(params)
		"get_open_scenes":
			return _get_open_scenes(params)
		"open_scene":
			return _open_scene(params)
		"save_scene":
			return _save_scene(params)
		"create_scene":
			return _create_scene(params)
		"add_scene_instance":
			return _add_scene_instance(params)
		"add_node":
			return _add_node(params)
		"delete_node":
			return _delete_node(params)
		"duplicate_node":
			return _duplicate_node(params)
		"move_node":
			return _move_node(params)
		"rename_node":
			return _rename_node(params)
		"update_property":
			return _update_property(params)
		"get_node_properties":
			return _get_node_properties(params)
		"get_editor_selection":
			return _get_editor_selection(params)
		"select_nodes":
			return _select_nodes(params)
		"find_nodes_by_type":
			return _find_nodes_by_type(params)
		"connect_signal":
			return _connect_signal(params)
		"disconnect_signal":
			return _disconnect_signal(params)
		"get_node_groups":
			return _get_node_groups(params)
		"set_node_groups":
			return _set_node_groups(params)
		"list_scripts":
			return _list_scripts(params)
		"read_script":
			return _read_script(params)
		"create_script":
			return _create_script(params)
		"edit_script":
			return _edit_script(params)
		"attach_script":
			return _attach_script(params)
		"validate_script":
			return _validate_script(params)
		"get_open_scripts":
			return _get_open_scripts(params)
		"search_in_files":
			return _search_in_files(params)
		"get_editor_errors":
			return _get_editor_errors(params)
		"get_output_log":
			return _get_output_log(params)
		"execute_editor_script":
			return _execute_editor_script(params)
		"get_editor_screenshot":
			return _get_editor_screenshot(params)
		"play_scene":
			return _play_scene(params)
		"stop_scene":
			return _stop_scene(params)
		"get_game_screenshot":
			return _get_game_screenshot(params)
		"simulate_key":
			return _simulate_key(params)
		"simulate_mouse_click":
			return _simulate_mouse_click(params)
		"list_input_actions":
			return _list_input_actions(params)
		"add_input_action":
			return _add_input_action(params)
		"remove_input_action":
			return _remove_input_action(params)
		"set_input_key":
			return _set_input_key(params)
		"get_input_map":
			return _get_input_map(params)
		"get_camera_3d_info":
			return _get_camera_3d_info(params)
		"set_camera_3d_transform":
			return _set_camera_3d_transform(params)
		"get_environment_info":
			return _get_environment_info(params)
		"set_render_setting":
			return _set_render_setting(params)
		"list_animations":
			return _list_animations(params)
		"play_animation":
			return _play_animation(params)
		"list_audio_streams":
			return _list_audio_streams(params)
		"play_audio_preview":
			return _play_audio_preview(params)
		"list_resources":
			return _list_resources(params)
		"get_resource_info":
			return _get_resource_info(params)
		"ping":
			return {"ok": true, "uptime": Time.get_ticks_msec() / 1000.0}
		_:
			return {"error": "unknown method: " + method}


func _get_project_info() -> Dictionary:
	return {
		"name": ProjectSettings.get_setting("application/config/name"),
		"version": _str_setting("application/config/version"),
		"godot_version": Engine.get_version_info(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"viewport_width": ProjectSettings.get_setting("display/window/size/viewport_width"),
		"viewport_height": ProjectSettings.get_setting("display/window/size/viewport_height"),
	}


func _get_project_settings(params: Variant) -> Dictionary:
	var keys: Array = _dict(params).get("keys", [])
	var out := {}
	for k in keys:
		var path := str(k)
		if ProjectSettings.has_setting(path):
			out[path] = ProjectSettings.get_setting(path)
		else:
			out[path] = null
	return out


func _set_project_setting(params: Variant) -> Dictionary:
	var p := _dict(params)
	var key: String = p.get("key", "")
	var value: Variant = p.get("value", null)
	if key.is_empty():
		return {"error": "missing key"}
	ProjectSettings.set_setting(key, value)
	if p.get("save", true):
		var err := ProjectSettings.save()
		return {"ok": true, "key": key, "saved": err == OK}
	return {"ok": true, "key": key, "saved": false}


func _get_filesystem_tree(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "res://")
	var recursive: bool = p.get("recursive", true)
	return {"path": path, "entries": _scan_dir(path, recursive)}


func _scan_dir(path: String, recursive: bool) -> Array:
	var out := []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var full := path.path_join(file_name)
		var entry := {"name": file_name, "path": full, "type": "file"}
		if dir.current_is_dir():
			entry["type"] = "directory"
			if recursive:
				entry["children"] = _scan_dir(full, true)
		out.append(entry)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func _search_files(params: Variant) -> Dictionary:
	var p := _dict(params)
	var query: String = p.get("query", "")
	var pattern: String = p.get("pattern", "")
	var matches: Array = []
	if not query.is_empty():
		_matches_recursive("res://", query, matches)
	return {"matches": matches, "query": query, "pattern": pattern}


func _matches_recursive(path: String, query: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var full := path.path_join(file_name)
		if dir.current_is_dir():
			_matches_recursive(full, query, out)
		elif query.is_subsequence_of(file_name) or query.is_subsequence_of(full):
			out.append(full)
		file_name = dir.get_next()
	dir.list_dir_end()


func _dict(v: Variant) -> Dictionary:
	if v == null:
		return {}
	return v as Dictionary


func _str_setting(path: String) -> String:
	if ProjectSettings.has_setting(path):
		return str(ProjectSettings.get_setting(path))
	return ""


# ---------- Scene tools ----------

func _get_scene_tree(_params: Variant) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	return {"root": _serialize_node(root, true)}


func _get_open_scenes(_params: Variant) -> Dictionary:
	return {"scenes": EditorInterface.get_open_scenes()}


func _open_scene(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	if path.is_empty():
		return {"error": "missing path"}
	EditorInterface.open_scene_from_path(path)
	return {"ok": true, "path": path}


func _save_scene(_params: Variant) -> Dictionary:
	var err := EditorInterface.save_scene()
	return {"ok": err == OK}


func _create_scene(params: Variant) -> Dictionary:
	var p := _dict(params)
	var root_type: String = p.get("root_type", "Node")
	var path: String = p.get("path", "")
	if path.is_empty():
		return {"error": "missing path"}

	var root := ClassDB.instantiate(root_type)
	if root == null:
		return {"error": "cannot instantiate " + root_type}
	if not root is Node:
		return {"error": root_type + " is not a Node"}
	root.name = path.get_file().get_basename()

	var ps := PackedScene.new()
	var pack_err := ps.pack(root)
	if pack_err != OK:
		return {"error": "pack failed", "code": pack_err}
	var save_err := ResourceSaver.save(ps, path)
	if save_err != OK:
		return {"error": "save failed", "code": save_err}
	EditorInterface.open_scene_from_path(path)
	return {"ok": true, "path": path, "root_type": root_type}


func _add_scene_instance(params: Variant) -> Dictionary:
	var p := _dict(params)
	var scene_path: String = p.get("scene_path", "")
	var parent_path: String = p.get("parent_path", ".")
	var node_name: String = p.get("node_name", "")
	if scene_path.is_empty():
		return {"error": "missing scene_path"}

	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {"error": "cannot load scene " + scene_path}
	var inst := packed.instantiate()
	if not node_name.is_empty():
		inst.name = node_name

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	var parent := root.get_node(parent_path) if parent_path != "." else root
	if parent == null:
		return {"error": "parent not found: " + parent_path}

	parent.add_child(inst)
	inst.owner = root
	return {"ok": true, "name": inst.name, "path": str(inst.get_path())}


func _serialize_node(node: Node, recursive: bool) -> Dictionary:
	var out := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}
	var scene_path := node.scene_file_path
	if not scene_path.is_empty():
		out["scene_file_path"] = scene_path
	if recursive:
		var children := []
		for c in node.get_children():
			children.append(_serialize_node(c, true))
		out["children"] = children
	return out


# ---------- Node CRUD tools ----------

func _add_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var parent_path: String = p.get("parent_path", ".")
	var type: String = p.get("type", "Node")
	var node_name: String = p.get("name", "")
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	var parent := root.get_node(parent_path) if parent_path != "." else root
	if parent == null:
		return {"error": "parent not found"}
	var node := ClassDB.instantiate(type)
	if node == null:
		return {"error": "cannot instantiate " + type}
	if not node is Node:
		return {"error": type + " is not a Node"}
	if not node_name.is_empty():
		node.name = node_name
	parent.add_child(node)
	node.owner = root
	return {"ok": true, "name": node.name, "path": str(node.get_path())}


func _delete_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	node.queue_free()
	return {"ok": true}


func _duplicate_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	var dup := node.duplicate()
	node.get_parent().add_child(dup)
	dup.owner = EditorInterface.get_edited_scene_root()
	return {"ok": true, "path": str(dup.get_path())}


func _move_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var new_parent_path: String = p.get("new_parent_path", ".")
	var new_index: int = p.get("new_index", -1)
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	var root := EditorInterface.get_edited_scene_root()
	var new_parent := root.get_node(new_parent_path) if new_parent_path != "." else root
	if new_parent == null:
		return {"error": "new parent not found"}
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	if new_index >= 0:
		new_parent.move_child(node, new_index)
	node.owner = root
	return {"ok": true, "path": str(node.get_path())}


func _rename_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var new_name: String = p.get("new_name", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	node.name = new_name
	return {"ok": true, "path": str(node.get_path())}


func _update_property(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var property: String = p.get("property", "")
	var value: Variant = p.get("value", null)
	var raw: bool = p.get("raw", false)
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if property.is_empty():
		return {"error": "missing property"}
	if not raw:
		value = _coerce_value(value)
	node.set(property, value)
	return {"ok": true}


func _coerce_value(value: Variant) -> Variant:
	if value is Dictionary:
		var d := value as Dictionary
		if d.has("x") and d.has("y") and d.has("z"):
			return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
		if d.has("x") and d.has("y"):
			return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		if d.has("r") and d.has("g") and d.has("b"):
			var a := float(d.get("a", 1.0))
			return Color(float(d.get("r", 0)), float(d.get("g", 0)), float(d.get("b", 0)), a)
	return value


func _get_node_properties(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	var out := {"name": node.name, "type": node.get_class(), "path": str(node.get_path())}
	if node is Node2D:
		out["position"] = var_to_str(node.position)
		out["rotation"] = node.rotation
		out["scale"] = var_to_str(node.scale)
	if node is Node3D:
		out["position"] = var_to_str(node.position)
		out["rotation"] = var_to_str(node.rotation)
		out["scale"] = var_to_str(node.scale)
	if node is CanvasItem:
		out["visible"] = node.visible
	if node is Control:
		out["size"] = var_to_str(node.size)
	return out


func _get_editor_selection(_params: Variant) -> Dictionary:
	var sel := EditorInterface.get_selection().get_selected_nodes()
	var out := []
	for node in sel:
		out.append({"name": node.name, "path": str(node.get_path())})
	return {"selected": out}


func _select_nodes(params: Variant) -> Dictionary:
	var p := _dict(params)
	var paths: Array = p.get("paths", [])
	var selection := EditorInterface.get_selection()
	selection.clear()
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	for path in paths:
		var node := root.get_node(str(path))
		if node != null:
			selection.add_node(node)
	return {"ok": true, "selected_count": selection.get_selected_nodes().size()}


func _find_nodes_by_type(params: Variant) -> Dictionary:
	var p := _dict(params)
	var type: String = p.get("type", "")
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	var matches := []
	_for_each_node(root, func(n: Node):
		if n.is_class(type) or n.is_class(type):
			matches.append({"name": n.name, "path": str(n.get_path())})
	)
	return {"matches": matches}


func _connect_signal(params: Variant) -> Dictionary:
	var p := _dict(params)
	var source_path: String = p.get("source_path", "")
	var signal_name: String = p.get("signal_name", "")
	var target_path: String = p.get("target_path", "")
	var method_name: String = p.get("method_name", "")
	var root := EditorInterface.get_edited_scene_root()
	var source := root.get_node(source_path) if root else null
	var target := root.get_node(target_path) if root else null
	if source == null or target == null:
		return {"error": "source or target not found"}
	var err := source.connect(signal_name, Callable(target, method_name))
	return {"ok": err == OK}


func _disconnect_signal(params: Variant) -> Dictionary:
	var p := _dict(params)
	var source_path: String = p.get("source_path", "")
	var signal_name: String = p.get("signal_name", "")
	var target_path: String = p.get("target_path", "")
	var method_name: String = p.get("method_name", "")
	var root := EditorInterface.get_edited_scene_root()
	var source := root.get_node(source_path) if root else null
	var target := root.get_node(target_path) if root else null
	if source == null or target == null:
		return {"error": "source or target not found"}
	source.disconnect(signal_name, Callable(target, method_name))
	return {"ok": true}


func _get_node_groups(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	return {"groups": node.get_groups()}


func _set_node_groups(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var groups: Array = p.get("groups", [])
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	for g in node.get_groups():
		node.remove_from_group(str(g))
	for g in groups:
		node.add_to_group(str(g))
	return {"ok": true}


func _get_node(path: String) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	if path == "." or path.is_empty():
		return root
	return root.get_node_or_null(path)


func _for_each_node(node: Node, callback: Callable) -> void:
	callback.call(node)
	for c in node.get_children():
		_for_each_node(c, callback)


# ---------- Script tools ----------

func _list_scripts(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "res://")
	var scripts := []
	_for_each_file(path, func(full: String):
		if full.ends_with(".gd"):
			scripts.append(full)
	)
	return {"scripts": scripts}


func _read_script(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	if not FileAccess.file_exists(path):
		return {"error": "file not found: " + path}
	var content := FileAccess.get_file_as_string(path)
	return {"path": path, "content": content}


func _create_script(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var content: String = p.get("content", "extends Node\n\nfunc _ready() -> void:\n\tpass\n")
	if path.is_empty():
		return {"error": "missing path"}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "cannot write file: " + path}
	file.store_string(content)
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	return {"ok": true, "path": path}


func _edit_script(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var replacements: Array = p.get("replacements", [])
	if path.is_empty():
		return {"error": "missing path"}
	if not FileAccess.file_exists(path):
		return {"error": "file not found: " + path}
	var content := FileAccess.get_file_as_string(path)
	for r in replacements:
		var rd := _dict(r)
		var search: String = rd.get("search", "")
		var replace: String = rd.get("replace", "")
		content = content.replace(search, replace)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "cannot write file: " + path}
	file.store_string(content)
	file.close()
	EditorInterface.get_resource_filesystem().scan()
	return {"ok": true, "path": path, "replacements_applied": replacements.size()}


func _attach_script(params: Variant) -> Dictionary:
	var p := _dict(params)
	var node_path: String = p.get("node_path", "")
	var script_path: String = p.get("script_path", "")
	var node := _get_node(node_path)
	if node == null:
		return {"error": "node not found: " + node_path}
	var script := load(script_path) as Script
	if script == null:
		return {"error": "cannot load script: " + script_path}
	node.set_script(script)
	return {"ok": true}


func _validate_script(params: Variant) -> Dictionary:
	var p := _dict(params)
	var content: String = p.get("content", "")
	var path: String = p.get("path", "")
	if content.is_empty() and not path.is_empty() and FileAccess.file_exists(path):
		content = FileAccess.get_file_as_string(path)
	if content.is_empty():
		return {"error": "missing content or path"}
	var gd := GDScript.new()
	gd.source_code = content
	var err := gd.reload()
	return {"valid": err == OK, "error": err, "error_string": error_string(err)}


func _get_open_scripts(_params: Variant) -> Dictionary:
	# EditorScript API does not expose open tabs directly; stub for now.
	return {"scripts": [], "note": "not yet implemented"}


func _search_in_files(params: Variant) -> Dictionary:
	var p := _dict(params)
	var query: String = p.get("query", "")
	var pattern: String = p.get("pattern", "*.gd")
	if query.is_empty():
		return {"error": "missing query"}
	var matches := []
	_for_each_file("res://", func(full: String):
		if not full.match(pattern):
			return
		if not FileAccess.file_exists(full):
			return
		var content := FileAccess.get_file_as_string(full)
		if content.contains(query):
			matches.append(full)
	)
	return {"matches": matches}


# ---------- Editor inspection tools ----------

func _get_editor_errors(_params: Variant) -> Dictionary:
	# Godot does not expose the editor error log through a public API.
	return {"errors": [], "note": "Godot does not expose the editor error log via public API"}


func _get_output_log(_params: Variant) -> Dictionary:
	# Godot does not expose the editor output log through a public API.
	return {"log": "", "note": "Godot does not expose the editor output log via public API"}


func _execute_editor_script(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var content: String = p.get("content", "")
	if path.is_empty() and content.is_empty():
		return {"error": "missing path or content"}

	var script_path := path
	if not content.is_empty():
		script_path = "user://__open_godot_mcp_exec_tmp.gd"
		var file := FileAccess.open(script_path, FileAccess.WRITE)
		if file == null:
			return {"error": "cannot write temp script: " + str(FileAccess.get_open_error())}
		file.store_string(content)
		file.close()

	var script := load(script_path) as Script
	if script == null:
		return {"error": "cannot load script: " + script_path}
	var instance = script.new()
	if instance == null:
		return {"error": "cannot instantiate script"}
	if not instance.has_method("_run"):
		return {"error": "script does not define _run()"}
	instance._run()
	return {"ok": true, "path": script_path}


func _get_editor_screenshot(_params: Variant) -> Dictionary:
	var viewport := EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return {"error": "cannot access editor viewport"}
	var texture := viewport.get_texture()
	if texture == null:
		return {"error": "cannot get viewport texture"}
	var image := texture.get_image()
	if image == null:
		return {"error": "cannot get image from viewport"}
	var png := image.save_png_to_buffer()
	if png.is_empty():
		return {"error": "cannot encode PNG"}
	return {
		"ok": true,
		"format": "png",
		"base64": Marshalls.raw_to_base64(png),
		"size": {"x": image.get_width(), "y": image.get_height()}
	}


# ---------- Runtime control tools ----------

func _play_scene(params: Variant) -> Dictionary:
	var p := _dict(params)
	var mode: String = p.get("mode", "current")
	if mode == "main":
		EditorInterface.play_main_scene()
	else:
		EditorInterface.play_current_scene()
	return {"ok": true, "mode": mode}


func _stop_scene(_params: Variant) -> Dictionary:
	EditorInterface.stop_playing_scene()
	return {"ok": true}


func _get_game_screenshot(_params: Variant) -> Dictionary:
	# The running game is normally a separate process; capturing it from the
	# editor is not reliably supported by Godot's public API.
	return {"error": "game screenshot is not available from the editor process"}


func _simulate_key(params: Variant) -> Dictionary:
	var p := _dict(params)
	var keycode: int = p.get("keycode", 0)
	if keycode == 0:
		return {"error": "missing keycode"}
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = p.get("pressed", true)
	event.ctrl_pressed = p.get("ctrl", false)
	event.shift_pressed = p.get("shift", false)
	event.alt_pressed = p.get("alt", false)
	event.meta_pressed = p.get("meta", false)
	Input.parse_input_event(event)
	return {"ok": true}


func _simulate_mouse_click(params: Variant) -> Dictionary:
	var p := _dict(params)
	var button: int = p.get("button", MOUSE_BUTTON_LEFT)
	var pos_dict := _dict(p.get("position", {}))
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = p.get("pressed", true)
	event.double_click = p.get("double_click", false)
	event.position = Vector2(float(pos_dict.get("x", 0)), float(pos_dict.get("y", 0)))
	Input.parse_input_event(event)
	return {"ok": true}


# ---------- Input map tools ----------

func _list_input_actions(_params: Variant) -> Dictionary:
	return {"actions": InputMap.get_actions()}


func _add_input_action(params: Variant) -> Dictionary:
	var p := _dict(params)
	var action: String = p.get("action", "")
	var deadzone: float = p.get("deadzone", 0.5)
	if action.is_empty():
		return {"error": "missing action"}
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	return {"ok": true, "action": action}


func _remove_input_action(params: Variant) -> Dictionary:
	var p := _dict(params)
	var action: String = p.get("action", "")
	if action.is_empty():
		return {"error": "missing action"}
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	return {"ok": true, "action": action}


func _set_input_key(params: Variant) -> Dictionary:
	var p := _dict(params)
	var action: String = p.get("action", "")
	var keycode: int = p.get("keycode", 0)
	var remove_existing: bool = p.get("remove_existing", false)
	if action.is_empty() or keycode == 0:
		return {"error": "missing action or keycode"}
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if remove_existing:
		InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)
	return {"ok": true, "action": action, "keycode": keycode}


func _get_input_map(_params: Variant) -> Dictionary:
	var out := {}
	for action in InputMap.get_actions():
		var events := []
		for ev in InputMap.action_get_events(action):
			events.append(_serialize_input_event(ev))
		out[action] = events
	return {"actions": out}


func _serialize_input_event(ev: InputEvent) -> Dictionary:
	var out := {"type": ev.get_class()}
	if ev is InputEventKey:
		out["keycode"] = ev.keycode
	elif ev is InputEventMouseButton:
		out["button_index"] = ev.button_index
	elif ev is InputEventJoypadButton:
		out["button_index"] = ev.button_index
	return out


# ---------- 3D & rendering tools ----------

func _get_camera_3d_info(_params: Variant) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	var cam := _find_first_node_of_class(root, "Camera3D")
	if cam == null:
		return {"error": "no Camera3D found in current scene"}
	return {
		"name": cam.name,
		"path": str(cam.get_path()),
		"position": var_to_str(cam.position),
		"rotation": var_to_str(cam.rotation),
		"fov": cam.fov,
		"near": cam.near,
		"far": cam.far,
	}


func _set_camera_3d_transform(params: Variant) -> Dictionary:
	var p := _dict(params)
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	var cam := _find_first_node_of_class(root, "Camera3D")
	if cam == null:
		return {"error": "no Camera3D found in current scene"}
	var pos := _dict(p.get("position", {}))
	var rot := _dict(p.get("rotation", {}))
	if pos.has("x") or pos.has("y") or pos.has("z"):
		cam.position = Vector3(float(pos.get("x", cam.position.x)), float(pos.get("y", cam.position.y)), float(pos.get("z", cam.position.z)))
	if rot.has("x") or rot.has("y") or rot.has("z"):
		cam.rotation = Vector3(float(rot.get("x", cam.rotation.x)), float(rot.get("y", cam.rotation.y)), float(rot.get("z", cam.rotation.z)))
	if p.has("fov"):
		cam.fov = float(p.get("fov", cam.fov))
	return {"ok": true, "path": str(cam.get_path())}


func _get_environment_info(_params: Variant) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	var env := _find_first_node_of_class(root, "WorldEnvironment")
	if env == null:
		return {"error": "no WorldEnvironment found in current scene"}
	var resource: Environment = env.environment
	if resource == null:
		return {"error": "WorldEnvironment has no Environment resource"}
	return {
		"path": str(env.get_path()),
		"background_mode": resource.background_mode,
		"ambient_light_source": resource.ambient_light_source,
		"tonemap_mode": resource.tonemap_mode,
		"ssr_enabled": resource.ssr_enabled,
		"ssao_enabled": resource.ssao_enabled,
		"glow_enabled": resource.glow_enabled,
	}


func _set_render_setting(params: Variant) -> Dictionary:
	var p := _dict(params)
	var key: String = p.get("key", "")
	var value: Variant = p.get("value", null)
	if key.is_empty():
		return {"error": "missing key"}
	ProjectSettings.set_setting(key, value)
	return {"ok": true, "key": key}


func _find_first_node_of_class(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for c in root.get_children():
		var found := _find_first_node_of_class(c, type_name)
		if found != null:
			return found
	return null


# ---------- UI / audio / animation / resources tools ----------

func _list_animations(_params: Variant) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}
	var players := []
	_for_each_node(root, func(n: Node):
		if n is AnimationPlayer:
			players.append({"name": n.name, "path": str(n.get_path()), "animations": n.get_animation_list()})
	)
	return {"players": players}


func _play_animation(params: Variant) -> Dictionary:
	var p := _dict(params)
	var node_path: String = p.get("node_path", "")
	var animation: String = p.get("animation", "")
	var node := _get_node(node_path)
	if node == null:
		return {"error": "node not found: " + node_path}
	if not node is AnimationPlayer:
		return {"error": "node is not an AnimationPlayer"}
	node.play(animation)
	return {"ok": true, "animation": animation}


func _list_audio_streams(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "res://")
	var streams := []
	_for_each_file(path, func(full: String):
		if full.ends_with(".ogg") or full.ends_with(".mp3") or full.ends_with(".wav"):
			streams.append(full)
	)
	return {"streams": streams}


func _play_audio_preview(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	if path.is_empty():
		return {"error": "missing path"}
	var stream := load(path) as AudioStream
	if stream == null:
		return {"error": "cannot load audio stream: " + path}
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.autoplay = true
	EditorInterface.get_edited_scene_root().add_child(player)
	player.finished.connect(player.queue_free)
	return {"ok": true, "path": path}


func _list_resources(params: Variant) -> Dictionary:
	var p := _dict(params)
	var extensions: Array = p.get("extensions", [])
	var resources := []
	_for_each_file("res://", func(full: String):
		if extensions.is_empty():
			resources.append(full)
		else:
			for ext in extensions:
				if full.ends_with(ext):
					resources.append(full)
					break
	)
	return {"resources": resources}


func _get_resource_info(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	if path.is_empty():
		return {"error": "missing path"}
	if not FileAccess.file_exists(path):
		return {"error": "file not found: " + path}
	var res := load(path)
	if res == null:
		return {"error": "cannot load resource: " + path}
	return {
		"path": path,
		"type": res.get_class(),
		"resource_name": res.resource_name,
		"resource_path": res.resource_path,
	}


func _for_each_file(path: String, callback: Callable) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var full := path.path_join(file_name)
		if dir.current_is_dir():
			_for_each_file(full, callback)
		else:
			callback.call(full)
		file_name = dir.get_next()
	dir.list_dir_end()
