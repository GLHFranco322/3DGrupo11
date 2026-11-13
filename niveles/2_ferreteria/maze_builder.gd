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
@export_range(2, 40) var columns: int = 10
## Celdas a lo largo (Z), sin contar la zona de atención.
@export_range(2, 40) var rows: int = 11
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
@export_range(1, 10) var front_rows: int = 5
## Entradas entre la zona de atención y el laberinto (repartidas a lo ancho).
@export_range(1, 10) var entrances: int = 3

@export_group("Piezas")
## Módulo de pared de una celda de largo. Su alto y su grosor son los de todas
## las paredes.
@export var wall_piece: PackedScene = preload("res://niveles/2_ferreteria/kit/pared.tscn")

@export_group("Decoración")
# Los muebles se ubican como en el mapa hecho a mano de Fabricio
# (niveles/Escenarios/laberinto_ferreteria.tscn): estanterías en fila contra
# las paredes de afuera, pallets con barriles en las esquinas, cajas en los
# fondos de los pasillos sin salida, casilleros en la franja que da a la zona
# de atención, escaleras y muebles contra las paredes de adentro, conos en los
# cruces y en las entradas, y una isla de estanterías en los salones abiertos.
## Lo que va en fila contra las paredes de afuera del laberinto.
@export var perimeter_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/estanteria.tscn"),
]
## Probabilidad de empezar una fila de estanterías (seguirla es más probable).
@export_range(0.0, 1.0, 0.05) var perimeter_chance: float = 0.6
## Lo que va en las esquinas del laberinto y de la zona de atención.
@export var corner_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/pallet_baldes.tscn"),
]
## Lo que va al fondo de los pasillos sin salida.
@export var dead_end_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/cajas_barriles.tscn"),
	preload("res://niveles/2_ferreteria/kit/escalera_chica.tscn"),
]
## Lo que se apoya contra las paredes de adentro del laberinto (puertas no:
## no llevarían a ningún lado).
@export var inner_wall_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/casillero_1.tscn"),
	preload("res://niveles/2_ferreteria/kit/casillero_2.tscn"),
	preload("res://niveles/2_ferreteria/kit/escalera_chica.tscn"),
	preload("res://niveles/2_ferreteria/kit/cajas_barriles.tscn"),
]
## Puerta del depósito: va solo contra las paredes de afuera del laberinto
## (como si llevara a otra parte de la ferretería).
@export var outer_door_prop: PackedScene = preload("res://niveles/2_ferreteria/kit/puerta_deco.tscn")
## Cuántas puertas del depósito como mucho.
@export_range(0, 10) var max_outer_doors: int = 2
## Probabilidad de que una celda tenga algo contra una pared de adentro.
@export_range(0.0, 1.0, 0.05) var inner_wall_chance: float = 0.3
## Casilleros de la última fila del laberinto (la que da a la zona de atención).
@export var front_row_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/casillero_2.tscn"),
]
## Conos: en algunos cruces. Son objetos sueltos (ObjetoSuelto): los jugadores
## los empujan o los tiran al chocarlos, así nunca tapan un pasillo.
@export var cone_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/cono_1.tscn"),
	preload("res://niveles/2_ferreteria/kit/cono_2.tscn"),
]
## Probabilidad de un cono en un cruce de pasillos.
@export_range(0.0, 1.0, 0.01) var junction_cone_chance: float = 0.08
## Cuántos conos como mucho en los cruces.
@export_range(0, 20) var max_junction_cones: int = 3
## Peso de cada cono (más liviano = sale volando más lejos).
@export_range(0.1, 20.0, 0.1, "suffix:kg") var cone_mass: float = 1.5
## Sala de estanterías (en los salones abiertos de 2x2 celdas, como la de
## Fabricio): dos estanterías en el medio, otra contra una pared y un pallet de
## barriles en una esquina.
@export var island_prop: PackedScene = preload("res://niveles/2_ferreteria/kit/estanteria.tscn")
## Cuántas salas de estanterías como mucho.
@export_range(0, 10) var max_islands: int = 2
## Sala de casilleros (al fondo de un pasillo sin salida, como la de Fabricio):
## casilleros en U contra las tres paredes.
@export var locker_room_prop: PackedScene = preload("res://niveles/2_ferreteria/kit/casillero_2.tscn")
## Cuántas salas de casilleros como mucho.
@export_range(0, 10) var max_locker_rooms: int = 2
## Rincón de la escalera (al fondo de un pasillo sin salida): la escalera alta
## apoyada en la pared, un pallet de barriles y un cono.
@export var ladder_corner_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/escalera_alta.tscn"),
	preload("res://niveles/2_ferreteria/kit/pallet_baldes.tscn"),
	preload("res://niveles/2_ferreteria/kit/cono_1.tscn"),
]
## Cuántos rincones de la escalera como mucho.
@export_range(0, 10) var max_ladder_corners: int = 2
## Profundidad máxima de un mueble contra una pared de pasillo (fracción del
## ancho del pasillo), para que no tape el paso ni las herramientas.
@export_range(0.1, 0.5, 0.05) var max_prop_depth: float = 0.35

