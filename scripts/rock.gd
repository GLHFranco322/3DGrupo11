class_name Rock
extends Node3D

@export var respawn_time: float = 3.0
@export var throw_speed: float = 14.0
@export var damage: int = 20

var is_held: bool = false
var is_available: bool = true

var _home_parent: Node
var _home_position: Vector3
var _target: Player
var _flying: bool = false


func _ready() -> void:
	_home_parent = get_parent()
	_home_position = global_position


func _physics_process(delta: float) -> void:
	if not _flying or _target == null:
		return

	var to_target := _target.global_position - global_position
	if to_target.length() <= 0.5:
		_on_hit()
		return
	global_position += to_target.normalized() * throw_speed * delta


func pick_up(holder: Player) -> void:
	is_held = true
	is_available = false
	reparent(holder)
	transform = Transform3D(Basis.IDENTITY, holder.rock_hold_offset)


func throw(target: Player) -> void:
	var world_transform := global_transform
	reparent(_home_parent)
	global_transform = world_transform
	is_held = false
	_flying = true
	_target = target


func _on_hit() -> void:
	_flying = false
	if _target:
		_target.get_hit_by_rock(damage)
	_return_home()


func _return_home() -> void:
	visible = false
	await get_tree().create_timer(respawn_time).timeout
	reparent(_home_parent)
	global_position = _home_position
	visible = true
	is_available = true
	_target = null
