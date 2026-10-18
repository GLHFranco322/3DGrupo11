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
		if _music_player:
			_music_player.volume_db = value
## Volumen de los efectos de sonido.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var sfx_volume_db: float = 0.0

@export_group("Música")
## Música durante la partida (se repite en loop).
@export var music_game: AudioStream
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

@export_group("Jugador")
@export var footstep: AudioStream
## Tiempo entre pasos caminando.
@export_range(0.05, 2.0, 0.01, "suffix:s") var footstep_interval: float = 0.35
## Tiempo entre pasos corriendo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var footstep_run_interval: float = 0.22

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
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}


func _ready() -> void:
	# Sigue sonando aunque el juego esté en pausa (ej: "¡Tiempo!")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = music_volume_db
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
	player.volume_db = sfx_volume_db + volume_offset_db
	player.play()


## Efecto que se dispara muy seguido (usa "Spam Cooldown").
func play_sfx_spam(stream: AudioStream) -> void:
	play_sfx(stream, spam_cooldown)


## Cambia la música. Si ya está sonando la misma, no la reinicia.
func play_music(stream: AudioStream) -> void:
	if stream == null:
		stop_music()
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_music_player.stream = null


## Crea un reproductor en loop (ej: motor) como hijo de "owner_node".
func create_loop_player(owner_node: Node, stream: AudioStream, volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset_db
	player.finished.connect(player.play)
	owner_node.add_child(player)
	return player
