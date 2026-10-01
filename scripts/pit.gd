class_name Pit
extends Node3D

enum State { SPAWNING, LANDED, HELD, PLACED, TRIGGERED }

@export var descent_speed: float = 2.0
@export var start_height: float = 6.0
@export var respawn_time: float = 5.0

@onready var bubble: MeshInstance3D = $Bubble
@onready var trap_visual: MeshInstance3D = $TrapVisual
@onready var pickup_area: Area3D = $PickupArea
@onready var trap_area: Area3D = $TrapArea

var state: int = State.SPAWNING
var holder: Player = null
var placed_by: Player = null

var _home_parent: Node
var _home_position: Vector3


func _ready() -> void:
	_home_parent = get_parent()
	_home_position = global_position
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	trap_area.body_entered.connect(_on_trap_area_body_entered)
	_enter_spawning()


func _process(delta: float) -> void:
	if state != State.SPAWNING:
		return
	global_position.y -= descent_speed * delta
	if global_position.y <= _home_position.y:
		global_position.y = _home_position.y
		_enter_landed()


func pick_up(player: Player) -> void:
	if state != State.LANDED:
		return
	state = State.HELD
	holder = player
	pickup_area.monitoring = false
	reparent(player)
	transform = Transform3D(Basis.IDENTITY, player.pit_hold_offset)


func place_at(world_position: Vector3) -> void:
	if state != State.HELD:
		return
	placed_by = holder
	holder = null
	reparent(_home_parent)
	global_position = world_position
	global_position.y = _home_position.y

	bubble.visible = false
	trap_visual.visible = true
	trap_area.monitoring = true
	state = State.PLACED


func drop() -> void:
	if state != State.HELD:
		return
	reparent(_home_parent)
	holder = null
	_enter_spawning()


func _enter_spawning() -> void:
	state = State.SPAWNING
	global_position = _home_position + Vector3(0.0, start_height, 0.0)
	bubble.visible = true
	trap_visual.visible = false
	pickup_area.monitoring = false
	trap_area.monitoring = false


func _enter_landed() -> void:
	state = State.LANDED
	pickup_area.monitoring = true


func _on_pickup_area_body_entered(body: Node) -> void:
	if state != State.LANDED:
		return
	if body is Player and not body.is_hands_full():
		pick_up(body)


func _on_trap_area_body_entered(body: Node) -> void:
	if state != State.PLACED:
		return
	if body == placed_by:
		return
	if body is Player:
		body.fall_into_pit()
		_trigger()


func _trigger() -> void:
	state = State.TRIGGERED
	trap_area.monitoring = false
	visible = false
	await get_tree().create_timer(respawn_time).timeout
	visible = true
	placed_by = null
	_enter_spawning()
