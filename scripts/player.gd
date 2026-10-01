class_name Player
extends CharacterBody3D

@export var player_id: int = 1
@export var color: Color = Color.WHITE
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var mower_speed: float = 2.0
@export var acceleration: float = 30.0
@export var friction: float = 25.0
@export var turn_speed: float = 12.0

@export_group("Cortadora")
@export var mower: Mower
@export var mower_hold_offset: Vector3 = Vector3(0.0, 0.0, -1.4)
@export var mower_pickup_distance: float = 2.0

@export_group("Piedra")
@export var rock_pickup_distance: float = 2.0
@export var rock_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)

@export_group("Pozo")
@export var pit_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)
@export var reticle: Node3D
@export var aim_range: float = 5.0

signal score_changed(new_score: int)

var score: int = 0
var has_mower: bool = false
var held_rock: Rock = null
var held_pit: Pit = null
var is_aiming: bool = false
var spawn_position: Vector3

var _mower_home: Node

@onready var body: MeshInstance3D = $Body
@onready var mower_collision: CollisionShape3D = $MowerCollision
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	spawn_position = global_position

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat

	if mower:
		_mower_home = mower.get_parent()
	else:
		push_warning("Player %d no tiene cortadora asignada" % player_id)


func _unhandled_input(event: InputEvent) -> void:
	if state_machine.is_current("stunned") or state_machine.is_current("falling"):
		return

	if event.is_action_pressed("p%d_toggle_mower" % player_id):
		toggle_mower()
	elif event.is_action_pressed("p%d_grab" % player_id):
		try_grab_rock()
	elif event.is_action_pressed("p%d_place" % player_id):
		confirm_aim()


func _physics_process(_delta: float) -> void:
	_update_aiming()


func apply_movement(input: Vector2, speed: float, delta: float) -> void:
	var direction := Vector3(input.x, 0.0, input.y)
	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	var target_angle := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)


func apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, friction * delta)


func get_walk_speed() -> float:
	return mower_speed if has_mower else walk_speed


func is_hands_full() -> bool:
	return has_mower or held_rock != null or held_pit != null


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func toggle_mower() -> void:
	if mower == null or held_rock != null or held_pit != null:
		return
	if has_mower:
		drop_mower()
	elif global_position.distance_to(mower.global_position) <= mower_pickup_distance:
		grab_mower()


func grab_mower() -> void:
	has_mower = true
	mower.is_held = true
	add_collision_exception_with(mower)
	mower.reparent(self)
	mower.transform = Transform3D(Basis.IDENTITY, mower_hold_offset)

	mower_collision.shape = mower.collision_shape.shape
	mower_collision.position = mower_hold_offset + mower.collision_shape.position
	mower_collision.set_deferred("disabled", false)


func drop_mower() -> void:
	has_mower = false
	mower.is_held = false
	mower.reparent(_mower_home)
	remove_collision_exception_with(mower)
	mower_collision.set_deferred("disabled", true)


func try_grab_rock() -> void:
	if is_hands_full():
		return

	var nearest: Rock = null
	var nearest_dist := INF
	for rock in get_tree().get_nodes_in_group("rock"):
		if not rock.is_available:
			continue
		var dist := global_position.distance_to(rock.global_position)
		if dist <= rock_pickup_distance and dist < nearest_dist:
			nearest = rock
			nearest_dist = dist

	if nearest:
		held_rock = nearest
		nearest.pick_up(self)


func confirm_aim() -> void:
	if not is_aiming or reticle == null:
		return

	if held_rock:
		held_rock.throw(reticle.global_position)
		held_rock = null
	elif held_pit:
		held_pit.place_at(reticle.global_position)
		held_pit = null

	is_aiming = false
	reticle.visible = false


func get_hit_by_rock(damage: int) -> void:
	if has_mower:
		drop_mower()
	if mower:
		mower.take_damage(damage)
	state_machine.force_state("stunned")


func fall_into_pit() -> void:
	if has_mower:
		remove_collision_exception_with(mower)
		mower_collision.set_deferred("disabled", true)
		mower.send_home()
		has_mower = false
	if held_rock:
		held_rock.drop()
		held_rock = null
	if held_pit:
		held_pit.drop()
		held_pit = null
	state_machine.force_state("falling")


func _update_aiming() -> void:
	if reticle == null:
		return

	var holding_something := held_rock != null or held_pit != null
	if state_machine.is_current("stunned") or state_machine.is_current("falling") or not holding_something:
		is_aiming = false
		reticle.visible = false
		return

	is_aiming = Input.is_action_pressed("p%d_aim" % player_id)
	reticle.visible = is_aiming
	if not is_aiming:
		return

	var prefix := "p%d_" % player_id
	var aim_input := Input.get_vector(prefix + "aim_left", prefix + "aim_right", prefix + "aim_up", prefix + "aim_down")
	var offset := Vector3(aim_input.x, 0.0, aim_input.y) * aim_range
	reticle.global_position = global_position + offset


func _get_rival() -> Player:
	var rival_id := 2 if player_id == 1 else 1
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.player_id == rival_id:
			return p
	return null
