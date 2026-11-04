@tool
class_name BarraCarga
extends Control

# Barra de carga dibujada a birome: un rectángulo que se va rayando.

@export var ink_color: Color = Color("1d2140")
@export_range(0.0, 1.0) var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## Separación entre las rayas del relleno.
@export var hatch_spacing: float = 9.0


func _draw() -> void:
	var h := size.y
	var fill := size.x * value
	# Rayas a 45°: cada una va de (x, h) a (x + h, 0), recortada a lo cargado
	var x := -h
	while x < fill:
		var t0 := maxf(0.0, -x)
		var t1 := minf(h, fill - x)
		if t1 > t0:
			draw_line(Vector2(x + t0, h - t0), Vector2(x + t1, h - t1), ink_color, 2.5)
		x += hatch_spacing
	draw_rect(Rect2(Vector2.ZERO, size), ink_color, false, 3.0)
