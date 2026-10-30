extends Node

# Autoload "Audio" (escena scenes/audio.tscn). Para asignar sonidos: abrir
# audio.tscn y arrastrar cada archivo a su slot en el inspector. Un slot vacío
# no suena. Para tener variaciones de un mismo sonido, usar un recurso
# "AudioStreamRandomizer" en el slot.

@export_group("Volumen")
## Volumen de la música.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var music_volume_db: float = -8.0:
	set(value):
		music_volume_db = value
		_update_music_volume()
## Volumen de los efectos de sonido.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var sfx_volume_db: float = 0.0

# Niveles del menú de opciones (0 a 1). Los maneja GameSettings.
var music_level: float = 1.0:
	set(value):
		music_level = value
		_update_music_volume()
var sfx_level: float = 1.0

@export_group("Música")
## Música del menú principal y la selección de personaje.
@export var music_menu: AudioStream
## Música por defecto de los niveles (se repite en loop). Suena en los niveles
## que no tengan su propia música abajo.
@export var music_game: AudioStream
## Música del nivel 1 (el patio). Vacío = usa "Music Game".
@export var music_patio: AudioStream
## Música del nivel 2 (la ferretería). Vacío = usa "Music Game".
@export var music_store: AudioStream
## Música del nivel 3 (la carrera). Vacío = usa "Music Game".
@export var music_race: AudioStream
## Música de los últimos segundos. Vacío = sigue la música normal.
@export var music_hurry: AudioStream
## Segundos restantes en los que empieza "Music Hurry".
@export_range(0.0, 60.0, 1.0, "suffix:s") var hurry_time: float = 10.0
## Música de fondo en la pantalla de resultados.
@export var music_results: AudioStream
## Fanfarria al entrar a la pantalla de resultados.
@export var victory_fanfare: AudioStream

@export_group("Cortadora")
## Motor en marcha mientras se empuja la cortadora (loop).
@export var mower_engine: AudioStream
## Volumen extra del motor (para que no tape todo).
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var mower_engine_volume_db: float = -10.0
## Al cortar pasto.
@export var grass_cut: AudioStream
## Al sumar puntos.
@export var score_ping: AudioStream
@export var mower_grab: AudioStream
@export var mower_drop: AudioStream
## Cuando la cortadora se rompe.
@export var mower_broken: AudioStream
## Cuando la cortadora termina de repararse.
@export var mower_repaired: AudioStream

@export_group("Piedra")
@export var rock_grab: AudioStream
@export var rock_throw: AudioStream
## Cuando la piedra le pega al rival.
@export var rock_hit_player: AudioStream
## Cuando la piedra choca contra una pared u objeto.
@export var rock_hit_wall: AudioStream

@export_group("Pozo")
## Mientras el pozo baja del cielo.
@export var pit_spawn: AudioStream
@export var pit_place: AudioStream
## Cuando un jugador cae dentro.
@export var pit_fall: AudioStream
## Cuando el pozo se cierra.
@export var pit_close: AudioStream

@export_group("Bota")
@export var boot_grab: AudioStream
## Al patear al rival.
@export var kick_hit: AudioStream
## Al patear sin nadie cerca.
@export var kick_whiff: AudioStream
## Grito mientras el pateado vuela.
@export var kicked_scream: AudioStream
## Cuando el pateado reaparece en la cancha.
@export var kicked_land: AudioStream

@export_group("Jugador")
@export var footstep: AudioStream
## Tiempo entre pasos caminando.
@export_range(0.05, 2.0, 0.01, "suffix:s") var footstep_interval: float = 0.35
## Tiempo entre pasos corriendo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var footstep_run_interval: float = 0.22

@export_group("Carrera")
## Cada palada con la pala.
@export var shovel_stroke: AudioStream
## Al chocar fuerte y caerse de la carretilla.
@export var barrow_crash: AudioStream
## Al subirse de nuevo a la carretilla.
@export var barrow_climb: AudioStream
## Al agarrar un item o el mate en la pista.
@export var item_pickup: AudioStream
## Cuando la caña de pescar engancha al rival.
@export var rod_hook: AudioStream
## Cuando se usa la caña con el rival fuera de alcance (no se gasta).
@export var rod_miss: AudioStream
## Cuenta regresiva de la largada (3, 2, 1).
@export var race_count: AudioStream
## "¡Ya!" de la largada.
@export var race_go: AudioStream
## Al pasar por una rampa de turbo.
@export var boost_pad: AudioStream
## Cuando una reja eléctrica tira a alguien de la carretilla.
@export var grate_zap: AudioStream
## Al caerse por un hueco del piso (vacío = usa "Pit Fall").
@export var void_fall: AudioStream

