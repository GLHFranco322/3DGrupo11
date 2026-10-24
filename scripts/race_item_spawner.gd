class_name RaceItemSpawner
extends Node3D

# Hace aparecer items (piedra, pozo, clavos, mate) en lugares al azar sobre la
# pista. Todo el azar de los items se decide acá (en online lo va a decidir
# solo el anfitrión).

@export_group("Items")
@export var pickup_scene: PackedScene
## Peso de cada item: más alto = aparece más seguido. 0 = no aparece.
@export_range(0.0, 10.0, 0.1) var rock_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var pit_weight: float = 2.0
@export_range(0.0, 10.0, 0.1) var nails_weight: float = 2.0
@export_range(0.0, 10.0, 0.1) var turbo_weight: float = 2.5
## Segundos que dura cada item en la pista antes de desaparecer.
@export_range(0.5, 120.0, 0.5, "suffix:s") var item_lifetime: float = 12.0

@export_group("Ritmo")
## Items que ya están en la pista al largar.
@export_range(0, 30) var initial_items: int = 6
## Tiempo mínimo entre items.
@export_range(0.1, 30.0, 0.1, "suffix:s") var spawn_interval_min: float = 0.8
## Tiempo máximo entre items.
@export_range(0.1, 30.0, 0.1, "suffix:s") var spawn_interval_max: float = 2.0
## Máximo de items en la pista al mismo tiempo.
@export_range(1, 50) var max_items: int = 12

@export_group("Zona")
## Recorrido de la pista (el mismo Path3D que usa el nivel).
@export var track: Path3D
## Ancho del camino donde pueden aparecer (desde el centro hacia cada lado).
@export_range(0.0, 20.0, 0.1, "suffix:u") var half_width: float = 3.2
## No aparecen en los primeros metros (la largada).
@export_range(0.0, 100.0, 1.0, "suffix:u") var start_margin: float = 15.0
## No aparecen en los últimos metros (la llegada).
@export_range(0.0, 100.0, 1.0, "suffix:u") var end_margin: float = 10.0
## Aparecen como mucho hasta esta distancia delante del primero.
@export_range(5.0, 300.0, 1.0, "suffix:u") var ahead_of_leader: float = 90.0
## Distancia mínima a los jugadores (para que no aparezca encima de nadie).
@export_range(0.0, 20.0, 0.1, "suffix:u") var min_distance_to_players: float = 6.0
## Distancia mínima entre items.
@export_range(0.0, 20.0, 0.1, "suffix:u") var min_distance_between_items: float = 4.0
## Intentos para encontrar un lugar libre antes de saltear ese item.
@export_range(1, 50) var max_attempts: int = 15

## Lo pone el nivel: false durante la cuenta regresiva y al terminar.
var active: bool = false
## Metros del primero (lo pone el nivel), para que los items aparezcan por delante.
var leader_progress: float = 0.0

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0


func _ready() -> void:
	_rng.randomize()


## Items que ya están en la pista al largar (lo llama el nivel cuando los
## jugadores ya están listos).
func spawn_initial_items() -> void:
	for i in initial_items:
		spawn_random_item(true)


func _process(delta: float) -> void:
	if not active:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _rng.randf_range(spawn_interval_min, maxf(spawn_interval_min, spawn_interval_max))
	if _get_items().size() < max_items:
		spawn_random_item()


## Crea un item al azar. "anywhere" = en cualquier parte de la pista (al largar).
func spawn_random_item(anywhere: bool = false) -> void:
	if pickup_scene == null or track == null:
		return
	var point = _find_free_point(anywhere)
	if point == null:
		return
	var pickup := pickup_scene.instantiate() as RacePickup
	pickup.kind = _random_kind()
	pickup.lifetime = item_lifetime
	pickup.position = to_local(point)
	add_child(pickup)


func _random_kind() -> Racer.Item:
	var weights := {
		Racer.Item.ROCK: rock_weight,
		Racer.Item.PIT: pit_weight,
		Racer.Item.NAILS: nails_weight,
		Racer.Item.TURBO: turbo_weight,
	}
	var total := 0.0
	for kind in weights:
		total += weights[kind]
	var roll := _rng.randf() * total
	for kind in weights:
		roll -= weights[kind]
		if roll <= 0.0:
			return kind
	return Racer.Item.ROCK


func _get_items() -> Array[Node3D]:
	var items: Array[Node3D] = []
	for child in get_children():
		if child is RacePickup:
			items.append(child)
	return items


func _find_free_point(anywhere: bool) -> Variant:
	var curve := track.curve
	var length := curve.get_baked_length()
	var from := start_margin
	var to := length - end_margin
	if not anywhere:
		from = maxf(from, leader_progress + min_distance_to_players)
		to = minf(to, leader_progress + ahead_of_leader)
	if to <= from:
		return null

	for i in max_attempts:
		var offset := _rng.randf_range(from, to)
		var along := track.global_transform * curve.sample_baked_with_rotation(offset)
		var side := along.basis.x
		side.y = 0.0
		var point := along.origin + side.normalized() * _rng.randf_range(-half_width, half_width)
		if _is_free(point):
			return point
	return null


func _is_free(point: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("racer"):
		var racer := node as Racer
		if racer and racer.barrow.global_position.distance_to(point) < min_distance_to_players:
			return false
	for item in _get_items():
		if item.global_position.distance_to(point) < min_distance_between_items:
			return false
	return true
