@tool
class_name MazeBuilder
extends Node3D

# Genera el laberinto de la ferretería: piso, paredes exteriores y paredes
# interiores (estanterías). Con la misma semilla sale siempre igual. En el
# editor se puede ver con el botón "Generar" del inspector.

@export_group("Tamaño")
## Celdas a lo ancho (X).
@export_range(2, 40) var columns: int = 9
## Celdas a lo largo (Z).
@export_range(2, 40) var rows: int = 7
## Tamaño de cada celda (ancho de los pasillos).
@export_range(1.0, 10.0, 0.1, "suffix:u") var cell_size: float = 4.0
## Altura de las paredes.
@export_range(0.5, 10.0, 0.1, "suffix:u") var wall_height: float = 2.6
## Grosor de las paredes.
@export_range(0.05, 2.0, 0.05, "suffix:u") var wall_thickness: float = 0.4

@export_group("Forma")
## Semilla del laberinto: el mismo número da siempre el mismo laberinto.
@export var maze_seed: int = 2026
## Porcentaje de paredes interiores extra que se quitan, para que haya varios
## caminos (0 = laberinto perfecto, con un solo camino entre dos puntos).
@export_range(0.0, 1.0, 0.05) var extra_openings: float = 0.15

@export_group("Aspecto")
@export var wall_material: StandardMaterial3D
@export var floor_material: StandardMaterial3D

@export_group("Editor")
## Regenera el laberinto en el editor para verlo.
@export_tool_button("Generar") var generate_button := build

# Paredes abiertas: _open[Vector2i(celda)] = Array de direcciones abiertas
var _open: Dictionary = {}
var _built: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		build()


## Tamaño total del laberinto (X, Z).
func get_size() -> Vector2:
	return Vector2(columns, rows) * cell_size


## Centro de la celda en coordenadas del mundo.
func get_cell_center(cell: Vector2i) -> Vector3:
	var half := get_size() * 0.5
	var local := Vector3((cell.x + 0.5) * cell_size - half.x, 0.0, (cell.y + 0.5) * cell_size - half.y)
	return to_global(local)


func get_all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows:
		for x in columns:
			cells.append(Vector2i(x, y))
	return cells


func build() -> void:
	for child in get_children():
		child.queue_free()
	_generate_layout()
	_build_floor()
	_build_walls()
	_built = true


func _generate_layout() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	_open.clear()
	for cell in get_all_cells():
		_open[cell] = []

	# Recursive backtracker: recorre todas las celdas abriendo paredes
	var visited := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + dir
			if _in_bounds(next) and not visited.has(next):
				options.append(dir)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen := options[rng.randi_range(0, options.size() - 1)]
		_open_wall(current, chosen)
		visited[current + chosen] = true
		stack.append(current + chosen)

	# Quita algunas paredes más para que haya varios caminos
	for cell in get_all_cells():
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if _in_bounds(cell + dir) and not _open[cell].has(dir) and rng.randf() < extra_openings:
				_open_wall(cell, dir)


func _open_wall(cell: Vector2i, dir: Vector2i) -> void:
	_open[cell].append(dir)
	_open[cell + dir].append(-dir)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func _build_floor() -> void:
	var size := get_size()
	var body := StaticBody3D.new()
	body.name = "Floor"
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 0.2, size.y)
	shape.shape = box
	shape.position.y = -0.1
	body.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.material = floor_material
	mesh_instance.mesh = plane
	body.add_child(mesh_instance)


func _build_walls() -> void:
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	var half := get_size() * 0.5

	for cell in get_all_cells():
		var origin := Vector2((cell.x) * cell_size - half.x, (cell.y) * cell_size - half.y)
		# Pared de arriba (-Z) y de la izquierda (-X) de cada celda; las de
		# abajo y derecha solo en el borde, para no duplicar
		if not _open[cell].has(Vector2i.UP):
			_add_wall(walls, origin + Vector2(cell_size * 0.5, 0.0), true)
		if not _open[cell].has(Vector2i.LEFT):
			_add_wall(walls, origin + Vector2(0.0, cell_size * 0.5), false)
		if cell.y == rows - 1:
			_add_wall(walls, origin + Vector2(cell_size * 0.5, cell_size), true)
		if cell.x == columns - 1:
			_add_wall(walls, origin + Vector2(cell_size, cell_size * 0.5), false)


# Pared de una celda de largo centrada en "center" (X, Z). "horizontal" = a lo largo de X.
func _add_wall(parent: Node3D, center: Vector2, horizontal: bool) -> void:
	var length := cell_size + wall_thickness
	var size := Vector3(length, wall_height, wall_thickness) if horizontal \
			else Vector3(wall_thickness, wall_height, length)

	var body := StaticBody3D.new()
	body.position = Vector3(center.x, wall_height * 0.5, center.y)
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = wall_material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
