extends Node3D

# Nivel 2, la ferretería: cada jugador tiene una lista de herramientas que
# tiene que encontrar en el laberinto y colgar en el tablero. Gana el primero
# que completa su lista; si se acaba el tiempo, el que entregó más.

@export_group("Partida")
## Herramientas en la lista de cada jugador.
@export_range(1, 12) var items_per_player: int = 5
## Herramientas extra que no están en ninguna lista (para confundir).
@export_range(0, 20) var decoy_items: int = 3
## Duración máxima de la partida.
@export_range(10.0, 900.0, 5.0, "suffix:s") var match_duration: float = 180.0
## Puntos por herramienta entregada.
@export_range(1, 1000) var points_per_item: int = 100
## Si es true, los dos jugadores reciben la misma lista.
@export var same_list_for_both: bool = false
## Semilla para las listas y dónde aparece cada herramienta. 0 = distinta cada partida.
@export var items_seed: int = 0
## Tiempo que se muestra el cartel final antes de los resultados.
@export_range(0.0, 10.0, 0.1, "suffix:s") var end_delay: float = 2.0
@export_file("*.tscn") var results_scene: String = "res://scenes/results.tscn"

@export_group("Herramientas")
## Herramientas que pueden aparecer en las listas.
@export var item_pool: Array[ItemData] = []
@export var collectible_scene: PackedScene

@export_group("Trampas")
## Banana o hielo que aparece tirado en el laberinto (se agarra pasando por encima).
@export var trap_pickup_scene: PackedScene
## Cuántas trampas puede haber tiradas al mismo tiempo.
@export_range(0, 30) var max_trap_pickups: int = 4
## Cada cuánto aparece una trampa nueva (si hay menos del máximo).
@export_range(0.5, 120.0, 0.5, "suffix:s") var trap_respawn_time: float = 8.0
## No aparecen más cerca que esto de los jugadores.
@export_range(0.0, 50.0, 0.5, "suffix:u") var trap_min_distance_to_players: float = 8.0

@export_group("Mostrador")
## Dónde va el mostrador en la zona de atención: 0 = pegado al laberinto, 1 = al fondo.
@export_range(0.0, 1.0, 0.05) var counter_depth: float = 0.6
## Altura de la parte de arriba del mostrador (ahí se apoya el tablero).
@export_range(0.0, 3.0, 0.05, "suffix:u") var counter_height: float = 1.06

@export_group("Referencias")
@export var maze: MazeBuilder
@export var board: ToolBoard
## Mostrador de la zona de atención (el tablero va arriba).
@export var counter: Node3D
@export var items_root: Node3D
@export var player1: StorePlayer
@export var player2: StorePlayer
@export var hud: StoreHud

var time_left: float
var _finished: bool = false
var _rng := RandomNumberGenerator.new()
var _trap_timer: float = 0.0


func _ready() -> void:
	if items_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = items_seed

	_place_board_and_players()
	_assign_lists()
	_spawn_items()
	for i in max_trap_pickups:
		_spawn_trap_pickup()
	_trap_timer = trap_respawn_time

	for p in _players():
		p.deliver_requested.connect(_on_deliver_requested)
	time_left = match_duration
	hud.setup(player1, player2)
	hud.set_time(time_left)
	Audio.play_level_music(Audio.music_store)


func _process(delta: float) -> void:
	if _finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	hud.set_time(time_left)
	for p in _players():
		hud.set_hint(p, _get_hint(p))
		hud.set_trap(p, p.get_trap_name())
	_update_trap_pickups(delta)
	if time_left <= 0.0:
		_finish("¡Tiempo!")


func _players() -> Array[StorePlayer]:
	return [player1, player2]


# Mostrador en la zona de atención (al frente del laberinto) con el tablero
# arriba, mirando hacia las góndolas. Los jugadores arrancan entre el
# mostrador y el laberinto, mirando hacia las góndolas.
func _place_board_and_players() -> void:
	var front := maze.get_front_center()
	var depth := maze.front_rows * maze.cell_size
	var counter_position := front + Vector3(0.0, 0.0, (counter_depth - 0.5) * depth)
	counter.global_position = counter_position
	# El frente del tablero es su +Z: se lo gira para que mire al laberinto (-Z)
	board.global_transform = Transform3D(Basis(Vector3.UP, PI), counter_position + Vector3(0.0, counter_height + 1.0, 0.0))
	var start := front - Vector3(0.0, 0.0, depth * 0.25)
	player1.global_position = start + Vector3(-1.5, 0.1, 0.0)
	player2.global_position = start + Vector3(1.5, 0.1, 0.0)
	# Flechas en el piso que llevan hacia el mostrador desde cualquier parte
	maze.build_path_arrows()


