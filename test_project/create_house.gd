@tool
extends EditorScript

func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.name != "House":
		var scene := Node3D.new()
		scene.name = "House"
		var ps := PackedScene.new()
		ps.pack(scene)
		ResourceSaver.save(ps, "res://house.tscn")
		EditorInterface.open_scene_from_path("res://house.tscn")
		root = EditorInterface.get_edited_scene_root()

	# Rimuovi nodi esistenti tranne la root
	for child in root.get_children():
		child.queue_free()

	# Pavimento
	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	floor.mesh = BoxMesh.new()
	floor.mesh.size = Vector3(8, 0.2, 8)
	floor.position = Vector3(0, -0.1, 0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.5, 0.2)
	floor.material_override = floor_mat
	root.add_child(floor)
	floor.owner = root

	# Muri
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.9, 0.85, 0.7)

	var walls := [
		{"name": "WallFront", "size": Vector3(8, 3, 0.2), "pos": Vector3(0, 1.5, -4)},
		{"name": "WallBack", "size": Vector3(8, 3, 0.2), "pos": Vector3(0, 1.5, 4)},
		{"name": "WallLeft", "size": Vector3(0.2, 3, 8), "pos": Vector3(-4, 1.5, 0)},
		{"name": "WallRight", "size": Vector3(0.2, 3, 8), "pos": Vector3(4, 1.5, 0)},
	]
	for w in walls:
		var wall := MeshInstance3D.new()
		wall.name = w["name"]
		wall.mesh = BoxMesh.new()
		wall.mesh.size = w["size"]
		wall.position = w["pos"]
		wall.material_override = wall_mat
		root.add_child(wall)
		wall.owner = root

	# Tetto
	var roof := MeshInstance3D.new()
	roof.name = "Roof"
	roof.mesh = PrismMesh.new()
	roof.mesh.size = Vector3(9, 2.5, 9)
	roof.position = Vector3(0, 4.25, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.6, 0.2, 0.1)
	roof.material_override = roof_mat
	root.add_child(roof)
	roof.owner = root

	# Luce
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(5, 10, 5)
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(45), 0)
	root.add_child(sun)
	sun.owner = root

	# Camera
	var cam := Camera3D.new()
	cam.name = "MainCamera"
	cam.position = Vector3(10, 8, 10)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	root.add_child(cam)
	cam.owner = root

	EditorInterface.save_scene()
	print("House scene created")
