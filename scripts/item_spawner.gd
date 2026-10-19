class_name ItemSpawner
extends Node3D

# Hace aparecer piedras y pozos en lugares al azar de la cancha. Todo el azar
# de los items se decide acá (en online lo va a decidir solo el anfitrión).

@export_group("Items")
@export var rock_scene: PackedScene
@export var pit_scene: PackedScene
## Probabilidad de que aparezca una piedra (el resto, un pozo). 0.6 = 60% piedras.
@export_range(0.0, 1.0, 0.05) var rock_chance: float = 0.6
## Segundos que dura cada item en el piso antes de desaparecer.
@export_range(0.5, 60.0, 0.5, "suffix:s") var item_lifetime: float = 5.0

@export_group("Ritmo")
## Espera antes del primer item.
@export_range(0.0, 30.0, 0.5, "suffix:s") var first_spawn_delay: float = 1.5
## Tiempo mínimo entre items.
@export_range(0.1, 30.0, 0.1, "suffix:s") var spawn_interval_min: float = 2.0
## Tiempo máximo entre items.
@export_range(0.1, 30.0, 0.1, "suffix:s") var spawn_interval_max: float = 4.0
## Máximo de items en el piso al mismo tiempo.
@export_range(1, 30) var max_items: int = 4

@export_group("Zona")
## Centro de la zona donde aparecen los items.
@export var area_center: Vector3 = Vector3(-0.75, 0.0, -1.15)
## Tamaño de la zona (X, Z). Conviene que sea un poco menor que la cancha.
@export var area_size: Vector2 = Vector2(24.0, 17.0)
## Distancia mínima a los jugadores (para que no aparezca encima de nadie).
@export_range(0.0, 10.0, 0.1, "suffix:u") var min_distance_to_players: float = 2.0
## Distancia mínima entre items.
@export_range(0.0, 10.0, 0.1, "suffix:u") var min_distance_between_items: float = 2.5
## Espacio libre que necesita alrededor (no aparece dentro de mesas, cajas, etc.).
@export_range(0.1, 3.0, 0.05, "suffix:u") var clearance_radius: float = 0.7
## Intentos para encontrar un lugar libre antes de saltear ese item.
@export_range(1, 50) var max_attempts: int = 15

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _clearance_shape := SphereShape3D.new()


func _ready() -> void:
	_rng.randomize()
	_timer = first_spawn_delay


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _rng.randf_range(spawn_interval_min, maxf(spawn_interval_min, spawn_interval_max))
	if _get_items().size() < max_items:
		spawn_random_item()


func spawn_random_item() -> void:
	var scene := rock_scene if _rng.randf() < rock_chance else pit_scene
	if scene == null:
		return
	var point = _find_free_point()
	if point == null:
		return
	spawn_item(scene, point)


func spawn_item(scene: PackedScene, world_position: Vector3) -> Node3D:
	var item := scene.instantiate() as Node3D
	item.set("lifetime", item_lifetime)
	# La posición va antes de add_child: el pozo la toma en su _ready
	item.position = to_local(world_position)
	add_child(item)
	return item


# Items que están en el piso (los que alguien tiene en la mano no son hijos del spawner)
func _get_items() -> Array[Node3D]:
	var items: Array[Node3D] = []
	for child in get_children():
		if child is Rock or child is Pit:
			items.append(child)
	return items


func _find_free_point() -> Variant:
	for i in max_attempts:
		var point := area_center + Vector3(
				_rng.randf_range(-area_size.x, area_size.x) * 0.5,
				0.0,
				_rng.randf_range(-area_size.y, area_size.y) * 0.5)
		if _is_free(point):
			return point
	return null


func _is_free(point: Vector3) -> bool:
	for player in get_tree().get_nodes_in_group("player"):
		if _flat_distance(point, player.global_position) < min_distance_to_players:
			return false
	for item in _get_items():
		if _flat_distance(point, item.global_position) < min_distance_between_items:
			return false

	# Nada sólido alrededor (cerca, mesa, cajas, cortadoras...)
	_clearance_shape.radius = clearance_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance_shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0.0, clearance_radius + 0.1, 0.0))
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