func _assign_lists() -> void:
	var pool := item_pool.duplicate()
	_shuffle(pool)
	var count := mini(items_per_player, pool.size())
	player1.remaining.assign(pool.slice(0, count))
	if same_list_for_both:
		player2.remaining.assign(player1.remaining)
	else:
		_shuffle(pool)
		player2.remaining.assign(pool.slice(0, count))


# Una herramienta por cada pedido de cada lista, más las de relleno, cada una
# en una celda distinta del laberinto
func _spawn_items() -> void:
	var to_spawn: Array[ItemData] = []
	to_spawn.append_array(player1.remaining)
	to_spawn.append_array(player2.remaining)
	for i in decoy_items:
		to_spawn.append(item_pool[_rng.randi_range(0, item_pool.size() - 1)])

	var cells := maze.get_free_cells()
	_shuffle(cells)

	for i in to_spawn.size():
		var item := collectible_scene.instantiate() as Collectible
		item.data = to_spawn[i]
		var cell: Vector2i = cells[i % cells.size()]
		var jitter := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * maze.cell_size * 0.2
		item.position = items_root.to_local(maze.get_cell_center(cell) + jitter)
		items_root.add_child(item)


func _on_deliver_requested(player: StorePlayer) -> void:
	if _finished:
		return
	var item := player.carried
	if not board.is_in_range(player):
		player.drop_carried()
		return
	if not player.needs(item.data):
		hud.flash_message(player, "¡No está en tu lista!")
		return

	player.remaining.erase(item.data)
	player.score += points_per_item
	board.hang(player.take_carried())
	Audio.play_sfx(Audio.score_ping)
	hud.mark_delivered(player, item.data)
	if player.remaining.is_empty():
		_finish("¡Jugador %d completó su lista!" % player.player_id)


func _get_hint(player: StorePlayer) -> String:
	if player.carried == null:
		return ""
	if not board.is_in_range(player):
		return "Llevala al mostrador  ·  ✕ soltar"
	if player.needs(player.carried.data):
		return "✕ Colgar en el tablero"
	return "No está en tu lista  ·  alejate y ✕ para soltar"


func _finish(message: String) -> void:
	_finished = true
	MatchResult.save_from(_players())
	MatchResult.last_level_scene = scene_file_path
	hud.show_message(message)
	Audio.stop_music()
	Audio.play_sfx(Audio.time_up)
	get_tree().paused = true
	await get_tree().create_timer(end_delay, true).timeout
	SceneLoader.change_scene(results_scene)


func _shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp


# Repone bananas y hielos tirados en el laberinto, de a uno, hasta el máximo
func _update_trap_pickups(delta: float) -> void:
	_trap_timer -= delta
	if _trap_timer > 0.0:
		return
	_trap_timer = trap_respawn_time
	if get_tree().get_nodes_in_group("trap_pickup").size() < max_trap_pickups:
		_spawn_trap_pickup()


func _spawn_trap_pickup() -> void:
	if trap_pickup_scene == null:
		return
	var cells := maze.get_free_cells()
	for attempt in 15:
		var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		var point := maze.get_cell_center(cell)
		var too_close := false
		for p in _players():
			if p.global_position.distance_to(point) < trap_min_distance_to_players:
				too_close = true
		for node in get_tree().get_nodes_in_group("trap_pickup"):
			if (node as Node3D).global_position.distance_to(point) < maze.cell_size * 0.5:
				too_close = true
		if too_close:
			continue
		var pickup := trap_pickup_scene.instantiate() as TrapPickup
		pickup.kind = StoreTrap.Kind.BANANA if _rng.randf() < 0.5 else StoreTrap.Kind.ICE
		pickup.add_to_group("trap_pickup")
		items_root.add_child(pickup)
		# Corrida a un costado del centro, para no tapar las flechas del piso
		pickup.global_position = point + Vector3(maze.cell_size * 0.25, 0.0, 0.0)
		return