@export_group("Muebles de la zona de atención")
## La zona de atención de Fabricio entera (kit/zona_atencion.tscn, sacada de su
## mapa con kit/extraer_zonas.gd). Vacío = se arma con los muebles de abajo.
@export var front_zone: PackedScene = preload("res://niveles/2_ferreteria/kit/zona_atencion.tscn")
## Junto al mostrador, a cada lado (contra el fondo).
@export var counter_side_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/sillon.tscn"),
	preload("res://niveles/2_ferreteria/kit/mesa.tscn"),
]
## Plantas: una a cada lado, después de lo del mostrador.
@export var plant_prop: PackedScene = preload("res://niveles/2_ferreteria/kit/cactus.tscn")
## Lo que va contra el resto del fondo y contra la pared que da al laberinto.
@export var front_wall_shelves: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/estanteria.tscn"),
	preload("res://niveles/2_ferreteria/kit/pallet_cajas.tscn"),
	preload("res://niveles/2_ferreteria/kit/escalera_alta.tscn"),
]
## Lo que cuelga de la pared del fondo de la zona de atención. El primero (el
## reloj) va siempre arriba del mostrador; los demás se reparten.
@export var front_wall_props: Array[PackedScene] = [
	preload("res://niveles/2_ferreteria/kit/reloj.tscn"),
	preload("res://niveles/2_ferreteria/kit/planos.tscn"),
	preload("res://niveles/2_ferreteria/kit/diana.tscn"),
]

@export_group("Piso")
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
# Celdas con un mueble grande (pallet, isla): ahí no se ponen herramientas
var _prop_cells: Dictionary = {}
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
		if not _room_of.has(cell) and not _prop_cells.has(cell):
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


