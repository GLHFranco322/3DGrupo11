@tool
class_name MazeBuilder
extends Node3D

# Genera la ferretería: el laberinto de góndolas (estanterías), la zona de
# atención al frente (donde va el mostrador, unida al laberinto por algunas
# entradas), el piso, el techo y las luces. Con semilla 0 sale un laberinto
# distinto en cada partida; con otro número sale siempre el mismo. En el editor
# se puede ver con el botón "Generar" del inspector.
#
# Las celdas del laberinto van de (0, 0) a (columns - 1, rows - 1). La zona de
# atención son las filas que siguen (rows .. rows + front_rows - 1), sin paredes
# adentro.

@export_group("Tamaño")
## Celdas a lo ancho (X).
@export_range(2, 40) var columns: int = 13
## Celdas a lo largo (Z), sin contar la zona de atención.
@export_range(2, 40) var rows: int = 10
## Tamaño de cada celda (ancho de los pasillos).
@export_range(1.0, 10.0, 0.1, "suffix:u") var cell_size: float = 4.0
## Altura de las paredes.
@export_range(0.5, 10.0, 0.1, "suffix:u") var wall_height: float = 2.6
## Grosor de las paredes (las estanterías tienen productos de los dos lados).
@export_range(0.05, 2.0, 0.05, "suffix:u") var wall_thickness: float = 0.8

@export_group("Forma")
## Semilla del laberinto. 0 = uno distinto en cada partida; otro número = siempre
## el mismo laberinto (sirve para probar uno en particular).
@export var maze_seed: int = 0
## Porcentaje de paredes interiores extra que se quitan, para que haya varios
## caminos (0 = laberinto perfecto, con un solo camino entre dos puntos).
@export_range(0.0, 1.0, 0.05) var extra_openings: float = 0.15

@export_group("Zona de atención")
## Profundidad de la zona del mostrador, en celdas.
@export_range(1, 10) var front_rows: int = 2
## Entradas entre la zona de atención y el laberinto (repartidas a lo ancho).
@export_range(1, 10) var entrances: int = 3

@export_group("Aspecto")
## Fondo de las estanterías (el panel del medio).
@export var wall_material: StandardMaterial3D
@export var floor_material: StandardMaterial3D
## Color de los parantes (las columnas de los costados de cada estantería).
@export var upright_color: Color = Color(0.95, 0.45, 0.1)
## Color de los estantes.
@export var shelf_color: Color = Color(0.55, 0.57, 0.6)
## Cantidad de estantes por estantería.
@export_range(1, 10) var shelves_per_wall: int = 4
## Productos por estante, de cada lado (0 = estanterías vacías).
@export_range(0, 12) var products_per_shelf: int = 5
## Colores de los productos (se eligen al azar).
@export var product_colors: PackedColorArray = [Color(0.85, 0.15, 0.12), Color(0.15, 0.35, 0.8), Color(0.95, 0.8, 0.15), Color(0.2, 0.6, 0.25), Color(0.95, 0.5, 0.1), Color(0.9, 0.9, 0.88), Color(0.35, 0.35, 0.38)]

@export_group("Techo y luces")
## Espacio entre la parte de arriba de las góndolas y el techo.
@export_range(0.0, 5.0, 0.1, "suffix:u") var ceiling_gap: float = 0.8
## Color del techo.
@export var ceiling_color: Color = Color(0.82, 0.83, 0.85)
## Color de los tubos de luz del techo (uno por celda).
@export var tube_color: Color = Color(1.0, 0.98, 0.9)
## Las luces se reparten en zonas de este tamaño (en celdas), una luz por zona.
## Godot (modo Compatibility) ilumina cada objeto con 8 luces como mucho, por eso
## el piso y las góndolas se arman por zonas.
@export_range(1, 10) var light_zone_cells: int = 3
## Color de las luces.
@export var light_color: Color = Color(1.0, 0.95, 0.85)
## Intensidad de las luces.
@export_range(0.0, 10.0, 0.05) var light_energy: float = 1.6
## Alcance de cada luz (como fracción del tamaño de su zona).
@export_range(0.2, 2.0, 0.05) var light_range_factor: float = 0.8

