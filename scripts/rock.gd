class_name Rock
extends Node3D

@export var respawn_time: float = 3.0
@export var throw_speed: float = 14.0
@export var damage: int = 20
@export var hit_radius: float = 1.0

var is_held: bool = false
var is_available: bool = true

var _home_parent: Node
var _home_position: Vector3
var _target_position: Vector3
var _flying: bool = false
var _thrower: Player = null


func _ready() -> void:
	_home_parent = get_parent()
	_home_position = global_position


func _physics_process(delta: float) -> void:
	if not _flying:
		return

	var to_target := _target_position - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.5:
		_on_hit()
		return
	global_position += to_target.normalized() * throw_speed * delta


func pick_up(holder: Player) -> void:
	is_held = true
	is_available = false
	reparent(holder)
	transform = Transform3D(Basis.IDENTITY, holder.rock_hold_offset)


func throw(target_position: Vector3, thrower: Player) -> void:
	var world_transform := global_transform
	reparent(_home_parent)
	global_transform = world_transform
	is_held = false
	_flying = true
	_target_position = target_position
	_thrower = thrower


func drop() -> void:
	if not is_held:
		return
	reparent(_home_parent)
	global_position = _home_position
	is_held = false
	is_available = true
	visible = true


func _on_hit() -> void:
	_flying = false
	for p in get_tree().get_nodes_in_group("player"):
		if p == _thrower or not p is Player:
			continue
		var flat := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
		if flat.length() <= hit_radius:
			p.get_hit_by_rock(damage)
			break
	_return_home()


func _return_home() -> void:
	_thrower = null
	visible = false
	await get_tree().create_timer(respawn_time).timeout
	reparent(_home_parent)
	global_position = _home_position
	visible = true
	is_available = true
