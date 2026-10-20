extends Node

# Autoload "GameSettings" (escena scenes/game_settings.tscn): personajes
# disponibles, qué personaje eligió cada jugador y volumen. El volumen se
# guarda en disco (user://settings.cfg).

const SETTINGS_PATH := "user://settings.cfg"

## Personajes que se pueden elegir, en el orden en que aparecen.
@export var characters: Array[CharacterData] = []
## Nombres de los niveles, en orden de juego (mismo orden que "Level Scenes").
@export var level_names: PackedStringArray = ["Nivel 1: El patio", "Nivel 2: La ferretería"]
## Escenas de los niveles, en orden de juego. Al terminar uno se ofrece el siguiente.
@export_file("*.tscn") var level_scenes: PackedStringArray = ["res://scenes/main.tscn", "res://scenes/store_level.tscn"]

## Volumen general (0 a 1).
var master_volume: float = 1.0
## Volumen de la música (0 a 1).
var music_volume: float = 1.0
## Volumen de los efectos (0 a 1).
var sfx_volume: float = 1.0

# player_id -> CharacterData elegido. Vacío = cada nivel usa su personaje por defecto.
var _player_characters: Dictionary = {}

## Nivel elegido en el menú (ruta de la escena). Vacío = el que tenga la selección de personaje.
var selected_level: String = ""


func _ready() -> void:
	_add_menu_joypad_buttons()
	load_settings()
	apply_volumes()


## Índice del nivel que sigue a "scene_path", o -1 si es el último (o no está en la lista).
func get_next_level(scene_path: String) -> int:
	var index := level_scenes.find(scene_path)
	if index < 0 or index + 1 >= level_scenes.size():
		return -1
	return index + 1


func set_character(player_id: int, character: CharacterData) -> void:
	_player_characters[player_id] = character


func get_character(player_id: int) -> CharacterData:
	return _player_characters.get(player_id)


func set_volumes(master: float, music: float, sfx: float) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	apply_volumes()


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _to_db(master_volume))
	Audio.music_level = music_volume
	Audio.sfx_level = sfx_volume


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = config.get_value("audio", "master", master_volume)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)


func _to_db(level: float) -> float:
	return linear_to_db(maxf(level, 0.0001))


# Godot no trae botones de mando para aceptar/volver en los menús:
# ✕ / A acepta y ○ / B vuelve, con cualquier mando.
func _add_menu_joypad_buttons() -> void:
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.device = -1
	InputMap.action_add_event("ui_accept", accept)

	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.device = -1
	InputMap.action_add_event("ui_cancel", cancel)