# Muebles del laberinto, ubicados como en el mapa de Fabricio (ver "Decoración")
func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 2
	var parent := Node3D.new()
	parent.name = "Props"
	add_child(parent)
	_prop_cells.clear()
	# Lados de cada celda que ya tienen algo: cell -> [dir, ...]
	var used: Dictionary = {}
	var cells := get_free_cells()
	var free := {}
	for cell in cells:
		free[cell] = true

	# 1. Esquinas: pallet con barriles contra las dos paredes de afuera
	for cell in cells:
		var outer: Array[Vector2i] = []
		for dir in DIRS:
			if not _in_bounds(cell + dir) and _has_wall(cell, dir):
				outer.append(dir)
		if outer.size() < 2 or corner_props.is_empty():
			continue
		_place_in_corner(parent, _pick(corner_props, rng), cell, outer[0], outer[1])
		_mark(used, cell, outer[0])
		_mark(used, cell, outer[1])
		_prop_cells[cell] = true

	# 2. Paredes de afuera: alguna puerta del depósito, y filas de estanterías
	# (con huecos entre filas); la última fila, que da a la zona de atención,
	# lleva casilleros
	if outer_door_prop and max_outer_doors > 0:
		var door_spots: Array = []
		for cell in cells:
			for dir in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
				if not _in_bounds(cell + dir) and _has_wall(cell, dir) and not _is_used(used, cell, dir):
					door_spots.append([cell, dir])
		for i in range(door_spots.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = door_spots[i]
			door_spots[i] = door_spots[j]
			door_spots[j] = tmp
		var doors := 0
		for spot in door_spots:
			if doors >= max_outer_doors:
				break
			var cell: Vector2i = spot[0]
			# Una por celda, y no al lado de otra
			if used.has(cell) or used.has(cell + Vector2i.LEFT) or used.has(cell + Vector2i.RIGHT) \
					or used.has(cell + Vector2i.UP) or used.has(cell + Vector2i.DOWN):
				continue
			_place_against_wall(parent, outer_door_prop, cell, spot[1], 0.0)
			_mark(used, cell, spot[1])
			doors += 1
	var sides := [
		[Vector2i.UP, _row_cells(0)], [Vector2i.LEFT, _column_cells(0)],
		[Vector2i.RIGHT, _column_cells(columns - 1)], [Vector2i.DOWN, _row_cells(rows - 1)],
	]
	for side in sides:
		var dir: Vector2i = side[0]
		var options := _fitting(front_row_props if dir == Vector2i.DOWN else perimeter_props)
		var in_row := false
		for cell in side[1]:
			if not free.has(cell) or not _has_wall(cell, dir) or _is_used(used, cell, dir) or options.is_empty():
				in_row = false
				continue
			in_row = rng.randf() < (0.85 if in_row else perimeter_chance)
			if in_row:
				_place_against_wall(parent, _pick(options, rng), cell, dir, 0.0)
				_mark(used, cell, dir)

	# 3. Pasillos sin salida: algunos son la sala de casilleros o el rincón de
	# la escalera de Fabricio; los demás, algo contra la pared del fondo
	var dead_end_options := _fitting(dead_end_props)
	var dead_ends: Array[Vector2i] = []
	for cell in cells:
		if _open_sides(cell).size() == 1 and not _prop_cells.has(cell):
			dead_ends.append(cell)
	_shuffle_cells(dead_ends, rng)
	var locker_rooms := 0
	var ladder_corners := 0
	for cell in dead_ends:
		var back: Vector2i = -_open_sides(cell)[0]
		var walls3: Array[Vector2i] = [back, Vector2i(back.y, back.x), Vector2i(-back.y, -back.x)]
		var free_walls := walls3.all(func(dir): return _has_wall(cell, dir) and not _is_used(used, cell, dir))
		if free_walls and locker_room_prop and locker_rooms < max_locker_rooms:
			_build_locker_room(parent, cell, walls3)
			for dir in walls3:
				_mark(used, cell, dir)
				if dir != back:
					_mark(used, cell - back, dir)
			locker_rooms += 1
		elif free_walls and ladder_corner_props.size() >= 3 and ladder_corners < max_ladder_corners:
			_build_ladder_corner(parent, cell, back, walls3[1], rng)
			for dir in walls3:
				_mark(used, cell, dir)
			_prop_cells[cell] = true
			ladder_corners += 1
		elif _has_wall(cell, back) and not _is_used(used, cell, back) and not dead_end_options.is_empty():
			_place_against_wall(parent, _pick(dead_end_options, rng), cell, back, 0.0)
			_mark(used, cell, back)

	# 4. Paredes de adentro: casilleros, escaleras, cajas...; en la última fila,
	# las paredes de los costados llevan casilleros (los boxes de Fabricio)
	var inner_options := _fitting(inner_wall_props)
	var row_options := _fitting(front_row_props)
	for cell in cells:
		var last_row := cell.y == rows - 1
		if not last_row and (used.has(cell) or rng.randf() >= inner_wall_chance):
			continue
		var walls: Array[Vector2i] = []
		for dir in DIRS:
			if _in_bounds(cell + dir) and _has_wall(cell, dir) and not _is_used(used, cell, dir):
				if not last_row or dir == Vector2i.LEFT or dir == Vector2i.RIGHT:
					walls.append(dir)
		if walls.is_empty():
			continue
		if last_row:
			for dir in walls:
				if not row_options.is_empty() and rng.randf() < 0.7:
					_place_against_wall(parent, _pick(row_options, rng), cell, dir, 0.0)
					_mark(used, cell, dir)
		elif not inner_options.is_empty():
			var dir := walls[rng.randi_range(0, walls.size() - 1)]
			var scene := _pick(inner_options, rng)
			var slack := maxf((cell_size - wall_thickness - 0.3 - _piece(scene).bounds.size.x) * 0.5, 0.0)
			_place_against_wall(parent, scene, cell, dir, rng.randf_range(-slack, slack))
			_mark(used, cell, dir)

	# 5. Salones abiertos (2x2 celdas sin paredes adentro): isla de estanterías
	var islands := 0
	for cell in cells:
		if islands >= max_islands or island_prop == null:
			break
		var block: Array[Vector2i] = [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]
		var ok := true
		for c in block:
			if not free.has(c) or _prop_cells.has(c):
				ok = false
		if not ok or _has_wall(cell, Vector2i.RIGHT) or _has_wall(cell, Vector2i.DOWN) \
				or _has_wall(cell + Vector2i.ONE, Vector2i.UP) or _has_wall(cell + Vector2i.ONE, Vector2i.LEFT):
			continue
		_build_shelf_room(parent, block, used, rng)
		for c in block:
			_prop_cells[c] = true
		islands += 1

	# 6. Conos en algunos cruces, en una esquina de la celda (pegados a las
	# paredes, no en el medio del paso)
	var cones := 0
	for cell in cells:
		if cones >= max_junction_cones:
			break
		if cone_props.is_empty() or _prop_cells.has(cell) or _open_sides(cell).size() < 3:
			continue
		if rng.randf() >= junction_cone_chance:
			continue
		var corner := Vector3(1.0 if rng.randf() < 0.5 else -1.0, 0.0, 1.0 if rng.randf() < 0.5 else -1.0)
		var spot := to_local(get_cell_center(cell)) + corner * (cell_size * 0.5 - wall_thickness * 0.5 - 0.5)
		_place_cone(parent, _pick(cone_props, rng), Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), spot))
		cones += 1


