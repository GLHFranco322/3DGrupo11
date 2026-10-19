class_name ItemTimer
extends Label3D

# Cuenta regresiva que flota sobre un item. Al llegar a 0 emite "expired".

signal expired

## Cuando quedan menos de estos segundos, el número cambia de color y el item parpadea.
@export_range(0.0, 10.0, 0.1, "suffix:s") var warning_time: float = 2.0
## Color normal del número.
@export var normal_color: Color = Color.WHITE
## Color del número cuando está por desaparecer.
@export var warning_color: Color = Color(1.0, 0.3, 0.3)
## Nodo que parpadea al final (ej: la malla del item). Vacío = no parpadea.
@export var blink_node: Node3D
## Parpadeos por segundo.
@export_range(1.0, 20.0, 0.5) var blink_speed: float = 8.0

var time_left: float = 0.0
var running: bool = false


func _ready() -> void:
	visible = false


func start(seconds: float) -> void:
	time_left = seconds
	running = true
	visible = true
	_refresh()


func stop() -> void:
	running = false
	visible = false
	if blink_node:
		blink_node.visible = true


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if time_left <= 0.0:
		stop()
		expired.emit()
		return
	_refresh()


func _refresh() -> void:
	text = str(ceili(time_left))
	var warning := time_left <= warning_time
	modulate = warning_color if warning else normal_color
	if blink_node:
		blink_node.visible = not warning or fmod(time_left * blink_speed, 1.0) > 0.4
