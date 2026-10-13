extends State


func physics_update(delta: float) -> void:
	var input := get_move_input()
	if input == Vector2.ZERO:
		transitioned.emit("idle")
		return
	if not is_run_pressed() or player.has_mower:
		transitioned.emit("walk")
		return

	player.play_anim(&"caminar")
	player.anim.speed_scale = 1.6
	player.apply_movement(input, player.run_speed, delta)
