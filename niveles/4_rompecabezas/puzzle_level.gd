extends Node3D

# Nivel 4, los rompecabezas: los dos jugadores están frente a frente en la mesa
# principal del taller, cada uno con su tablero. En un minuto tienen que armar
# todos los rompecabezas que puedan; cada uno que terminan desaparece y aparece
# el siguiente con más piezas (2x2, 3x3, 4x4...). Gana el que completó más; si
# empatan, el que tiene más piezas puestas en el que estaba armando.

@export_group("Partida")
## Duración de la partida.
@export_range(10.0, 600.0, 5.0, "suffix:s") var match_duration: float = 60.0
## Segundos de la cuenta regresiva antes de empezar.
@export_range(0, 10) var countdown: int = 3
## Tamaño del primer rompecabezas (2 = 2x2).
@export_range(1, 10) var first_grid: int = 2
## Cuánto crece la grilla con cada rompecabezas completado.
@export_range(0, 5) var grid_step: int = 1
## Tamaño máximo de la grilla.
@export_range(1, 12) var max_grid: int = 8
## Pausa entre que desaparece un rompecabezas y aparece el siguiente.
@export_range(0.0, 3.0, 0.05, "suffix:s") var next_puzzle_delay: float = 0.3
## Puntos por rompecabezas completado (cada pieza puesta del actual suma 1).
@export_range(1, 1000) var points_per_puzzle: int = 100
## Semilla del orden de las imágenes. 0 = distinto cada partida.
@export var puzzle_seed: int = 0
## Tiempo que se muestra el cartel final antes de los resultados.
@export_range(0.0, 10.0, 0.1, "suffix:s") var end_delay: float = 2.5
@export_file("*.tscn") var results_scene: String = "res://menus/results.tscn"
## Segundos que tarda en subir la música al empezar.
@export_range(0.0, 10.0, 0.1, "suffix:s") var music_fade_in: float = 1.5

@export_group("Imágenes")
## Dibujos de los rompecabezas (los carga el artista: conviene que sean
## cuadrados). Los dos jugadores reciben los mismos, en el mismo orden al azar.
## Si está vacío se usan dibujos de prueba hechos por código.
@export var images: Array[Texture2D] = []

@export_group("Referencias")
@export var room: WorkshopRoom
@export var player1: PuzzlePlayer
@export var player2: PuzzlePlayer
@export var hud: PuzzleHud

var time_left: float
var _playing: bool = false
var _finished: bool = false
var _rng := RandomNumberGenerator.new()
var _images: Array[Texture2D] = []


func _ready() -> void:
	if puzzle_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = puzzle_seed
	_prepare_images()
	_place_players()
	time_left = match_duration
	hud.setup(_players())
	hud.set_time(time_left)
	Audio.play_level_music(Audio.music_puzzle, music_fade_in)
	_start_countdown()


func _players() -> Array[PuzzlePlayer]:
	return [player1, player2]


func _prepare_images() -> void:
	_images.assign(images.filter(func(t: Texture2D) -> bool: return t != null))
	if _images.is_empty():
		for i in PuzzlePlaceholders.MOTIFS:
			_images.append(PuzzlePlaceholders.make(i))
	for i in range(_images.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := _images[i]
		_images[i] = _images[j]
		_images[j] = temp


# Un tablero en cada mitad de la mesa, mirando a su jugador: el 1 del lado +Z
# y el 2 del lado -Z
func _place_players() -> void:
	var anchor := room.get_puzzle_anchor()
	var half_depth := room.main_table_size.y * 0.5
	var offset := half_depth * 0.5
	for p in _players():
		var side := 1.0 if p.player_id == 1 else -1.0
		var board := PuzzleBoard.new()
		board.name = "Board%d" % p.player_id
		board.play_area = Vector2(room.main_table_size.x - 0.3, half_depth - 0.1)
		add_child(board)
		var basis := Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI)
		board.global_transform = Transform3D(basis, anchor.global_position + Vector3(0.0, 0.0, side * offset))
		p.setup(board, hud.get_camera(p.player_id), half_depth - offset, room.main_table_height)
		board.piece_snapped.connect(func(_piece: PuzzlePiece) -> void: _update_counts(p))
		board.completed.connect(_on_completed.bind(p))


func _start_countdown() -> void:
	for i in range(countdown, 0, -1):
		hud.show_message(str(i))
		Audio.play_sfx(Audio.race_count)
		await get_tree().create_timer(1.0, false).timeout
	hud.show_message("¡YA!", 0.8)
	Audio.play_sfx(Audio.race_go)
	_playing = true
	for p in _players():
		p.controls_enabled = true
		_start_puzzle(p)


func _start_puzzle(p: PuzzlePlayer) -> void:
	var grid := mini(first_grid + p.completed * grid_step, max_grid)
	var texture := _images[p.completed % _images.size()]
	p.board.start_puzzle(texture, grid, _rng)
	p.on_new_puzzle()
	_update_counts(p)


func _on_completed(p: PuzzlePlayer) -> void:
	if _finished:
		return
	p.completed += 1
	_update_counts(p)
	Audio.play_sfx(Audio.puzzle_complete)
	hud.flash(p, "¡Completo!", 0.6)
	p.play_animation(Player.ANIM_EMOTE)
	# Un instante para ver la imagen terminada, y se va con pops
	await get_tree().create_timer(0.5, false).timeout
	if _finished:
		return
	var gone := p.board.clear_with_pop()
	await get_tree().create_timer(gone + next_puzzle_delay, false).timeout
	p.play_animation(Player.ANIM_IDLE)
	if not _finished:
		_start_puzzle(p)


func _update_counts(p: PuzzlePlayer) -> void:
	var total := p.board.pieces.size()
	var placed := p.board.get_placed_count() if not p.board.is_done() else total
	p.score = p.completed * points_per_puzzle + (placed if not p.board.is_done() else 0)
	hud.set_counts(p, placed, total)


func _process(delta: float) -> void:
	if not _playing or _finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	hud.set_time(time_left)
	for p in _players():
		hud.set_hint(p, hud.get_grab_text(p.held != null))
	if time_left <= 0.0:
		_finish()


func _finish() -> void:
	_finished = true
	_playing = false
	for p in _players():
		p.controls_enabled = false
		hud.set_hint(p, "")
		_update_counts(p)
	var message := "¡Empate!"
	if player1.score != player2.score:
		var winner := player1 if player1.score > player2.score else player2
		message = "¡Tiempo! Gana el Jugador %d" % winner.player_id
		winner.play_animation(Player.ANIM_EMOTE)
	MatchResult.save_from(_players())
	MatchResult.last_level_scene = scene_file_path
	hud.show_message(message)
	Audio.play_match_end()
	get_tree().paused = true
	await get_tree().create_timer(end_delay, true).timeout
	SceneLoader.change_scene(results_scene)
