@tool
class_name MazeBuilder
extends Node3D

# Genera la ferretería: el laberinto, la zona de atención al frente (donde va el
# mostrador, unida al laberinto por algunas entradas), el piso, el techo y las
# luces. Con semilla 0 sale un laberinto distinto en cada partida; con otro
# número sale siempre el mismo. En el editor se puede ver con el botón
# "Generar" del inspector.
#
# Se arma con las piezas del mapa hecho a mano (niveles/Escenarios/
# laberinto_ferreteria.tscn), sacadas a niveles/2_ferreteria/kit/ con
# kit/extraer_kit.gd: paredes de cemento, muebles contra las paredes y la
# decoración de la zona de atención.
#
# Las celdas del laberinto van de (0, 0) a (columns - 1, rows - 1). La zona de
# atención son las filas que siguen (rows .. rows + front_rows - 1), sin paredes
# adentro.

@export_group("Tamaño")
## Celdas a lo ancho (X).
@export_range(2, 40) var columns: int = 13
## Celdas a lo largo (Z), sin contar la zona de atención.
@export_range(2, 40) var rows: int = 10
## Tamaño de cada celda (ancho de los pasillos). La pieza de pared se estira a
## este largo (mide 4).
@export_range(1.0, 10.0, 0.1, "suffix:u") var cell_size: float = 4.0

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

@export_group("Piezas")
## Módulo de pared de una celda de largo. Su alto y su grosor son los de todas
## las paredes.
@export var wall_piece: PackedScene = preload("res://niveles/2_ferreteria/kit/pared.tscn")
## Muebles que se apoyan contra las paredes de los pasillos (como mucho uno por celda).
@export var corridor_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/estanteria.tscn"),
	preload("res://niveles/2_ferreteria/kit/casillero_1.tscn"),
	preload("res://niveles/2_ferreteria/kit/casillero_2.tscn"),
	preload("res://niveles/2_ferreteria/kit/cajas_barriles.tscn"),
	preload("res://niveles/2_ferreteria/kit/cono_1.tscn"),
	preload("res://niveles/2_ferreteria/kit/cono_2.tscn"),
	preload("res://niveles/2_ferreteria/kit/escalera_chica.tscn"),
	preload("res://niveles/2_ferreteria/kit/puerta_deco.tscn"),
]
## Probabilidad de que una celda de pasillo tenga un mueble.
@export_range(0.0, 1.0, 0.05) var prop_chance: float = 0.4
## Profundidad máxima de un mueble de pasillo (fracción del ancho del pasillo),
## para que no tape el paso ni las herramientas, que aparecen en el medio.
@export_range(0.1, 0.5, 0.05) var max_prop_depth: float = 0.35
## Muebles de la zona de atención (contra el fondo y los costados).
@export var front_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/sillon.tscn"),
	preload("res://niveles/2_ferreteria/kit/mesa.tscn"),
	preload("res://niveles/2_ferreteria/kit/silla.tscn"),
	preload("res://niveles/2_ferreteria/kit/cactus.tscn"),
	preload("res://niveles/2_ferreteria/kit/pallet_baldes.tscn"),
	preload("res://niveles/2_ferreteria/kit/pallet_cajas.tscn"),
	preload("res://niveles/2_ferreteria/kit/escalera_alta.tscn"),
	preload("res://niveles/2_ferreteria/kit/estanteria.tscn"),
]
## Probabilidad de que cada tramo de pared de la zona de atención tenga un mueble.
@export_range(0.0, 1.0, 0.05) var front_prop_chance: float = 0.75
## Lo que cuelga de la pared del fondo de la zona de atención. El primero (el
## reloj) va siempre arriba del mostrador; los demás se reparten.
@export var front_wall_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/reloj.tscn"),
	preload("res://niveles/2_ferreteria/kit/planos.tscn"),
	preload("res://niveles/2_ferreteria/kit/diana.tscn"),
]
## Malla del piso y del techo (se estira al tamaño de cada zona).
@export var floor_mesh: Mesh = preload("res://niveles/2_ferreteria/kit/mallas/piso.res")

