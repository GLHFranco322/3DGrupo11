extends State


func physics_update(delta: float) -> void:
	var input := get_move_input()
	if input == Vector2.ZERO:
		transitioned.emit("idle")
		return
	if is_run_pressed() and not player.has_mower:
		transitioned.emit("run")
		return

	player.apply_movement(input, player.get_walk_speed(), delta)