@export_group("Ferretería")
## Piña que le pega al rival.
@export var punch_hit: AudioStream
## Piña al aire.
@export var punch_whiff: AudioStream
## Al agarrar una banana o un hielo del piso.
@export var trap_pickup: AudioStream
## Al dejar una trampa.
@export var trap_place: AudioStream
## Cuando alguien pisa una banana.
@export var banana_slip: AudioStream
## Cuando alguien empieza a patinar en el hielo.
@export var ice_slide: AudioStream

@export_group("Partida")
## Suena una vez por segundo cuando el tiempo se pone rojo.
@export var countdown_tick: AudioStream
## Al terminar la partida ("¡Tiempo!").
@export var time_up: AudioStream

@export_group("Menú")
@export var ui_hover: AudioStream
@export var ui_click: AudioStream

@export_group("Avanzado")
## Cantidad de efectos que pueden sonar al mismo tiempo.
@export_range(1, 64) var sfx_voices: int = 16
## Tiempo mínimo entre repeticiones de sonidos que se disparan muy seguido
## (cortar pasto, sumar puntos).
@export_range(0.0, 1.0, 0.01, "suffix:s") var spam_cooldown: float = 0.12

var _music_player: AudioStreamPlayer
# Volumen del fade de la música (0 = muda, 1 = normal) y su animación
var _music_fade: float = 1.0
var _music_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}


func _ready() -> void:
	# Sigue sonando aunque el juego esté en pausa (ej: "¡Tiempo!")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_update_music_volume()
	_music_player.finished.connect(_music_player.play)
	add_child(_music_player)

	for i in sfx_voices:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)


## Reproduce un efecto. "cooldown" evita que se repita más seguido que eso.
func play_sfx(stream: AudioStream, cooldown: float = 0.0, volume_offset_db: float = 0.0) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if cooldown > 0.0 and now - _last_played.get(stream, -INF) < cooldown:
		return
	_last_played[stream] = now

	var player := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = get_sfx_db() + volume_offset_db
	player.play()


## Efecto que se dispara muy seguido (usa "Spam Cooldown").
func play_sfx_spam(stream: AudioStream) -> void:
	play_sfx(stream, spam_cooldown)


## Cambia la música. Si ya está sonando la misma, no la reinicia. "fade_in" =
## segundos que tarda en subir el volumen desde cero (0 = de golpe).
func play_music(stream: AudioStream, fade_in: float = 0.0) -> void:
	if stream == null:
		stop_music()
		return
	_kill_music_fade()
	if _music_player.stream == stream and _music_player.playing:
		_set_music_fade(1.0)
		return
	_music_player.stream = stream
	_music_player.play()
	if fade_in > 0.0:
		_set_music_fade(0.0)
		_music_tween = create_tween()
		_music_tween.tween_method(_set_music_fade, 0.0, 1.0, fade_in)
	else:
		_set_music_fade(1.0)


## Baja la música de a poco en "time" segundos y la corta. Sigue aunque el juego
## esté en pausa (ej: al terminar la partida).
func fade_out_music(time: float) -> void:
	if not _music_player.playing:
		return
	if time <= 0.0:
		stop_music()
		return
	_kill_music_fade()
	_music_tween = create_tween()
	_music_tween.tween_method(_set_music_fade, _music_fade, 0.0, time)
	_music_tween.tween_callback(stop_music)


func _kill_music_fade() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _set_music_fade(value: float) -> void:
	_music_fade = value
	_update_music_volume()


## Pone la música de un nivel: la suya si tiene, si no "Music Game".
func play_level_music(level_stream: AudioStream, fade_in: float = 0.0) -> void:
	play_music(level_stream if level_stream else music_game, fade_in)


func stop_music() -> void:
	_kill_music_fade()
	_music_player.stop()
	_music_player.stream = null
	_set_music_fade(1.0)


## Crea un reproductor en loop (ej: motor) como hijo de "owner_node".
func create_loop_player(owner_node: Node, stream: AudioStream, volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = get_sfx_db() + volume_offset_db
	player.finished.connect(player.play)
	owner_node.add_child(player)
	return player


## Volumen final de los efectos (dB), con el nivel del menú de opciones aplicado.
func get_sfx_db() -> float:
	return sfx_volume_db + linear_to_db(maxf(sfx_level, 0.0001))


func _update_music_volume() -> void:
	if _music_player:
		_music_player.volume_db = music_volume_db + linear_to_db(maxf(music_level * _music_fade, 0.0001))
