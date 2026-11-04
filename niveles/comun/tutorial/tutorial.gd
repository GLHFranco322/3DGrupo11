class_name Tutorial
extends Control

# Pantalla de tutorial que muestra SceneLoader mientras carga un nivel (ver
# "tutorials" en sistema/scene_loader.tscn). Cuando el nivel terminó de cargar
# pide que cada jugador apriete ✕ (p*_grab); con los dos listos emite
# "finished" y SceneLoader arranca el nivel.

signal finished

## Tamaño con el que se armó la pantalla (%Mesa); se escala para entrar en la ventana.
@export var design_size: Vector2 = Vector2(1920, 1080)
## Segundos en que se ignoran los botones al aparecer, para que el ✕ con que
## se eligió el nivel no cuente como "listo".
@export var input_delay: float = 0.6
## Velocidad con que titila el "Apretá ✕".
@export var prompt_pulse_speed: float = 3.0

@onready var desk: Control = %Mesa
@onready var loading_box: Control = %Cargando
@onready var progress_bar: BarraCarga = %Barra
@onready var ready_box: Control = %Listos
@onready var prompt: CanvasItem = %Aviso
@onready var checks: Array[Casilla] = [%CasillaJ1, %CasillaJ2]

var _loaded: bool = false
var _elapsed: float = 0.0
var _ready_players: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_fit)
	_fit()
	loading_box.visible = true
	ready_box.visible = false


func _process(delta: float) -> void:
	_elapsed += delta
	if _loaded and not is_finished():
		prompt.modulate.a = 0.6 + 0.4 * absf(sin(_elapsed * prompt_pulse_speed))


## Avance de la carga, de 0 a 1.
func set_progress(value: float) -> void:
	progress_bar.value = maxf(progress_bar.value, value)


## El nivel ya está cargado: se pide que los jugadores confirmen.
func set_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	progress_bar.value = 1.0
	loading_box.visible = false
	ready_box.visible = true


func is_finished() -> bool:
	return _ready_players.size() >= checks.size()


func _input(event: InputEvent) -> void:
	if not _loaded or is_finished() or _elapsed < input_delay:
		return
	for player in range(1, checks.size() + 1):
		if event.is_action_pressed("p%d_grab" % player) and not _ready_players.has(player):
			_ready_players[player] = true
			checks[player - 1].checked = true
			Audio.play_sfx(Audio.ui_click)
			get_viewport().set_input_as_handled()
			if is_finished():
				prompt.modulate.a = 1.0
				finished.emit()


func _fit() -> void:
	var view := get_viewport_rect().size
	var s := minf(view.x / design_size.x, view.y / design_size.y)
	desk.scale = Vector2(s, s)
	desk.position = (view - design_size * s) / 2.0