# Zona de atención, como la de Fabricio: pallets en las esquinas, estanterías
# contra las paredes largas (sin tapar las entradas), y en el fondo, a los lados
# del mostrador, el sillón y la mesa, después plantas; colgados del fondo, el
# reloj arriba del mostrador y algún cuadro. Conos a los lados de cada entrada.
func _build_front() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 3
	var parent := Node3D.new()
	parent.name = "FrontProps"
	add_child(parent)
	# La zona de atención de Fabricio, tal cual: pegada a la pared del laberinto
	if front_zone:
		var zone := front_zone.instantiate() as Node3D
		zone.name = "ZonaAtencion"
		zone.position = Vector3(0.0, 0.0, get_size().y * 0.5)
		parent.add_child(zone)
		var body := StaticBody3D.new()
		zone.add_child(body)
		for box: AABB in zone.get_meta("collisions", []):
			body.add_child(_box_collision(box.size, box.get_center()))
		# Las puertas de entrada, pegadas a la pared del fondo (en el mapa de
		# Fabricio la pared estaba un poco más adelante)
		var back_face := front_rows * cell_size - wall_thickness * 0.5 - 0.01
		for child in zone.get_children():
			if child is MeshInstance3D and child.get_meta("pegar_al_fondo", false):
				var box: AABB = child.transform * (child as MeshInstance3D).mesh.get_aabb()
				child.position.z += back_face - box.end.z
		return
	var first_row := rows
	var back_row := _total_rows() - 1
	var middle := (columns - 1) * 0.5
	var entrance_columns := get_entrance_columns()
	var low_spots: Array[int] = []

	# Esquinas
	if not corner_props.is_empty():
		for cell in [Vector2i(0, first_row), Vector2i(columns - 1, first_row), Vector2i(0, back_row), Vector2i(columns - 1, back_row)]:
			var side := Vector2i.LEFT if cell.x == 0 else Vector2i.RIGHT
			var end := Vector2i.UP if cell.y == first_row else Vector2i.DOWN
			if end == Vector2i.UP and entrance_columns.has(cell.x):
				continue
			_place_in_corner(parent, _pick(corner_props, rng), cell, side, end)

	# Costados (si la zona tiene más de dos filas)
	if not front_wall_shelves.is_empty():
		for y in range(first_row + 1, back_row):
			for side in [Vector2i.LEFT, Vector2i.RIGHT]:
				_place_against_wall(parent, front_wall_shelves[0], Vector2i(0 if side == Vector2i.LEFT else columns - 1, y), side, 0.0)

	# Pared que da al laberinto: estanterías entre las entradas
	for x in range(1, columns - 1):
		if entrance_columns.has(x) or front_wall_shelves.is_empty():
			continue
		if rng.randf() < 0.75:
			_place_against_wall(parent, front_wall_shelves[0], Vector2i(x, first_row), Vector2i.UP, 0.0)

	# Fondo: del mostrador hacia afuera
	for x in range(1, columns - 1):
		var distance := absf(x - middle)
		if distance <= 1.0:
			continue
		var scene: PackedScene = null
		if distance <= 2.0 and not counter_side_props.is_empty():
			scene = counter_side_props[0 if x < middle else mini(1, counter_side_props.size() - 1)]
		elif distance <= 3.0:
			scene = plant_prop
		elif not front_wall_shelves.is_empty():
			scene = front_wall_shelves[rng.randi_range(0, front_wall_shelves.size() - 1)]
		if scene == null:
			low_spots.append(x)
			continue
		_place_against_wall(parent, scene, Vector2i(x, back_row), Vector2i.DOWN, 0.0)
		if _piece(scene).bounds.end.y < 1.8:
			low_spots.append(x)

	# Conos a los lados de cada entrada (menos la del medio, donde arrancan los
	# jugadores)
	if not cone_props.is_empty():
		for x in entrance_columns:
			if absf(x - middle) < 1.0:
				continue
			var center := to_local(get_cell_center(Vector2i(x, first_row)))
			for along in [-1.0, 1.0]:
				var spot := center + Vector3(along * (cell_size * 0.5 - 0.35), 0.0, -cell_size * 0.5 + 0.7)
				_place_cone(parent, _pick(cone_props, rng), Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), spot))

	if front_wall_props.is_empty():
		return
	# El reloj, arriba del mostrador (en el medio del fondo)
	var middle_cell := Vector2i(floori(middle), back_row)
	var middle_offset := (middle - floori(middle)) * cell_size
	if front_wall_props[0]:
		_place_against_wall(parent, front_wall_props[0], middle_cell, Vector2i.DOWN, middle_offset)
	for x in low_spots:
		if front_wall_props.size() > 1 and rng.randf() < 0.6:
			var scene := front_wall_props[rng.randi_range(1, front_wall_props.size() - 1)]
			if scene:
				_place_against_wall(parent, scene, Vector2i(x, back_row), Vector2i.DOWN, rng.randf_range(-0.6, 0.6))


