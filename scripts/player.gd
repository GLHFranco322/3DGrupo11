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

var has_mower: bool = false

var _mower_home: Node

@onready var body: MeshInstance3D = $Body
@onready var mower_collision: CollisionShape3D = $MowerCollision

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
	if event.is_action_pressed("p%d_toggle_mower" % player_id):
		toggle_mower()


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
	if mower == null:
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
