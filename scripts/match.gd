extends Node3D

# Controla la duración de la partida y pasa a la escena de resultados.

@export_group("Partida")
## Duración de la partida.
@export_range(5.0, 600.0, 1.0, "suffix:s") var match_duration: float = 120.0
## Tiempo que se muestra "¡Tiempo!" antes de pasar a los resultados.
@export_range(0.0, 10.0, 0.1, "suffix:s") var end_delay: float = 2.0
## Escena que se abre al terminar la partida.
@export_file("*.tscn") var results_scene: String = "res://scenes/results.tscn"

@export_group("Referencias")
@export var player1: Player
@export var player2: Player
@export var hud: Hud

var time_left: float
var _finished: bool = false


func _ready() -> void:
	time_left = match_duration
	hud.set_time(time_left)
	Audio.play_music(Audio.music_game)


func _process(delta: float) -> void:
	if _finished:
		return
	var previous_second := ceili(time_left)
	time_left = maxf(time_left - delta, 0.0)
	hud.set_time(time_left)
	_update_time_sounds(previous_second)
	if time_left <= 0.0:
		_finish()


func _update_time_sounds(previous_second: int) -> void:
	if time_left <= Audio.hurry_time and Audio.music_hurry:
		Audio.play_music(Audio.music_hurry)
	# Un tic por segundo cuando el tiempo se pone rojo
	if ceili(time_left) < previous_second and time_left <= hud.warning_time and time_left > 0.0:
		Audio.play_sfx(Audio.countdown_tick)


func _finish() -> void:
	_finished = true
	MatchResult.save_from([player1, player2])
	MatchResult.last_level_scene = scene_file_path
	hud.show_message("¡Tiempo!")
	Audio.stop_music()
	Audio.play_sfx(Audio.time_up)

	get_tree().paused = true
	await get_tree().create_timer(end_delay, true).timeout
	SceneLoader.change_scene(results_scene)
