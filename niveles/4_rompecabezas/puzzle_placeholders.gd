class_name PuzzlePlaceholders
extends RefCounted

# Dibujos de prueba para los rompecabezas, hechos por código, mientras no estén
# los del artista: sol con colinas, casa, árbol, barco, flor y pez. Formas
# grandes y de colores bien distintos, para que las piezas se reconozcan.

const SIZE := 256
const MOTIFS := 6


## Dibujo número "index" (se repiten cada MOTIFS, con otros colores).
static func make(index: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (index + 1)
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var hue := rng.randf()
	match index % MOTIFS:
		0:
			_sky(image, Color.from_hsv(0.58, 0.45, 1.0), Color.from_hsv(0.55, 0.15, 1.0))
			_circle(image, 190, 70, 38, Color(1.0, 0.85, 0.2))
			_ellipse(image, 70, 270, 150, 110, Color(0.3, 0.7, 0.3))
			_ellipse(image, 220, 290, 140, 120, Color(0.2, 0.55, 0.25))
			for c in [Vector2i(60, 60), Vector2i(85, 50), Vector2i(105, 64)]:
				_circle(image, c.x, c.y, 22, Color.WHITE)
		1:
			_sky(image, Color(0.55, 0.8, 1.0), Color(0.85, 0.95, 1.0))
			image.fill_rect(Rect2i(0, 200, SIZE, 56), Color(0.35, 0.7, 0.3))
			image.fill_rect(Rect2i(60, 120, 136, 90), Color.from_hsv(hue, 0.35, 0.95))
			_triangle(image, Vector2(45, 125), Vector2(211, 125), Vector2(128, 55), Color(0.8, 0.2, 0.15))
			image.fill_rect(Rect2i(110, 160, 36, 50), Color(0.45, 0.28, 0.15))
			image.fill_rect(Rect2i(75, 140, 26, 24), Color(0.6, 0.85, 1.0))
			image.fill_rect(Rect2i(155, 140, 26, 24), Color(0.6, 0.85, 1.0))
			_circle(image, 225, 35, 20, Color(1.0, 0.9, 0.25))
		2:
			_sky(image, Color(0.7, 0.9, 1.0), Color(0.95, 1.0, 0.9))
			image.fill_rect(Rect2i(0, 215, SIZE, 41), Color(0.45, 0.75, 0.3))
			image.fill_rect(Rect2i(112, 140, 32, 80), Color(0.5, 0.32, 0.18))
			for c in [Vector2i(128, 85), Vector2i(85, 115), Vector2i(171, 115), Vector2i(128, 125)]:
				_circle(image, c.x, c.y, 52, Color(0.2, 0.6, 0.25))
			for c in [Vector2i(100, 90), Vector2i(155, 100), Vector2i(125, 130), Vector2i(80, 125), Vector2i(175, 130)]:
				_circle(image, c.x, c.y, 9, Color(0.9, 0.15, 0.15))
		3:
			_sky(image, Color(1.0, 0.75, 0.5), Color(1.0, 0.92, 0.75))
			_circle(image, 128, 150, 45, Color(1.0, 0.55, 0.2))
			image.fill_rect(Rect2i(0, 160, SIZE, 96), Color(0.15, 0.4, 0.7))
			for y in range(170, 256, 18):
				image.fill_rect(Rect2i(0, y, SIZE, 4), Color(0.3, 0.55, 0.85))
			_triangle(image, Vector2(50, 160), Vector2(206, 160), Vector2(80, 195), Color(0.45, 0.25, 0.12))
			_triangle(image, Vector2(206, 160), Vector2(176, 195), Vector2(80, 195), Color(0.45, 0.25, 0.12))
			image.fill_rect(Rect2i(124, 50, 8, 110), Color(0.35, 0.2, 0.1))
			_triangle(image, Vector2(132, 55), Vector2(132, 150), Vector2(200, 150), Color.WHITE)
			_triangle(image, Vector2(124, 70), Vector2(124, 150), Vector2(70, 150), Color.from_hsv(hue, 0.6, 0.95))
		4:
			_sky(image, Color.from_hsv(hue, 0.2, 1.0), Color.from_hsv(hue, 0.1, 1.0))
			image.fill_rect(Rect2i(122, 130, 12, 126), Color(0.25, 0.6, 0.25))
			_ellipse(image, 100, 200, 26, 12, Color(0.3, 0.7, 0.3))
			_ellipse(image, 156, 180, 26, 12, Color(0.3, 0.7, 0.3))
			var petal := Color.from_hsv(fmod(hue + 0.5, 1.0), 0.7, 1.0)
			for i in 8:
				var angle := i * TAU / 8.0
				_circle(image, 128 + int(cos(angle) * 45), 100 + int(sin(angle) * 45), 26, petal)
			_circle(image, 128, 100, 28, Color(1.0, 0.8, 0.15))
		_:
			_sky(image, Color(0.1, 0.45, 0.75), Color(0.4, 0.8, 0.95))
			var body := Color.from_hsv(fmod(hue + 0.08, 1.0), 0.75, 1.0)
			_triangle(image, Vector2(175, 128), Vector2(235, 80), Vector2(235, 176), body.darkened(0.2))
			_ellipse(image, 115, 128, 80, 48, body)
			_circle(image, 70, 115, 10, Color.WHITE)
			_circle(image, 68, 115, 5, Color.BLACK)
			for c in [Vector2i(40, 60), Vector2i(55, 35), Vector2i(30, 20)]:
				_circle(image, c.x, c.y, 8, Color(0.8, 0.95, 1.0))
	return ImageTexture.create_from_image(image)


# Fondo degradé de arriba ("top") a abajo ("bottom")
static func _sky(image: Image, top: Color, bottom: Color) -> void:
	for y in SIZE:
		image.fill_rect(Rect2i(0, y, SIZE, 1), top.lerp(bottom, float(y) / SIZE))


static func _circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	_ellipse(image, cx, cy, radius, radius, color)


# Se pinta de a una fila (fill_rect es rápido)
static func _ellipse(image: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	for y in range(maxi(cy - ry, 0), mini(cy + ry + 1, SIZE)):
		var dy := float(y - cy) / ry
		var half := int(rx * sqrt(maxf(1.0 - dy * dy, 0.0)))
		var from := maxi(cx - half, 0)
		var to := mini(cx + half, SIZE - 1)
		if to >= from:
			image.fill_rect(Rect2i(from, y, to - from + 1, 1), color)


static func _triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var top := int(minf(a.y, minf(b.y, c.y)))
	var bottom := int(maxf(a.y, maxf(b.y, c.y)))
	for y in range(maxi(top, 0), mini(bottom + 1, SIZE)):
		var row := float(y) + 0.5
		var xs: Array[float] = []
		for edge in [[a, b], [b, c], [c, a]]:
			var p: Vector2 = edge[0]
			var q: Vector2 = edge[1]
			if (row >= p.y and row < q.y) or (row >= q.y and row < p.y):
				xs.append(p.x + (row - p.y) / (q.y - p.y) * (q.x - p.x))
		if xs.size() < 2:
			continue
		var from := maxi(int(minf(xs[0], xs[1])), 0)
		var to := mini(int(maxf(xs[0], xs[1])), SIZE - 1)
		if to >= from:
			image.fill_rect(Rect2i(from, y, to - from + 1, 1), color)
