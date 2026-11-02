extends Node

# Autoload "Metrics" (escena sistema/metrics.tscn): cuenta lo que pasa en cada
# partida para los testeos (puntos, trampas usadas, tiempos) y al terminar la
# manda como una fila a una planilla de Google Sheets.
#
# Cómo se usa desde un nivel:
#   Metrics.start_match("Nivel 1 - Corta el pasto")   al empezar
#   Metrics.add(player_id, "piedras")                  cada vez que pasa algo
#   Metrics.start_timer / stop_timer(player_id, ...)   para medir tiempos
#   Metrics.set_value / set_info(...)                  datos sueltos
#   Metrics.end_match()                                al terminar: arma y envía
#
# Cada partida se guarda como .json en user://metricas/pendientes y, cuando la
# planilla confirma que la recibió, pasa a user://metricas/enviadas. Si no hay
# internet, las pendientes se reenvían la próxima vez (al terminar otra partida
# o al abrir el juego). La planilla y su script están explicados en
# docs/metricas/LEEME.md.

@export_group("Google Sheets")
## Si está apagado no se cuenta ni se envía nada.
@export var enabled: bool = true
## URL de la aplicación web de Apps Script (termina en /exec). Vacío = las
## partidas solo se guardan en la PC.
@export var web_app_url: String = ""
## Clave compartida con el script de la planilla (la misma que CLAVE allá).
@export var secret_key: String = ""
## Segundos de espera de cada envío antes de darlo por fallido.
@export_range(1.0, 120.0, 1.0, "suffix:s") var timeout: float = 20.0

const PENDING_DIR := "user://metricas/pendientes"
const SENT_DIR := "user://metricas/enviadas"

## Identifica la vez que se abrió el juego (agrupa las partidas de un torneo).
var session_id: String = ""
## ID de la última partida terminada (se muestra en resultados para las
## observaciones).
var last_match_id: String = ""

var _active: bool = false
var _sheet: String = ""
var _match_id: String = ""
var _started_at: String = ""
var _duration: float = 0.0
# Datos de la partida (fin, ganador...) y de cada jugador: player_id -> {clave: valor}
var _info: Dictionary = {}
var _players: Dictionary = {}
# "player_id:clave" que están midiendo tiempo
var _running_timers: Dictionary = {}
var _http: HTTPRequest
var _queue: Array[String] = []
var _sending: String = ""


func _ready() -> void:
	session_id = _timestamp()
	DirAccess.make_dir_recursive_absolute(PENDING_DIR)
	DirAccess.make_dir_recursive_absolute(SENT_DIR)
	_http = HTTPRequest.new()
	_http.timeout = timeout
	# Apps Script responde con una redirección: se sigue a mano (con GET) para
	# leer su respuesta, porque seguirla sola repetiría el POST
	_http.max_redirects = 0
	# Sigue enviando aunque el juego esté en pausa (al terminar la partida)
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	_send_pending()


# Los tiempos solo corren con el juego andando (no en pausa)
func _process(delta: float) -> void:
	if not _active:
		return
	_duration += delta
	for key in _running_timers:
		var parts: PackedStringArray = key.split(":", true, 1)
		var data: Dictionary = _players.get_or_add(int(parts[0]), {})
		data[parts[1]] = data.get(parts[1], 0.0) + delta


## Empieza a contar una partida. "sheet" = nombre de la pestaña de la planilla.
func start_match(sheet: String) -> void:
	if not enabled:
		return
	_active = true
	_sheet = sheet
	_match_id = _timestamp()
	_started_at = Time.get_datetime_string_from_system(false, true)
	_duration = 0.0
	_info.clear()
	_players = {1: {}, 2: {}}
	_running_timers.clear()


func is_active() -> bool:
	return _active


## Suma "amount" a un contador del jugador (crea el contador si no existe).
func add(player_id: int, key: String, amount: int = 1) -> void:
	if not _active:
		return
	var data: Dictionary = _players.get_or_add(player_id, {})
	data[key] = data.get(key, 0) + amount


