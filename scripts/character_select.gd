extends Node3D

# Selección de personaje: primero cada uno se une apretando ✕ con el mando que
# quiera usar (el primero es el Jugador 1, el segundo el Jugador 2; los demás
# mandos no juegan). Después palanca izquierda/derecha cambia, ✕ confirma,
# ○ cancela o deja el lugar (si no hay nadie, vuelve al menú). Cuando los dos
# confirman, arranca la partida.

const PLAYERS := [1, 2]
# Valor de "_devices" para el que se unió con teclado
const KEYBOARD := -2

## Escena que se abre cuando los dos están listos.
@export_file("*.tscn") var game_scene: String = "res://scenes/main.tscn"
## Escena a la que se vuelve con ○ / B.
@export_file("*.tscn") var menu_scene: String = "res://scenes/main_menu.tscn"
## Color de cada jugador (igual que en la partida).
@export var player_colors: Array[Color] = [Color(0.945, 0.941, 0.0), Color(0.945, 0.0, 0.0)]
## Tamaño de los personajes en la vista previa.
@export_range(0.1, 10.0, 0.1) var preview_scale: float = 2.0
## Cuánto gira el personaje de lado a lado (0 = quieto).
@export_range(0.0, 180.0, 1.0, "suffix:°") var sway_angle: float = 20.0
## Espera entre que los dos confirman y empieza la partida.
@export_range(0.0, 5.0, 0.1, "suffix:s") var start_delay: float = 1.2
## Cuánto hay que empujar la palanca para cambiar de personaje (1 = a fondo).
@export_range(0.1, 1.0, 0.05) var stick_threshold: float = 0.7
## La palanca tiene que volver por debajo de esto antes de poder cambiar otra vez.
@export_range(0.0, 0.9, 0.05) var stick_release: float = 0.3

@onready var spots := {1: $Spot1 as Node3D, 2: $Spot2 as Node3D}
@onready var name_labels := {1: %NameLabel1 as Label, 2: %NameLabel2 as Label}
@onready var character_labels := {1: %CharacterLabel1 as Label, 2: %CharacterLabel2 as Label}
@onready var status_labels := {1: %StatusLabel1 as Label, 2: %StatusLabel2 as Label}
@onready var message_label: Label = %MessageLabel

var _index := {1: 0, 2: 1}
# Si cada jugador ya se unió con un mando (y cuál)
var _joined := {1: false, 2: false}
var _devices := {1: -1, 2: -1}
var _ready_players := {1: false, 2: false}
var _starting: bool = false
var _time: float = 0.0
# Si la palanca de cada jugador está empujada (espera que la suelte)
var _stick_held := {1: false, 2: false}


func _ready() -> void:
	Audio.play_music(Audio.music_menu)
	message_label.visible = false
	var roster := GameSettings.characters
	if roster.is_empty():
		push_error("No hay personajes en GameSettings (scenes/game_settings.tscn)")
		return

	for p in PLAYERS:
		# Si ya habían elegido antes, arranca en ese personaje
		var previous := GameSettings.get_character(p)
		var found := roster.find(previous)
		_index[p] = found if found >= 0 else (p - 1) % roster.size()
		name_labels[p].text = "JUGADOR %d" % p
		name_labels[p].modulate = player_colors[p - 1]
		_refresh(p)


func _process(delta: float) -> void:
	_time += delta
	for p in PLAYERS:
		spots[p].rotation.y = deg_to_rad(sway_angle) * sin(_time * 1.2 + p)
		_update_stick(p)


# Palanca: un cambio por empujón (a fondo), y hay que soltarla para el siguiente
func _update_stick(p: int) -> void:
	if not _joined[p]:
		return
	var x := Input.get_joy_axis(Controls.get_player_device(p), JOY_AXIS_LEFT_X)
	if _stick_held[p]:
		if absf(x) < stick_release:
			_stick_held[p] = false
		return
	if absf(x) >= stick_threshold:
		_stick_held[p] = true
		if not _starting and not _ready_players[p] and not GameSettings.characters.is_empty():
			_change(p, 1 if x > 0.0 else -1)