@export_group("Techo y luces")
## Espacio entre la parte de arriba de las paredes y el techo.
@export_range(0.0, 5.0, 0.1, "suffix:u") var ceiling_gap: float = 0.0
## Las luces se reparten en zonas de este tamaño (en celdas), una luz por zona.
## Godot (modo Compatibility) ilumina cada objeto con 8 luces como mucho, por eso
## el piso, las paredes y los muebles se arman por zonas.
@export_range(1, 10) var light_zone_cells: int = 3
## Color de las luces.
@export var light_color: Color = Color(1.0, 0.95, 0.85)
## Intensidad de las luces (son focos que apuntan para abajo, como en el mapa a mano).
@export_range(0.0, 40.0, 0.5) var light_energy: float = 10.0
## Apertura de cada foco.
@export_range(10.0, 89.0, 1.0, "suffix:°") var spot_angle: float = 55.0

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
## Alto y grosor de las paredes (los de la pieza de pared; los usan los lugares).
var wall_height: float = 8.0
var wall_thickness: float = 0.56
# Piezas del kit ya desarmadas en mallas (ver _piece)
var _piece_cache: Dictionary = {}
# Copias de mallas con los materiales que pisa cada pieza: [[clave, malla], ...]
var _material_meshes: Array = []
# MultiMesh por armar: "zona_malla" -> {"mesh", "zone", "transforms"}
var _batches: Dictionary = {}


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
	_read_wall_size()
	_build_room()
	_build_walls()
	_build_props()
	_build_front()
	_flush_batches()
	_build_places()
	_built = true


func _generate_layout() -> void:
	current_seed = maze_seed if maze_seed != 0 else randi()
	# Para repetir un laberinto: poner este número en "Maze Seed"
	if not Engine.is_editor_hint():
		print("Laberinto: semilla %d" % current_seed)
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


# Clave de una pared para buscarla por su centro (local X, Z) y orientación
func _wall_key(center: Vector2, horizontal: bool) -> Vector3i:
	return Vector3i(roundi(center.x * 10.0), roundi(center.y * 10.0), 1 if horizontal else 0)


# true si una esquina de la grilla (punto local X, Z) está en el borde de un lugar
func _point_touches_room(point: Vector2) -> bool:
	var half := get_size() * 0.5
	var corner := Vector2i(roundi((point.x + half.x) / cell_size), roundi((point.y + half.y) / cell_size))
	for offset in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		if _room_of.has(corner + offset):
			return true
	return false


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
		# Apenas por debajo del techo, para que no compartan plano
		room.wall_height = wall_height + ceiling_gap - 0.02
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


# Alto y grosor de las paredes: los de la pieza de pared
func _read_wall_size() -> void:
	if wall_piece == null:
		return
	var bounds: AABB = _piece(wall_piece).bounds
	wall_height = bounds.size.y
	wall_thickness = bounds.size.z


# Piso y techo (por zonas, con las mallas del mapa a mano) y un foco por zona
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

	var zones := _zone_count()
	var zone_size := light_zone_cells * cell_size
	for zx in zones.x:
		for zy in zones.y:
			var from := Vector2(zx * zone_size - half.x, zy * zone_size - half.y)
			var to := Vector2(minf(from.x + zone_size, half.x), minf(from.y + zone_size, -half.y + total.y))
			var zone_center := (from + to) * 0.5
			floor_body.add_child(_slab("Floor_%d_%d" % [zx, zy], zone_center, to - from, 0.0, false))
			var ceiling_slab := _slab("Ceiling_%d_%d" % [zx, zy], zone_center, to - from, ceiling_y, true)
			# No tapa el sol: así sigue iluminando un poco desde arriba
			ceiling_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ceiling.add_child(ceiling_slab)

			var light := SpotLight3D.new()
			light.name = "Light_%d_%d" % [zx, zy]
			light.position = Vector3(zone_center.x, ceiling_y - 0.3, zone_center.y)
			light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			light.light_color = light_color
			light.light_energy = light_energy
			light.spot_range = ceiling_y * 1.6
			light.spot_angle = spot_angle
			light.shadow_enabled = false
			add_child(light)