# Sala de casilleros de Fabricio: casilleros en U (fondo y costados) al final
# de un pasillo sin salida, y si el pasillo sigue derecho, también en la celda
# de antes. "sides" = [fondo, costado, otro costado].
func _build_locker_room(parent: Node3D, cell: Vector2i, sides: Array[Vector2i]) -> void:
	var bounds: AABB = _piece(locker_room_prop).bounds
	var width := bounds.size.x
	var depth := bounds.size.z
	var back := sides[0]
	var open := -back
	for offset in [-width * 0.5, width * 0.5]:
		_place_against_wall(parent, locker_room_prop, cell, back, offset)
	for i in [1, 2]:
		var dir: Vector2i = sides[i]
		# Corrido hacia la salida, para no chocar con los del fondo
		var along := Vector3(-dir.y, 0.0, dir.x)
		var toward_open := signf(along.dot(Vector3(open.x, 0.0, open.y)))
		_place_against_wall(parent, locker_room_prop, cell, dir, toward_open * depth * 0.3)
		var before := cell + open
		if free_cell(before) and _has_wall(before, dir):
			_place_against_wall(parent, locker_room_prop, before, dir, 0.0)


# Rincón de la escalera de Fabricio: la escalera alta apoyada en la pared del
# fondo, un pallet de barriles en la otra esquina y un cono más adelante
func _build_ladder_corner(parent: Node3D, cell: Vector2i, back: Vector2i, side: Vector2i, rng: RandomNumberGenerator) -> void:
	var ladder: PackedScene = ladder_corner_props[0]
	var pallet: PackedScene = ladder_corner_props[1]
	var cone: PackedScene = ladder_corner_props[2]
	_place_in_corner(parent, ladder, cell, back, side)
	_place_in_corner(parent, pallet, cell, back, -side)
	var open := Vector3(-back.x, 0.0, -back.y)
	var spot := to_local(get_cell_center(cell)) + open * (cell_size * 0.3) - Vector3(side.x, 0.0, side.y) * (cell_size * 0.25)
	_place_cone(parent, cone, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), spot))


