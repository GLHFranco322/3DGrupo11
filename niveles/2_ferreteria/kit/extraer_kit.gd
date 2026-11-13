extends SceneTree

# Arma el kit de piezas del laberinto (paredes, muebles y decoración) a partir
# del mapa hecho a mano niveles/2_ferreteria/mapa_fabricio/laberinto_ferreteria.tscn. Cada pieza
# queda como una escena en niveles/2_ferreteria/kit/, con su frente hacia +Z y
# la espalda (lo que va contra la pared) en Z = 0; MazeBuilder las reparte.
#
# Si se cambia el mapa a mano, se vuelve a correr así (con el editor cerrado o
# después recargar el proyecto):
#   Godot_console.exe --headless --path . -s res://niveles/2_ferreteria/kit/extraer_kit.gd

const SOURCE := "res://niveles/2_ferreteria/mapa_fabricio/laberinto_ferreteria.tscn"
const OUT := "res://niveles/2_ferreteria/kit/"
const WALL_GROUPS := ["ParedesHorizontales1", "ParedesHorizontales2", "Paredesverticales1",
		"Paredesverticales2", "ParedesInicio", "Paredeslaberinto", "PuertasAbiertas"]

var _lab: Node3D
var _walls: Array[AABB] = []
var _saved_meshes: Dictionary = {}


var _done := false


func _initialize() -> void:
	_lab = load(SOURCE).instantiate()
	root.add_child(_lab)


# Se trabaja en el primer cuadro, cuando el mapa ya está en el árbol
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_extract()
	return true


func _extract() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "mallas"))
	for group in WALL_GROUPS:
		for mesh in _meshes_of(_lab.get_node(group)):
			_walls.append(_world_aabb([mesh]))

	_save_wall("pared", [_lab.get_node("Paredeslaberinto/Wall1"), _lab.get_node("Paredeslaberinto/Wall2")])
	_save_racks()
	_save_lockers()
	_save_prop("pallet_baldes", [_lab.get_node("Pallets/Pallet_Small_Decorated_B")])
	_save_prop("pallet_cajas", _meshes_of(_lab.get_node("Palletmadera")))
	_save_prop("cajas_barriles", _clusters(_meshes_of(_lab.get_node("Cajas")))[0])
	_save_prop("cono_1", [_lab.get_node("Conos/Cone_007")])
	_save_prop("cono_2", [_lab.get_node("Conos/Cone_006")])
	_save_ladder("escalera_chica", _lab.get_node("Escaleras/LowPolyLadder01Small"))
	_save_ladder("escalera_alta", _lab.get_node("Escaleras/LowPolyLadder02Tall"))
	_save_prop("puerta_deco", [_lab.get_node("Puertasdecorativas/Door_B")])
	_save_prop("computadora", _meshes_of(_lab.get_node("Computer")), false)
	# Decoración de la zona de atención: cada grupo de cosas que se tocan es una
	# pieza (las repetidas se guardan una sola vez)
	for cluster in _clusters(_meshes_of(_lab.get_node("decoracion"))):
		var base := _decor_name(cluster)
		if DECOR_NAMES.has(base) and not FileAccess.file_exists(OUT + DECOR_NAMES[base] + ".tscn"):
			_save_prop(DECOR_NAMES[base], cluster, true, not DECOR_NAMES[base] in WALL_DECOR)
	_save_floor()
	print("Kit listo en ", OUT)


# Decoración que cuelga de la pared (no se baja al piso)
const WALL_DECOR := ["reloj", "diana", "planos"]


# Nombre del nodo de "decoracion" del que sale la pieza -> nombre en el kit
const DECOR_NAMES := {
	"cactus_medium_a": "cactus", "blueprint_stacked": "planos", "wall_clock": "reloj",
	"target_wall_small": "diana", "table_medium_decorated": "mesa", "couch": "sillon",
	"chair_b": "silla", "box_c": "caja",
}