@export_group("Camino al tablero")
## Flechas pintadas en el piso que marcan el camino más corto al tablero.
@export var show_path_arrows: bool = true
## Color de las flechas (el canal A es la opacidad).
@export var arrow_color: Color = Color(1.0, 0.85, 0.1, 0.35)
## Largo de cada flecha (como fracción del ancho del pasillo).
@export_range(0.1, 1.0, 0.05) var arrow_size: float = 0.35

@export_group("Lugares")
## Habitaciones (escenas cuya raíz es un MazeRoom, ej: el taller) que aparecen
## en un lugar al azar del laberinto en cada partida, con sus propias paredes y
## puertas a los pasillos.
@export var places: Array[PackedScene] = []
## Celdas de pasillo que se dejan entre un lugar y el borde del laberinto (y
## entre dos lugares). Con 1 o más, el laberinto siempre queda conectado.
@export_range(1, 5) var place_margin: int = 1
## Puertas máximas de cada lugar (siempre tiene al menos 2, si este número lo permite).
@export_range(1, 8) var place_doors: int = 2

@export_group("Editor")
## Regenera el laberinto en el editor para verlo.
@export_tool_button("Generar") var generate_button := build

# Paredes abiertas: _open[Vector2i(celda)] = Array de direcciones abiertas
var _open: Dictionary = {}
# Lugares de esta partida: {"node": MazeRoom, "rect": Rect2i, "doors": [[celda, dirección hacia afuera], ...]}
var _rooms: Array[Dictionary] = []
# Celda -> índice en _rooms de la habitación que la ocupa
var _room_of: Dictionary = {}
var _built: bool = false
## Semilla con la que se generó el último laberinto (en online, el anfitrión se
## la va a pasar al otro jugador para que tengan el mismo).
var current_seed: int = 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		build()


## Tamaño del laberinto (X, Z), sin la zona de atención.
func get_size() -> Vector2:
	return Vector2(columns, rows) * cell_size


## Centro de la celda en coordenadas del mundo (sirve también para las filas de
## la zona de atención).
func get_cell_center(cell: Vector2i) -> Vector3:
	var half := get_size() * 0.5
	var local := Vector3((cell.x + 0.5) * cell_size - half.x, 0.0, (cell.y + 0.5) * cell_size - half.y)
	return to_global(local)


## Celdas del laberinto (sin la zona de atención).
func get_all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows:
		for x in columns:
			cells.append(Vector2i(x, y))
	return cells


## Celdas de pasillo (sin las que ocupan los lugares, como el taller). Sirve
## para repartir cosas por el laberinto sin que caigan adentro de una habitación.
func get_free_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in get_all_cells():
		if not _room_of.has(cell):
			cells.append(cell)
	return cells


## Habitaciones que tocaron en esta partida.
func get_places() -> Array[MazeRoom]:
	var result: Array[MazeRoom] = []
	for info in _rooms:
		if is_instance_valid(info.node):
			result.append(info.node)
	return result


## Columnas de la última fila del laberinto que tienen salida a la zona de atención.
func get_entrance_columns() -> Array[int]:
	var result: Array[int] = []
	for i in entrances:
		var column := clampi(roundi((i + 0.5) / entrances * columns - 0.5), 0, columns - 1)
		if not result.has(column):
			result.append(column)
	return result


## Celdas del laberinto que dan a la zona de atención.
func get_entrance_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for column in get_entrance_columns():
		cells.append(Vector2i(column, rows - 1))
	return cells


## Centro de la zona de atención (en el piso, coordenadas del mundo).
func get_front_center() -> Vector3:
	var half := get_size() * 0.5
	return to_global(Vector3(0.0, 0.0, half.y + front_rows * cell_size * 0.5))


