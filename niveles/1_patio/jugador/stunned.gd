extends State

## Tiempo que el jugador queda aturdido al recibir una piedra.
@export_range(0.0, 10.0, 0.1, "suffix:s") var duration: float = 1.0

var _elapsed: float = 0.0


func enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector3.ZERO
	player.anim.speed_scale = 1.0
	player.play_anim(Player.ANIM_STUNNED, true)


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_friction(delta)
	if _elapsed >= duration:
		transitioned.emit("idle")
