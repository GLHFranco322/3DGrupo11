class_name CameraRig
extends Camera3D

enum Mode {
	## Cámara fija que encuadra toda la cancha.
	FIT_ARENA,
	## Sigue a los jugadores con zoom según la distancia entre ellos.
	FOLLOW_PLAYERS,
}

@export var mode: Mode = Mode.FIT_ARENA

@export_group("Referencias")
@export var player1: Player
@export var player2: Player

@export_group("Cancha")
## Centro de la cancha (dentro de la cerca).
@export var arena_center: Vector3 = Vector3(-0.75, 0.0, -1.15)
## Tamaño de la cancha (X, Z) que tiene que entrar en pantalla.
@export var arena_size: Vector2 = Vector2(27.5, 20.5)
## Altura de la cerca, para que también entre entera en pantalla.
@export_range(0.0, 5.0, 0.1, "suffix:u") var fence_height: float = 1.2
## Espacio libre alrededor de la cancha, como fracción de la pantalla.
## Más alto = se ve más del entorno.
@export_range(0.0, 0.4, 0.01) var screen_margin: float = 0.04

@export_group("Seguir jugadores")
## Cuánto se queda la cámara en el centro de la cancha en vez de seguir a los
## jugadores. 0 = sigue solo a los jugadores, 1 = queda fija en el centro.
@export_range(0.0, 1.0, 0.05) var center_weight: float = 0.4
## Con los jugadores a esta distancia o menos, la cámara está en su zoom máximo.
@export_range(0.0, 50.0, 0.5, "suffix:u") var min_player_distance: float = 4.0
## Con los jugadores a esta distancia o más, la cámara está en su zoom mínimo.
@export_range(0.0, 100.0, 0.5, "suffix:u") var max_player_distance: float = 24.0
## Zoom máximo: distancia mínima respecto a la que encuadra toda la cancha
## (1 = igual, 0.6 = 40% más cerca).
@export_range(0.2, 1.0, 0.05) var min_zoom_factor: float = 0.65
## Qué tan rápido sigue a los jugadores. Más bajo = más suave.
@export_range(0.1, 20.0, 0.1) var follow_speed: float = 4.0

var _tilt: float
var _fit_target: Vector3
var _fit_distance: float
var _current_distance: float
var _current_target: Vector3


func _ready() -> void:
	_tilt = -rotation.x
	get_viewport().size_changed.connect(_fit_arena)
	_fit_arena()
	_current_target = _fit_target
	_current_distance = _fit_distance
	_apply(_current_target, _current_distance)


func _process(delta: float) -> void:
	if mode == Mode.FIT_ARENA or player1 == null or player2 == null:
		_apply(_fit_target, _fit_distance)
		return

	var weight := minf(follow_speed * delta, 1.0)
	_current_distance = lerpf(_current_distance, _get_follow_distance(), weight)
	_current_target = _current_target.lerp(_get_follow_target(), weight)
	_apply(_current_target, _current_distance)


func _apply(target: Vector3, distance: float) -> void:
	global_position = target + Vector3(0.0, sin(_tilt), cos(_tilt)) * distance


# Busca el punto y la distancia con los que toda la cancha entra en pantalla
# y queda centrada verticalmente (con la cámara inclinada lo cercano ocupa más).
func _fit_arena() -> void:
	var screen := get_viewport().get_visible_rect().size
	var half := Vector3(arena_size.x * 0.5, 0.0, arena_size.y * 0.5)
	var target := arena_center
	var distance := 1.0

	for i in 6:
		distance = _min_fit_distance(target, half, screen)
		_apply(target, distance)
		var back_y := unproject_position(arena_center + Vector3(0.0, fence_height, -half.z)).y
		var front_y := unproject_position(arena_center + Vector3(0.0, 0.0, half.z)).y
		var error := (back_y + front_y) * 0.5 - screen.y * 0.5
		target.z += error / screen.y * arena_size.y

	_fit_target = target
	_fit_distance = _min_fit_distance(target, half, screen)


func _min_fit_distance(target: Vector3, half: Vector3, screen: Vector2) -> float:
	var margin := screen * screen_margin
	var rect := Rect2(margin, screen - margin * 2.0)
	var distance := 2.0
	while distance < 200.0:
		_apply(target, distance)
		if _arena_fits(half, rect):
			return distance
		distance += 0.1
	return distance


func _arena_fits(half: Vector3, rect: Rect2) -> bool:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [0.0, fence_height]:
				var corner := arena_center + Vector3(half.x * sx, y, half.z * sz)
				if is_position_behind(corner) or not rect.has_point(unproject_position(corner)):
					return false
	return true


func _get_follow_target() -> Vector3:
	var midpoint := (player1.global_position + player2.global_position) * 0.5
	midpoint.y = 0.0
	var offset := midpoint - arena_center
	return _fit_target + offset * (1.0 - center_weight)


func _get_follow_distance() -> float:
	var p1 := player1.global_position
	var p2 := player2.global_position
	var spread := Vector2(p1.x, p1.z).distance_to(Vector2(p2.x, p2.z))
	var t := clampf(inverse_lerp(min_player_distance, max_player_distance, spread), 0.0, 1.0)
	return lerpf(_fit_distance * min_zoom_factor, _fit_distance, t)