func build() -> void:
	for child in get_children():
		child.free()
	_generate_layout()
	_build_room()
	_build_walls()
	_build_places()
	_built = true


func _generate_layout() -> void:
	current_seed = maze_seed if maze_seed != 0 else randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed
	_open.clear()
	for cell in get_all_cells():
		_open[cell] = []
	_plan_places(rng)

	# Recursive backtracker: recorre todas las celdas abriendo paredes. Cada
	# lugar cuenta como una sola celda grande: al entrar se lo recorre entero
	# de una vez, y cada pared que se abre en su borde es una puerta.
	var visited := {}
	var stack: Array[Vector2i] = []
	_visit(Vector2i.ZERO, visited, stack, rng)
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + dir
			if _in_bounds(next) and not visited.has(next) and _can_cross(current, dir):
				options.append(dir)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen := options[rng.randi_range(0, options.size() - 1)]
		_open_wall(current, chosen)
		_note_door(current, chosen)
		_visit(current + chosen, visited, stack, rng)

	# Quita algunas paredes más para que haya varios caminos (no en los lugares)
	for cell in get_all_cells():
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if _in_bounds(cell + dir) and not _open[cell].has(dir) and not _touches_room(cell, dir) \
					and rng.randf() < extra_openings:
				_open_wall(cell, dir)

	_add_missing_doors(rng)


