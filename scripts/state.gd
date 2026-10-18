class_name State
extends Node

# Se emite desde los estados hijos (idle.gd, walk.gd, etc.)
@warning_ignore("unused_signal")
signal transitioned(state_name: String)

var player: Player


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func get_move_input() -> Vector2:
	var prefix := "p%d_" % player.player_id
	return Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")


func is_run_pressed() -> bool:
	return Input.is_action_pressed("p%d_run" % player.player_id)
