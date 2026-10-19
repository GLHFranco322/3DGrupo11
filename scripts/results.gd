extends Node3D

# Pantalla de fin de partida: muestra al ganador sobre el pedestal con sus
# puntos y las opciones de volver a jugar o salir.

## Escena que se abre con "Volver a jugar".
@export_file("*.tscn") var game_scene: String = "res://scenes/main.tscn"
## Separación entre los modelos cuando hay empate.
@export_range(0.0, 5.0, 0.05, "suffix:u") var tie_spacing: float = 1.0
## Cuánto gira el ganador de lado a lado sobre el pedestal (0 = quieto).
@export_range(0.0, 180.0, 1.0, "suffix:°") var sway_angle: float = 25.0
## Velocidad del balanceo.
@export_range(0.0, 10.0, 0.1) var sway_speed: float = 1.2

@onready var winner_spot: Node3D = $Pedestal/WinnerSpot
@onready var title_label: Label = $UI/Title
@onready var points_label: Label = $UI/Points
@onready var play_again_button: Button = $UI/Buttons/PlayAgain
@onready var quit_button: Button = $UI/Buttons/Quit

var _time: float = 0.0


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# El foco inicial va antes de conectar los sonidos para que no suene al entrar
	play_again_button.grab_focus()
	for button in [play_again_button, quit_button]:
		button.mouse_entered.connect(Audio.play_sfx.bind(Audio.ui_hover))
		button.focus_entered.connect(Audio.play_sfx.bind(Audio.ui_hover))
		button.pressed.connect(Audio.play_sfx.bind(Audio.ui_click))

	Audio.play_sfx(Audio.victory_fanfare)
	Audio.play_music(Audio.music_results)

	var winners := MatchResult.winners
	if winners.is_empty():
		title_label.text = "Fin de la partida"
		points_label.text = ""
		return

	if MatchResult.is_tie():
		title_label.text = "¡Empate!"
		points_label.text = "%d puntos cada uno" % winners[0].score
	else:
		var winner: Dictionary = winners[0]
		title_label.text = "¡Ganó el Jugador %d!" % winner.id
		title_label.modulate = winner.color
		points_label.text = "%d puntos" % winner.score

	for i in winners.size():
		var offset := (i - (winners.size() - 1) * 0.5) * tie_spacing
		_spawn_model(winners[i], Vector3(offset, 0.0, 0.0))


# Godot no trae botones de mando para aceptar en menús: se manejan acá.
# Cualquiera de los dos jugadores puede elegir.
func _unhandled_input(event: InputEvent) -> void:
	if _is_pressed(event, ["p1_grab", "p2_grab"]) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		var focused := get_viewport().gui_get_focus_owner() as BaseButton
		if focused:
			focused.pressed.emit()
			get_viewport().set_input_as_handled()
	elif _is_pressed(event, ["p1_left", "p2_left", "p1_up", "p2_up"]):
		play_again_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif _is_pressed(event, ["p1_right", "p2_right", "p1_down", "p2_down"]):
		quit_button.grab_focus()
		get_viewport().set_input_as_handled()


func _is_pressed(event: InputEvent, actions: Array[String]) -> bool:
	for action in actions:
		if event.is_action_pressed(action):
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	winner_spot.rotation.y = deg_to_rad(sway_angle) * sin(_time * sway_speed)


func _spawn_model(info: Dictionary, offset: Vector3) -> void:
	var scene: PackedScene = info.model_scene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * info.model_scale
	model.position = offset
	winner_spot.add_child(model)

	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		var extra: Array[PackedScene] = info.extra_animations
		Player.merge_animations(anim, extra)
		if anim.has_animation(Player.ANIM_IDLE):
			anim.play(Player.ANIM_IDLE)


func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file(game_scene)


func _on_quit_pressed() -> void:
	get_tree().quit()
