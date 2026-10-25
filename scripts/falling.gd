extends State

## Tiempo que el jugador queda escondido dentro del pozo antes de reaparecer.
@export_range(0.0, 10.0, 0.1, "suffix:s") var duration: float = 1.0
## Al reaparecer queda invencible (titilando) estos segundos, igual que después
## de una patada: no le pegan piedras, no cae en pozos y no lo pueden patear.
@export_range(0.0, 10.0, 0.1, "suffix:s") var invincible_time: float = 1.5

var _elapsed: float = 0.0
var _start_position: Vector3
var _end_position: Vector3
var _freeze_time: float = 0.0
var _sink_time: float = 0.0

@onready var _collision: CollisionShape3D = $"../../CollisionShape3D"


func enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)

	_start_position = player.global_position
	_end_position = _start_position
	var pit := player.falling_pit
	if pit:
		_freeze_time = pit.freeze_time
		_sink_time = pit.sink_time
		_end_position = Vector3(pit.global_position.x, _start_position.y - pit.sink_depth, pit.global_position.z)
	else:
		_freeze_time = 0.0
		_sink_time = 0.0

	player.anim.speed_scale = 1.0
	if player.anim.has_animation(Player.ANIM_FALL):
		player.play_anim(Player.ANIM_FALL, true)
	else:
		player.anim.stop()


func exit() -> void:
	player.visible = true
	player.falling_pit = null
	_collision.set_deferred("disabled", false)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.velocity = Vector3.ZERO

	# 1) Congelado sobre el pozo  2) Se hunde hacia el centro  3) Escondido
	if _elapsed < _freeze_time:
		return
	if _elapsed < _freeze_time + _sink_time:
		var t := (_elapsed - _freeze_time) / _sink_time
		player.global_position = _start_position.lerp(_end_position, t * t)
		return

	player.visible = false
	if _elapsed >= _freeze_time + _sink_time + duration:
		player.global_position = player.spawn_position
		player.make_invincible(invincible_time)
		Audio.play_sfx(Audio.kicked_land)
		transitioned.emit("idle")