# Losa de piso (cara de arriba en "height") o de techo (cara de abajo en
# "height") hecha con la malla del piso estirada a "size" (X, Z). La malla del
# kit está acostada en su plano XY, con el grosor en Z.
func _slab(slab_name: String, center: Vector2, size: Vector2, height: float, is_ceiling: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = slab_name
	if floor_mesh == null:
		var plane := PlaneMesh.new()
		plane.size = size
		plane.flip_faces = is_ceiling
		mesh_instance.mesh = plane
		mesh_instance.position = Vector3(center.x, height, center.y)
		return mesh_instance
	var box := floor_mesh.get_aabb()
	var thickness := 0.1 / maxf(box.size.z, 0.0001)
	var sx := size.x / box.size.x
	var sz := size.y / box.size.y
	# Piso: Z de la malla hacia arriba; techo: hacia abajo (la cara de arriba
	# de la malla queda mirando al piso)
	var basis := Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, 0.0, -sz), Vector3(0.0, thickness, 0.0)) if not is_ceiling \
			else Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, 0.0, sz), Vector3(0.0, -thickness, 0.0))
	var top := Vector3(box.get_center().x, box.get_center().y, box.end.z)
	mesh_instance.mesh = floor_mesh
	mesh_instance.transform = Transform3D(basis, Vector3(center.x, height, center.y) - basis * top)
	return mesh_instance


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
	var entrance_columns := get_entrance_columns()

	# Dónde va cada pared (centro y si va a lo largo de X)
	var specs: Array = []

	for cell in get_all_cells():
		var origin := Vector2((cell.x) * cell_size - half.x, (cell.y) * cell_size - half.y)
		# Pared de arriba (-Z) y de la izquierda (-X) de cada celda; las de
		# abajo y derecha solo en el borde, para no duplicar. Abajo quedan
		# abiertas las entradas a la zona de atención. Las paredes de los
		# lugares las arma cada lugar.
		if not _open[cell].has(Vector2i.UP) and not _touches_room(cell, Vector2i.UP):
			specs.append([origin + Vector2(cell_size * 0.5, 0.0), true])
		if not _open[cell].has(Vector2i.LEFT) and not _touches_room(cell, Vector2i.LEFT):
			specs.append([origin + Vector2(0.0, cell_size * 0.5), false])
		if cell.y == rows - 1 and not entrance_columns.has(cell.x):
			specs.append([origin + Vector2(cell_size * 0.5, cell_size), true])
		if cell.x == columns - 1:
			specs.append([origin + Vector2(cell_size, cell_size * 0.5), false])

	# Zona de atención: solo paredes en el borde (costados y fondo)
	for y in range(rows, _total_rows()):
		for x in columns:
			var origin := Vector2(x * cell_size - half.x, y * cell_size - half.y)
			if x == 0:
				specs.append([origin + Vector2(0.0, cell_size * 0.5), false])
			if x == columns - 1:
				specs.append([origin + Vector2(cell_size, cell_size * 0.5), false])
			if y == _total_rows() - 1:
				specs.append([origin + Vector2(cell_size * 0.5, cell_size), true])

	# Puntas de cada pared: en las esquinas, cruces y puntas sueltas va una
	# columna del mismo material (donde dos paredes siguen en línea recta, no)
	var corners := {}
	for spec in specs:
		_add_wall(walls, spec[0], spec[1])
		var dir: Vector2 = Vector2.RIGHT if spec[1] else Vector2.DOWN
		for side in [-1.0, 1.0]:
			var point: Vector2 = spec[0] + dir * side * cell_size * 0.5
			var key := Vector2i(roundi(point.x * 10.0), roundi(point.y * 10.0))
			if not corners.has(key):
				corners[key] = {"point": point, "along_x": 0, "along_z": 0}
			corners[key]["along_x" if spec[1] else "along_z"] += 1
	for info in corners.values():
		var straight: bool = (info.along_x == 2 and info.along_z == 0) or (info.along_x == 0 and info.along_z == 2)
		if not straight and not _point_touches_room(info.point):
			_add_post(walls, info.point)


# Pared de una celda de largo centrada en "center" (X, Z). "horizontal" = a lo
# largo de X. La colisión es una caja; lo que se ve es el módulo de pared del
# kit estirado al largo de la celda. Si toca un lugar (ej: el taller), se acorta
# y termina a 2 cm de su pared.
func _add_wall(parent: Node3D, center: Vector2, horizontal: bool) -> void:
	var dir := Vector2.RIGHT if horizontal else Vector2.DOWN
	var ends: Array[float] = []
	for side in [-1.0, 1.0]:
		ends.append(-wall_thickness * 0.5 - 0.02 if _point_touches_room(center + dir * side * cell_size * 0.5) else 0.0)
	var length := cell_size + ends[0] + ends[1]
	center += dir * (ends[1] - ends[0]) * 0.5
	var body := StaticBody3D.new()
	body.position = Vector3(center.x, wall_height * 0.5, center.y)
	parent.add_child(body)
	body.add_child(_box_collision(Vector3(length, wall_height, wall_thickness) if horizontal \
			else Vector3(wall_thickness, wall_height, length), Vector3.ZERO))

	var piece_length: float = _piece(wall_piece).bounds.size.x
	# El módulo va a lo largo de su X: para las paredes a lo largo de Z se gira
	var basis := Basis(Vector3.UP, 0.0 if horizontal else -PI * 0.5) \
			* Basis.from_scale(Vector3(length / piece_length, 1.0, 1.0))
	_stamp(wall_piece, Transform3D(basis, Vector3(center.x, 0.0, center.y)))


