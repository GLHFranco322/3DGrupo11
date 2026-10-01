class_name CameraRig
extends Camera3D

@export var player1: Player
@export var player2: Player

@export var min_player_distance: float = 2.0
@export var max_player_distance: float = 20.0
@export var min_camera_distance: float = 14.0
@export var max_camera_distance: float = 30.0
@export var follow_speed: float = 4.0

var _tilt: float
var _current_distance: float
var _current_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	_tilt = -rotation.x
	_current_distance = max_camera_distance


func _process(delta: float) -> void:
	if player1 == null or player2 == null:
		return

	var p1 := player1.global_position
	var p2 := player2.global_position

	var midpoint := (p1 + p2) * 0.5
	midpoint.y = 0.0

	var spread := Vector2(p1.x, p1.z).distance_to(Vector2(p2.x, p2.z))
	var t: float = min(max(inverse_lerp(min_player_distance, max_player_distance, spread), 0.0), 1.0)
	var target_distance: float = lerp(min_camera_distance, max_camera_distance, t)

	_current_distance = lerp(_current_distance, target_distance, follow_speed * delta)
	_current_target = _current_target.lerp(midpoint, follow_speed * delta)

	var offset := Vector3(0.0, sin(_tilt), cos(_tilt)) * _current_distance
	global_position = _current_target + offset
