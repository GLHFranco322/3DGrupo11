class_name PuzzleBoard
extends Node3D

# Tablero de rompecabezas de un jugador, apoyado en la mesa. En el medio va la
# bandeja con la grilla (y la imagen muy suave de guía); las piezas aparecen
# desparramadas a los costados. El jugador está del lado +Z local mirando a -Z:
# la fila de arriba de la imagen queda del lado de -Z.
#
# Una pieza que se suelta cerca de su lugar encastra sola. Cuando están todas,
# avisa con "completed" y las piezas desaparecen con un pop.

signal piece_snapped(piece: PuzzlePiece)
signal completed

## Lado de la bandeja (la imagen entera).
@export_range(0.2, 3.0, 0.01, "suffix:u") var board_size: float = 0.78
## Zona de juego (ancho, fondo) centrada en el tablero: por acá se mueve el
## cursor y se desparraman las piezas.
@export var play_area: Vector2 = Vector2(2.6, 0.9)
## Distancia para que una pieza encastre sola (como fracción del lado de una pieza).
@export_range(0.0, 1.0, 0.05) var snap_distance: float = 0.4
## Opacidad de la imagen de guía en la bandeja (0 = sin guía).
@export_range(0.0, 1.0, 0.01) var guide_alpha: float = 0.18
## Grosor de las piezas.
@export_range(0.002, 0.05, 0.001, "suffix:u") var piece_thickness: float = 0.012
@export var tray_color: Color = Color(0.3, 0.2, 0.13)
@export var piece_side_color: Color = Color(0.85, 0.8, 0.7)

@export_group("Efectos")
## Duración del pop de cada pieza.
@export_range(0.05, 2.0, 0.01, "suffix:s") var pop_time: float = 0.28
## Tiempo entre el pop de una pieza y el de la siguiente.
@export_range(0.0, 0.5, 0.005, "suffix:s") var pop_stagger: float = 0.035

const TRAY_HEIGHT := 0.02

var grid: int = 0
var pieces: Array[PuzzlePiece] = []

var _tray: Node3D
var _next_order: int = 0
var _done: bool = false


## Altura de arriba de la bandeja (las piezas encastradas van ahí).
func get_tray_height() -> float:
	return TRAY_HEIGHT


## Lado de cada pieza del rompecabezas actual.
func get_piece_size() -> float:
	return board_size / maxi(grid, 1)


## Dónde va la pieza de la casilla "slot" (espacio local).
func slot_position(slot: Vector2i) -> Vector3:
	var cell := get_piece_size()
	return Vector3(-board_size * 0.5 + (slot.x + 0.5) * cell, TRAY_HEIGHT, -board_size * 0.5 + (slot.y + 0.5) * cell)


func get_placed_count() -> int:
	var count := 0
	for piece in pieces:
		if piece.placed:
			count += 1
	return count


func is_done() -> bool:
	return _done


## Arma un rompecabezas nuevo de "size" x "size" con "texture": la bandeja y las
## piezas aparecen con pops. Devuelve cuánto tarda en terminar de aparecer.
func start_puzzle(texture: Texture2D, size: int, rng: RandomNumberGenerator) -> float:
	_clear()
	grid = maxi(size, 1)
	_done = false
	_build_tray(texture)

	var spots := _scatter_spots(grid * grid, rng)
	var slots: Array[Vector2i] = []
	for y in grid:
		for x in grid:
			slots.append(Vector2i(x, y))
	_shuffle(slots, rng)

	var cell := get_piece_size()
	for i in slots.size():
		var piece := PuzzlePiece.new()
		piece.name = "Piece_%d_%d" % [slots[i].x, slots[i].y]
		add_child(piece)
		piece.setup(texture, grid, slots[i], cell, piece_thickness, piece_side_color)
		piece.target = slot_position(slots[i])
		piece.position = spots[i]
		piece.stack_order = _bump_order()
		pieces.append(piece)
		piece.pop_in(0.15 + i * pop_stagger, pop_time)
	return 0.15 + slots.size() * pop_stagger + pop_time


## La pieza suelta que está debajo de "point" (la de más arriba), o null.
func piece_at(point: Vector3) -> PuzzlePiece:
	var best: PuzzlePiece = null
	for piece in pieces:
		if piece.placed or not piece.contains(point):
			continue
		if best == null or piece.stack_order > best.stack_order:
			best = piece
	return best


## La pieza suelta más cerca de "point", o null si están todas en su lugar.
func nearest_loose_piece(point: Vector3) -> PuzzlePiece:
	var best: PuzzlePiece = null
	var best_distance := INF
	for piece in pieces:
		if piece.placed:
			continue
		var distance := Vector2(piece.position.x - point.x, piece.position.z - point.z).length()
		if distance < best_distance:
			best = piece
			best_distance = distance
	return best


## Levanta la pieza (queda arriba de todas mientras se la lleva).
func lift(piece: PuzzlePiece) -> void:
	piece.stack_order = _bump_order()
	piece.position.y = 0.07