func _unhandled_input(event: InputEvent) -> void:
	if _starting or GameSettings.characters.is_empty():
		return
	if _try_join(event) or _try_back_to_menu(event):
		get_viewport().set_input_as_handled()
		return
	for p in PLAYERS:
		if not _joined[p]:
			continue
		if _is_cancel(event, p):
			if _ready_players[p]:
				_ready_players[p] = false
				Audio.play_sfx(Audio.ui_click)
				_refresh(p)
			else:
				_leave(p)
			get_viewport().set_input_as_handled()
			return
		if _ready_players[p]:
			continue
		# La palanca se maneja en _update_stick; acá teclado y D-pad
		var is_stick := event is InputEventJoypadMotion
		if (event.is_action_pressed("p%d_left" % p) and not is_stick) or _is_dpad(event, p, JOY_BUTTON_DPAD_LEFT):
			_change(p, -1)
		elif (event.is_action_pressed("p%d_right" % p) and not is_stick) or _is_dpad(event, p, JOY_BUTTON_DPAD_RIGHT):
			_change(p, 1)
		elif event.is_action_pressed("p%d_grab" % p):
			_confirm(p)
		else:
			continue
		get_viewport().set_input_as_handled()
		return


func _is_dpad(event: InputEvent, p: int, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == button \
			and event.device == Controls.get_player_device(p)


# ○ / B del mando de ese jugador (Esc en teclado, para probar)
func _is_cancel(event: InputEvent, p: int) -> bool:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		return event.device == Controls.get_player_device(p)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		return p == 1
	return false


func _change(p: int, step: int) -> void:
	var count := GameSettings.characters.size()
	_index[p] = wrapi(_index[p] + step, 0, count)
	Audio.play_sfx(Audio.ui_hover)
	_refresh(p)


func _confirm(p: int) -> void:
	_ready_players[p] = true
	Audio.play_sfx(Audio.ui_click)
	_refresh(p)
	if _ready_players[1] and _ready_players[2]:
		_start_game()


func _refresh(p: int) -> void:
	var character: CharacterData = GameSettings.characters[_index[p]]
	character_labels[p].text = "◀  %s  ▶" % character.display_name
	character_labels[p].modulate = Color.WHITE if _joined[p] else Color(1, 1, 1, 0.35)
	if not _joined[p]:
		status_labels[p].text = "Apretá ✕ con tu mando para unirte"
		status_labels[p].modulate = Color(1, 1, 1, 0.7)
	elif _ready_players[p]:
		status_labels[p].text = "¡LISTO!   (○ para cambiar)"
		status_labels[p].modulate = Color(0.5, 1.0, 0.5)
	else:
		status_labels[p].text = "✕ para confirmar · ○ salir"
		status_labels[p].modulate = Color.WHITE
	_show_model(p, character)


func _show_model(p: int, character: CharacterData) -> void:
	var spot: Node3D = spots[p]
	for child in spot.get_children():
		child.queue_free()
	if character.model_scene == null:
		return

	var model := character.model_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * character.model_scale * preview_scale
	spot.add_child(model)

	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	Player.merge_animations(anim, character.extra_animations)
	AnimNames.normalize(anim)
	# Festeja al confirmar (si tiene la animación), si no queda en idle
	if _ready_players[p] and anim.has_animation(Player.ANIM_EMOTE):
		anim.play(Player.ANIM_EMOTE)
	elif anim.has_animation(Player.ANIM_IDLE):
		anim.play(Player.ANIM_IDLE)


func _start_game() -> void:
	_starting = true
	for p in PLAYERS:
		GameSettings.set_character(p, GameSettings.characters[_index[p]])
	message_label.text = "¡A jugar!"
	message_label.visible = true
	await get_tree().create_timer(start_delay).timeout
	var level := GameSettings.selected_level if GameSettings.selected_level != "" else game_scene
	SceneLoader.change_scene(level)


# ✕ de un mando que todavía no juega: ocupa el primer lugar libre.
# En teclado, la tecla de agarrar (E) une al Jugador 1 (para probar sin mandos).
func _try_join(event: InputEvent) -> bool:
	var device := -1
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		device = event.device
		if device in _devices.values():
			return false
	elif event is InputEventKey and event.is_action_pressed("p1_grab"):
		if _joined[1]:
			return false
		_join(1, KEYBOARD)
		return true
	else:
		return false

	for p in PLAYERS:
		if not _joined[p]:
			Controls.assign_device(p, device)
			_join(p, device)
			return true
	return false


# ○ de un mando que no juega, o Esc, cuando todavía no se unió nadie
func _try_back_to_menu(event: InputEvent) -> bool:
	if _joined[1] or _joined[2]:
		return false
	var back: bool = (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE)
	if back:
		SceneLoader.change_scene(menu_scene)
	return back


func _join(p: int, device: int) -> void:
	_joined[p] = true
	_devices[p] = device
	# El mando recién unido no cambia de personaje hasta que suelte la palanca
	_stick_held[p] = true
	Audio.play_sfx(Audio.ui_click)
	_refresh(p)


func _leave(p: int) -> void:
	_joined[p] = false
	_devices[p] = -1
	Audio.play_sfx(Audio.ui_click)
	_refresh(p)