# Marca una celda como recorrida. Si es de un lugar, marca el lugar entero
# (abriendo sus paredes de adentro) y sigue desde cualquiera de sus celdas.
func _visit(cell: Vector2i, visited: Dictionary, stack: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	if not _room_of.has(cell):
		visited[cell] = true
		stack.append(cell)
		return
	var rect: Rect2i = _rooms[_room_of[cell]].rect
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var inside := Vector2i(x, y)
			visited[inside] = true
			cells.append(inside)
			if x + 1 < rect.end.x:
				_open_wall(inside, Vector2i.RIGHT)
			if y + 1 < rect.end.y:
				_open_wall(inside, Vector2i.DOWN)
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := cells[i]
		cells[i] = cells[j]
		cells[j] = temp
	stack.append_array(cells)


# Si abrir la pared de "cell" hacia "dir" entra o sale de un lugar, solo se
# puede mientras ese lugar tenga menos puertas que el máximo
func _can_cross(cell: Vector2i, dir: Vector2i) -> bool:
	var from: int = _room_of.get(cell, -1)
	var to: int = _room_of.get(cell + dir, -1)
	if from == to:
		return true
	if from != -1 and to != -1:
		return false
	return _rooms[from if from != -1 else to].doors.size() < place_doors


# Si la pared que se abrió es el borde de un lugar, la anota como puerta (desde
# adentro del lugar, mirando hacia afuera)
func _note_door(cell: Vector2i, dir: Vector2i) -> void:
	var from: int = _room_of.get(cell, -1)
	var to: int = _room_of.get(cell + dir, -1)
	if from == to:
		return
	if from != -1:
		_rooms[from].doors.append([cell, dir])
	else:
		_rooms[to].doors.append([cell + dir, -dir])


# Cada lugar tiene al menos 2 puertas (si "Place Doors" lo permite), así no
# queda como un callejón sin salida
func _add_missing_doors(rng: RandomNumberGenerator) -> void:
	var wanted := mini(2, place_doors)
	for room in _rooms:
		var rect: Rect2i = room.rect
		while room.doors.size() < wanted:
			var options := []
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var cell := Vector2i(x, y)
					for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var outside: Vector2i = cell + dir
						if _in_bounds(outside) and not _room_of.has(outside) and not _open[cell].has(dir):
							options.append([cell, dir])
			if options.is_empty():
				break
			var door: Array = options[rng.randi_range(0, options.size() - 1)]
			_open_wall(door[0], door[1])
			room.doors.append(door)


# true si la pared entre "cell" y "cell + dir" es de un lugar (la arma el lugar)
func _touches_room(cell: Vector2i, dir: Vector2i) -> bool:
	return _room_of.has(cell) or _room_of.has(cell + dir)


# Elige dónde va cada lugar: un rectángulo al azar, lejos del borde y de los
# otros lugares. Si no entra, se saltea (con un aviso).
func _plan_places(rng: RandomNumberGenerator) -> void:
	_rooms.clear()
	_room_of.clear()
	for scene in places:
		if scene == null:
			continue
		var room := scene.instantiate() as MazeRoom
		if room == null:
			push_warning("MazeBuilder: la raíz de %s no es un MazeRoom" % scene.resource_path)
			continue
		var rect = _find_place_rect(room.size_cells, rng)
		if rect == null:
			push_warning("MazeBuilder: %s no entra en el laberinto" % scene.resource_path)
			room.free()
			continue
		var index := _rooms.size()
		_rooms.append({"node": room, "rect": rect, "doors": []})
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				_room_of[Vector2i(x, y)] = index


func _find_place_rect(size: Vector2i, rng: RandomNumberGenerator) -> Variant:
	var max_x := columns - place_margin - size.x
	var max_y := rows - place_margin - size.y
	if max_x < place_margin or max_y < place_margin:
		return null
	for attempt in 40:
		var rect := Rect2i(Vector2i(rng.randi_range(place_margin, max_x), rng.randi_range(place_margin, max_y)), size)
		var free := true
		for room in _rooms:
			var other: Rect2i = room.rect
			if other.grow(place_margin).intersects(rect):
				free = false
				break
		if free:
			return rect
	return null


# Pone cada lugar en su rectángulo, a la altura del techo y con las puertas
# donde quedaron abiertas
func _build_places() -> void:
	for i in _rooms.size():
		var info: Dictionary = _rooms[i]
		var room: MazeRoom = info.node
		var rect: Rect2i = info.rect
		room.cell_size = cell_size
		room.wall_height = wall_height + ceiling_gap
		room.wall_thickness = wall_thickness
		room.closed_doors = false
		# Mismo azar que el laberinto (en online se ve igual en los dos)
		room.decor_seed = current_seed + 100 + i
		var doors: Array[Vector2i] = []
		for door in info.doors:
			doors.append(_door_side(rect, door[0], door[1]))
		room.doors = doors
		var center := (get_cell_center(rect.position) + get_cell_center(rect.end - Vector2i.ONE)) * 0.5
		room.position = to_local(center)
		add_child(room)
		if not room.is_built():
			room.build()


# Puerta en el formato de MazeRoom: Vector2i(lado, tramo)
func _door_side(rect: Rect2i, cell: Vector2i, dir: Vector2i) -> Vector2i:
	if dir == Vector2i.UP:
		return Vector2i(MazeRoom.Side.BACK, cell.x - rect.position.x)
	if dir == Vector2i.RIGHT:
		return Vector2i(MazeRoom.Side.RIGHT, cell.y - rect.position.y)
	if dir == Vector2i.DOWN:
		return Vector2i(MazeRoom.Side.FRONT, cell.x - rect.position.x)
	return Vector2i(MazeRoom.Side.LEFT, cell.y - rect.position.y)


func _open_wall(cell: Vector2i, dir: Vector2i) -> void:
	_open[cell].append(dir)
	_open[cell + dir].append(-dir)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func _total_rows() -> int:
	return rows + front_rows


# Zona (para las luces) a la que pertenece un punto local (X, Z)
func _zone_of(point: Vector2) -> Vector2i:
	var half := get_size() * 0.5
	var zone_size := light_zone_cells * cell_size
	return Vector2i(
			clampi(floori((point.x + half.x) / zone_size), 0, _zone_count().x - 1),
			clampi(floori((point.y + half.y) / zone_size), 0, _zone_count().y - 1))


func _zone_count() -> Vector2i:
	return Vector2i(ceili(float(columns) / light_zone_cells), ceili(float(_total_rows()) / light_zone_cells))


# Piso (por zonas), techo, tubos de luz y una luz por zona
func _build_room() -> void:
	var half := get_size() * 0.5
	var total := Vector2(columns, _total_rows()) * cell_size
	var center_z := -half.y + total.y * 0.5
	var ceiling_y := wall_height + ceiling_gap

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)
	floor_body.add_child(_box_collision(Vector3(total.x, 0.2, total.y), Vector3(0.0, -0.1, center_z)))

	var ceiling := StaticBody3D.new()
	ceiling.name = "Ceiling"
	add_child(ceiling)
	# Con colisión, así la cámara no lo atraviesa
	ceiling.add_child(_box_collision(Vector3(total.x, 0.2, total.y), Vector3(0.0, ceiling_y + 0.1, center_z)))
	var ceiling_mesh := MeshInstance3D.new()
	var ceiling_plane := PlaneMesh.new()
	ceiling_plane.size = total
	ceiling_plane.flip_faces = true
	var ceiling_material := StandardMaterial3D.new()
	ceiling_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ceiling_material.albedo_color = ceiling_color
	ceiling_plane.material = ceiling_material
	ceiling_mesh.mesh = ceiling_plane
	ceiling_mesh.position = Vector3(0.0, ceiling_y, center_z)
	# No tapa el sol: así sigue iluminando un poco desde arriba
	ceiling_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ceiling.add_child(ceiling_mesh)

	var zones := _zone_count()
	var zone_size := light_zone_cells * cell_size
	for zx in zones.x:
		for zy in zones.y:
			var from := Vector2(zx * zone_size - half.x, zy * zone_size - half.y)
			var to := Vector2(minf(from.x + zone_size, half.x), minf(from.y + zone_size, -half.y + total.y))
			var zone_center := (from + to) * 0.5
			var floor_mesh := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = to - from
			plane.material = floor_material
			floor_mesh.mesh = plane
			floor_mesh.position = Vector3(zone_center.x, 0.0, zone_center.y)
			floor_body.add_child(floor_mesh)

			var light := OmniLight3D.new()
			light.name = "Light_%d_%d" % [zx, zy]
			light.position = Vector3(zone_center.x, ceiling_y - 0.4, zone_center.y)
			light.light_color = light_color
			light.light_energy = light_energy
			light.omni_range = zone_size * light_range_factor
			light.shadow_enabled = false
			add_child(light)

	# Un tubo de luz (que brilla, sin iluminar) en el techo de cada celda (los
	# lugares tienen sus propias lámparas)
	var tubes: Array[Transform3D] = []
	for y in _total_rows():
		for x in columns:
			if _room_of.has(Vector2i(x, y)):
				continue
			var center := to_local(get_cell_center(Vector2i(x, y)))
			tubes.append(_box_transform(Vector3(center.x, ceiling_y - 0.05, center.z), Vector3.RIGHT, Vector3.BACK,
					Vector3(cell_size * 0.5, 0.06, 0.18)))
	var tube_material := StandardMaterial3D.new()
	tube_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tube_material.albedo_color = tube_color
	var tube_instance := _make_multimesh("Tubes", tubes, [], tube_material)
	tube_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tube_instance)


