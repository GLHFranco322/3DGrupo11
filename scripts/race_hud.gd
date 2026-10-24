class_name RaceHud
extends CanvasLayer

# HUD de la carrera: en el costado de cada jugador su puesto, item, mate y
# barra de progreso; el tiempo arriba al centro; ayudas abajo; carteles
# (cuenta regresiva, ganador) en el medio.

## Cuando quedan menos de estos segundos, el tiempo se muestra en rojo.
@export_range(0.0, 60.0, 1.0, "suffix:s") var warning_time: float = 15.0
@export var warning_color: Color = Color(1.0, 0.3, 0.3)
## Color del texto del item cuando se tiene uno.
@export var item_color: Color = Color(1.0, 0.9, 0.4)
## Texto del botón para usar el item (cambiarlo si cambian los controles).
@export var item_button_text: String = "□"
## Texto del botón del turbo (cambiarlo si cambian los controles).
@export var turbo_button_text: String = "R1"

@onready var time_label: Label = %TimeLabel
@onready var message_label: Label = %MessageLabel
@onready var titles := {1: %Title1 as Label, 2: %Title2 as Label}
@onready var places := {1: %Place1 as Label, 2: %Place2 as Label}
@onready var items := {1: %Item1 as Label, 2: %Item2 as Label}
@onready var turbos := {1: %Turbo1 as Label, 2: %Turbo2 as Label}
@onready var bars := {1: %Progress1 as ProgressBar, 2: %Progress2 as ProgressBar}
@onready var hints := {1: %Hint1 as Label, 2: %Hint2 as Label}

var _racers: Array[Racer] = []
var _message_token: int = 0


func setup(racers: Array[Racer]) -> void:
	_racers = racers
	message_label.visible = false
	for r in racers:
		var id := r.player_id
		titles[id].text = "JUGADOR %d" % id
		titles[id].modulate = r.color
		hints[id].text = ""


func _process(_delta: float) -> void:
	for r in _racers:
		var id := r.player_id
		if r.item == Racer.Item.NONE:
			items[id].text = "Item: —"
			items[id].modulate = Color(1, 1, 1, 0.6)
		else:
			items[id].text = "%s  %s" % [item_button_text, Racer.ITEM_NAMES[r.item]]
			items[id].modulate = item_color

		if r.is_turbo_active():
			turbos[id].text = "¡TURBO!"
			turbos[id].modulate = item_color
		elif r.has_turbo:
			turbos[id].text = "%s  Mate" % turbo_button_text
			turbos[id].modulate = item_color
		elif r.is_tire_flat():
			turbos[id].text = "¡Rueda pinchada!"
			turbos[id].modulate = warning_color
		else:
			turbos[id].text = ""


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


func set_hint(racer: Racer, text: String) -> void:
	hints[racer.player_id].text = text


## Muestra un cartel en el centro. "duration" > 0 = se oculta solo.
func show_message(text: String, duration: float = 0.0) -> void:
	message_label.text = text
	message_label.visible = true
	_message_token += 1
	if duration > 0.0:
		var token := _message_token
		await get_tree().create_timer(duration).timeout
		if token == _message_token:
			message_label.visible = false
