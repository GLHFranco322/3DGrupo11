extends Control

# Menú principal: Jugar, Opciones (volumen) y Salir. "Jugar" siempre arranca
# por el primer nivel; los siguientes se juegan desde la pantalla de resultados.
# Se maneja con mouse o con cualquier mando (palanca / D-pad para moverse,
# ✕ / A acepta, ○ / B vuelve).

## Escena que se abre con "Jugar".
@export_file("*.tscn") var character_select_scene: String = "res://scenes/character_select.tscn"

@onready var main_panel: Control = %MainPanel
@onready var options_panel: Control = %OptionsPanel
# Oscurece la imagen de fondo en Opciones para que se lean los textos
@onready var dim: Control = %Dim
@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var back_button: Button = %BackButton
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
## Jugador 1 con teclado y mouse: el (único) mando queda para el Jugador 2.
@onready var keyboard_check: CheckButton = %KeyboardCheck


func _ready() -> void:
	Audio.play_music(Audio.music_menu)

	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_show_panel.bind(options_panel))
	quit_button.pressed.connect(get_tree().quit)
	back_button.pressed.connect(_show_panel.bind(main_panel))

	var buttons: Array[BaseButton] = [play_button, options_button, quit_button, keyboard_check, back_button]

	master_slider.value = GameSettings.master_volume * 100.0
	music_slider.value = GameSettings.music_volume * 100.0
	sfx_slider.value = GameSettings.sfx_volume * 100.0
	_refresh_values()
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.value_changed.connect(_on_volume_changed)
		slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play_sfx(Audio.ui_click))

	keyboard_check.button_pressed = GameSettings.keyboard_mouse_p1
	keyboard_check.toggled.connect(GameSettings.set_keyboard_mouse_p1)

	_show_panel(main_panel)

	# Sonidos después del foco inicial, para que no suenen al entrar
	for button in buttons:
		button.focus_entered.connect(Audio.play_sfx.bind(Audio.ui_hover))
		button.mouse_entered.connect(Audio.play_sfx.bind(Audio.ui_hover))
		button.pressed.connect(Audio.play_sfx.bind(Audio.ui_click))


func _unhandled_input(event: InputEvent) -> void:
	if not main_panel.visible and event.is_action_pressed("ui_cancel"):
		_show_panel(main_panel)
		get_viewport().set_input_as_handled()


func _show_panel(panel: Control) -> void:
	var previous: Control = null
	for p in [main_panel, options_panel]:
		if p.visible:
			previous = p
		p.visible = p == panel
	dim.visible = panel == options_panel

	if previous == options_panel:
		GameSettings.save_settings()

	if panel == options_panel:
		master_slider.grab_focus()
	elif previous == options_panel:
		options_button.grab_focus()
	else:
		play_button.grab_focus()


func _on_play_pressed() -> void:
	MatchResult.reset_tournament()
	GameSettings.selected_level = GameSettings.level_scenes[0]
	SceneLoader.change_scene(character_select_scene)


func _on_volume_changed(_value: float) -> void:
	GameSettings.set_volumes(master_slider.value / 100.0, music_slider.value / 100.0, sfx_slider.value / 100.0)
	_refresh_values()


func _refresh_values() -> void:
	master_value.text = "%d%%" % master_slider.value
	music_value.text = "%d%%" % music_slider.value
	sfx_value.text = "%d%%" % sfx_slider.value
