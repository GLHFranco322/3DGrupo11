@tool
class_name Libreta
extends Control

# Libreta abierta dibujada (tapa negra, dos hojas rayadas con el encabezado
# impreso, cinta separadora y elástico), como la de la foto del tutorial.
# El texto y los dibujos van en nodos aparte; get_rule_y() da la altura de
# cada renglón para apoyar el texto encima.

@export_group("Colores")
@export var cover_color: Color = Color("141519")
@export var page_color: Color = Color("f4efe2")
@export var page_edge_color: Color = Color("ddd5c0")
@export var rule_color: Color = Color(0.55, 0.55, 0.56, 0.75)
@export var print_color: Color = Color(0.42, 0.42, 0.45)
@export var ribbon_color: Color = Color("3a2a22")

@export_group("Medidas")
## Tapa que se ve alrededor de las hojas.
@export var page_margin: float = 18.0
@export var spine_gap: float = 14.0
## Altura del encabezado impreso (íconos, días, Memo/Date).
@export var header_height: float = 128.0
## Distancia del borde de arriba de la hoja al primer renglón.
@export var first_rule: float = 174.0
@export var rule_spacing: float = 56.0
## Largo del elástico que sale por la derecha.
@export var strap_length: float = 200.0

const DAYS := ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]


## Altura (en coordenadas de la libreta) del renglón número "index".
func get_rule_y(index: int) -> float:
	return page_margin + first_rule + index * rule_spacing


func get_rule_count() -> int:
	var bottom := size.y - page_margin - 34.0
	return int((bottom - page_margin - first_rule) / rule_spacing) + 1


func _draw() -> void:
	_draw_shadow()
	_draw_ribbons()
	_draw_strap()
	_draw_cover()
	var half := size.x / 2.0
	var top := page_margin
	var bottom := size.y - page_margin
	var left_page := Rect2(page_margin, top, half - spine_gap / 2.0 - page_margin, bottom - top)
	var right_page := Rect2(half + spine_gap / 2.0, top, left_page.size.x, bottom - top)
	_draw_page(left_page, true)
	_draw_page(right_page, false)


func _draw_shadow() -> void:
	for i in 8:
		var grow := 4.0 + i * 5.0
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.06)
		box.set_corner_radius_all(int(28 + grow))
		draw_style_box(box, Rect2(Vector2(14, 22) - Vector2.ONE * grow, size + Vector2.ONE * grow * 2.0))


func _draw_ribbons() -> void:
	var x := size.x / 2.0 - 46.0
	draw_rect(Rect2(x, -26, 22, 60), ribbon_color)
	draw_rect(Rect2(size.x / 2.0 - 70.0, size.y - 30.0, 20, 56), ribbon_color.darkened(0.2))


func _draw_strap() -> void:
	var h := 92.0
	var y := size.y * 0.5 - h / 2.0
	var rect := Rect2(size.x - 40.0, y, strap_length + 40.0, h)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.06)
	box.corner_radius_top_right = 20
	box.corner_radius_bottom_right = 20
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 10
	box.shadow_offset = Vector2(6, 8)
	draw_style_box(box, rect)
	# Brillo arriba y costura donde se dobla el elástico
	draw_rect(Rect2(rect.position + Vector2(0, 6), Vector2(rect.size.x - 20, 10)), Color(1, 1, 1, 0.06))
	var fold := size.x + strap_length * 0.42
	draw_line(Vector2(fold, y + 4), Vector2(fold, y + h - 4), Color(1, 1, 1, 0.12), 3.0)
	draw_line(Vector2(fold + 4, y + 4), Vector2(fold + 4, y + h - 4), Color(0, 0, 0, 0.5), 2.0)


func _draw_cover() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = cover_color
	box.set_corner_radius_all(26)
	box.border_color = cover_color.lightened(0.12)
	box.set_border_width_all(2)
	draw_style_box(box, Rect2(Vector2.ZERO, size))


