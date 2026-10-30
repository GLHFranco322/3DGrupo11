class_name StoreHud
extends CanvasLayer

# HUD del nivel de la ferretería: lista de cada jugador en su costado de la
# pantalla dividida, tiempo arriba al centro y ayudas abajo.

## Color de las herramientas ya entregadas.
@export var delivered_color: Color = Color(0.5, 1.0, 0.5)
## Cuando quedan menos de estos segundos, el tiempo se muestra en rojo.
@export_range(0.0, 60.0, 1.0, "suffix:s") var warning_time: float = 15.0
@export var warning_color: Color = Color(1.0, 0.3, 0.3)
## Tiempo que se muestran los avisos (ej: "¡No está en tu lista!").
@export_range(0.2, 5.0, 0.1, "suffix:s") var flash_time: float = 1.5
## Texto del botón para dejar la trampa (cambiarlo si cambian los controles).
@export var trap_button_text: String = "△"

@onready var time_label: Label = %TimeLabel
@onready var message_label: Label = %MessageLabel
@onready var lists := {1: %List1 as VBoxContainer, 2: %List2 as VBoxContainer}
@onready var titles := {1: %ListTitle1 as Label, 2: %ListTitle2 as Label}
@onready var hints := {1: %Hint1 as Label, 2: %Hint2 as Label}

# player_id -> { ItemData -> Label }
var _rows: Dictionary = {1: {}, 2: {}}
var _flash_until: Dictionary = {1: 0.0, 2: 0.0}
# player_id -> Label con la trampa que lleva
var _trap_labels: Dictionary = {}


func setup(player1: StorePlayer, player2: StorePlayer) -> void:
	message_label.visible = false
	for player in [player1, player2]:
		var id: int = player.player_id
		titles[id].text = "JUGADOR %d" % id
		titles[id].modulate = player.color
		for item in player.remaining:
			var row := Label.new()
			row.text = "☐  " + item.display_name
			row.add_theme_font_size_override("font_size", 24)
			row.add_theme_color_override("font_outline_color", Color.BLACK)
			row.add_theme_constant_override("outline_size", 8)
			row.horizontal_alignment = titles[id].horizontal_alignment
			lists[id].add_child(row)
			_rows[id][item] = row
		var trap_label := Label.new()
		trap_label.add_theme_font_size_override("font_size", 22)
		trap_label.add_theme_color_override("font_outline_color", Color.BLACK)
		trap_label.add_theme_constant_override("outline_size", 8)
		trap_label.horizontal_alignment = titles[id].horizontal_alignment
		lists[id].add_child(trap_label)
		_trap_labels[id] = trap_label
		set_trap(player, "")


func set_time(seconds: float) -> void:
	var total := int(ceil(seconds))
	@warning_ignore("integer_division")
	var minutes := total / 60
	time_label.text = "%d:%02d" % [minutes, total % 60]
	time_label.modulate = warning_color if seconds <= warning_time else Color.WHITE


func mark_delivered(player: StorePlayer, item: ItemData) -> void:
	var row: Label = _rows[player.player_id].get(item)
	if row:
		row.text = "✔  " + item.display_name
		row.modulate = delivered_color


func set_hint(player: StorePlayer, text: String) -> void:
	if Time.get_ticks_msec() / 1000.0 < _flash_until[player.player_id]:
		return
	hints[player.player_id].text = text


func flash_message(player: StorePlayer, text: String) -> void:
	hints[player.player_id].text = text
	_flash_until[player.player_id] = Time.get_ticks_msec() / 1000.0 + flash_time


func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true


## Muestra la trampa que lleva el jugador ("" = ninguna).
func set_trap(player: StorePlayer, trap_name: String) -> void:
	var label: Label = _trap_labels.get(player.player_id)
	if label == null:
		return
	if trap_name.is_empty():
		label.text = "Trampa: —"
		label.modulate = Color(1, 1, 1, 0.6)
	else:
		label.text = "%s  %s" % [trap_button_text, trap_name]
		label.modulate = Color(1.0, 0.9, 0.4)
