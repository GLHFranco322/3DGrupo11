extends State

@export var duration: float = 1.0

var _elapsed: float = 0.0


func enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.apply_friction(delta)
	if _elapsed >= duration:
		transitioned.emit("idle")