# Sala de estanterías de Fabricio en un salón de 2x2 celdas: dos estanterías en
# el medio (mirando cada una para un lado), otra contra una pared del salón y
# un pallet de barriles en una esquina
func _build_shelf_room(parent: Node3D, block: Array[Vector2i], used: Dictionary, rng: RandomNumberGenerator) -> void:
	var center := to_local(get_cell_center(block[0])) + Vector3(cell_size, 0.0, cell_size) * 0.5
	for facing in [1.0, -1.0]:
		var basis := Basis(Vector3.UP, PI * 0.5 * facing)
		_place_piece(parent, island_prop, Transform3D(basis, center + Vector3(0.4 * facing, 0.0, 0.0)))
	# Lados del salón: [dirección, las dos celdas de ese lado]
	var sides := [
		[Vector2i.UP, block[0], block[1]], [Vector2i.DOWN, block[2], block[3]],
		[Vector2i.LEFT, block[0], block[2]], [Vector2i.RIGHT, block[1], block[3]],
	]
	var wall_side: Vector2i = Vector2i.ZERO
	for side in sides:
		var dir: Vector2i = side[0]
		if wall_side == Vector2i.ZERO and _has_wall(side[1], dir) and _has_wall(side[2], dir) \
				and not _is_used(used, side[1], dir) and not _is_used(used, side[2], dir):
			wall_side = dir
			# Centrada en el lado del salón: corrida media celda hacia la otra
			var along := Vector3(-dir.y, 0.0, dir.x)
			var to_other: Vector2i = side[2] - side[1]
			var shift := signf(along.dot(Vector3(to_other.x, 0.0, to_other.y))) * cell_size * 0.5
			_place_against_wall(parent, island_prop, side[1], dir, shift)
			_mark(used, side[1], dir)
			_mark(used, side[2], dir)
	# Pallet en una esquina del salón (del lado contrario a la estantería)
	if corner_props.is_empty():
		return
	var corners := [
		[block[0], Vector2i.UP, Vector2i.LEFT], [block[1], Vector2i.UP, Vector2i.RIGHT],
		[block[2], Vector2i.DOWN, Vector2i.LEFT], [block[3], Vector2i.DOWN, Vector2i.RIGHT],
	]
	for corner in corners:
		var c: Vector2i = corner[0]
		if corner[1] == wall_side or corner[2] == wall_side:
			continue
		if _has_wall(c, corner[1]) and _has_wall(c, corner[2]) and not _is_used(used, c, corner[1]):
			_place_in_corner(parent, _pick(corner_props, rng), c, corner[1], corner[2])
			_mark(used, c, corner[1])
			_mark(used, c, corner[2])
			return


## Celda del laberinto libre (adentro, sin habitación ni mueble grande).
func free_cell(cell: Vector2i) -> bool:
	return _in_bounds(cell) and not _room_of.has(cell) and not _prop_cells.has(cell)


func _shuffle_cells(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp


const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _row_cells(y: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in columns:
		cells.append(Vector2i(x, y))
	return cells


func _column_cells(x: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows:
		cells.append(Vector2i(x, y))
	return cells


# Lados de la celda por donde se puede pasar
func _open_sides(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRS:
		if not _has_wall(cell, dir):
			result.append(dir)
	return result


func _mark(used: Dictionary, cell: Vector2i, dir: Vector2i) -> void:
	if not used.has(cell):
		used[cell] = []
	used[cell].append(dir)


func _is_used(used: Dictionary, cell: Vector2i, dir: Vector2i) -> bool:
	return used.has(cell) and used[cell].has(dir)


# Los que entran contra una pared de pasillo sin tapar el paso
func _fitting(scenes: Array[PackedScene]) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var usable := cell_size - wall_thickness - 0.3
	for scene in scenes:
		if scene == null:
			continue
		var bounds: AABB = _piece(scene).bounds
		if bounds.size.x <= usable and bounds.size.z <= cell_size * max_prop_depth:
			result.append(scene)
	return result


func _pick(scenes: Array[PackedScene], rng: RandomNumberGenerator) -> PackedScene:
	return scenes[rng.randi_range(0, scenes.size() - 1)]


# Contra la pared "wall" de la celda, corrida hasta la esquina con "toward"
func _place_in_corner(parent: Node3D, scene: PackedScene, cell: Vector2i, wall: Vector2i, toward: Vector2i) -> void:
	var toward_wall := Vector3(wall.x, 0.0, wall.y)
	var along := Vector3(-toward_wall.z, 0.0, toward_wall.x)
	var side := signf(along.dot(Vector3(toward.x, 0.0, toward.y)))
	var usable := cell_size - wall_thickness
	var offset := side * maxf((usable - _piece(scene).bounds.size.x) * 0.5 - 0.05, 0.0)
	_place_against_wall(parent, scene, cell, wall, offset)


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


# Cono (u otra pieza chica) que se puede chocar: un ObjetoSuelto con física en
# vez de una caja fija. "xform" es como para _place_piece (la pieza con la
# espalda en Z = 0).
func _place_cone(parent: Node3D, scene: PackedScene, xform: Transform3D) -> void:
	var body := ObjetoSuelto.from_piece(scene, cone_mass)
	var base: Vector3 = body.get_meta("base_offset")
	body.transform = xform * Transform3D(Basis(), base)
	# Sin física en el editor (si no, se cae al regenerar)
	body.freeze = Engine.is_editor_hint()
	parent.add_child(body)


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
