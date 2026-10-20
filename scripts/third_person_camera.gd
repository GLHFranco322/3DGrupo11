class_name ThirdPersonCamera
extends Node3D

# Cámara en tercera persona que sigue a un jugador. El analógico derecho de ese
# jugador la gira. Usa un SpringArm3D para no atravesar las paredes.

## Jugador al que sigue.
@export var target: StorePlayer
## Distancia de la cámara al jugador.
@export_range(1.0, 20.0, 0.1, "suffix:u") var distance: float = 4.5
## Altura del punto al que mira (sobre los pies del jugador).
@export_range(0.0, 5.0, 0.1, "suffix:u") var look_height: float = 1.4
## Inclinación inicial (negativo = mira hacia abajo).
@export_range(-80.0, 30.0, 1.0, "suffix:°") var pitch_degrees: float = -22.0
## Límites de inclinación al moverla con el analógico.
@export var pitch_limits: Vector2 = Vector2(-60.0, 5.0)
## Velocidad de giro con el analógico.
@export_range(0.1, 10.0, 0.1) var turn_speed: float = 2.8
## Invierte el eje vertical del analógico.
@export var invert_y: bool = false
## Qué tan rápido sigue al jugador. Más bajo = más suave.
@export_range(1.0, 40.0, 0.5) var follow_speed: float = 15.0

## Giro horizontal actual (lo usa el jugador para saber hacia dónde es "adelante").
var yaw: float = 0.0

@onready var pitch_pivot: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D


func _ready() -> void:
	top_level = true
	spring_arm.spring_length = distance
	pitch_pivot.rotation.x = deg_to_rad(pitch_degrees)
	if target:
		spring_arm.add_excluded_object(target.get_rid())
		yaw = target.rotation.y
		global_position = target.global_position + Vector3.UP * look_height


func _process(delta: float) -> void:
	if target == null:
		return
	var prefix := "p%d_" % target.player_id
	var look := Input.get_vector(prefix + "aim_left", prefix + "aim_right", prefix + "aim_up", prefix + "aim_down")
	yaw -= look.x * turn_speed * delta
	var pitch_input := -look.y if invert_y else look.y
	pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - pitch_input * turn_speed * delta,
			deg_to_rad(pitch_limits.x), deg_to_rad(pitch_limits.y))
	rotation = Vector3(0.0, yaw, 0.0)

	var goal := target.global_position + Vector3.UP * look_height
	global_position = global_position.lerp(goal, minf(follow_speed * delta, 1.0))
