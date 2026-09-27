class_name Player
extends CharacterBody3D

signal score_changed(new_score: int)

@export_group("Piedra")

@export var player_id: int = 1
@export var color: Color = Color.WHITE
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var mower_speed: float = 2.0
@export var acceleration: float = 30.0
@export var friction: float = 25.0
@export var turn_speed: float = 12.0
@export var rock_pickup_distance: float = 2.0
@export var rock_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)

@export_group("Cortadora")
@export var mower: Mower
@export var mower_hold_offset: Vector3 = Vector3(0.0, 0.0, -1.4)
@export var mower_pickup_distance: float = 2.0

var has_mower: bool = false
var _mower_home: Node
var score: int = 0
var held_rock: Rock = null

@onready var body: MeshInstance3D = $Body
@onready var mower_collision: CollisionShape3D = $MowerCollision
@onready var state_machine: StateMachine = $StateMachine

func _ready() -> void:
	# Material propio por instancia para que cada jugador tenga su color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat

	if mower:
		_mower_home = mower.get_parent()
	else:
		push_warning("Player %d no tiene cortadora asignada" % player_id)

func _unhandled_input(event: InputEvent) -> void:
	if state_machine.is_current("stunned"):
		return

	if event.is_action_pressed("p%d_toggle_mower" % player_id):
		toggle_mower()
	elif event.is_action_pressed("p%d_grab" % player_id):
		try_grab_rock()
	elif event.is_action_pressed("p%d_throw" % player_id):
		throw_rock()

func apply_movement(input: Vector2, speed: float, delta: float) -> void:
	var direction := Vector3(input.x, 0.0, input.y)
	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	var target_angle := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

func apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, friction * delta)

func get_walk_speed() -> float:
	return mower_speed if has_mower else walk_speed

func toggle_mower() -> void:
	if mower == null or held_rock != null:
		return
	if has_mower:
		drop_mower()
	elif global_position.distance_to(mower.global_position) <= mower_pickup_distance:
		grab_mower()

func grab_mower() -> void:
	has_mower = true
	mower.is_held = true
	add_collision_exception_with(mower)  # no chocar con su propia cortadora
	mower.reparent(self)
	mower.transform = Transform3D(Basis.IDENTITY, mower_hold_offset)

	# Copia de la forma de la cortadora para que las paredes frenen al jugador
	mower_collision.shape = mower.collision_shape.shape
	mower_collision.position = mower_hold_offset + mower.collision_shape.position
	mower_collision.set_deferred("disabled", false)

func drop_mower() -> void:
	has_mower = false
	mower.is_held = false
	mower.reparent(_mower_home)  # queda donde está, con la orientación actual
	remove_collision_exception_with(mower)
	mower_collision.set_deferred("disabled", true)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func try_grab_rock() -> void:
	if has_mower or held_rock != null:
		return

	var nearest: Rock = null
	var nearest_dist := INF
	for rock in get_tree().get_nodes_in_group("rock"):   # antes: "rocks"
		if not rock.is_available:
			continue
		var dist := global_position.distance_to(rock.global_position)
		if dist <= rock_pickup_distance and dist < nearest_dist:
			nearest = rock
			nearest_dist = dist

	if nearest:
		held_rock = nearest
		nearest.pick_up(self)

func throw_rock() -> void:
	if held_rock == null:
		return
	var rival := _get_rival()
	if rival == null:
		return
	held_rock.throw(rival)
	held_rock = null

func get_hit_by_rock(damage: int) -> void:
	if has_mower:
		drop_mower()
	if mower:
		mower.take_damage(damage)
	state_machine.force_state("stunned")

func _get_rival() -> Player:
	var rival_id := 2 if player_id == 1 else 1
	for p in get_tree().get_nodes_in_group("player"):   # antes: "players"
		if p is Player and p.player_id == rival_id:
			return p
	return null
