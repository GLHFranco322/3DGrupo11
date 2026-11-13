class_name ThirdPersonCamera
extends Node3D

# Cámara en tercera persona que sigue a un jugador. El analógico derecho de ese
# jugador la gira. Usa un SpringArm3D para no atravesar las paredes.
# El objetivo puede tener (opcional): get_camera_focus() -> Vector3,
# get_heading() -> float y get_camera_exclusions() -> Array[RID].

## Jugador al que sigue (necesita la propiedad "player_id").
@export var target: Node3D
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
## Sensibilidad del mouse (jugador de teclado y mouse, activado en Opciones).
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.004

@export_group("Acomodarse detrás")
## Qué tan rápido gira sola para quedar detrás de hacia dónde mira el
## jugador (carreras). 0 = nunca, solo se gira con el analógico.
@export_range(0.0, 10.0, 0.1) var auto_follow_speed: float = 0.0
## Segundos sin tocar el analógico derecho antes de acomodarse sola.
@export_range(0.0, 5.0, 0.1, "suffix:s") var auto_follow_delay: float = 0.8

## Giro horizontal actual (lo usa el jugador para saber hacia dónde es "adelante").
var yaw: float = 0.0

@export_group("Efecto de turbo")
## Grados que se abre la cámara con el turbo (play_boost).
@export_range(0.0, 60.0, 1.0, "suffix:°") var boost_fov_kick: float = 24.0
## Cuánto se aleja la cámara con el turbo.
@export_range(0.0, 5.0, 0.1, "suffix:u") var boost_distance_kick: float = 1.2
## Cuánto tiembla la cámara con el turbo.
@export_range(0.0, 0.5, 0.01, "suffix:u") var boost_shake: float = 0.08
## Segundos que tarda en llegar al efecto entero.
@export_range(0.01, 1.0, 0.01, "suffix:s") var boost_attack: float = 0.12
## Segundos que tarda en volver a la normal cuando termina el turbo.
@export_range(0.05, 3.0, 0.05, "suffix:s") var boost_release: float = 0.9
## Líneas de velocidad en la pantalla durante el turbo.
@export var boost_speed_lines: bool = true

var _idle_time: float = 0.0
# Efecto de turbo: 0 = nada, 1 = a pleno; se mantiene "_boost_hold" segundos
var _boost: float = 0.0
var _boost_hold: float = 0.0
var _base_fov: float = 70.0
var _speed_lines: ColorRect

@onready var pitch_pivot: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	_base_fov = camera.fov
	spring_arm.spring_length = distance
	pitch_pivot.rotation.x = deg_to_rad(pitch_degrees)
	if target:
		if target.has_method("get_camera_exclusions"):
			for rid in target.get_camera_exclusions():
				spring_arm.add_excluded_object(rid)
		elif target is CollisionObject3D:
			spring_arm.add_excluded_object(target.get_rid())
		yaw = _get_heading()
		global_position = _get_focus() + Vector3.UP * look_height
	if _uses_mouse():
		# El cursor se esconde y queda atrapado en la ventana mientras dure el nivel
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Controls.take_mouse_motion()


func _exit_tree() -> void:
	if _uses_mouse():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# El jugador al que sigue es el de teclado y mouse
func _uses_mouse() -> bool:
	return target != null and Controls.keyboard_player != 0 and target.player_id == Controls.keyboard_player


func _process(delta: float) -> void:
	if target == null:
		return
	var prefix := "p%d_" % target.player_id
	var look := Input.get_vector(prefix + "aim_left", prefix + "aim_right", prefix + "aim_up", prefix + "aim_down")
	if _uses_mouse():
		# El mouse se suma al analógico (convertido a "velocidad de palanca")
		look += Controls.take_mouse_motion() * mouse_sensitivity / maxf(turn_speed * delta, 0.0001)
	yaw -= look.x * turn_speed * delta
	var pitch_input := -look.y if invert_y else look.y
	pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - pitch_input * turn_speed * delta,
			deg_to_rad(pitch_limits.x), deg_to_rad(pitch_limits.y))

	# Sin tocar el analógico un rato, vuelve sola detrás del jugador
	_idle_time = 0.0 if look.length() > 0.1 else _idle_time + delta
	if auto_follow_speed > 0.0 and _idle_time >= auto_follow_delay:
		yaw = lerp_angle(yaw, _get_heading(), minf(auto_follow_speed * delta, 1.0))
	rotation = Vector3(0.0, yaw, 0.0)

	var goal := _get_focus() + Vector3.UP * look_height
	global_position = global_position.lerp(goal, minf(follow_speed * delta, 1.0))
	_update_boost(delta)


## Efecto de turbo (como en los juegos de carreras): la cámara se abre, se
## aleja, tiembla un poco y aparecen líneas de velocidad. Dura "time" segundos
## a pleno y después vuelve de a poco.
func play_boost(time: float) -> void:
	_boost_hold = maxf(_boost_hold, time)
	if boost_speed_lines and _speed_lines == null:
		_build_speed_lines()


func _update_boost(delta: float) -> void:
	if _boost_hold > 0.0:
		_boost_hold -= delta
		_boost = move_toward(_boost, 1.0, delta / boost_attack)
	elif _boost > 0.0:
		_boost = move_toward(_boost, 0.0, delta / boost_release)
	else:
		return
	# Sube rápido y baja suave
	var amount := ease(_boost, 0.6)
	camera.fov = _base_fov + boost_fov_kick * amount
	spring_arm.spring_length = distance + boost_distance_kick * amount
	camera.h_offset = randf_range(-1.0, 1.0) * boost_shake * amount
	camera.v_offset = randf_range(-1.0, 1.0) * boost_shake * amount
	if _speed_lines:
		var size := get_viewport().get_visible_rect().size
		var material := _speed_lines.material as ShaderMaterial
		material.set_shader_parameter("intensity", amount)
		material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


# Las líneas van en una capa propia dentro del viewport de esta cámara (en
# pantalla dividida, solo en la mitad de este jugador)
func _build_speed_lines() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_speed_lines = ColorRect.new()
	_speed_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://niveles/comun/lineas_velocidad.gdshader")
	_speed_lines.material = material
	layer.add_child(_speed_lines)


func _get_focus() -> Vector3:
	return target.get_camera_focus() if target.has_method("get_camera_focus") else target.global_position


func _get_heading() -> float:
	return target.get_heading() if target.has_method("get_heading") else target.rotation.y