## Pone un valor del jugador (puntos, personaje...).
func set_value(player_id: int, key: String, value: Variant) -> void:
	if _active:
		var data: Dictionary = _players.get_or_add(player_id, {})
		data[key] = value


## Pone un dato de la partida (fin, ganador...).
func set_info(key: String, value: Variant) -> void:
	if _active:
		_info[key] = value


## Empieza a medir un tiempo del jugador (se suma en "key", en segundos).
func start_timer(player_id: int, key: String) -> void:
	if _active:
		_running_timers["%d:%s" % [player_id, key]] = true
		var data: Dictionary = _players.get_or_add(player_id, {})
		if not data.has(key):
			data[key] = 0.0


func stop_timer(player_id: int, key: String) -> void:
	_running_timers.erase("%d:%s" % [player_id, key])


## Nombre del personaje que eligió el jugador ("" si no eligió).
func character_name(player_id: int) -> String:
	var character := GameSettings.get_character(player_id)
	return character.display_name if character else ""


func get_value(player_id: int, key: String, default: Variant = 0) -> Variant:
	return _players.get(player_id, {}).get(key, default)


## Termina la partida: arma la fila, la guarda y la envía.
func end_match() -> void:
	if not _active:
		return
	_active = false
	_running_timers.clear()
	last_match_id = _match_id

	var row := {
		"partida_id": _match_id,
		"sesion": session_id,
		"fecha": _started_at,
		"duracion_s": snappedf(_duration, 0.1),
	}
	row.merge(_info)
	for player_id in [1, 2]:
		var data: Dictionary = _players.get(player_id, {})
		for key in data:
			var value = data[key]
			row["j%d_%s" % [player_id, key]] = snappedf(value, 0.1) if value is float else value

	var payload := {
		"clave": secret_key,
		"hoja": _sheet,
		"columnas": row.keys(),
		"fila": row,
	}
	var path := PENDING_DIR.path_join("%s.json" % _match_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Metrics: no se pudo guardar %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_send_pending()


# --- Envío ----------------------------------------------------------------------

func _send_pending() -> void:
	if web_app_url.is_empty():
		return
	for file_name in DirAccess.get_files_at(PENDING_DIR):
		var path := PENDING_DIR.path_join(file_name)
		if file_name.ends_with(".json") and path != _sending and not _queue.has(path):
			_queue.append(path)
	_send_next()


func _send_next() -> void:
	if not _sending.is_empty() or _queue.is_empty():
		return
	_sending = _queue.pop_front()
	var body := FileAccess.get_file_as_string(_sending)
	var error := _http.request(web_app_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("Metrics: no se pudo enviar (%s)" % error_string(error))
		_give_up_for_now()


func _on_request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# Apps Script contesta el envío con una redirección: la respuesta de verdad
	# ({"ok":true} o el error) se pide aparte, con un GET a esa dirección
	var location := _get_header(headers, "location")
	if code >= 300 and code < 400 and not location.is_empty():
		var error := _http.request(location)
		if error != OK:
			push_warning("Metrics: no se pudo leer la respuesta de la planilla (%s)" % error_string(error))
			_give_up_for_now()
		return
	var text := body.get_string_from_utf8()
	var reply = JSON.parse_string(text) if result == HTTPRequest.RESULT_SUCCESS else null
	if not (reply is Dictionary and reply.get("ok", false)):
		var reason: String = reply.get("error", "") if reply is Dictionary else text.left(200)
		push_warning("Metrics: la planilla no recibió la partida (resultado %d, código %d) %s" % [result, code, reason])
		_give_up_for_now()
		return
	DirAccess.rename_absolute(_sending, SENT_DIR.path_join(_sending.get_file()))
	_sending = ""
	_send_next()


func _get_header(headers: PackedStringArray, header_name: String) -> String:
	for header in headers:
		if header.to_lower().begins_with(header_name + ":"):
			return header.substr(header_name.length() + 1).strip_edges()
	return ""


# Sin conexión: las que quedan se reintentan en el próximo envío
func _give_up_for_now() -> void:
	_sending = ""
	_queue.clear()


func _timestamp() -> String:
	return Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
