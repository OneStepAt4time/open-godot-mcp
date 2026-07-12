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
		"set_control_anchors":
			return _set_control_anchors(params)
		"set_theme_override":
			return _set_theme_override(params)
		"modify_stylebox":
			return _modify_stylebox(params)
		"set_tilemap_cell":
			return _set_tilemap_cell(params)
		"get_tilemap_cells":
			return _get_tilemap_cells(params)
		"list_tilemap_layers":
			return _list_tilemap_layers(params)
		"configure_animation_tree":
			return _configure_animation_tree(params)
		"set_animation_tree_parameter":
			return _set_animation_tree_parameter(params)
		"create_animation_state_transition":
			return _create_animation_state_transition(params)
		"set_material_shader":
			return _set_material_shader(params)
		"set_shader_parameter":
			return _set_shader_parameter(params)
		"configure_particle_system":
			return _configure_particle_system(params)
		"perform_raycast_query_3d":
			return _perform_raycast_query_3d(params)
		"get_overlapping_bodies":
			return _get_overlapping_bodies(params)
		"create_audio_bus":
			return _create_audio_bus(params)
		"set_audio_bus_effect":
			return _set_audio_bus_effect(params)
		"set_audio_bus_volume":
			return _set_audio_bus_volume(params)
		"list_export_presets":
			return _list_export_presets(params)
		"run_project_export":
			return _run_project_export(params)
		"scatter_prefabs":
			return _scatter_prefabs(params)
		"generate_collision_from_mesh":
			return _generate_collision_from_mesh(params)
		"bake_navigation":
			return _bake_navigation(params)
		"get_performance_diagnostics":
			return _get_performance_diagnostics(params)
		"undo":
			return _undo()
		"redo":
			return _redo()
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
		"log_path": _find_editor_log_path(),
	}


