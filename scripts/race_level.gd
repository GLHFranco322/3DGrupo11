extends Node3D

# Nivel 3, carrera de carretillas en un circuito cerrado: gana el primero que
# completa todas las vueltas. Si se acaba el tiempo, gana el más adelantado.
# El recorrido es el Path3D "Track" (curva cerrada): al mover sus puntos en el
# editor, el camino, los cordones, la ciudad y el minimapa lo siguen solos. La
# largada y la meta están en el primer punto de la curva.

@export_group("Partida")
## Duración máxima de la carrera.
@export_range(10.0, 900.0, 5.0, "suffix:s") var match_duration: float = 240.0
## Vueltas al circuito para ganar.
@export_range(1, 20) var laps: int = 3
## Segundos de la cuenta regresiva antes de largar.
@export_range(0, 10) var countdown: int = 3
## Tiempo que se muestra el cartel final antes de los resultados.
@export_range(0.0, 10.0, 0.1, "suffix:s") var end_delay: float = 2.5
@export_file("*.tscn") var results_scene: String = "res://scenes/results.tscn"
## Segundos que tarda en subir la música al empezar.
@export_range(0.0, 10.0, 0.1, "suffix:s") var music_fade_in: float = 2.0
## Segundos que tarda en apagarse la música al terminar (conviene menor o igual a "End Delay").
@export_range(0.0, 10.0, 0.1, "suffix:s") var music_fade_out: float = 2.0

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
## Línea de largada y llegada (se acomoda sola en el primer punto del recorrido).
@export var finish_line: Node3D

var time_left: float
var _racing: bool = false
var _finished: bool = false
var _length: float = 0.0
# Racer -> true cuando ya se le calculó el progreso por primera vez
var _tracked: Dictionary = {}
var _last_lap_shown: bool = false


func _ready() -> void:
	_length = track.curve.get_baked_length()
	_place_finish_line()
	spawner.spawn_initial_items()
	time_left = match_duration
	hud.setup(_racers(), track)
	hud.set_time(time_left)
	_update_progress()
	Audio.play_level_music(Audio.music_race, music_fade_in)
	_start_countdown()


func _racers() -> Array[Racer]:
	return [racer1, racer2]


## Metros totales de la carrera (todas las vueltas).
func get_race_distance() -> float:
	return _length * laps


## Vuelta en la que va (1 a "laps").
func get_lap(r: Racer) -> int:
	return clampi(floori(r.progress / _length) + 1, 1, laps)


func _place_finish_line() -> void:
	if finish_line == null:
		return
	var at := track.global_transform * track.curve.sample_baked_with_rotation(0.0)
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
		if r.progress >= get_race_distance() and r.state != Racer.Mode.SINKING:
			_finish(r, "¡Jugador %d ganó la carrera!" % r.player_id)
			return
	if time_left <= 0.0:
		var leader := _get_leader()
		_finish(leader, "¡Tiempo! Gana el Jugador %d" % leader.player_id)


# Metros recorridos en total: se sigue el punto del recorrido más cercano a la
# carretilla y se suma lo que avanzó desde el cuadro anterior. Al cruzar la meta
# el punto vuelve a 0 pero el total sigue sumando (así se cuentan las vueltas);
# cruzarla marcha atrás resta.
func _update_progress() -> void:
	var to_track := track.global_transform.affine_inverse()
	for r in _racers():
		var offset := track.curve.get_closest_offset(to_track * r.barrow.global_position)
		if not _tracked.has(r):
			# En la largada están detrás de la meta: progreso negativo
			_tracked[r] = true
			r.progress = offset - _length if offset > _length * 0.5 else offset
			continue
		var moved := wrapf(offset - fposmod(r.progress, _length), -_length * 0.5, _length * 0.5)
		if absf(moved) <= max_progress_jump:
			r.progress += moved
	var leader := _get_leader()
	spawner.leader_progress = leader.progress
	hud.set_progress(_racers(), get_race_distance(), leader)
	for r in _racers():
		hud.set_lap(r, get_lap(r), laps)
	if _racing and laps > 1 and not _last_lap_shown and get_lap(leader) == laps:
		_last_lap_shown = true
		hud.show_message("¡ÚLTIMA VUELTA!", 1.5)


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
		r.score = maxi(int(r.progress), 0)
	winner.score += 100
	MatchResult.save_from(_racers())
	MatchResult.last_level_scene = scene_file_path
	hud.show_message(message)
	Audio.fade_out_music(music_fade_out)
	Audio.play_sfx(Audio.time_up)
	get_tree().paused = true
	await get_tree().create_timer(end_delay, true).timeout
	SceneLoader.change_scene(results_scene)
