extends State


func physics_update(delta: float) -> void:
	player.apply_friction(delta)

	if get_move_input() != Vector2.ZERO:
		transitioned.emit("walk")