func _decor_name(cluster: Array) -> String:
	var node: Node = cluster[0]
	while node.get_parent() != _lab.get_node("decoracion"):
		node = node.get_parent()
	return node.name.to_lower().replace(" ", "_").rstrip("0123456789")


# Estanterías: cada rack con los accesorios que tiene encima (todos tienen lo
# mismo, se guarda el que más cosas tiene)
func _save_racks() -> void:
	var accessories := _meshes_of(_lab.get_node("AccesoriosEstanteria"))
	var racks := []
	for rack in _lab.get_node("Estanteria").get_children():
		if not rack is MeshInstance3D:
			continue
		var box := _world_aabb([rack]).grow(0.1)
		var parts: Array = [rack]
		for item in accessories:
			if box.has_point(_world_aabb([item]).get_center()):
				parts.append(item)
		racks.append(parts)
	racks.sort_custom(func(a, b): return a.size() > b.size())
	if not racks.is_empty():
		_save_prop("estanteria", racks[0])


# Casilleros: cada cuerpo con sus puertas; uno por cada color distinto
func _save_lockers() -> void:
	var colors := {}
	for group in ["casilleros", "Casilleros2", "Casilleros3", "Casilleros4"]:
		for cluster in _clusters(_meshes_of(_lab.get_node(group)), 0.01):
			var material: Material = cluster[0].get_active_material(0)
			var key := material.get_instance_id() if material else 0
			if colors.has(key) or colors.size() >= 3:
				continue
			colors[key] = true
			_save_prop("casillero_%d" % colors.size(), cluster)


# La pared son dos módulos (el de arriba dado vuelta): queda centrada, a lo largo de X
func _save_wall(prop_name: String, parts: Array) -> void:
	var box := _world_aabb(parts)
	var along_x := box.size.x >= box.size.z
	var frame := Transform3D(Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5),
			Vector3(box.get_center().x, 0.0, box.get_center().z))
	_pack(prop_name, parts, frame)


# Pieza que va contra una pared: la espalda mira a la pared más cercana del mapa
# (o a "back", si se da). Las que van en el piso quedan apoyadas en Y = 0; las
# que cuelgan de la pared (on_floor = false) conservan su altura.
func _save_prop(prop_name: String, parts: Array, against_wall: bool = true, on_floor: bool = true,
		back: Vector3 = Vector3.ZERO) -> void:
	var box := _world_aabb(parts)
	if back == Vector3.ZERO and against_wall:
		back = _back_direction(box)
	var angle := 0.0
	var origin := Vector3(box.get_center().x, box.position.y if on_floor else 0.0, box.get_center().z)
	if back != Vector3.ZERO:
		# Base que lleva -Z (espalda local) a "back"
		angle = atan2(-back.x, -back.z)
		var half := box.size * 0.5
		origin += back * (absf(back.x) * half.x + absf(back.z) * half.z)
	_pack(prop_name, parts, Transform3D(Basis(Vector3.UP, angle), origin))


# Escalera apoyada: la espalda es hacia donde se inclina (la punta de arriba)
func _save_ladder(prop_name: String, ladder: MeshInstance3D) -> void:
	var up := ladder.global_basis.y
	var back := Vector3(signf(up.x), 0.0, 0.0) if absf(up.x) > absf(up.z) else Vector3(0.0, 0.0, signf(up.z))
	_save_prop(prop_name, [ladder], true, true, back)


func _back_direction(box: AABB) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := 1.5
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		for wall in _walls:
			var gap := _gap(box, wall, dir)
			if gap >= -0.3 and gap < best_distance:
				best_distance = gap
				best = dir
	return best


# Distancia de la cara de "box" que mira a "dir" a la pared, si la pared está de
# ese lado y se superponen en el otro eje horizontal (si no, INF)
func _gap(box: AABB, wall: AABB, dir: Vector3) -> float:
	var axis := 0 if dir.x != 0.0 else 2
	var other := 2 - axis
	if wall.end[other] < box.position[other] + 0.1 or wall.position[other] > box.end[other] - 0.1:
		return INF
	if wall.end.y < 0.5:
		return INF
	if dir[axis] > 0.0:
		return wall.position[axis] - box.end[axis]
	return box.position[axis] - wall.end[axis]


