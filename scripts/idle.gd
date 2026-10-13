extends State


func physics_update(delta: float) -> void:
	player.apply_friction(delta)
	player.stop_anim()

	if get_move_input() != Vector2.ZERO:
		transitioned.emit("walk")
