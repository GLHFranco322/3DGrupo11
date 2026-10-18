class_name Rock
extends Node3D

## Tiempo hasta que la piedra vuelve a su lugar después de lanzarse.
@export_range(0.0, 60.0, 0.5, "suffix:s") var respawn_time: float = 3.0
## Velocidad de la piedra en el aire.
@export_range(1.0, 60.0, 0.5, "suffix:u/s") var throw_speed: float = 14.0
## Daño que le hace a la cortadora del rival.
@export_range(0, 100) var damage: int = 20
## Si no choca con nada, desaparece después de recorrer esta distancia.
@export_range(1.0, 200.0, 1.0, "suffix:u") var max_distance: float = 40.0

var is_held: bool = false
var is_available: bool = true

var _home_parent: Node
var _home_position: Vector3
var _direction: Vector3
var _traveled: float = 0.0
var _flying: bool = false
var _thrower: Player = null
var _exclude: Array[RID] = []


func _ready() -> void:
	_home_parent = get_parent()
	_home_position = global_position


func _physics_process(delta: float) -> void:
	if not _flying:
		return

	var from := global_position
	var to := from + _direction * throw_speed * delta

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		global_position = hit.position
		_on_hit(hit.collider)
		return

	global_position = to
	_traveled += throw_speed * delta
	if _traveled >= max_distance:
		_on_hit(null)


func pick_up(holder: Player) -> void:
	is_held = true
	is_available = false
	Audio.play_sfx(Audio.rock_grab)
	reparent(holder)
	global_transform = holder.hold_transform(holder.rock_hold_offset)


# Lanza la piedra en línea recta en "direction" (se ignora el componente Y)
func throw(direction: Vector3, thrower: Player) -> void:
	var world_transform := global_transform
	reparent(_home_parent)
	global_transform = world_transform
	is_held = false
	_flying = true
	_traveled = 0.0
	Audio.play_sfx(Audio.rock_throw)
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_thrower = thrower

	# La piedra no choca contra quien la tiró ni contra la cortadora que lleva
	_exclude = [thrower.get_rid()]
	if thrower.has_mower and thrower.mower:
		_exclude.append(thrower.mower.get_rid())


func drop() -> void:
	if not is_held:
		return
	reparent(_home_parent)
	global_position = _home_position
	is_held = false
	is_available = true
	visible = true


func _on_hit(collider: Object) -> void:
	_flying = false

	# Si pega en una cortadora que alguien lleva, cuenta como golpe a ese jugador
	var target := collider
	if target is Mower and target.get_parent() is Player:
		target = target.get_parent()
	if target is Player and target != _thrower:
		Audio.play_sfx(Audio.rock_hit_player)
		target.get_hit_by_rock(damage)
	elif collider != null:
		Audio.play_sfx(Audio.rock_hit_wall)

	_return_home()


func _return_home() -> void:
	_thrower = null
	_exclude.clear()
	visible = false
	await get_tree().create_timer(respawn_time).timeout
	reparent(_home_parent)
	global_position = _home_position
	visible = true
	is_available = true
