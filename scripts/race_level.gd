extends Node3D

# Nivel 3, carrera de carretillas por el barrio: de punta a punta, gana el
# primero que llega a la meta. Si se acaba el tiempo, gana el más adelantado.
# El recorrido es el Path3D "Track": al mover sus puntos en el editor, el
# camino y los cordones lo siguen solos.

@export_group("Partida")
## Duración máxima de la carrera.
@export_range(10.0, 900.0, 5.0, "suffix:s") var match_duration: float = 150.0
## Segundos de la cuenta regresiva antes de largar.
@export_range(0, 10) var countdown: int = 3
## La meta está a esta distancia antes del final del recorrido.
@export_range(0.0, 50.0, 0.5, "suffix:u") var finish_margin: float = 8.0
## Tiempo que se muestra el cartel final antes de los resultados.
@export_range(0.0, 10.0, 0.1, "suffix:s") var end_delay: float = 2.5
@export_file("*.tscn") var results_scene: String = "res://scenes/results.tscn"

@export_group("Progreso")
## Si el punto más cercano del recorrido salta más que esto de golpe (por
## ejemplo en una curva cerrada que pasa cerca de otra parte de la pista), se
## ignora. Evita que alguien "avance" cortando camino.
@export_range(1.0, 100.0, 1.0, "suffix:u") var max_progress_jump: float = 15.0

@export_group("Referencias")
@export var track: Path3D
@export var racer1: Racer
@export var racer2: Racer
@export var spawner: RaceItemSpawner
@export var hud: RaceHud
## Línea de llegada (se acomoda sola sobre el recorrido).
@export var finish_line: Node3D

var time_left: float
var _racing: bool = false
var _finished: bool = false
var _length: float = 0.0


func _ready() -> void:
	_length = track.curve.get_baked_length()
	_place_finish_line()
	spawner.spawn_initial_items()
	time_left = match_duration
	hud.setup(_racers())
	hud.set_time(time_left)
	_update_progress()
	Audio.play_music(Audio.music_game)
	_start_countdown()


func _racers() -> Array[Racer]:
	return [racer1, racer2]


func get_finish_distance() -> float:
	return maxf(_length - finish_margin, 0.0)


func _place_finish_line() -> void:
	if finish_line == null:
		return
	var at := track.global_transform * track.curve.sample_baked_with_rotation(get_finish_distance())
	finish_line.global_transform = Transform3D(at.basis.orthonormalized(), at.origin)


func _start_countdown() -> void:
	for i in range(countdown, 0, -1):
		hud.show_message(str(i))
		Audio.play_sfx(Audio.race_count)
		await get_tree().create_timer(1.0).timeout
	hud.show_message("¡YA!", 0.8)
	Audio.play_sfx(Audio.race_go)
	_racing = true
	spawner.active = true
	for r in _racers():
		r.controls_enabled = true


func _process(delta: float) -> void:
	_update_progress()
	if not _racing or _finished:
		return

	time_left = maxf(time_left - delta, 0.0)
	hud.set_time(time_left)
	for r in _racers():
		hud.set_hint(r, _get_hint(r))

	for r in _racers():
		if r.progress >= get_finish_distance() and r.state != Racer.Mode.SINKING:
			_finish(r, "¡Jugador %d ganó la carrera!" % r.player_id)
			return
	if time_left <= 0.0:
		var leader := _get_leader()
		_finish(leader, "¡Tiempo! Gana el Jugador %d" % leader.player_id)


# Metros recorridos: el punto del recorrido más cercano a la carretilla
func _update_progress() -> void:
	var to_track := track.global_transform.affine_inverse()
	for r in _racers():
		var offset := track.curve.get_closest_offset(to_track * r.barrow.global_position)
		if absf(offset - r.progress) <= max_progress_jump or r.progress == 0.0:
			r.progress = offset
	var leader := _get_leader()
	spawner.leader_progress = leader.progress
	hud.set_progress(_racers(), get_finish_distance(), leader)


func _get_leader() -> Racer:
	return racer1 if racer1.progress >= racer2.progress else racer2


func _get_hint(r: Racer) -> String:
	match r.state:
		Racer.Mode.ON_FOOT:
			return "✕ Subite a la carretilla" if r.can_climb() else "¡Volvé a la carretilla!"
		Racer.Mode.KNOCKED:
			return "¡Te caíste!"
	return ""


func _finish(winner: Racer, message: String) -> void:
	_finished = true
	_racing = false
	spawner.active = false
	# Puntaje = metros recorridos; el ganador suma un extra para que no haya empate
	for r in _racers():
		r.controls_enabled = false
		r.score = int(r.progress)
	winner.score += 100
	MatchResult.save_from(_racers())
	MatchResult.last_level_scene = scene_file_path
	hud.show_message(message)
	Audio.stop_music()
	Audio.play_sfx(Audio.time_up)
	get_tree().paused = true
	await get_tree().create_timer(end_delay, true).timeout
	SceneLoader.change_scene(results_scene)
