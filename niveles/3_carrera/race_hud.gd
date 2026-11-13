class_name RaceHud
extends CanvasLayer

# HUD de la carrera: en el costado de cada jugador su puesto, vuelta, item y
# barra de progreso; el tiempo arriba al centro; el minimapa abajo al centro;
# ayudas abajo; carteles (cuenta regresiva, ganador) en el medio.

## Cuando quedan menos de estos segundos, el tiempo se muestra en rojo.
@export_range(0.0, 60.0, 1.0, "suffix:s") var warning_time: float = 15.0
@export var warning_color: Color = Color(1.0, 0.3, 0.3)
## Color del texto del item cuando se tiene uno.
@export var item_color: Color = Color(1.0, 0.9, 0.4)
## Botón para tirar el item (marca de TextoConBotones; cambiarla si cambian los controles).
@export var item_button_text: String = "{X}"

@onready var time_label: Label = %TimeLabel
@onready var message_label: Label = %MessageLabel
@onready var titles := {1: %Title1 as Label, 2: %Title2 as Label}
@onready var places := {1: %Place1 as Label, 2: %Place2 as Label}
@onready var items := {1: %Item1 as TextoConBotones, 2: %Item2 as TextoConBotones}
@onready var bars := {1: %Progress1 as ProgressBar, 2: %Progress2 as ProgressBar}
@onready var lap_labels := {1: %Lap1 as Label, 2: %Lap2 as Label}
@onready var hints := {1: %Hint1 as TextoConBotones, 2: %Hint2 as TextoConBotones}
@onready var minimap: RaceMinimap = %Minimap

var _racers: Array[Racer] = []
var _message_token: int = 0
# Cartel de contramano de cada jugador (sobre su mitad de la pantalla)
var _wrong_way: Dictionary = {}


func setup(racers: Array[Racer], track: Path3D) -> void:
	_racers = racers
	minimap.setup(racers, track)
	message_label.visible = false
	for r in racers:
		var id := r.player_id
		titles[id].text = "JUGADOR %d" % id
		titles[id].modulate = r.color
		hints[id].texto = ""
		var sign := CartelContramano.new()
		sign.name = "Contramano%d" % id
		add_child(sign)
		_wrong_way[id] = sign


func _process(_delta: float) -> void:
	for r in _racers:
		var id := r.player_id
		# El cartel ocupa la mitad de la pantalla de ese jugador
		var view := get_node_or_null("Split/View%d" % id) as Control
		if view and _wrong_way.has(id) and _wrong_way[id].visible:
			var rect := view.get_global_rect()
			_wrong_way[id].position = rect.position
			_wrong_way[id].size = rect.size
		if r.item == Racer.Item.NONE:
			_set_item_text(id, "Ítem: —")
			items[id].modulate = Color(1, 1, 1, 0.6)
		else:
			_set_item_text(id, "%s %s" % [item_button_text, Racer.ITEM_NAMES[r.item]])
			items[id].modulate = item_color


func set_time(seconds: float) -> void:
	var total := int(ceil(seconds))
	@warning_ignore("integer_division")
	var minutes := total / 60
	time_label.text = "%d:%02d" % [minutes, total % 60]
	time_label.modulate = warning_color if seconds <= warning_time else Color.WHITE


func set_progress(racers: Array[Racer], finish_distance: float, leader: Racer) -> void:
	for r in racers:
		var id := r.player_id
		bars[id].max_value = maxf(finish_distance, 1.0)
		bars[id].value = r.progress
		places[id].text = "1°" if r == leader else "2°"


## Muestra u oculta el cartel de "¡CONTRAMANO!" de ese jugador.
func set_wrong_way(racer: Racer, on: bool) -> void:
	if _wrong_way.has(racer.player_id):
		_wrong_way[racer.player_id].show_warning(on)


func set_lap(racer: Racer, lap: int, laps: int) -> void:
	lap_labels[racer.player_id].text = "VUELTA %d/%d" % [lap, laps]


func set_hint(racer: Racer, text: String) -> void:
	if hints[racer.player_id].texto != text:
		hints[racer.player_id].texto = text


# Solo si cambió (rearmar el texto con íconos en cada cuadro es caro)
func _set_item_text(id: int, text: String) -> void:
	if items[id].texto != text:
		items[id].texto = text


## Muestra un cartel en el centro. "duration" > 0 = se oculta solo.
func show_message(text: String, duration: float = 0.0) -> void:
	message_label.text = text
	message_label.visible = true
	_message_token += 1
	if duration > 0.0:
		var token := _message_token
		await get_tree().create_timer(duration, false).timeout
		if token == _message_token:
			message_label.visible = false
