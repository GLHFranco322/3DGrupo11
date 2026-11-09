extends CanvasLayer

# Autoload "PauseMenu": menú de pausa de los niveles (Volver, Opciones, Menú
# principal). Lo abre cualquiera de los dos con su botón de pausa (Start /
# Options del mando; Esc para el Jugador 1 y P para el Jugador 2 en teclado),
# pero solo lo maneja y lo puede cerrar el que pausó: el menú lee únicamente
# los controles de ese jugador (palanca o flechas para moverse, ✕ para elegir,
# pausa para volver).
#
# Solo funciona en las escenas de GameSettings.level_scenes y mientras el
# nivel no esté pausado por otra cosa (ej: el cartel final).

## Escena del menú principal.
@export_file("*.tscn") var main_menu_scene: String = "res://menus/main_menu.tscn"
## Cuánto cambia el volumen por cada toque de izquierda / derecha.
@export_range(1, 50) var volume_step: int = 10

const ITEMS := ["Volver", "Opciones", "Menú principal"]
const OPTIONS := ["Volumen general", "Música", "Efectos", "Volver"]

## Jugador que pausó (0 = no está en pausa).
var owner_id: int = 0

var _in_options: bool = false
var _selected: int = 0
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _root: Control
var _title: Label
var _hint: Label
var _prompts: HBoxContainer
var _list: VBoxContainer
var _rows: Array[Button] = []
var _color: Color = Color.WHITE
# El mouse elige al pasar por encima solo después de moverse (si el menú
# aparece debajo del cursor, no cambia lo elegido)
var _mouse_moved: bool = false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return owner_id != 0


func _input(event: InputEvent) -> void:
	if owner_id != 0 and event is InputEventMouseMotion:
		_mouse_moved = true


func _process(_delta: float) -> void:
	if owner_id == 0:
		for player in [1, 2]:
			if Input.is_action_just_pressed("p%d_pause" % player) and _can_pause():
				_open(player)
				return
		return

	var prefix := "p%d_" % owner_id
	# (○ no sirve para volver: en teclado comparte tecla con "abajo")
	if Input.is_action_just_pressed(prefix + "pause"):
		_back()
	elif Input.is_action_just_pressed(prefix + "up"):
		_move(-1)
	elif Input.is_action_just_pressed(prefix + "down"):
		_move(1)
	elif Input.is_action_just_pressed(prefix + "grab"):
		_choose(_selected)
	elif _in_options and Input.is_action_just_pressed(prefix + "left"):
		_change_volume(_selected, -volume_step)
	elif _in_options and Input.is_action_just_pressed(prefix + "right"):
		_change_volume(_selected, volume_step)


# Solo en un nivel, y si el nivel no se pausó solo (ej: terminó la partida)
func _can_pause() -> bool:
	var scene := get_tree().current_scene
	return scene != null and not get_tree().paused and not SceneLoader.visible \
			and scene.scene_file_path in GameSettings.level_scenes


func _open(player: int) -> void:
	owner_id = player
	_color = _find_player_color(player)
	get_tree().paused = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_list(false)
	_root.visible = true
	Audio.play_sfx(Audio.ui_click)


func _close() -> void:
	owner_id = 0
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode
	# Lo que se movió el mouse en la pausa no tiene que girar la cámara
	Controls.take_mouse_motion()
	Audio.play_sfx(Audio.ui_click)


func _back() -> void:
	if _in_options:
		GameSettings.save_settings()
		_show_list(false)
		_select(1)
	else:
		_close()


func _choose(index: int) -> void:
	Audio.play_sfx(Audio.ui_click)
	if _in_options:
		if index == OPTIONS.size() - 1:
			_back()
		return
	match index:
		0:
			_close()
		1:
			_show_list(true)
		2:
			# Sigue en pausa mientras carga: SceneLoader la saca al cambiar de escena
			owner_id = 0
			_root.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			SceneLoader.change_scene(main_menu_scene)


