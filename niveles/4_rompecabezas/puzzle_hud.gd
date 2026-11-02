class_name PuzzleHud
extends CanvasLayer

# HUD del nivel de los rompecabezas. Arma por código la pantalla dividida
# (jugador 1 arriba, jugador 2 abajo: la mesa se ve mejor en franjas anchas),
# con una cámara en cada mitad. En la esquina de cada mitad: rompecabezas
# completados y piezas del actual; el tiempo en el medio; carteles en el centro.

## Cuando quedan menos de estos segundos, el tiempo se muestra en rojo.
@export_range(0.0, 60.0, 1.0, "suffix:s") var warning_time: float = 10.0
@export var warning_color: Color = Color(1.0, 0.3, 0.3)
## Texto del botón para agarrar y soltar (cambiarlo si cambian los controles).
@export var grab_button_text: String = "✕"

var _cameras: Dictionary = {}
var _views: Dictionary = {}
var _titles: Dictionary = {}
var _counts: Dictionary = {}
var _pieces: Dictionary = {}
var _hints: Dictionary = {}
var _time_label: Label
var _message_label: Label
var _message_token: int = 0


func _ready() -> void:
	var split := VBoxContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 4)
	split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(split)
	for id in [1, 2]:
		# Cada mitad: la imagen de su cámara y, encima, sus textos
		var half := Control.new()
		half.size_flags_vertical = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		split.add_child(half)
		var container := SubViewportContainer.new()
		container.stretch = true
		container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.add_child(container)
		var viewport := SubViewport.new()
		viewport.handle_input_locally = false
		container.add_child(viewport)
		var camera := Camera3D.new()
		camera.name = "Camera%d" % id
		viewport.add_child(camera)
		_cameras[id] = camera
		_views[id] = half
		_build_corner(id, half)

	var time_panel := PanelContainer.new()
	time_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	time_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	time_panel.position.x -= 24.0
	add_child(time_panel)
	_time_label = _make_label(44)
	time_panel.add_child(_time_label)

	_message_label = _make_label(72)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.visible = false
	add_child(_message_label)


## Cámara de la mitad de la pantalla del jugador "id".
func get_camera(id: int) -> Camera3D:
	return _cameras[id]


func setup(players: Array) -> void:
	for p in players:
		_titles[p.player_id].text = "JUGADOR %d" % p.player_id
		_titles[p.player_id].modulate = p.color
		set_counts(p, 0, 0)
		set_hint(p, "")


## Rompecabezas completados y piezas encastradas del actual.
func set_counts(player, placed: int, total: int) -> void:
	_counts[player.player_id].text = "Rompecabezas: %d" % player.completed
	_pieces[player.player_id].text = "Piezas: %d / %d" % [placed, total] if total > 0 else ""


func set_hint(player, text: String) -> void:
	_hints[player.player_id].text = text


func set_time(seconds: float) -> void:
	var total := int(ceil(seconds))
	@warning_ignore("integer_division")
	var minutes := total / 60
	_time_label.text = "%d:%02d" % [minutes, total % 60]
	_time_label.modulate = warning_color if seconds <= warning_time else Color.WHITE


## Muestra un cartel en el centro. "duration" > 0 = se oculta solo.
func show_message(text: String, duration: float = 0.0) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_token += 1
	if duration > 0.0:
		var token := _message_token
		await get_tree().create_timer(duration).timeout
		if token == _message_token:
			_message_label.visible = false


## Cartel chico sobre la mitad de un jugador (ej: "¡Completo!").
func flash(player, text: String, duration: float = 1.0) -> void:
	var label := _make_label(56)
	label.text = text
	label.modulate = player.color
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = _views[player.player_id].size * 0.5
	_views[player.player_id].add_child(label)
	label.scale = Vector2.ONE * 0.3
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


# Esquina de arriba a la izquierda de cada mitad, y la ayuda abajo
func _build_corner(id: int, container: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 12.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_titles[id] = _make_label(26)
	_counts[id] = _make_label(30)
	_pieces[id] = _make_label(22)
	for label in [_titles[id], _counts[id], _pieces[id]]:
		column.add_child(label)

	_hints[id] = _make_label(22)
	_hints[id].set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hints[id].grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints[id].position.y -= 10.0
	_hints[id].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_hints[id])


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(int(font_size * 0.25), 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func get_grab_text(holding: bool) -> String:
	return "%s  %s" % [grab_button_text, "Soltar" if holding else "Agarrar"]
