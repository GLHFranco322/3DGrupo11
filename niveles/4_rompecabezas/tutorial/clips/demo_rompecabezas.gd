class_name DemoRompecabezas
extends Demo

# Base de los clips del nivel 4: sin cuenta regresiva, siempre las mismas
# imágenes y piezas, y la cámara en los ojos del jugador 1 (como en su mitad
# de la pantalla, pero sin su personaje).

const SEMILLA := 4

var p1: PuzzlePlayer
var p2: PuzzlePlayer


func escena() -> String:
	return "res://niveles/4_rompecabezas/puzzle_level.tscn"


func configurar(n: Node) -> void:
	n.countdown = 0
	n.match_duration = 999.0
	n.puzzle_seed = SEMILLA


func preparar() -> void:
	p1 = nivel.player1
	p2 = nivel.player2
	# Que no titile la pista del rival al fondo
	p2.hint_delay = 999.0
	var board := p1.board
	# Más atrás que en el juego: el clip es 16:9 y en el juego la mitad de la
	# pantalla es una franja ancha (si no, las piezas de los costados no entran)
	var eye := board.to_global(Vector3(0.0, 1.3, 1.05))
	var look := board.to_global(Vector3(0.0, 0.0, -0.1))
	camara.fov = p1.camera_fov
	camara.look_at_from_position(eye, look, Vector3.UP)
	camara.cull_mask &= ~(1 << (p1.get_model_layer() - 1))


## Lleva el cursor del jugador con la palanca izquierda hasta "punto" (espacio
## del tablero), frenando al llegar.
func llevar_cursor(p: PuzzlePlayer, punto: Vector3) -> void:
	var tiempo := 0.0
	while tiempo < 4.0:
		var falta := punto - p._cursor.position
		falta.y = 0.0
		if falta.length() < 0.012:
			break
		var fuerza := clampf(falta.length() / 0.12, 0.25, 1.0)
		_direccion(p.player_id, Vector2(falta.x, falta.z).normalized() * fuerza)
		await get_tree().physics_frame
		tiempo += get_physics_process_delta_time()
	_direccion(p.player_id, Vector2.ZERO)


## Agarra la pieza, la lleva a su lugar y la suelta (encastra sola).
func colocar(p: PuzzlePlayer, pieza: PuzzlePiece, pausa: float = 0.15) -> void:
	await llevar_cursor(p, pieza.position)
	await esperar(pausa)
	await apretar(p.player_id, "grab")
	await esperar(pausa)
	await llevar_cursor(p, pieza.target)
	await esperar(pausa)
	await apretar(p.player_id, "grab")


## Piezas que faltan poner, empezando por la más cercana al cursor.
func sueltas(p: PuzzlePlayer) -> Array[PuzzlePiece]:
	var result: Array[PuzzlePiece] = []
	for pieza in p.board.pieces:
		if not pieza.placed:
			result.append(pieza)
	var desde: Vector3 = p._cursor.position
	result.sort_custom(func(a: PuzzlePiece, b: PuzzlePiece) -> bool:
		return a.position.distance_to(desde) < b.position.distance_to(desde))
	return result