func _find_editor_log_path() -> String:
	var candidates := [
		"user://logs/godot.log",
		"user://godot.log",
		"res://godot.log",
	]
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return ProjectSettings.globalize_path(candidate)
	return ProjectSettings.globalize_path("user://logs/godot.log")


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
		inst.queue_free()
		return {"error": "no scene open"}
	var parent := root.get_node(parent_path) if parent_path != "." else root
	if parent == null:
		inst.queue_free()
		return {"error": "parent not found: " + parent_path}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Instance Scene: " + inst.name)
	undo_redo.add_do_method(parent, "add_child", inst)
	undo_redo.add_do_method(inst, "set_owner", root)
	undo_redo.add_undo_method(parent, "remove_child", inst)
	undo_redo.add_undo_reference(inst)
	undo_redo.commit_action()

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

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add Node: " + node.name)
	undo_redo.add_do_method(parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", root)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()

	return {"ok": true, "name": node.name, "path": str(node.get_path())}


func _delete_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	var root := EditorInterface.get_edited_scene_root()
	if node == root:
		return {"error": "cannot delete the root node of the scene"}
	var parent := node.get_parent()
	var index := node.get_index()

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Delete Node: " + node.name)
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(parent, "move_child", node, index)
	undo_redo.add_undo_method(node, "set_owner", root)
	undo_redo.commit_action()

	return {"ok": true}


func _duplicate_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	var root := EditorInterface.get_edited_scene_root()
	var parent := node.get_parent()
	if parent == null:
		return {"error": "node parent not found"}
	var dup := node.duplicate()

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Duplicate Node: " + node.name)
	undo_redo.add_do_method(parent, "add_child", dup)
	undo_redo.add_do_method(dup, "set_owner", root)
	undo_redo.add_undo_method(parent, "remove_child", dup)
	undo_redo.add_undo_reference(dup)
	undo_redo.commit_action()

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
	var old_parent := node.get_parent()
	var old_index := node.get_index()

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Move Node: " + node.name)
	
	# Do action
	undo_redo.add_do_method(old_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node)
	if new_index >= 0:
		undo_redo.add_do_method(new_parent, "move_child", node, new_index)
	undo_redo.add_do_method(node, "set_owner", root)

	# Undo action
	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(old_parent, "add_child", node)
	undo_redo.add_undo_method(old_parent, "move_child", node, old_index)
	undo_redo.add_undo_method(node, "set_owner", root)

	undo_redo.commit_action()

	return {"ok": true, "path": str(node.get_path())}


func _rename_node(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var new_name: String = p.get("new_name", "")
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	var old_name := node.name

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Rename Node: " + old_name + " to " + new_name)
	undo_redo.add_do_property(node, "name", new_name)
	undo_redo.add_undo_property(node, "name", old_name)
	undo_redo.commit_action()

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
	var old_value = node.get(property)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update Property: " + property + " on " + node.name)
	undo_redo.add_do_property(node, property, value)
	undo_redo.add_undo_property(node, property, old_value)
	undo_redo.commit_action()

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
	
	var callable := Callable(target, method_name)
	if source.is_connected(signal_name, callable):
		return {"ok": true, "note": "already connected"}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Connect Signal: " + signal_name)
	undo_redo.add_do_method(source, "connect", signal_name, callable)
	undo_redo.add_undo_method(source, "disconnect", signal_name, callable)
	undo_redo.commit_action()

	return {"ok": true}


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
	
	var callable := Callable(target, method_name)
	if not source.is_connected(signal_name, callable):
		return {"ok": true, "note": "already disconnected"}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Disconnect Signal: " + signal_name)
	undo_redo.add_do_method(source, "disconnect", signal_name, callable)
	undo_redo.add_undo_method(source, "connect", signal_name, callable)
	undo_redo.commit_action()

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

	var old_groups := node.get_groups()
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Groups on " + node.name)

	# Do methods
	for g in old_groups:
		undo_redo.add_do_method(node, "remove_from_group", str(g))
	for g in groups:
		undo_redo.add_do_method(node, "add_to_group", str(g))

	# Undo methods
	for g in groups:
		undo_redo.add_undo_method(node, "remove_from_group", str(g))
	for g in old_groups:
		undo_redo.add_undo_method(node, "add_to_group", str(g))

	undo_redo.commit_action()

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
	var old_script = node.get_script()

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Attach Script to " + node.name)
	undo_redo.add_do_property(node, "script", script)
	undo_redo.add_undo_property(node, "script", old_script)
	undo_redo.commit_action()

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


func _get_editor_screenshot(params: Variant) -> Dictionary:
	var p := _dict(params)
	var viewport_type: String = p.get("viewport", "3d")
	var viewport: SubViewport
	if viewport_type == "2d":
		viewport = EditorInterface.get_editor_viewport_2d()
	else:
		viewport = EditorInterface.get_editor_viewport_3d()
	if viewport == null:
		return {"error": "cannot access editor viewport"}
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
		"size": {"x": image.get_width(), "y": image.get_height()},
		"viewport": viewport_type
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
	var cam := _find_first_node_of_class(root, "Camera3D") as Camera3D
	if cam == null:
		return {"error": "no Camera3D found in current scene"}
	var pos := _dict(p.get("position", {}))
	var rot := _dict(p.get("rotation", {}))
	
	var old_pos = cam.position
	var old_rot = cam.rotation
	var old_fov = cam.fov

	var new_pos = Vector3(
		float(pos.get("x", cam.position.x)) if pos.has("x") else cam.position.x,
		float(pos.get("y", cam.position.y)) if pos.has("y") else cam.position.y,
		float(pos.get("z", cam.position.z)) if pos.has("z") else cam.position.z
	)
	var new_rot = Vector3(
		float(rot.get("x", cam.rotation.x)) if rot.has("x") else cam.rotation.x,
		float(rot.get("y", cam.rotation.y)) if rot.has("y") else cam.rotation.y,
		float(rot.get("z", cam.rotation.z)) if rot.has("z") else cam.rotation.z
	)
	var new_fov = float(p.get("fov", cam.fov)) if p.has("fov") else cam.fov

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Camera3D Transform")
	
	undo_redo.add_do_property(cam, "position", new_pos)
	undo_redo.add_do_property(cam, "rotation", new_rot)
	undo_redo.add_do_property(cam, "fov", new_fov)

	undo_redo.add_undo_property(cam, "position", old_pos)
	undo_redo.add_undo_property(cam, "rotation", old_rot)
	undo_redo.add_undo_property(cam, "fov", old_fov)
	
	undo_redo.commit_action()

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


func _undo() -> Dictionary:
	var ev := InputEventKey.new()
	ev.keycode = KEY_Z
	ev.ctrl_pressed = true
	ev.pressed = true
	Input.parse_input_event(ev)
	var release := ev.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	return {"ok": true}


func _redo() -> Dictionary:
	var ev := InputEventKey.new()
	ev.keycode = KEY_Z
	ev.ctrl_pressed = true
	ev.shift_pressed = true
	ev.pressed = true
	Input.parse_input_event(ev)
	var release := ev.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	return {"ok": true}


func _set_control_anchors(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var preset: int = int(p.get("preset", 0))
	var keep_offsets: bool = p.get("keep_offsets", false)
	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if not node is Control:
		return {"error": "node is not a Control"}

	var old_anchors := [node.anchor_left, node.anchor_top, node.anchor_right, node.anchor_bottom]
	var old_offsets := [node.offset_left, node.offset_top, node.offset_right, node.offset_bottom]

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Anchors Preset on " + node.name)
	undo_redo.add_do_method(node, "set_anchors_preset", preset, keep_offsets)
	
	undo_redo.add_undo_property(node, "anchor_left", old_anchors[0])
	undo_redo.add_undo_property(node, "anchor_top", old_anchors[1])
	undo_redo.add_undo_property(node, "anchor_right", old_anchors[2])
	undo_redo.add_undo_property(node, "anchor_bottom", old_anchors[3])
	undo_redo.add_undo_property(node, "offset_left", old_offsets[0])
	undo_redo.add_undo_property(node, "offset_top", old_offsets[1])
	undo_redo.add_undo_property(node, "offset_right", old_offsets[2])
	undo_redo.add_undo_property(node, "offset_bottom", old_offsets[3])
	
	undo_redo.commit_action()
	return {"ok": true}


func _set_theme_override(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var override_type: String = p.get("override_type", "")
	var name: String = p.get("name", "")
	var value: Variant = p.get("value", null)

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if not node is Control:
		return {"error": "node is not a Control"}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Theme Override on " + node.name)

	match override_type:
		"color":
			var col := _coerce_value(value) as Color
			var has_old = node.has_theme_color_override(name)
			var old_val = node.get_theme_color(name) if has_old else Color()

			undo_redo.add_do_method(node, "add_theme_color_override", name, col)
			if has_old:
				undo_redo.add_theme_color_override(name, old_val)
			else:
				undo_redo.add_undo_method(node, "remove_theme_color_override", name)

		"font_size":
			var size := int(value)
			var has_old = node.has_theme_font_size_override(name)
			var old_val = node.get_theme_font_size(name) if has_old else 0

			undo_redo.add_do_method(node, "add_theme_font_size_override", name, size)
			if has_old:
				undo_redo.add_theme_font_size_override(name, old_val)
			else:
				undo_redo.add_undo_method(node, "remove_theme_font_size_override", name)

		"constant":
			var val := int(value)
			var has_old = node.has_theme_constant_override(name)
			var old_val = node.get_theme_constant(name) if has_old else 0

			undo_redo.add_do_method(node, "add_theme_constant_override", name, val)
			if has_old:
				undo_redo.add_theme_constant_override(name, old_val)
			else:
				undo_redo.add_undo_method(node, "remove_theme_constant_override", name)

		"font":
			var font := load(str(value)) as Font
			if font == null:
				return {"error": "cannot load font: " + str(value)}
			var has_old = node.has_theme_font_override(name)
			var old_val = node.get_theme_font(name) if has_old else null

			undo_redo.add_do_method(node, "add_theme_font_override", name, font)
			if has_old:
				undo_redo.add_theme_font_override(name, old_val)
			else:
				undo_redo.add_undo_method(node, "remove_theme_font_override", name)

		"stylebox":
			var sb := load(str(value)) as StyleBox
			if sb == null:
				return {"error": "cannot load stylebox: " + str(value)}
			var has_old = node.has_theme_stylebox_override(name)
			var old_val = node.get_theme_stylebox(name) if has_old else null

			undo_redo.add_do_method(node, "add_theme_stylebox_override", name, sb)
			if has_old:
				undo_redo.add_theme_stylebox_override(name, old_val)
			else:
				undo_redo.add_undo_method(node, "remove_theme_stylebox_override", name)
		_:
			return {"error": "unknown override type: " + override_type}

	undo_redo.commit_action()
	return {"ok": true}


func _modify_stylebox(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var theme_item_name: String = p.get("theme_item_name", "")
	var theme_type_name: String = p.get("theme_type_name", "")
	var property: String = p.get("property", "")
	var value: Variant = p.get("value", null)

	if path.is_empty() or property.is_empty():
		return {"error": "missing path or property"}

	var res := load(path)
	if res == null:
		return {"error": "cannot load resource: " + path}

	var sb: StyleBox = null
	if res is StyleBox:
		sb = res
	elif res is Theme and not theme_item_name.is_empty() and not theme_type_name.is_empty():
		sb = res.get_stylebox(theme_item_name, theme_type_name)

	if sb == null:
		return {"error": "cannot resolve StyleBox resource"}

	var current_val = sb.get(property)
	if current_val is Color:
		value = _coerce_value(value)
	elif current_val is Vector2 or current_val is Vector3:
		value = _coerce_value(value)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Modify StyleBox: " + property)
	undo_redo.add_do_property(sb, property, value)
	undo_redo.add_undo_property(sb, property, current_val)
	undo_redo.add_do_method(sb, "emit_changed")
	undo_redo.add_undo_method(sb, "emit_changed")
	undo_redo.commit_action()

	ResourceSaver.save(res, path)
	return {"ok": true}


func _set_tilemap_cell(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var layer: int = p.get("layer", 0)
	var x: int = p.get("x", 0)
	var y: int = p.get("y", 0)
	var source_id: int = p.get("source_id", -1)
	var atlas_x: int = p.get("atlas_x", -1)
	var atlas_y: int = p.get("atlas_y", -1)
	var alternative_tile: int = p.get("alternative_tile", 0)

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}

	var coords := Vector2i(x, y)
	var atlas_coords := Vector2i(atlas_x, atlas_y)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set TileMap Cell")

	if node.has_method("set_cell"):
		if node.get_class() == "TileMap":
			var old_source_id = node.get_cell_source_id(layer, coords)
			var old_atlas = node.get_cell_atlas_coords(layer, coords)
			var old_alt = node.get_cell_alternative_tile(layer, coords)

			undo_redo.add_do_method(node, "set_cell", layer, coords, source_id, atlas_coords, alternative_tile)
			undo_redo.add_undo_method(node, "set_cell", layer, coords, old_source_id, old_atlas, old_alt)
		elif node.get_class() == "TileMapLayer":
			var old_source_id = node.get_cell_source_id(coords)
			var old_atlas = node.get_cell_atlas_coords(coords)
			var old_alt = node.get_cell_alternative_tile(coords)

			undo_redo.add_do_method(node, "set_cell", coords, source_id, atlas_coords, alternative_tile)
			undo_redo.add_undo_method(node, "set_cell", coords, old_source_id, old_atlas, old_alt)
		else:
			return {"error": "node is neither a TileMap nor a TileMapLayer"}
	else:
		return {"error": "node does not support set_cell"}

	undo_redo.commit_action()
	return {"ok": true}


func _get_tilemap_cells(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var layer: int = p.get("layer", 0)

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}

	var cells := []
	if node.get_class() == "TileMap":
		for c in node.get_used_cells(layer):
			cells.append({"x": c.x, "y": c.y})
	elif node.get_class() == "TileMapLayer":
		for c in node.get_used_cells():
			cells.append({"x": c.x, "y": c.y})
	else:
		return {"error": "node is neither a TileMap nor a TileMapLayer"}

	return {"cells": cells}


func _list_tilemap_layers(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}

	var layers := []
	if node.get_class() == "TileMap":
		var count = node.get_layers_count()
		for i in range(count):
			layers.append({
				"index": i,
				"name": node.get_layer_name(i),
				"enabled": node.is_layer_enabled(i)
			})
	elif node.get_class() == "TileMapLayer":
		layers.append({
			"index": 0,
			"name": node.name,
			"enabled": node.enabled
		})
	else:
		return {"error": "node is neither a TileMap nor a TileMapLayer"}

	return {"layers": layers}


func _configure_animation_tree(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var anim_player_path: String = p.get("anim_player_path", "")
	var active: bool = p.get("active", true)

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if not node is AnimationTree:
		return {"error": "node is not an AnimationTree"}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Configure AnimationTree")

	var old_player = node.anim_player
	var old_active = node.active

	undo_redo.add_do_property(node, "anim_player", anim_player_path)
	undo_redo.add_do_property(node, "active", active)

	undo_redo.add_undo_property(node, "anim_player", old_player)
	undo_redo.add_undo_property(node, "active", old_active)

	undo_redo.commit_action()
	return {"ok": true}


func _set_animation_tree_parameter(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var parameter: String = p.get("parameter", "")
	var value: Variant = p.get("value", null)

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if not node is AnimationTree:
		return {"error": "node is not an AnimationTree"}

	if not parameter.begins_with("parameters/"):
		parameter = "parameters/" + parameter

	var current_val = node.get(parameter)
	if current_val is Vector2 or current_val is Vector3:
		value = _coerce_value(value)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set AnimationTree Parameter: " + parameter)
	undo_redo.add_do_property(node, parameter, value)
	undo_redo.add_undo_property(node, parameter, current_val)
	undo_redo.commit_action()

	return {"ok": true}


func _create_animation_state_transition(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var from_state: String = p.get("from_state", "")
	var to_state: String = p.get("to_state", "")
	var switch_mode: int = p.get("switch_mode", 0)
	var advance_mode: int = p.get("advance_mode", 1)
	var advance_condition: String = p.get("advance_condition", "")
	var xfade_time: float = p.get("xfade_time", 0.0)

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if not node is AnimationTree:
		return {"error": "node is not an AnimationTree"}

	var state_machine := node.tree_root as AnimationNodeStateMachine
	if state_machine == null:
		return {"error": "AnimationTree root node is not an AnimationNodeStateMachine"}

	if not state_machine.has_node(from_state) or not state_machine.has_node(to_state):
		return {"error": "from_state or to_state does not exist in the state machine"}

	var transition := AnimationNodeStateMachineTransition.new()
	transition.switch_mode = switch_mode as AnimationNodeStateMachineTransition.SwitchMode
	transition.advance_mode = advance_mode as AnimationNodeStateMachineTransition.AdvanceMode
	if not advance_condition.is_empty():
		transition.advance_condition = advance_condition
	transition.xfade_time = xfade_time

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add Animation State Transition")

	var has_old = state_machine.has_transition(from_state, to_state)
	var old_trans = null
	if has_old:
		old_trans = state_machine.get_transition(state_machine.find_transition(from_state, to_state))

	if has_old:
		undo_redo.add_do_method(state_machine, "remove_transition", from_state, to_state)
	undo_redo.add_do_method(state_machine, "add_transition", from_state, to_state, transition)

	undo_redo.add_undo_method(state_machine, "remove_transition", from_state, to_state)
	if has_old:
		undo_redo.add_undo_method(state_machine, "add_transition", from_state, to_state, old_trans)

	undo_redo.commit_action()
	return {"ok": true}


func _set_material_shader(params: Variant) -> Dictionary:
	var p := _dict(params)
	var material_path: String = p.get("material_path", "")
	var shader_path: String = p.get("shader_path", "")

	if material_path.is_empty() or shader_path.is_empty():
		return {"error": "missing material_path or shader_path"}

	var shader := load(shader_path) as Shader
	if shader == null:
		return {"error": "cannot load shader: " + shader_path}

	var material: ShaderMaterial = null
	var node: Node = null

	if material_path.begins_with("res://") or material_path.begins_with("user://"):
		var res := load(material_path)
		if res == null:
			material = ShaderMaterial.new()
			ResourceSaver.save(material, material_path)
		elif res is ShaderMaterial:
			material = res
		else:
			return {"error": "resource is not a ShaderMaterial: " + material_path}
	else:
		node = _get_node(material_path)
		if node == null:
			return {"error": "node not found: " + material_path}
		if node is CanvasItem or node is GeometryInstance3D:
			if node.material == null:
				node.material = ShaderMaterial.new()
			material = node.material as ShaderMaterial

	if material == null:
		return {"error": "cannot resolve ShaderMaterial"}

	var old_shader = material.shader
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Material Shader")
	undo_redo.add_do_property(material, "shader", shader)
	undo_redo.add_undo_property(material, "shader", old_shader)
	undo_redo.add_do_method(material, "emit_changed")
	undo_redo.add_undo_method(material, "emit_changed")
	undo_redo.commit_action()

	if material_path.begins_with("res://") or material_path.begins_with("user://"):
		ResourceSaver.save(material, material_path)

	return {"ok": true}


func _set_shader_parameter(params: Variant) -> Dictionary:
	var p := _dict(params)
	var material_path: String = p.get("material_path", "")
	var parameter_name: String = p.get("parameter_name", "")
	var value: Variant = p.get("value", null)

	if material_path.is_empty() or parameter_name.is_empty():
		return {"error": "missing material_path or parameter_name"}

	var material: ShaderMaterial = null
	var node: Node = null

	if material_path.begins_with("res://") or material_path.begins_with("user://"):
		var res := load(material_path) as ShaderMaterial
		if res == null:
			return {"error": "cannot load ShaderMaterial: " + material_path}
		material = res
	else:
		node = _get_node(material_path)
		if node == null:
			return {"error": "node not found: " + material_path}
		if node is CanvasItem or node is GeometryInstance3D:
			material = node.material as ShaderMaterial

	if material == null:
		return {"error": "cannot resolve ShaderMaterial"}

	var old_val = material.get_shader_parameter(parameter_name)
	if old_val is Color:
		value = _coerce_value(value)
	elif old_val is Vector2 or old_val is Vector3:
		value = _coerce_value(value)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Shader Parameter: " + parameter_name)
	undo_redo.add_do_method(material, "set_shader_parameter", parameter_name, value)
	undo_redo.add_undo_method(material, "set_shader_parameter", parameter_name, old_val)
	undo_redo.add_do_method(material, "emit_changed")
	undo_redo.add_undo_method(material, "emit_changed")
	undo_redo.commit_action()

	if material_path.begins_with("res://") or material_path.begins_with("user://"):
		ResourceSaver.save(material, material_path)

	return {"ok": true}


func _configure_particle_system(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var settings: Dictionary = p.get("settings", {})

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if not (node is GPUParticles2D or node is GPUParticles3D or node is CPUParticles2D or node is CPUParticles3D):
		return {"error": "node is not a particle system"}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Configure Particle System: " + node.name)

	var process_mat: Material = null
	if node.has_method("get_process_material"):
		process_mat = node.process_material
		if process_mat == null and settings.keys().any(func(k): return not k in node):
			node.process_material = ParticleProcessMaterial.new()
			process_mat = node.process_material

	for key in settings.keys():
		var val = settings[key]
		if key in node:
			var old_val = node.get(key)
			if old_val is Color or old_val is Vector2 or old_val is Vector3:
				val = _coerce_value(val)
			undo_redo.add_do_property(node, key, val)
			undo_redo.add_undo_property(node, key, old_val)
		elif process_mat != null and key in process_mat:
			var old_val = process_mat.get(key)
			if old_val is Color or old_val is Vector2 or old_val is Vector3:
				val = _coerce_value(val)
			undo_redo.add_do_property(process_mat, key, val)
			undo_redo.add_undo_property(process_mat, key, old_val)

	undo_redo.add_do_method(node, "emit_changed")
	undo_redo.add_undo_method(node, "emit_changed")
	if process_mat:
		undo_redo.add_do_method(process_mat, "emit_changed")
		undo_redo.add_undo_method(process_mat, "emit_changed")

	undo_redo.commit_action()
	return {"ok": true}


func _perform_raycast_query_3d(params: Variant) -> Dictionary:
	var p := _dict(params)
	var from := _coerce_value(p.get("from", {})) as Vector3
	var to := _coerce_value(p.get("to", {})) as Vector3
	var exclude_paths: Array = p.get("exclude_paths", [])

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"error": "no scene open"}

	var world_3d: World3D = null
	if root is Node3D:
		world_3d = root.get_world_3d()
	else:
		var cam = EditorInterface.get_editor_viewport_3d().get_camera_3d()
		if cam:
			world_3d = cam.get_world_3d()

	if world_3d == null:
		return {"error": "cannot find World3D"}

	var space_state := world_3d.direct_space_state
	if space_state == null:
		return {"error": "physics space state is not available"}

	var query := PhysicsRayQueryParameters3D.create(from, to)

	var exclude_rids := []
	for path in exclude_paths:
		var node = root.get_node(str(path))
		if node and node is CollisionObject3D:
			exclude_rids.append(node.get_rid())
	query.exclude = exclude_rids

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return {"hit": false}

	var hit_node = result.get("collider") as Node
	var hit_path = str(hit_node.get_path()) if hit_node else ""
	return {
		"hit": true,
		"position": var_to_str(result.get("position")),
		"normal": var_to_str(result.get("normal")),
		"collider_path": hit_path,
		"collider_id": result.get("collider_id"),
		"rid": var_to_str(result.get("rid")),
		"shape": result.get("shape")
	}


func _get_overlapping_bodies(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}

	var root := EditorInterface.get_edited_scene_root()
	var overlaps := []

	if node is Area3D:
		var world_3d = node.get_world_3d()
		var space_state = world_3d.direct_space_state
		if space_state == null:
			return {"error": "no 3D physics space"}

		for child in node.get_children():
			if child is CollisionShape3D and child.shape != null:
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = child.shape
				query.transform = child.global_transform
				query.exclude = [node.get_rid()]

				var results = space_state.intersect_shape(query)
				for r in results:
					var collider = r.get("collider") as Node
					if collider and collider != node:
						var c_path = str(collider.get_path())
						if not overlaps.has(c_path):
							overlaps.append(c_path)

	elif node is Area2D:
		var world_2d = node.get_world_2d()
		var space_state = world_2d.direct_space_state
		if space_state == null:
			return {"error": "no 2D physics space"}

		for child in node.get_children():
			if child is CollisionShape2D and child.shape != null:
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape = child.shape
				query.transform = child.global_transform
				query.exclude = [node.get_rid()]

				var results = space_state.intersect_shape(query)
				for r in results:
					var collider = r.get("collider") as Node
					if collider and collider != node:
						var c_path = str(collider.get_path())
						if not overlaps.has(c_path):
							overlaps.append(c_path)
	else:
		return {"error": "node is not an Area2D or Area3D"}

	return {"overlapping_paths": overlaps}


func _create_audio_bus(params: Variant) -> Dictionary:
	var p := _dict(params)
	var name: String = p.get("name", "")
	var index: int = p.get("index", -1)

	if name.is_empty():
		return {"error": "missing name"}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Create Audio Bus: " + name)

	var actual_index = index if index >= 0 else AudioServer.get_bus_count()

	undo_redo.add_do_method(AudioServer, "add_bus", actual_index)
	undo_redo.add_do_method(AudioServer, "set_bus_name", actual_index, name)
	undo_redo.add_undo_method(AudioServer, "remove_bus", actual_index)

	undo_redo.commit_action()
	return {"ok": true, "index": actual_index}


func _set_audio_bus_effect(params: Variant) -> Dictionary:
	var p := _dict(params)
	var bus_name: String = p.get("bus_name", "")
	var effect_type: String = p.get("effect_type", "")
	var index: int = p.get("index", -1)

	if bus_name.is_empty() or effect_type.is_empty():
		return {"error": "missing bus_name or effect_type"}

	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return {"error": "audio bus not found: " + bus_name}

	var effect = ClassDB.instantiate(effect_type)
	if effect == null:
		return {"error": "cannot instantiate audio effect: " + effect_type}

	var actual_index = index if index >= 0 else AudioServer.get_bus_effect_count(bus_idx)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Add Audio Effect: " + effect_type)

	undo_redo.add_do_method(AudioServer, "add_bus_effect", bus_idx, effect, actual_index)
	undo_redo.add_undo_method(AudioServer, "remove_bus_effect", bus_idx, actual_index)

	undo_redo.commit_action()
	return {"ok": true, "index": actual_index}


func _set_audio_bus_volume(params: Variant) -> Dictionary:
	var p := _dict(params)
	var bus_name: String = p.get("bus_name", "")
	var volume_db: float = float(p.get("volume_db", 0.0))

	if bus_name.is_empty():
		return {"error": "missing bus_name"}

	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return {"error": "audio bus not found: " + bus_name}

	var old_volume = AudioServer.get_bus_volume_db(bus_idx)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Set Audio Bus Volume: " + bus_name)
	undo_redo.add_do_method(AudioServer, "set_bus_volume_db", bus_idx, volume_db)
	undo_redo.add_undo_method(AudioServer, "set_bus_volume_db", bus_idx, old_volume)
	undo_redo.commit_action()

	return {"ok": true}


func _list_export_presets(_params: Variant) -> Dictionary:
	var path := "res://export_presets.cfg"
	if not FileAccess.file_exists(path):
		return {"presets": [], "note": "export_presets.cfg does not exist"}

	var config := ConfigFile.new()
	var err = config.load(path)
	if err != OK:
		return {"error": "cannot load export presets", "code": err}

	var presets := []
	for section in config.get_sections():
		if section.begins_with("preset."):
			var name = config.get_value(section, "name", "")
			var platform = config.get_value(section, "platform", "")
			var export_path = config.get_value(section, "export_path", "")
			presets.append({
				"id": section.get_slice(".", 1),
				"name": name,
				"platform": platform,
				"export_path": export_path
			})
	return {"presets": presets}


func _run_project_export(params: Variant) -> Dictionary:
	var p := _dict(params)
	var preset_name: String = p.get("preset_name", "")
	var output_path: String = p.get("output_path", "")

	if preset_name.is_empty() or output_path.is_empty():
		return {"error": "missing preset_name or output_path"}

	var output := []
	var args := [
		"--headless",
		"--export-release" if p.get("release", true) else "--export-debug",
		preset_name,
		ProjectSettings.globalize_path(output_path)
	]

	var exec_path = OS.get_executable_path()
	var exit_code = OS.execute(exec_path, args, output, true)
	var output_str = "\n".join(output)

	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": output_str
	}


func _scatter_prefabs(params: Variant) -> Dictionary:
	var p := _dict(params)
	var prefab_path: String = p.get("prefab_path", "")
	var parent_path: String = p.get("parent_path", "")
	var count: int = p.get("count", 1)
	var bounds: Dictionary = p.get("bounds", {})
	var min_scale: float = float(p.get("min_scale", 1.0))
	var max_scale: float = float(p.get("max_scale", 1.0))
	var min_rotation = p.get("min_rotation", 0.0)
	var max_rotation = p.get("max_rotation", 0.0)

	var parent := _get_node(parent_path)
	if parent == null:
		return {"error": "parent node not found: " + parent_path}

	var scene := load(prefab_path) as PackedScene
	if scene == null:
		return {"error": "cannot load prefab scene: " + prefab_path}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Scatter Prefabs: " + prefab_path)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var is_3d := parent is Node3D

	for i in range(count):
		var inst = scene.instantiate()
		inst.name = inst.name + "_" + str(i)

		var s = rng.randf_range(min_scale, max_scale)
		if is_3d:
			inst.scale = Vector3(s, s, s)
		else:
			inst.scale = Vector2(s, s)

		if is_3d:
			var px = rng.randf_range(bounds.get("x", 0.0), bounds.get("x", 0.0) + bounds.get("size_x", 0.0))
			var py = rng.randf_range(bounds.get("y", 0.0), bounds.get("y", 0.0) + bounds.get("size_y", 0.0))
			var pz = rng.randf_range(bounds.get("z", 0.0), bounds.get("z", 0.0) + bounds.get("size_z", 0.0))
			inst.position = Vector3(px, py, pz)

			var rx_min = 0.0; var rx_max = 0.0
			var ry_min = 0.0; var ry_max = 0.0
			var rz_min = 0.0; var rz_max = 0.0
			if min_rotation is Dictionary:
				rx_min = float(min_rotation.get("x", 0.0))
				ry_min = float(min_rotation.get("y", 0.0))
				rz_min = float(min_rotation.get("z", 0.0))
			if max_rotation is Dictionary:
				rx_max = float(max_rotation.get("x", 0.0))
				ry_max = float(max_rotation.get("y", 0.0))
				rz_max = float(max_rotation.get("z", 0.0))

			var rx = deg_to_rad(rng.randf_range(rx_min, rx_max))
			var ry = deg_to_rad(rng.randf_range(ry_min, ry_max))
			var rz = deg_to_rad(rng.randf_range(rz_min, rz_max))
			inst.rotation = Vector3(rx, ry, rz)
		else:
			var px = rng.randf_range(bounds.get("x", 0.0), bounds.get("x", 0.0) + bounds.get("width", 0.0))
			var py = rng.randf_range(bounds.get("y", 0.0), bounds.get("y", 0.0) + bounds.get("height", 0.0))
			inst.position = Vector2(px, py)

			var r_min = float(min_rotation)
			var r_max = float(max_rotation)
			inst.rotation = deg_to_rad(rng.randf_range(r_min, r_max))

		undo_redo.add_do_method(parent, "add_child", inst)
		undo_redo.add_do_reference(inst)
		undo_redo.add_do_method(inst, "set_owner", EditorInterface.get_edited_scene_root())
		undo_redo.add_undo_method(parent, "remove_child", inst)

	undo_redo.commit_action()
	return {"ok": true}


func _generate_collision_from_mesh(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")
	var collision_type: String = p.get("collision_type", "trimesh")

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}
	if not node is MeshInstance3D:
		return {"error": "node is not a MeshInstance3D"}

	var old_children = node.get_children()
	if collision_type == "trimesh":
		node.create_trimesh_collision()
	elif collision_type == "convex":
		node.create_convex_collision(true, false)
	else:
		return {"error": "unknown collision type: " + collision_type}

	var new_children = node.get_children()
	var added: Node = null
	for child in new_children:
		if not child in old_children:
			added = child
			break

	if added == null:
		return {"error": "failed to generate collision shape"}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Generate Collision from Mesh")

	node.remove_child(added)

	undo_redo.add_do_method(node, "add_child", added)
	undo_redo.add_do_method(added, "set_owner", EditorInterface.get_edited_scene_root())
	for c in added.get_children():
		undo_redo.add_do_method(c, "set_owner", EditorInterface.get_edited_scene_root())
	undo_redo.add_do_reference(added)

	undo_redo.add_undo_method(node, "remove_child", added)

	undo_redo.commit_action()
	return {"ok": true}


func _bake_navigation(params: Variant) -> Dictionary:
	var p := _dict(params)
	var path: String = p.get("path", "")

	var node := _get_node(path)
	if node == null:
		return {"error": "node not found: " + path}

	if node is NavigationRegion3D:
		node.bake_navigation_mesh(false)
		return {"ok": true, "type": "3D"}
	elif node is NavigationRegion2D:
		node.bake_navigation_polygon(false)
		return {"ok": true, "type": "2D"}
	else:
		return {"error": "node is not a NavigationRegion2D or NavigationRegion3D"}


func _get_performance_diagnostics(_params: Variant) -> Dictionary:
	var diagnostics := {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"memory_static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"objects_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"draw_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives_rendered": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"physics_3d_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"physics_2d_active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	}
	return diagnostics