## Suelta la pieza donde está. Si quedó cerca de su lugar, encastra y devuelve
## true; si no, queda apoyada en la mesa (o arriba de la bandeja).
func drop(piece: PuzzlePiece) -> bool:
	var flat := Vector2(piece.position.x - piece.target.x, piece.position.z - piece.target.z)
	if flat.length() <= snap_distance * get_piece_size():
		_snap(piece)
		return true
	piece.position = clamp_to_area(piece.position)
	var on_tray := absf(piece.position.x) < board_size * 0.5 and absf(piece.position.z) < board_size * 0.5
	# Las de más arriba quedan apenas más altas, así no titilan al pisarse
	piece.position.y = (TRAY_HEIGHT if on_tray else 0.0) + 0.0005 * (piece.stack_order % 20)
	Audio.play_sfx(Audio.piece_drop, 0.0, -4.0)
	return false


## Mantiene un punto dentro de la zona de juego.
func clamp_to_area(point: Vector3) -> Vector3:
	var half := play_area * 0.5
	return Vector3(clampf(point.x, -half.x, half.x), point.y, clampf(point.z, -half.y, half.y))


## Hace desaparecer todo con pops (al terminar o al cortar la partida).
func clear_with_pop() -> float:
	var delay := 0.0
	for piece in pieces:
		if is_instance_valid(piece):
			piece.pop_out(delay, pop_time)
			delay += pop_stagger
	pieces.clear()
	if _tray:
		var tray := _tray
		_tray = null
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(tray, "scale", Vector3.ONE * 0.001, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(tray.queue_free)
	return delay + pop_time


func _snap(piece: PuzzlePiece) -> void:
	piece.placed = true
	piece.set_highlight(false)
	var tween := create_tween()
	tween.tween_property(piece, "position", piece.target, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_callback(piece.bounce)
	Audio.play_sfx(Audio.piece_snap)
	piece_snapped.emit(piece)
	if get_placed_count() == pieces.size() and not _done:
		_done = true
		completed.emit()


# Bandeja de madera con borde, la imagen de guía muy suave y las líneas de la grilla
func _build_tray(texture: Texture2D) -> void:
	_tray = Node3D.new()
	_tray.name = "Tray"
	add_child(_tray)

	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(board_size + 0.06, TRAY_HEIGHT, board_size + 0.06)
	box.material = MazeRoom.flat_material(tray_color, 0.8)
	base.mesh = box
	base.position.y = TRAY_HEIGHT * 0.5
	_tray.add_child(base)

	if guide_alpha > 0.0:
		var guide := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * board_size
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.albedo_color = Color(1.0, 1.0, 1.0, guide_alpha)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plane.material = material
		guide.mesh = plane
		guide.position.y = TRAY_HEIGHT + 0.0005
		_tray.add_child(guide)

	var lines: Array[Transform3D] = []
	var cell := get_piece_size()
	for i in range(1, grid):
		var offset := -board_size * 0.5 + i * cell
		lines.append(MazeRoom.box_transform(Vector3(offset, TRAY_HEIGHT + 0.0008, 0.0), Vector3.RIGHT, Vector3.BACK,
				Vector3(0.004, 0.001, board_size)))
		lines.append(MazeRoom.box_transform(Vector3(0.0, TRAY_HEIGHT + 0.0008, offset), Vector3.RIGHT, Vector3.BACK,
				Vector3(board_size, 0.001, 0.004)))
	if not lines.is_empty():
		_tray.add_child(MazeRoom.make_multimesh("Grid", lines, [], MazeRoom.flat_material(tray_color * 0.6, 0.9)))

	_tray.scale = Vector3.ONE * 0.001
	var tween := create_tween()
	tween.tween_property(_tray, "scale", Vector3.ONE, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Lugares libres a los costados de la bandeja (en una grilla, mezclados). Si no
# alcanzan, las que sobran van en cualquier lugar de los costados.
func _scatter_spots(count: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var cell := get_piece_size()
	var step := cell * 1.2
	var half := play_area * 0.5 - Vector2.ONE * cell * 0.55
	var inner := board_size * 0.5 + 0.06 + cell * 0.6
	var spots: Array[Vector3] = []
	var x := inner
	while x <= half.x:
		var z := -half.y
		while z <= half.y:
			for side in [-1.0, 1.0]:
				var jitter := Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1)) * cell
				spots.append(Vector3(side * x, 0.0, z) + jitter)
			z += step
		x += step
	_shuffle(spots, rng)
	while spots.size() < count:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		spots.append(Vector3(side * rng.randf_range(inner, maxf(inner, half.x)), 0.0, rng.randf_range(-half.y, half.y)))
	spots.resize(count)
	return spots


func _bump_order() -> int:
	_next_order += 1
	return _next_order


func _clear() -> void:
	for piece in pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	pieces.clear()
	if _tray:
		_tray.queue_free()
		_tray = null


func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
