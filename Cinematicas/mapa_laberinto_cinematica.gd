extends Node3D

## Escena que sigue cuando termina (o se saltea) la cinemática.
@export_file("*.tscn") var next_scene: String = "res://menus/character_select.tscn"
## Segundos que hay que mantener apretado ✕ para saltear.
@export_range(0.3, 3.0, 0.1, "suffix:s") var hold_time: float = 1.0

@onready var presentacion: AnimationPlayer = $CinematicaInicial

var _terminada := false
# Evita que el ✕ con el que se apretó "Jugar" cuente como parte de la pausa
var _armado := false
var _held := 0.0
var _bar: ProgressBar


func _ready() -> void:
	Audio.fade_out_music(0.5)
	_build_skip_ui()
	presentacion.animation_finished.connect(_on_animation_finished)
	presentacion.play("CinematicaPresentacion")


func _process(delta: float) -> void:
	if _terminada:
		return
	var held := _is_skip_pressed()
	if not held:
		_armado = true
	if held and _armado:
		_held += delta
	else:
		_held = maxf(_held - delta * 2.0, 0.0)
	_bar.value = _held / hold_time * 100.0
	if _held >= hold_time:
		_terminar()


func _is_skip_pressed() -> bool:
	if Input.is_action_pressed("ui_accept"):
		return true
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_A): # ✕ en PlayStation
			return true
	return false


func _on_animation_finished(_anim_name: StringName) -> void:
	_terminar()


func _terminar() -> void:
	if _terminada:
		return
	_terminada = true
	presentacion.stop()
	SceneLoader.change_scene(next_scene)


# Indicación abajo a la derecha: texto + barra que se llena al mantener
func _build_skip_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var box := VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -360
	box.offset_right = -40
	box.offset_top = -100
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 6)
	layer.add_child(box)

	var label := Label.new()
	label.text = "Mantené ✕ para saltear"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.max_value = 100.0
	box.add_child(_bar)