func _box_collision(size: Vector3, position: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	return shape


func _build_walls() -> void:
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	var half := get_size() * 0.5
	# Mismo azar para el aspecto que para la forma (en online se ve igual en los dos)
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 1
	var entrance_columns := get_entrance_columns()

	# Las piezas visuales se juntan en MultiMesh por zona: pocos dibujos en total
	# (en vez de miles de mallas sueltas) y cada zona recibe sus luces cercanas
	var zones := {}

	for cell in get_all_cells():
		var origin := Vector2((cell.x) * cell_size - half.x, (cell.y) * cell_size - half.y)
		# Pared de arriba (-Z) y de la izquierda (-X) de cada celda; las de
		# abajo y derecha solo en el borde, para no duplicar. Abajo quedan
		# abiertas las entradas a la zona de atención. Las paredes de los
		# lugares las arma cada lugar.
		if not _open[cell].has(Vector2i.UP) and not _touches_room(cell, Vector2i.UP):
			_add_wall(walls, origin + Vector2(cell_size * 0.5, 0.0), true, rng, zones)
		if not _open[cell].has(Vector2i.LEFT) and not _touches_room(cell, Vector2i.LEFT):
			_add_wall(walls, origin + Vector2(0.0, cell_size * 0.5), false, rng, zones)
		if cell.y == rows - 1 and not entrance_columns.has(cell.x):
			_add_wall(walls, origin + Vector2(cell_size * 0.5, cell_size), true, rng, zones)
		if cell.x == columns - 1:
			_add_wall(walls, origin + Vector2(cell_size, cell_size * 0.5), false, rng, zones)

	# Zona de atención: solo paredes en el borde (costados y fondo)
	for y in range(rows, _total_rows()):
		for x in columns:
			var origin := Vector2(x * cell_size - half.x, y * cell_size - half.y)
			if x == 0:
				_add_wall(walls, origin + Vector2(0.0, cell_size * 0.5), false, rng, zones)
			if x == columns - 1:
				_add_wall(walls, origin + Vector2(cell_size, cell_size * 0.5), false, rng, zones)
			if y == _total_rows() - 1:
				_add_wall(walls, origin + Vector2(cell_size * 0.5, cell_size), true, rng, zones)

	var uprights_material := _flat_material(upright_color)
	var shelves_material := _flat_material(shelf_color)
	var products_material := _vertex_color_material()
	for zone in zones:
		var parts: Dictionary = zones[zone]
		var suffix := "_%d_%d" % [zone.x, zone.y]
		walls.add_child(_make_multimesh("Panels" + suffix, parts.panels, [], wall_material))
		walls.add_child(_make_multimesh("Uprights" + suffix, parts.uprights, [], uprights_material))
		walls.add_child(_make_multimesh("Shelves" + suffix, parts.boards, [], shelves_material))
		walls.add_child(_make_multimesh("Products" + suffix, parts.products, parts.tints, products_material))


# Pared de una celda de largo centrada en "center" (X, Z). "horizontal" = a lo
# largo de X. La colisión es una caja; lo que se ve es una estantería de
# ferretería: fondo en el medio, parantes en las puntas, estantes y productos de
# colores de los dos lados.
func _add_wall(parent: Node3D, center: Vector2, horizontal: bool, rng: RandomNumberGenerator, zones: Dictionary) -> void:
	var length := cell_size + wall_thickness
	var body := StaticBody3D.new()
	body.position = Vector3(center.x, wall_height * 0.5, center.y)
	parent.add_child(body)
	body.add_child(_box_collision(Vector3(length, wall_height, wall_thickness) if horizontal \
			else Vector3(wall_thickness, wall_height, length), Vector3.ZERO))

	var zone := _zone_of(center)
	if not zones.has(zone):
		zones[zone] = {
			"panels": [] as Array[Transform3D],
			"uprights": [] as Array[Transform3D],
			"boards": [] as Array[Transform3D],
			"products": [] as Array[Transform3D],
			"tints": [] as Array[Color],
		}
	var parts: Dictionary = zones[zone]

	var base := Vector3(center.x, 0.0, center.y)
	# "along" = a lo largo de la pared, "across" = hacia los pasillos
	var along := Vector3.RIGHT if horizontal else Vector3.BACK
	var across := Vector3.BACK if horizontal else Vector3.RIGHT

	parts.panels.append(_box_transform(base + Vector3.UP * wall_height * 0.5, along, across,
			Vector3(length, wall_height, wall_thickness * 0.2)))
	for end in [-1.0, 1.0]:
		parts.uprights.append(_box_transform(base + along * (length * 0.5 - 0.06) * end + Vector3.UP * wall_height * 0.5,
				along, across, Vector3(0.12, wall_height, wall_thickness + 0.04)))

	var gap := (wall_height - 0.3) / shelves_per_wall
	var usable := length - 0.4
	var depth := wall_thickness * 0.4
	for i in shelves_per_wall:
		var height := 0.15 + gap * i
		parts.boards.append(_box_transform(base + Vector3.UP * height, along, across,
				Vector3(length - 0.1, 0.05, wall_thickness)))
		for side in [-1.0, 1.0]:
			for j in products_per_shelf:
				if rng.randf() < 0.2:
					continue  # algún hueco, para que no se vea tan prolijo
				var size := Vector3(rng.randf_range(0.2, 0.45),
						rng.randf_range(0.15, maxf(0.16, minf(gap - 0.1, 0.6))),
						rng.randf_range(0.15, maxf(0.16, depth)))
				var slot := (j + 0.5) / products_per_shelf - 0.5
				var position: Vector3 = base + along * (slot * usable + rng.randf_range(-0.08, 0.08)) \
						+ across * side * (wall_thickness * 0.1 + size.z * 0.5 + 0.01) \
						+ Vector3.UP * (height + 0.025 + size.y * 0.5)
				parts.products.append(_box_transform(position, along, across, size))
				parts.tints.append(product_colors[rng.randi_range(0, product_colors.size() - 1)] \
						if not product_colors.is_empty() else Color.WHITE)


# Transform de una caja de 1x1x1 estirada a "size" (largo, alto, profundidad) y
# orientada con "along" / "across"
func _box_transform(position: Vector3, along: Vector3, across: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis(along * size.x, Vector3.UP * size.y, across * size.z), position)


func _make_multimesh(node_name: String, transforms: Array, colors: Array, material: Material) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material


func _vertex_color_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	return material


## Pinta en el piso de cada celda del laberinto una flecha hacia la siguiente
## celda del camino más corto a la zona de atención (donde está el tablero). En
## las entradas, la flecha apunta hacia afuera. Lo llama el nivel.
func build_path_arrows() -> void:
	var old := get_node_or_null("PathArrows")
	if old:
		old.free()
	if not show_path_arrows:
		return

	# Recorrido a lo ancho desde las entradas: next_step[celda] = hacia dónde ir
	var next_step := {}
	var queue: Array[Vector2i] = []
	for cell in get_entrance_cells():
		next_step[cell] = Vector2i.DOWN
		queue.append(cell)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir in _open[cell]:
			var neighbor: Vector2i = cell + dir
			if not next_step.has(neighbor):
				next_step[neighbor] = -dir
				queue.append(neighbor)

	var transforms: Array[Transform3D] = []
	for cell in next_step:
		# Adentro de los lugares no se pintan (quedarían debajo de los muebles)
		if _room_of.has(cell):
			continue
		var dir: Vector2i = next_step[cell]
		var yaw := atan2(-float(dir.x), -float(dir.y))
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * cell_size * arrow_size)
		transforms.append(Transform3D(basis, to_local(get_cell_center(cell)) + Vector3.UP * 0.02))

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = arrow_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := _arrow_mesh()
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "PathArrows"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


# Flecha plana de 1 de largo que apunta a -Z, acostada en el piso
func _arrow_mesh() -> ArrayMesh:
	var points := PackedVector3Array([
		# Punta
		Vector3(0.0, 0.0, -0.5), Vector3(0.4, 0.0, -0.05), Vector3(-0.4, 0.0, -0.05),
		# Cuerpo
		Vector3(-0.15, 0.0, -0.05), Vector3(0.15, 0.0, -0.05), Vector3(0.15, 0.0, 0.5),
		Vector3(-0.15, 0.0, -0.05), Vector3(0.15, 0.0, 0.5), Vector3(-0.15, 0.0, 0.5),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	for point in points:
		surface.add_vertex(point)
	return surface.commit()
