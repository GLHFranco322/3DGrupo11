extends SceneTree

# Saca del mapa hecho a mano de Fabricio (niveles/2_ferreteria/mapa_fabricio/
# laberinto_ferreteria.tscn) zonas enteras, tal cual él las armó, para que
# MazeBuilder las ponga en el laberinto al azar:
#   kit/zona_atencion.tscn: la zona de atención (pared del medio con el
#   tablero de corcho, los planos, el reloj y las dianas; sillón, mesa, silla,
#   puertas de entrada con los cactus, pallets en las esquinas y estanterías
#   contra los costados). El mostrador y el tablero de entregas los pone el
#   nivel (son los que funcionan).
# La zona queda con el origen en el medio de la pared que da al laberinto y
# hacia +Z hacia el fondo. "collisions" (metadato) son las cajas de lo que se
# choca.
#
# Se corre (con el editor cerrado o recargando el proyecto después):
#   Godot_console.exe --headless --path . -s res://niveles/2_ferreteria/kit/extraer_zonas.gd

const SOURCE := "res://niveles/2_ferreteria/mapa_fabricio/laberinto_ferreteria.tscn"
const OUT := "res://niveles/2_ferreteria/kit/"
const MESHES := "res://niveles/2_ferreteria/kit/mallas_zonas/"

# Zona de atención en el mapa de Fabricio: X de la línea del medio, Z de la
# pared que da al laberinto y hasta dónde llega hacia el fondo (-Z)
const FRONT_CENTER_X := -0.6
const FRONT_WALL_Z := -27.5
const FRONT_REGION := Rect2(-21.0, -48.5, 41.0, 20.3)
# Grupos que no van: las paredes de afuera las hace MazeBuilder, el mostrador
# y el tablero los pone el nivel, y luces, piso y techo también los hace él
const SKIP_GROUPS := ["Piso", "Techo", "Luces", "Escritorio", "Tablero", "Computer",
		"ParedesHorizontales1", "ParedesHorizontales2", "Paredesverticales1",
		"Paredesverticales2", "Paredeslaberinto", "PuertasAbiertas"]
# Sueltos que no van (la caja estaba arriba del mostrador de él)
const SKIP_NODES := ["Box_C"]
# El piso de él tiene 0,5 de alto: los muebles están apoyados ahí y las paredes
# arrancan en 0 (en el laberinto el piso está en 0)
const FLOOR_Y := 0.5

var _lab: Node3D
var _done := false
var _saved: Dictionary = {}


func _initialize() -> void:
	_lab = load(SOURCE).instantiate()
	root.add_child(_lab)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES))
	_save_front()
	return true


func _save_front() -> void:
	var parts: Array = []
	var walls: Array = []
	for group in _lab.get_children():
		if group.name in SKIP_GROUPS:
			continue
		for mesh in _meshes_of(group):
			if mesh.name in SKIP_NODES:
				continue
			# De las paredes de la entrada, solo la del medio de la zona
			if group.name == "ParedesInicio" and absf(_box(mesh).get_center().z - FRONT_WALL_Z) < 1.0:
				continue
			var center := _box(mesh).get_center()
			if FRONT_REGION.has_point(Vector2(center.x, center.z)):
				parts.append(mesh)
				if group.name == "ParedesInicio":
					walls.append(mesh)
	# Girada 180°: el fondo de la zona de él (-Z) queda hacia +Z
	var frame := Transform3D(Basis(Vector3.UP, PI), Vector3(FRONT_CENTER_X, FLOOR_Y, FRONT_WALL_Z))
	_pack("zona_atencion", parts, frame, walls)


func _pack(scene_name: String, parts: Array, frame: Transform3D, walls: Array = []) -> void:
	var zone := Node3D.new()
	zone.name = scene_name
	var to_local := frame.affine_inverse()
	for i in parts.size():
		var source: MeshInstance3D = parts[i]
		var copy := MeshInstance3D.new()
		copy.name = "%s_%d" % [source.name.validate_node_name(), i]
		copy.mesh = _saved_mesh(source)
		copy.transform = to_local * source.global_transform
		# Las paredes conservan su altura (arrancan en el piso de verdad)
		if source in walls:
			copy.position.y += FLOOR_Y
		for s in source.get_surface_override_material_count():
			copy.set_surface_override_material(s, source.get_surface_override_material(s))
		copy.material_override = source.material_override
		# Las puertas van pegadas a la pared del fondo: MazeBuilder las corre
		# hasta su pared (la de él no está en el mismo lugar)
		if _is_door(source):
			copy.set_meta("pegar_al_fondo", true)
		zone.add_child(copy)
		copy.owner = zone
	# Colisión: una caja por cada grupo de cosas que se tocan y llegan al piso
	# (las puertas no: quedan planas contra la pared)
	var collisions: Array[AABB] = []
	var props := parts.filter(func(p): return not p in walls and not _is_door(p))
	for cluster in _clusters(props, 0.02):
		var box := to_local * _world_box(cluster)
		if box.position.y < 0.3 and box.size.y > 0.4:
			collisions.append(box)
	for wall in walls:
		var box := to_local * _box(wall)
		box.position.y += FLOOR_Y
		collisions.append(box)
	zone.set_meta("collisions", collisions)
	var scene := PackedScene.new()
	scene.pack(zone)
	ResourceSaver.save(scene, OUT + scene_name + ".tscn")
	print("%s: %d mallas, %d cajas de colisión" % [scene_name, parts.size(), collisions.size()])
	zone.free()


func _is_door(mesh: MeshInstance3D) -> bool:
	return str(mesh.name).begins_with("Door")


func _saved_mesh(source: MeshInstance3D) -> Mesh:
	if _saved.has(source.mesh):
		return _saved[source.mesh]
	var mesh: Mesh = source.mesh
	if not mesh.resource_path.begins_with("res://") or mesh.resource_path.contains("::"):
		mesh = mesh.duplicate(true)
		var file_name := source.mesh.resource_name if source.mesh.resource_name != "" else str(source.name)
		file_name = file_name.validate_filename().replace(" ", "_")
		var path := MESHES + "%s.res" % file_name
		var n := 2
		while _saved.values().any(func(m): return m.resource_path == path):
			path = MESHES + "%s_%d.res" % [file_name, n]
			n += 1
		ResourceSaver.save(mesh, path)
		mesh = load(path)
	_saved[source.mesh] = mesh
	return mesh


func _meshes_of(node: Node) -> Array:
	var result := []
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes_of(child))
	return result


func _box(mesh: MeshInstance3D) -> AABB:
	return mesh.global_transform * mesh.mesh.get_aabb()


func _world_box(parts: Array) -> AABB:
	var box := _box(parts[0])
	for i in range(1, parts.size()):
		box = box.merge(_box(parts[i]))
	return box


# Grupos de mallas que se tocan (sus cajas se superponen)
func _clusters(meshes: Array, margin: float = 0.05) -> Array:
	var group := range(meshes.size())
	var boxes := meshes.map(func(m): return _box(m).grow(margin))
	for i in meshes.size():
		for j in range(i + 1, meshes.size()):
			if boxes[i].intersects(boxes[j]):
				var a: int = _find(group, i)
				var b: int = _find(group, j)
				group[b] = a
	var by_root := {}
	for i in meshes.size():
		var r: int = _find(group, i)
		if not by_root.has(r):
			by_root[r] = []
		by_root[r].append(meshes[i])
	return by_root.values()


func _find(group: Array, i: int) -> int:
	while group[i] != i:
		i = group[i]
	return i
