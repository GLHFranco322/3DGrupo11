extends Node

# Autoload: asigna los joysticks conectados a cada jugador. El primer mando
# conectado controla las acciones "p1_*", el segundo las "p2_*", sin importar
# qué número de dispositivo le dé el sistema operativo.

const PLAYER_COUNT := 2
# Imprime en consola lo que llega de los joysticks (para depurar)
const DEBUG_INPUT := true


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_assign_devices()


func _input(event: InputEvent) -> void:
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
	var pads := Input.get_connected_joypads()
	for pad in pads:
		print("Joystick conectado: %d - %s" % [pad, Input.get_joy_name(pad)])
	if pads.is_empty():
		print("No hay joysticks conectados")

	for player in range(1, PLAYER_COUNT + 1):
		# Sin mando para este jugador: se deja el número por defecto (p1 = 0, p2 = 1)
		var device: int = pads[player - 1] if player - 1 < pads.size() else player - 1
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
