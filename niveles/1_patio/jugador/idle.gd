extends State


func physics_update(delta: float) -> void:
	player.apply_friction(delta)
	if player.anim and player.anim.has_animation(Player.ANIM_IDLE):
		player.anim.speed_scale = 1.0
		player.play_anim(Player.ANIM_IDLE)
	else:
		player.stop_anim()

	if get_move_input() != Vector2.ZERO:
		transitioned.emit("walk")
