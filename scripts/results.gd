extends Node3D

# Pantalla de fin de nivel: muestra al ganador del nivel sobre el pedestal y
# cómo va el torneo. Si hay otro nivel se sigue con "Siguiente nivel"; después
# del último, "Ver campeón" muestra al que ganó más niveles.

## Escena que se abre con "Menú".
@export_file("*.tscn") var menu_scene: String = "res://scenes/main_menu.tscn"
## Separación entre los modelos cuando hay empate.
@export_range(0.0, 5.0, 0.05, "suffix:u") var tie_spacing: float = 1.0
## Cuánto gira el ganador de lado a lado sobre el pedestal (0 = quieto).
@export_range(0.0, 180.0, 1.0, "suffix:°") var sway_angle: float = 25.0
## Velocidad del balanceo.
@export_range(0.0, 10.0, 0.1) var sway_speed: float = 1.2

@onready var winner_spot: Node3D = $Pedestal/WinnerSpot
@onready var title_label: Label = $UI/Title
@onready var points_label: Label = $UI/Points
@onready var standings_label: Label = $UI/Standings
@onready var main_button: Button = $UI/Buttons/NextLevel
@onready var menu_button: Button = $UI/Buttons/Menu
@onready var quit_button: Button = $UI/Buttons/Quit
@onready var buttons: Array[Button] = [main_button, menu_button, quit_button]

var _time: float = 0.0
var _next_level: int = -1


func _ready() -> void:
	_next_level = GameSettings.get_next_level(MatchResult.last_level_scene)
	if _next_level >= 0:
		main_button.text = "Jugar: " + GameSettings.level_names[_next_level]
	else:
		main_button.text = "Ver campeón"
	main_button.pressed.connect(_on_main_pressed)
	menu_button.pressed.connect(SceneLoader.change_scene.bind(menu_scene))
	quit_button.pressed.connect(get_tree().quit)

	# El foco inicial va antes de conectar los sonidos para que no suene al entrar
	main_button.grab_focus()
	for button in buttons:
		button.mouse_entered.connect(Audio.play_sfx.bind(Audio.ui_hover))
		button.focus_entered.connect(Audio.play_sfx.bind(Audio.ui_hover))
		button.pressed.connect(Audio.play_sfx.bind(Audio.ui_click))

	Audio.play_sfx(Audio.victory_fanfare)
	Audio.play_music(Audio.music_results)
	_show_level_result()


func _show_level_result() -> void:
	standings_label.text = _standings_text()
	var winners := MatchResult.winners
	if winners.is_empty():
		title_label.text = "Fin del nivel"
		points_label.text = ""
		return

	if MatchResult.is_tie():
		title_label.text = "¡Empate! Nadie suma la victoria"
		title_label.modulate = Color.WHITE
		points_label.text = "%d puntos cada uno" % winners[0].score
	else:
		var winner: Dictionary = winners[0]
		title_label.text = "¡El Jugador %d ganó el nivel!" % winner.id
		title_label.modulate = winner.color
		points_label.text = "%d puntos" % winner.score
	_show_models(winners)


func _show_champion() -> void:
	var champions := MatchResult.get_champions()
	var champion_wins: int = MatchResult.wins.get(champions[0].id, 0) if not champions.is_empty() else 0
	if champions.size() == 1:
		title_label.text = "¡Campeón: Jugador %d!" % champions[0].id
		title_label.modulate = champions[0].color
		points_label.text = "Ganó %d %s" % [champion_wins, "nivel" if champion_wins == 1 else "niveles"]
	else:
		title_label.text = "¡Empate en el torneo!"
		title_label.modulate = Color.WHITE
		points_label.text = "Los dos ganaron %d %s" % [champion_wins, "nivel" if champion_wins == 1 else "niveles"]
	standings_label.text = _standings_text()
	_show_models(champions)

	# Ya no hay más niveles: queda Menú y Salir
	main_button.visible = false
	buttons.erase(main_button)
	menu_button.grab_focus()
	Audio.play_sfx(Audio.victory_fanfare)


func _standings_text() -> String:
	var parts: PackedStringArray = []
	for id in [1, 2]:
		var count: int = MatchResult.wins.get(id, 0)
		parts.append("Jugador %d: %d %s" % [id, count, "victoria" if count == 1 else "victorias"])
	return "Torneo  ·  " + "   ·   ".join(parts)


func _on_main_pressed() -> void:
	if _next_level >= 0:
		GameSettings.selected_level = GameSettings.level_scenes[_next_level]
		SceneLoader.change_scene(GameSettings.selected_level)
	else:
		_show_champion()


# Godot no trae botones de mando para aceptar en menús: se manejan acá.
# Cualquiera de los dos jugadores puede elegir.
func _unhandled_input(event: InputEvent) -> void:
	if _is_pressed(event, ["p1_grab", "p2_grab"]) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		var focused := get_viewport().gui_get_focus_owner() as BaseButton
		if focused:
			# Primero se marca como usado: el botón puede cambiar de escena y
			# después esta pantalla ya no existe
			get_viewport().set_input_as_handled()
			focused.pressed.emit()
	elif _is_pressed(event, ["p1_left", "p2_left", "p1_up", "p2_up"]):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif _is_pressed(event, ["p1_right", "p2_right", "p1_down", "p2_down"]):
		_move_focus(1)
		get_viewport().set_input_as_handled()


func _move_focus(step: int) -> void:
	var current := buttons.find(get_viewport().gui_get_focus_owner() as Button)
	buttons[clampi(current + step, 0, buttons.size() - 1)].grab_focus()


func _is_pressed(event: InputEvent, actions: Array[String]) -> bool:
	for action in actions:
		if event.is_action_pressed(action):
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	winner_spot.rotation.y = deg_to_rad(sway_angle) * sin(_time * sway_speed)


func _show_models(infos: Array[Dictionary]) -> void:
	for child in winner_spot.get_children():
		child.queue_free()
	for i in infos.size():
		var offset := (i - (infos.size() - 1) * 0.5) * tie_spacing
		_spawn_model(infos[i], Vector3(offset, 0.0, 0.0))


func _spawn_model(info: Dictionary, offset: Vector3) -> void:
	var scene: PackedScene = info.model_scene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.scale = Vector3.ONE * info.model_scale
	model.position = offset
	winner_spot.add_child(model)
	ModelUtils.tint(model, info.get("tint", Color.WHITE))

	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		var extra: Array[PackedScene] = info.extra_animations
		Player.merge_animations(anim, extra)
		AnimNames.normalize(anim)
		# En el podio: festejo si el personaje lo tiene, si no idle
		if anim.has_animation(Player.ANIM_EMOTE):
			anim.play(Player.ANIM_EMOTE)
		elif anim.has_animation(Player.ANIM_IDLE):
			anim.play(Player.ANIM_IDLE)
