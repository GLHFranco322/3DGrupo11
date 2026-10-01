extends State

@export var duration: float = 1.0

var _elapsed: float = 0.0


func enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector3.ZERO
	player.visible = false


func exit() -> void:
	player.visible = true


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		player.global_position = player.spawn_position
		transitioned.emit("idle")
