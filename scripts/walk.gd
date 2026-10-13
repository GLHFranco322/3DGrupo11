extends State


func physics_update(delta: float) -> void:
	var input := get_move_input()
	if input == Vector2.ZERO:
		transitioned.emit("idle")
		return
	if is_run_pressed() and not player.has_mower:
		transitioned.emit("run")
		return

	player.play_anim(&"cortarPasto" if player.has_mower else &"caminar")
	player.anim.speed_scale = 1.0
	player.apply_movement(input, player.get_walk_speed(), delta)
