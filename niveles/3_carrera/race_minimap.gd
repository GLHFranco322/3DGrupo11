class_name RaceMinimap
extends Control

# Minimapa del circuito visto desde arriba: el dibujo de la pista, la meta y una
# flecha del color de cada jugador que apunta para donde va. La pista se saca
# del Path3D del nivel, así que si se cambia el recorrido el mapa se actualiza
# solo. Arriba del mapa es -Z del mundo.

@export_group("Pista")
## Ancho del dibujo de la pista.
@export_range(1.0, 30.0, 0.5, "suffix:px") var track_width: float = 7.0
@export var track_color: Color = Color(0.85, 0.85, 0.95, 0.9)
## Borde de la pista (se dibuja por debajo, un poco más ancho).
@export_range(0.0, 10.0, 0.5, "suffix:px") var border_width: float = 2.0
@export var border_color: Color = Color(0.1, 0.9, 1.0, 0.9)
@export var finish_color: Color = Color(1.0, 0.15, 0.6)
## Margen entre el borde del mapa y la pista.
@export_range(0.0, 60.0, 1.0, "suffix:px") var padding: float = 14.0

@export_group("Jugadores")
## Tamaño de la flecha de cada jugador.
@export_range(2.0, 30.0, 0.5, "suffix:px") var marker_size: float = 9.0
@export var marker_outline: Color = Color(0, 0, 0, 0.9)

@export_group("Fondo")
## Fondo del mapa (vacío = sin fondo).
@export var background: StyleBox

var _racers: Array[Racer] = []
var _track: Path3D
# Puntos de la pista en el plano X/Z del mundo
var _points := PackedVector2Array()
var _bounds := Rect2()


func setup(racers: Array[Racer], track: Path3D) -> void:
	_racers = racers
	_track = track
	_points.clear()
	if track == null:
		return
	for p in track.curve.get_baked_points():
		var world := track.global_transform * p
		_points.append(Vector2(world.x, world.z))
	if track.curve.closed and _points.size() > 1:
		_points.append(_points[0])
	_bounds = Rect2(_points[0], Vector2.ZERO)
	for p in _points:
		_bounds = _bounds.expand(p)
	queue_redraw()


func _process(_delta: float) -> void:
	if not _racers.is_empty():
		queue_redraw()


func _draw() -> void:
	if background:
		draw_style_box(background, Rect2(Vector2.ZERO, size))
	if _points.size() < 2:
		return
	var map := PackedVector2Array()
	for p in _points:
		map.append(_to_map(p))
	if border_width > 0.0:
		draw_polyline(map, border_color, track_width + border_width * 2.0, true)
	draw_polyline(map, track_color, track_width, true)
	_draw_finish()
	# El que va primero se dibuja último (queda arriba)
	var order := _racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool: return a.progress < b.progress)
	for r in order:
		_draw_marker(r)


func _draw_finish() -> void:
	var at := _track.global_transform * _track.curve.sample_baked_with_rotation(0.0)
	var side := Vector2(at.basis.x.x, at.basis.x.z).normalized()
	var center := _to_map(Vector2(at.origin.x, at.origin.z))
	var half := side * (track_width * 0.5 + border_width + 2.0)
	draw_line(center - half, center + half, finish_color, 3.0, true)


func _draw_marker(r: Racer) -> void:
	var pos := r.barrow.global_position
	var forward := r.get_forward()
	var dir := Vector2(forward.x, forward.z).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var side := Vector2(-dir.y, dir.x)
	var center := _to_map(Vector2(pos.x, pos.z))
	var tip := center + dir * marker_size
	var left := center - dir * marker_size * 0.6 + side * marker_size * 0.7
	var right := center - dir * marker_size * 0.6 - side * marker_size * 0.7
	var outline := PackedVector2Array([tip, left, right, tip])
	draw_colored_polygon(PackedVector2Array([tip, left, right]), r.color)
	draw_polyline(outline, marker_outline, 2.0, true)


# Del plano X/Z del mundo al rectángulo del mapa (sin deformar)
func _to_map(world: Vector2) -> Vector2:
	var area := size - Vector2.ONE * padding * 2.0
	var scale_factor := minf(area.x / maxf(_bounds.size.x, 0.001), area.y / maxf(_bounds.size.y, 0.001))
	var used := _bounds.size * scale_factor
	var origin := Vector2.ONE * padding + (area - used) * 0.5
	return origin + (world - _bounds.position) * scale_factor