# Columna en una esquina: el mismo módulo de pared, angosto. Apenas más gruesa
# que las paredes, así sus caras no quedan en el mismo plano que las de ellas.
func _add_post(parent: Node3D, point: Vector2) -> void:
	var bounds: AABB = _piece(wall_piece).bounds
	var width := wall_thickness + 0.01
	var basis := Basis.from_scale(Vector3(width / bounds.size.x, 1.0, width / bounds.size.z))
	_stamp(wall_piece, Transform3D(basis, Vector3(point.x, 0.0, point.y)))
	var body := StaticBody3D.new()
	body.position = Vector3(point.x, wall_height * 0.5, point.y)
	parent.add_child(body)
	body.add_child(_box_collision(Vector3(width, wall_height, width), Vector3.ZERO))


# true si del lado "dir" de "cell" hay una pared del laberinto (no de un lugar)
func _has_wall(cell: Vector2i, dir: Vector2i) -> bool:
	if _touches_room(cell, dir):
		return false
	if _in_bounds(cell + dir):
		return not _open[cell].has(dir)
	# Abajo de la última fila están las entradas a la zona de atención
	return not (dir == Vector2i.DOWN and get_entrance_columns().has(cell.x))


# Muebles de los pasillos: en algunas celdas, uno contra una de sus paredes
func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 2
	var parent := Node3D.new()
	parent.name = "Props"
	add_child(parent)
	var usable := cell_size - wall_thickness - 0.3
	var options: Array[PackedScene] = []
	for scene in corridor_props:
		if scene == null:
			continue
		var bounds: AABB = _piece(scene).bounds
		if bounds.size.x <= usable and bounds.size.z <= cell_size * max_prop_depth:
			options.append(scene)
	if options.is_empty():
		return
	for cell in get_free_cells():
		if rng.randf() >= prop_chance:
			continue
		var sides: Array[Vector2i] = []
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if _has_wall(cell, dir):
				sides.append(dir)
		if sides.is_empty():
			continue
		var side := sides[rng.randi_range(0, sides.size() - 1)]
		var scene := options[rng.randi_range(0, options.size() - 1)]
		var slack := maxf((usable - _piece(scene).bounds.size.x) * 0.5, 0.0)
		_place_against_wall(parent, scene, cell, side, rng.randf_range(-slack, slack))


# Zona de atención: muebles contra el fondo y los costados (dejando libre el
# lugar del mostrador) y, colgados del fondo, el reloj arriba del mostrador y
# algún cuadro más
func _build_front() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 3
	var parent := Node3D.new()
	parent.name = "FrontProps"
	add_child(parent)
	var usable := cell_size - 0.3
	var options: Array[PackedScene] = []
	for scene in front_props:
		if scene != null and _piece(scene).bounds.size.x <= usable:
			options.append(scene)
	var back_row := _total_rows() - 1
	var middle := (columns - 1) * 0.5
	# Celdas del fondo con algo bajo (o nada): ahí se puede colgar un cuadro
	var low_spots: Array[int] = []
	for x in columns:
		if absf(x - middle) <= 1.0:
			continue
		if options.is_empty() or rng.randf() >= front_prop_chance:
			low_spots.append(x)
			continue
		var scene := options[rng.randi_range(0, options.size() - 1)]
		var slack := maxf((usable - _piece(scene).bounds.size.x) * 0.5, 0.0)
		_place_against_wall(parent, scene, Vector2i(x, back_row), Vector2i.DOWN, rng.randf_range(-slack, slack))
		if _piece(scene).bounds.end.y < 1.4:
			low_spots.append(x)
	# Costados (sin la fila del fondo, que ya tiene lo suyo en las esquinas)
	for y in range(rows, back_row):
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			if options.is_empty() or rng.randf() >= front_prop_chance:
				continue
			var x := 0 if side == Vector2i.LEFT else columns - 1
			var scene := options[rng.randi_range(0, options.size() - 1)]
			var slack := maxf((usable - wall_thickness - _piece(scene).bounds.size.x) * 0.5, 0.0)
			_place_against_wall(parent, scene, Vector2i(x, y), side, rng.randf_range(-slack, slack))

	if front_wall_props.is_empty():
		return
	# El reloj, arriba del mostrador (en el medio del fondo)
	var middle_cell := Vector2i(floori(middle), back_row)
	var middle_offset := (middle - floori(middle)) * cell_size
	if front_wall_props[0]:
		_place_against_wall(parent, front_wall_props[0], middle_cell, Vector2i.DOWN, middle_offset)
	for x in low_spots:
		if front_wall_props.size() > 1 and rng.randf() < 0.5:
			var scene := front_wall_props[rng.randi_range(1, front_wall_props.size() - 1)]
			if scene:
				_place_against_wall(parent, scene, Vector2i(x, back_row), Vector2i.DOWN, rng.randf_range(-0.6, 0.6))