func _move(step: int) -> void:
	_select(wrapi(_selected + step, 0, _rows.size()))
	Audio.play_sfx(Audio.ui_hover)


func _change_volume(index: int, amount: int) -> void:
	if index >= 3:
		return
	var levels := [GameSettings.master_volume, GameSettings.music_volume, GameSettings.sfx_volume]
	levels[index] = clampf(snappedf(levels[index] + amount / 100.0, 0.01), 0.0, 1.0)
	GameSettings.set_volumes(levels[0], levels[1], levels[2])
	_refresh_texts()
	Audio.play_sfx(Audio.ui_hover)


# --- Dibujo -------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)

	_title = _make_label(&"Titulo")
	column.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	column.add_child(_list)
	_hint = _make_label(&"Chico")
	_hint.modulate = Color(1, 1, 1, 0.75)
	column.add_child(_hint)
	_prompts = HBoxContainer.new()
	_prompts.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompts.add_theme_constant_override("separation", 32)
	column.add_child(_prompts)


func _show_list(options: bool) -> void:
	_in_options = options
	_mouse_moved = false
	for row in _rows:
		row.queue_free()
	_rows.clear()
	for i in (OPTIONS if options else ITEMS).size():
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(400, 52)
		# Con mouse solo si el que pausó es el jugador de teclado y mouse
		if Controls.keyboard_player == owner_id:
			row.mouse_entered.connect(func() -> void:
				if _mouse_moved:
					_select(i))
			row.pressed.connect(_choose.bind(i))
		else:
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(row)
		_rows.append(row)
	_title.text = "OPCIONES" if options else "PAUSA"
	_title.modulate = _color
	_refresh_texts()
	_select(0)


func _refresh_texts() -> void:
	if _in_options:
		var levels := [GameSettings.master_volume, GameSettings.music_volume, GameSettings.sfx_volume]
		for i in 3:
			_rows[i].text = "%s:  ◀ %d%% ▶" % [OPTIONS[i], roundi(levels[i] * 100.0)]
		_rows[3].text = OPTIONS[3]
		_hint.text = "Jugador %d" % owner_id
		Botones.llenar(_prompts, [["PALANCA_IZQ", "Cambiar"], ["X", "Seleccionar"], ["OPTIONS", "Volver"]])
	else:
		for i in ITEMS.size():
			_rows[i].text = ITEMS[i]
		_hint.text = "Solo el Jugador %d puede manejar la pausa" % owner_id
		Botones.llenar(_prompts, [["X", "Seleccionar"], ["OPTIONS", "Volver"]])


func _select(index: int) -> void:
	_selected = index
	var normal := _make_style(Color(0.0, 0.0, 0.0, 0.55), Color(1, 1, 1, 0.15))
	var chosen := _make_style(_color.darkened(0.15), Color.WHITE)
	for i in _rows.size():
		var on := i == index
		for state in ["normal", "hover", "pressed"]:
			_rows[i].add_theme_stylebox_override(state, chosen if on else normal)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			_rows[i].add_theme_color_override(state, Color.WHITE if on else Color(1, 1, 1, 0.75))
		_rows[i].add_theme_color_override("font_outline_color", Color.BLACK)
		_rows[i].add_theme_constant_override("outline_size", 6 if on else 0)
		_rows[i].scale = Vector2.ONE * (1.06 if on else 1.0)
		_rows[i].pivot_offset = _rows[i].custom_minimum_size * 0.5


func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style


func _make_label(variation: StringName) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = variation
	return label


# Color del jugador que pausó (lo tiene su nodo en el nivel)
func _find_player_color(player: int) -> Color:
	var scene := get_tree().current_scene
	if scene:
		for node in scene.find_children("*", "Node", true, false):
			if "player_id" in node and "color" in node and node.player_id == player:
				return node.color
	return Color.WHITE
