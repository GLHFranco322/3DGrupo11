extends State

# El jugador fue pateado con la bota: sale volando en arco fuera de la cancha
# (y de la cámara), desaparece y, al cumplirse "Total Time", reaparece en su
# lugar de inicio titilando e invencible un rato.

## Tiempo total afuera sin poder jugar (vuelo + escondido).
@export_range(0.5, 15.0, 0.1, "suffix:s") var total_time: float = 2.5
## Tiempo volando hasta salir de la cancha.
@export_range(0.1, 5.0, 0.05, "suffix:s") var flight_time: float = 0.9
## Distancia horizontal que vuela.
@export_range(1.0, 100.0, 1.0, "suffix:u") var flight_distance: float = 28.0
## Altura máxima del vuelo.
@export_range(0.0, 50.0, 0.5, "suffix:u") var flight_height: float = 9.0
## Vueltas que da en el aire.
@export_range(0.0, 10.0, 0.5) var spins: float = 2.5
## Al reaparecer queda invencible (titilando) estos segundos: no le pegan
## piedras, no cae en pozos y no lo pueden patear.
@export_range(0.0, 10.0, 0.1, "suffix:s") var invincible_time: float = 1.5

var _elapsed: float = 0.0
var _start: Vector3
var _end: Vector3
var _start_yaw: float

@onready var _collision: CollisionShape3D = $"../../CollisionShape3D"


func enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	_start = player.global_position
	var direction := player.kick_direction
	_end = _start + Vector3(direction.x, 0.0, direction.z).normalized() * flight_distance
	_start_yaw = player.rotation.y
	player.anim.speed_scale = 1.0
	if player.anim.has_animation(Player.ANIM_FALL):
		player.play_anim(Player.ANIM_FALL, true)
	else:
		player.play_anim(Player.ANIM_STUNNED, true)
	Audio.play_sfx(Audio.kicked_scream)


func exit() -> void:
	player.visible = true
	player.rotation.y = _start_yaw
	_collision.set_deferred("disabled", false)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.velocity = Vector3.ZERO

	# 1) Vuela en arco hacia afuera girando
	if _elapsed < flight_time:
		var t := _elapsed / flight_time
		var position := _start.lerp(_end, t)
		position.y = _start.y + 4.0 * flight_height * t * (1.0 - t) + t * flight_height * 0.5
		player.global_position = position
		player.rotation.y = _start_yaw + t * spins * TAU
		return

	# 2) Fuera del mapa: desaparece (se lo deja en su lugar de inicio, así la
	# cámara vuelve a los jugadores)
	if _elapsed < total_time:
		player.visible = false
		player.global_position = player.spawn_position
		return

	# 3) Reaparece en su lugar de inicio, titilando e invencible
	player.global_position = player.spawn_position
	player.make_invincible(invincible_time)
	Audio.play_sfx(Audio.kicked_land)
	transitioned.emit("idle")


## Si todavía está volando hacia afuera (la cámara no lo sigue mientras tanto).
func is_flying() -> bool:
	return _elapsed < flight_time
