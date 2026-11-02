extends Node3D

# Controla la duración de la partida y pasa a la escena de resultados.

@export_group("Partida")
## Duración de la partida.
@export_range(5.0, 600.0, 1.0, "suffix:s") var match_duration: float = 120.0
## Tiempo que se muestra "¡Tiempo!" antes de pasar a los resultados.
@export_range(0.0, 10.0, 0.1, "suffix:s") var end_delay: float = 2.0
## Escena que se abre al terminar la partida.
@export_file("*.tscn") var results_scene: String = "res://menus/results.tscn"

@export_group("Referencias")
@export var player1: Player
@export var player2: Player
@export var hud: Hud

var time_left: float
var _finished: bool = false


func _ready() -> void:
	time_left = match_duration
	Metrics.start_match("Nivel 1 - Corta el pasto")
	# Que las columnas salgan en este orden aunque alguien no use nada
	for p in [player1, player2]:
		Metrics.set_value(p.player_id, "personaje", Metrics.character_name(p.player_id))
		for key in ["puntos", "piedras", "pozos", "botas_agarradas", "patadas", "patadas_acertadas"]:
			Metrics.set_value(p.player_id, key, 0)
		Metrics.set_value(p.player_id, "seg_con_maquina", 0.0)
	hud.set_time(time_left)
	Audio.play_level_music(Audio.music_patio)


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
	_save_metrics()
	MatchResult.last_level_scene = scene_file_path
	hud.show_message("¡Tiempo!")
	Audio.stop_music()
	Audio.play_sfx(Audio.time_up)

	get_tree().paused = true
	await get_tree().create_timer(end_delay, true).timeout
	SceneLoader.change_scene(results_scene)


# Métricas de testeo: puntos de cada uno, promedio y ganador
func _save_metrics() -> void:
	for p in [player1, player2]:
		Metrics.set_value(p.player_id, "puntos", p.score)
	Metrics.set_info("promedio_puntos", (player1.score + player2.score) / 2.0)
	Metrics.set_info("ganador", MatchResult.winners[0].id if MatchResult.winners.size() == 1 else "empate")
	Metrics.end_match()
