class_name GrassGrid
extends MultiMeshInstance3D

@export var field_size: Vector2 = Vector2(32.0, 18.0)
@export var cell_size: float = 1.0
@export var grown_height: float = 0.35
@export var regrow_time: float = 6.0
@export var grown_color: Color = Color(0.2, 0.65, 0.15)
@export var blade_mesh: Mesh
@export var blade_material: StandardMaterial3D

@export_group("Modelo")
@export var cell_fill: float = 0.7
@export var height_multiplier: float = 0.3
@export var jitter: float = 0.4
@export var random_rotation: bool = true

var columns: int
var rows: int

# Solo guarda las celdas cortadas: índice -> segundos para regenerar
var _cut_timers: Dictionary = {}

var _half_field: Vector2
var _base_scale: Vector3 = Vector3.ONE
var _base_y: float = 0.0
var _yaw: PackedFloat32Array
var _offset: PackedVector2Array


func _ready() -> void:
	columns = int(field_size.x / cell_size)
	rows = int(field_size.y / cell_size)
	_half_field = field_size / 2.0

	var mesh: Mesh = blade_mesh if blade_mesh else _default_blade_mesh()
	_prepare_mesh_scale(mesh)

	var count := columns * rows
	_yaw.resize(count)
	_offset.resize(count)
	for i in count:
		_yaw[i] = randf() * TAU if random_rotation else 0.0
		_offset[i] = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter * cell_size * 0.5

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	multimesh = mm

	for y in rows:
		for x in columns:
			var index := _index(x, y)
			mm.set_instance_transform(index, _make_transform(x, y, true))
			mm.set_instance_color(index, grown_color)

	material_override = blade_material if blade_material else _default_material()


func _process(delta: float) -> void:
	if _cut_timers.is_empty():
		return
	for index in _cut_timers.keys().duplicate():
		_cut_timers[index] -= delta
		if _cut_timers[index] <= 0.0:
			_set_cell_state(index, true)
			_cut_timers.erase(index)


# Corta las celdas dentro de "radius" alrededor de world_position.
# Devuelve cuántas celdas se cortaron recién (no estaban cortadas antes).
func cut_area(world_position: Vector3, radius: float) -> int:
	var newly_cut := 0
	var center := _world_to_cell(world_position)
	var cell_radius := int(ceil(radius / cell_size))

	for oy in range(-cell_radius, cell_radius + 1):
		for ox in range(-cell_radius, cell_radius + 1):
			var x := center.x + ox
			var y := center.y + oy
			if x < 0 or x >= columns or y < 0 or y >= rows:
				continue

			var cell_pos := _cell_to_world(x, y)
			if Vector2(cell_pos.x, cell_pos.z).distance_to(Vector2(world_position.x, world_position.z)) > radius:
				continue

			var index := _index(x, y)
			if not _cut_timers.has(index):
				newly_cut += 1
			_cut_timers[index] = regrow_time
			_set_cell_state(index, false)

	return newly_cut


func _set_cell_state(index: int, grown: bool) -> void:
	var x := index % columns
	var y := index / columns
	multimesh.set_instance_transform(index, _make_transform(x, y, grown))


func _make_transform(x: int, y: int, grown: bool) -> Transform3D:
	var index := _index(x, y)
	var factor := 1.0 if grown else 0.001
	var scale := _base_scale * factor
	var basis := Basis(Vector3.UP, _yaw[index]) * Basis.from_scale(scale)

	var origin := _cell_to_world(x, y)
	origin.x += _offset[index].x
	origin.z += _offset[index].y
	origin.y = _base_y * scale.y
	return Transform3D(basis, origin)


func _prepare_mesh_scale(mesh: Mesh) -> void:
	var aabb := mesh.get_aabb()
	if blade_mesh:
		var s := cell_size * cell_fill / maxf(aabb.size.x, aabb.size.z)
		_base_scale = Vector3(s, s * height_multiplier, s)
	else:
		_base_scale = Vector3.ONE
	_base_y = -aabb.position.y


func _index(x: int, y: int) -> int:
	return y * columns + x


func _world_to_cell(world_position: Vector3) -> Vector2i:
	var local_x := world_position.x + _half_field.x
	var local_z := world_position.z + _half_field.y
	return Vector2i(int(local_x / cell_size), int(local_z / cell_size))


func _cell_to_world(x: int, y: int) -> Vector3:
	var wx := (x + 0.5) * cell_size - _half_field.x
	var wz := (y + 0.5) * cell_size - _half_field.y
	return Vector3(wx, 0.0, wz)


func _default_blade_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size, grown_height, cell_size)
	return mesh


func _default_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	return mat
