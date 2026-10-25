extends Node

# Autoload: asigna los joysticks a cada jugador. En la selección de personaje
# cada uno se une apretando ✕ con su mando (ver assign_device). Hasta entonces
# (o si se abre un nivel directo) el primer mando conectado controla "p1_*" y
# el segundo "p2_*", sin importar el número que le dé el sistema operativo.
#
# Con "keyboard_player" (Opciones del menú) ese jugador usa solo teclado y
# mouse: no le llega ningún mando y los mandos quedan para los demás.

const PLAYER_COUNT := 2
# Imprime en consola lo que llega de los joysticks (para depurar)
const DEBUG_INPUT := false
# Mandos que no juegan (número que aparece en consola en "Joystick conectado").
# Ej: [0] para que jueguen el 1 contra el 2. Vacío = juegan los primeros dos.
const IGNORED_DEVICES: Array[int] = []
# Número de mando que no existe: se usa para que un jugador no reciba mandos
const NO_DEVICE := 99


var _debug_timer: float = 0.0
# player_id -> número de mando asignado
var _player_devices: Dictionary = {}
# Si los mandos los eligieron los jugadores (no se reasignan solos)
var _manual: bool = false
## Jugador que usa teclado y mouse (0 = nadie, todos con mando). Lo pone GameSettings.
var keyboard_player: int = 0

var _mouse_motion: Vector2 = Vector2.ZERO


## Número de mando que controla al jugador "player" (1 o 2).
func get_player_device(player: int) -> int:
	return _player_devices.get(player, player - 1)


## Cambia qué jugador usa teclado y mouse (0 = nadie) y reparte los mandos de nuevo.
func set_keyboard_player(player: int) -> void:
	keyboard_player = player
	_manual = false
	_assign_devices()


## Movimiento del mouse acumulado desde la última llamada (para girar la cámara
## del jugador de teclado). Lo junta este autoload porque las cámaras de la
## pantalla dividida no reciben el mouse cuando está sobre la otra mitad.
func take_mouse_motion() -> Vector2:
	var motion := _mouse_motion
	_mouse_motion = Vector2.ZERO
	return motion


## Hace que "device" controle al jugador "player". Lo usa la selección de
## personaje cuando alguien se une con su mando.
func assign_device(player: int, device: int) -> void:
	_manual = true
	_player_devices[player] = device
	_set_player_device(player, device)
	print("Jugador %d -> mando %d (%s)" % [player, device, Input.get_joy_name(device)])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_assign_devices()


# Lee el estado de los mandos directamente (sin eventos) cada medio segundo
func _process(delta: float) -> void:
	if not DEBUG_INPUT:
		return
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return
	_debug_timer = 0.5

	for pad in Input.get_connected_joypads():
		var active: Array[String] = []
		for axis in JOY_AXIS_SDL_MAX:
			var value := Input.get_joy_axis(pad, axis)
			if absf(value) > 0.3:
				active.append("eje %d=%.2f" % [axis, value])
		for button in JOY_BUTTON_SDL_MAX:
			if Input.is_joy_button_pressed(pad, button):
				active.append("botón %d" % button)
		if not active.is_empty():
			print("[Estado] Mando %d: %s" % [pad, ", ".join(active)])


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_motion += event.relative
	if not DEBUG_INPUT:
		return
	if event is InputEventJoypadButton and event.pressed:
		print("Mando %d: botón %d" % [event.device, event.button_index])
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		print("Mando %d: eje %d = %.2f" % [event.device, event.axis, event.axis_value])
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		for action in ["p1_left", "p1_right", "p1_up", "p1_down"]:
			if event.is_action(action):
				print("  -> coincide con %s" % action)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_assign_devices()


func _assign_devices() -> void:
	var pads: Array[int] = []
	for pad in Input.get_connected_joypads():
		var ignored := pad in IGNORED_DEVICES
		print("Joystick conectado: %d - %s%s" % [pad, Input.get_joy_name(pad), " (no juega)" if ignored else ""])
		if not ignored:
			pads.append(pad)
		if DEBUG_INPUT:
			print("  conocido por Godot: %s" % Input.is_joy_known(pad))
			print("  info: %s" % Input.get_joy_info(pad))
			print("  ventana con foco: %s" % get_window().has_focus())
	if pads.is_empty():
		print("No hay joysticks conectados")
	# Los eligieron los jugadores: se respeta aunque se conecte otro mando
	if _manual:
		return

	var next_pad := 0
	for player in range(1, PLAYER_COUNT + 1):
		var device: int
		if player == keyboard_player:
			device = NO_DEVICE
		elif next_pad < pads.size():
			device = pads[next_pad]
			next_pad += 1
		else:
			# Sin mando para este jugador: el número por defecto (p1 = 0, p2 = 1)
			device = player - 1
		_player_devices[player] = device
		_set_player_device(player, device)


func _set_player_device(player: int, device: int) -> void:
	var prefix := "p%d_" % player
	for action in InputMap.get_actions():
		if not String(action).begins_with(prefix):
			continue
		for event in InputMap.action_get_events(action):
			if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
				continue
			if event.device == device:
				continue
			var new_event: InputEvent = event.duplicate()
			new_event.device = device
			InputMap.action_erase_event(action, event)
			InputMap.action_add_event(action, new_event)
