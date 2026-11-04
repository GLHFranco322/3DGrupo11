@tool
class_name Casilla
extends Control

# Casilla dibujada a birome; al marcarla se dibuja la tilde de a poco.

@export var ink_color: Color = Color("1d2140")
@export var checked: bool = false:
	set(value):
		if value and not checked and is_inside_tree() and not Engine.is_editor_hint():
			_tick = 0.0
		elif value:
			_tick = 1.0
		checked = value
		queue_redraw()
## Segundos que tarda en dibujarse la tilde.
@export var tick_time: float = 0.18

var _tick: float = 0.0


func _process(delta: float) -> void:
	if checked and _tick < 1.0:
		_tick = minf(_tick + delta / tick_time, 1.0)
		queue_redraw()


func _draw() -> void:
	var s := size
	# Cuadrado un poco torcido, como hecho a mano
	draw_polyline(PackedVector2Array([
			Vector2(s.x * 0.06, s.y * 0.1), Vector2(s.x * 0.95, s.y * 0.04),
			Vector2(s.x * 0.92, s.y * 0.94), Vector2(s.x * 0.04, s.y * 0.97),
			Vector2(s.x * 0.08, s.y * 0.06)]), ink_color, 3.0, true)
	if not checked:
		return
	var points := [Vector2(s.x * 0.15, s.y * 0.5), Vector2(s.x * 0.42, s.y * 0.8), Vector2(s.x * 1.15, -s.y * 0.2)]
	var lengths := [points[0].distance_to(points[1]), points[1].distance_to(points[2])]
	var left: float = (lengths[0] + lengths[1]) * _tick
	var line := PackedVector2Array([points[0]])
	for i in 2:
		var t := clampf(left / lengths[i], 0.0, 1.0)
		line.append(points[i].lerp(points[i + 1], t))
		left -= lengths[i]
		if left <= 0.0:
			break
	draw_polyline(line, Color("c0262d"), 6.0, true)
