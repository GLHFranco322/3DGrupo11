class_name CartelContramano
extends Control

# Advertencia grande de "¡CONTRAMANO!" en la mitad de la pantalla de un jugador
# (la pone RaceHud cuando el nivel avisa que va para el lado contrario). Es un
# cartel rojo con borde amarillo, triángulos de advertencia a los costados, que
# titila. Se dibuja todo acá, sin depender de símbolos de la fuente.

@export var text: String = "¡CONTRAMANO!"
@export var subtext: String = "Date vuelta"
@export var background_color: Color = Color(0.8, 0.05, 0.08, 0.88)
@export var border_color: Color = Color(1.0, 0.85, 0.1)
@export var text_color: Color = Color.WHITE
## Titiladas por segundo.
@export_range(0.5, 10.0, 0.5) var pulse_speed: float = 3.0
@export_range(16, 200) var font_size: int = 76
@export_range(10, 100) var subtext_size: int = 30
## Altura del cartel en la pantalla (0 = arriba, 1 = abajo); un poco arriba del
## medio, así no tapa la carretilla.
@export_range(0.0, 1.0, 0.01) var vertical_position: float = 0.36

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_warning(on: bool) -> void:
	if on and not visible:
		_time = 0.0
	visible = on


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# Late: se agranda y achica un poco y titila
	var beat := 0.5 + 0.5 * sin(_time * TAU * pulse_speed * 0.5)
	modulate.a = lerpf(0.65, 1.0, beat)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * lerpf(0.97, 1.04, beat)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon := font_size * 1.1
	var width := text_width + icon * 2.0 + 120.0
	var height := font_size * 1.9 + subtext_size
	var box := Rect2((size.x - width) * 0.5, size.y * vertical_position - height * 0.5, width, height)
	# Fondo y borde
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(8)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	draw_style_box(style, box)
	# Triángulos de advertencia a los costados
	var middle_y := box.position.y + box.size.y * 0.5
	_draw_warning_icon(Vector2(box.position.x + 30.0 + icon * 0.5, middle_y), icon)
	_draw_warning_icon(Vector2(box.end.x - 30.0 - icon * 0.5, middle_y), icon)
	# Textos
	var top := box.position.y + font_size * 1.05
	draw_string_outline(font, Vector2(box.position.x, top), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, font_size, 10, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(box.position.x, top), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, font_size, text_color)
	draw_string(font, Vector2(box.position.x, top + subtext_size * 1.5), subtext, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, subtext_size, border_color)


# Triángulo amarillo con un "!" negro, centrado en "center"
func _draw_warning_icon(center: Vector2, side: float) -> void:
	var h := side * 0.87
	var points := PackedVector2Array([
		center + Vector2(0.0, -h * 0.55), center + Vector2(side * 0.5, h * 0.45), center + Vector2(-side * 0.5, h * 0.45)])
	draw_colored_polygon(points, border_color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.8), 4.0, true)
	var bar := side * 0.09
	draw_rect(Rect2(center.x - bar * 0.5, center.y - h * 0.25, bar, h * 0.4), Color.BLACK)
	draw_circle(center + Vector2(0.0, h * 0.28), bar * 0.6, Color.BLACK)