func _pack(prop_name: String, parts: Array, frame: Transform3D) -> void:
	var prop := Node3D.new()
	prop.name = prop_name
	var to_local := frame.affine_inverse()
	var local_box := AABB()
	for i in parts.size():
		var source: MeshInstance3D = parts[i]
		var copy := MeshInstance3D.new()
		copy.name = "%s_%d" % [source.name.validate_node_name(), i]
		copy.mesh = _saved_mesh(source)
		copy.transform = to_local * source.global_transform
		for s in source.get_surface_override_material_count():
			copy.set_surface_override_material(s, source.get_surface_override_material(s))
		copy.material_override = source.material_override
		prop.add_child(copy)
		copy.owner = prop
		var part_box := copy.transform * copy.mesh.get_aabb()
		local_box = part_box if i == 0 else local_box.merge(part_box)
	# MazeBuilder usa esto para la colisión y para ver si la pieza entra
	prop.set_meta("bounds", local_box)
	var scene := PackedScene.new()
	scene.pack(prop)
	ResourceSaver.save(scene, OUT + prop_name + ".tscn")
	print("  %s: %d mallas, %s" % [prop_name, parts.size(), local_box.size])
	prop.free()


func _saved_mesh(source: MeshInstance3D) -> Mesh:
	if _saved_meshes.has(source.mesh):
		return _saved_meshes[source.mesh]
	var mesh: Mesh = source.mesh
	if not mesh.resource_path.begins_with("res://") or mesh.resource_path.contains("::"):
		mesh = mesh.duplicate(true)
		var file_name := (source.mesh.resource_name if source.mesh.resource_name != "" else str(source.name))
		file_name = file_name.validate_filename().replace(" ", "_")
		var path := OUT + "mallas/%s.res" % file_name
		var n := 2
		while FileAccess.file_exists(path):
			path = OUT + "mallas/%s_%d.res" % [file_name, n]
			n += 1
		ResourceSaver.save(mesh, path)
		mesh = load(path)
	_saved_meshes[source.mesh] = mesh
	return mesh


# Piso: la malla del piso de él (MazeBuilder la estira al tamaño del laberinto)
func _save_floor() -> void:
	var floor_mesh: MeshInstance3D = _lab.get_node("Piso/Floor")
	var mesh := floor_mesh.mesh.duplicate(true)
	ResourceSaver.save(mesh, OUT + "mallas/piso.res")
	print("  piso: ", mesh.get_aabb())


func _meshes_of(node: Node) -> Array:
	var result := []
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes_of(child))
	return result


func _world_aabb(parts: Array) -> AABB:
	var box := AABB()
	for i in parts.size():
		var mesh: MeshInstance3D = parts[i]
		var part_box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		box = part_box if i == 0 else box.merge(part_box)
	return box


# Agrupa las mallas que se tocan (sus cajas se superponen)
func _clusters(meshes: Array, margin: float = 0.05) -> Array:
	var boxes := []
	for mesh in meshes:
		boxes.append(_world_aabb([mesh]).grow(margin))
	var group := range(meshes.size())
	for i in meshes.size():
		for j in range(i + 1, meshes.size()):
			if boxes[i].intersects(boxes[j]):
				var a: int = _find(group, i)
				var b: int = _find(group, j)
				if a != b:
					group[b] = a
	var by_root := {}
	for i in meshes.size():
		var r: int = _find(group, i)
		if not by_root.has(r):
			by_root[r] = []
		by_root[r].append(meshes[i])
	var result := by_root.values()
	result.sort_custom(func(a, b): return _world_aabb(a).position.z < _world_aabb(b).position.z)
	return result


func _find(group: Array, i: int) -> int:
	while group[i] != i:
		i = group[i]
	return i