# Pone una pieza contra la pared del lado "dir" de "cell", corrida "offset" a
# lo largo de la pared. Las piezas del kit tienen el frente hacia +Z y la
# espalda en Z = 0.
func _place_against_wall(parent: Node3D, scene: PackedScene, cell: Vector2i, dir: Vector2i, offset: float) -> void:
	var center := to_local(get_cell_center(cell))
	var toward_wall := Vector3(dir.x, 0.0, dir.y)
	var along := Vector3(-toward_wall.z, 0.0, toward_wall.x)
	var origin := center + toward_wall * (cell_size * 0.5 - wall_thickness * 0.5 - 0.02) + along * offset
	_place_piece(parent, scene, Transform3D(Basis(Vector3.UP, atan2(-toward_wall.x, -toward_wall.z)), origin))


# Pieza del kit: lo que se ve va a los MultiMesh de su zona; la colisión es
# una caja (salvo lo que cuelga de la pared, que no estorba)
func _place_piece(parent: Node3D, scene: PackedScene, xform: Transform3D) -> void:
	_stamp(scene, xform)
	var bounds: AABB = _piece(scene).bounds
	if bounds.position.y > 0.3:
		return
	var body := StaticBody3D.new()
	body.transform = xform
	parent.add_child(body)
	body.add_child(_box_collision(bounds.size, bounds.get_center()))


# Piezas desarmadas: escena -> {"parts": [[malla, transform]], "bounds": AABB}
func _piece(scene: PackedScene) -> Dictionary:
	if _piece_cache.has(scene):
		return _piece_cache[scene]
	var root := scene.instantiate() as Node3D
	var parts := []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var xform := mesh_instance.transform
		var parent := mesh_instance.get_parent()
		while parent != root:
			xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		parts.append([_mesh_with_materials(mesh_instance), xform])
	var info := {"parts": parts, "bounds": root.get_meta("bounds", AABB())}
	root.free()
	_piece_cache[scene] = info
	return info


# El MultiMesh no tiene materiales por instancia: si la pieza pisa materiales,
# se usa una copia de la malla con esos materiales puestos
func _mesh_with_materials(mesh_instance: MeshInstance3D) -> Mesh:
	var mesh := mesh_instance.mesh
	var materials := []
	var changed := false
	for i in mesh.get_surface_count():
		var material: Material = mesh_instance.material_override
		if material == null and i < mesh_instance.get_surface_override_material_count():
			material = mesh_instance.get_surface_override_material(i)
		materials.append(material)
		changed = changed or material != null
	if not changed:
		return mesh
	var key := [mesh, materials]
	for entry in _material_meshes:
		if entry[0] == key:
			return entry[1]
	var copy := mesh.duplicate() as Mesh
	for i in materials.size():
		if materials[i]:
			copy.surface_set_material(i, materials[i])
	_material_meshes.append([key, copy])
	return copy


# Suma una pieza a los MultiMesh de su zona (uno por malla y por zona)
func _stamp(scene: PackedScene, xform: Transform3D) -> void:
	var zone := _zone_of(Vector2(xform.origin.x, xform.origin.z))
	for part in _piece(scene).parts:
		var mesh: Mesh = part[0]
		var key := "%d_%d_%d" % [zone.x, zone.y, mesh.get_instance_id()]
		if not _batches.has(key):
			_batches[key] = {"mesh": mesh, "zone": zone, "transforms": []}
		_batches[key].transforms.append(xform * part[1])


func _flush_batches() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var count := {}
	for batch in _batches.values():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = batch.mesh
		multimesh.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			multimesh.set_instance_transform(i, batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		var zone: Vector2i = batch.zone
		count[zone] = count.get(zone, 0) + 1
		instance.name = "Zone_%d_%d_%d" % [zone.x, zone.y, count[zone]]
		instance.multimesh = multimesh
		visual.add_child(instance)
	_batches.clear()


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