func _draw_page(rect: Rect2, is_left: bool) -> void:
	# Canto de las hojas de abajo (se ve el grosor de la libreta)
	for i in range(3, 0, -1):
		var edge := StyleBoxFlat.new()
		edge.bg_color = page_edge_color.darkened(i * 0.05)
		_round_outer(edge, is_left, 20)
		var offset := Vector2(-i * 2.0 if is_left else i * 2.0, i * 2.5)
		draw_style_box(edge, Rect2(rect.position + offset, rect.size))

	var page := StyleBoxFlat.new()
	page.bg_color = page_color
	_round_outer(page, is_left, 20)
	draw_style_box(page, rect)

	# Sombra del lomo: la hoja se curva hacia el centro
	var spine_x := rect.end.x if is_left else rect.position.x
	var dir := -1.0 if is_left else 1.0
	var width := 46.0
	var dark := Color(0.25, 0.2, 0.12, 0.22)
	var clear := Color(0.25, 0.2, 0.12, 0.0)
	draw_polygon(PackedVector2Array([
			Vector2(spine_x, rect.position.y), Vector2(spine_x + dir * width, rect.position.y),
			Vector2(spine_x + dir * width, rect.end.y), Vector2(spine_x, rect.end.y)]),
			PackedColorArray([dark, clear, clear, dark]))

	# Lo impreso va en letra de imprenta, no con la fuente manuscrita del tema
	var font := ThemeDB.fallback_font
	var x0 := rect.position.x + 30.0
	var x1 := rect.end.x - 30.0
	var top := rect.position.y

	# Encabezado impreso: íconos del clima y días de la semana
	for i in 3:
		var icon := Rect2(x0 + 6 + i * 34.0, top + 40.0, 24, 24)
		draw_rect(icon, print_color, false, 1.5)
		_draw_weather(i, icon)
	for i in DAYS.size():
		var day := Rect2(x0 + i * 26.0, top + 76.0, 23, 15)
		draw_rect(day, print_color, false, 1.0)
		draw_string(font, day.position + Vector2(3, 12), DAYS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, print_color)
	if is_left:
		draw_string(font, Vector2(x1 - 255, top + 66), "Nota N°", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, print_color)
		draw_line(Vector2(x1 - 185, top + 70), Vector2(x1, top + 70), print_color, 1.0)
	draw_string(font, Vector2(x1 - 255, top + 104), "Fecha", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, print_color)
	draw_line(Vector2(x1 - 185, top + 108), Vector2(x1, top + 108), print_color, 1.0)
	draw_line(Vector2(x0, top + header_height), Vector2(x1, top + header_height), print_color.darkened(0.5), 2.5)

	# Renglones; el último más grueso, como en la libreta
	var count := get_rule_count()
	for i in count:
		var y := get_rule_y(i)
		var last := i == count - 1
		draw_line(Vector2(x0, y), Vector2(x1, y), print_color.darkened(0.5) if last else rule_color,
				2.5 if last else 1.5)


func _round_outer(box: StyleBoxFlat, is_left: bool, radius: int) -> void:
	box.corner_radius_top_left = radius if is_left else 4
	box.corner_radius_bottom_left = radius if is_left else 4
	box.corner_radius_top_right = 4 if is_left else radius
	box.corner_radius_bottom_right = 4 if is_left else radius


# Sol, nube y paraguas en miniatura, como los del encabezado de la libreta
func _draw_weather(kind: int, r: Rect2) -> void:
	var c := r.get_center()
	match kind:
		0:
			draw_arc(c, 4.5, 0, TAU, 16, print_color, 1.2)
			for i in 8:
				var d := Vector2.RIGHT.rotated(i * TAU / 8.0)
				draw_line(c + d * 6.5, c + d * 9.0, print_color, 1.2)
		1:
			draw_arc(c + Vector2(-3, 1), 4.5, PI, TAU, 10, print_color, 1.2)
			draw_arc(c + Vector2(3, 0), 5.5, PI, TAU, 10, print_color, 1.2)
			draw_line(c + Vector2(-8, 1), c + Vector2(9, 1), print_color, 1.2)
			draw_line(c + Vector2(-6, 7), c + Vector2(6, -6), print_color, 1.2)
		2:
			draw_arc(c + Vector2(0, 2), 8.0, PI, TAU, 14, print_color, 1.2)
			draw_line(c + Vector2(-8, 2), c + Vector2(8, 2), print_color, 1.2)
			draw_line(c + Vector2(0, 2), c + Vector2(0, 9), print_color, 1.2)
