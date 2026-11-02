class_name PuzzlePiece
extends Node3D

# Pieza cuadrada de un rompecabezas: un cartón grueso con su pedazo de la
# imagen arriba. La crea PuzzleBoard; su posición es en el espacio del tablero.

## Lugar de la pieza en la grilla (columna, fila; la fila 0 es la de arriba de la imagen).
var slot: Vector2i
## Dónde va en el tablero (espacio local del tablero).
var target: Vector3
## Ya encastró en su lugar (no se puede mover más).
var placed: bool = false
## Lado de la pieza.
var size: float = 0.2
## Para saber cuál está arriba cuando dos se pisan (más alto = arriba).
var stack_order: int = 0

var _top_material: StandardMaterial3D
var _visual: Node3D
var _highlighted: bool = false


## Arma la pieza mostrando su pedazo de "texture" (una grilla de "grid" x "grid").
func setup(texture: Texture2D, grid: int, piece_slot: Vector2i, piece_size: float, thickness: float, side_color: Color) -> void:
	slot = piece_slot
	size = piece_size
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(piece_size * 0.985, thickness, piece_size * 0.985)
	var side := StandardMaterial3D.new()
	side.albedo_color = side_color
	side.roughness = 0.9
	box.material = side
	body.mesh = box
	body.position.y = thickness * 0.5
	_visual.add_child(body)

	# Arriba: un plano con solo su pedazo de la imagen (escala y corrimiento de UV)
	_top_material = StandardMaterial3D.new()
	_top_material.albedo_texture = texture
	_top_material.roughness = 0.6
	_top_material.uv1_scale = Vector3(1.0 / grid, 1.0 / grid, 1.0)
	_top_material.uv1_offset = Vector3(float(piece_slot.x) / grid, float(piece_slot.y) / grid, 0.0)
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * piece_size * 0.985
	plane.material = _top_material
	top.mesh = plane
	top.position.y = thickness + 0.0008
	_visual.add_child(top)


## true si "point" (espacio del tablero, se ignora la altura) cae sobre la pieza.
func contains(point: Vector3) -> bool:
	return absf(point.x - position.x) <= size * 0.5 and absf(point.z - position.z) <= size * 0.5


## Resalta la pieza (la que está debajo del cursor o en la mano).
func set_highlight(on: bool) -> void:
	if on == _highlighted or _top_material == null:
		return
	_highlighted = on
	_top_material.emission_enabled = on
	_top_material.emission = Color(1.0, 0.95, 0.75)
	_top_material.emission_energy_multiplier = 0.35
	_visual.scale = Vector3.ONE * (1.06 if on else 1.0)


## Aparece con un pop (crece pasándose un poquito) después de "delay" segundos.
func pop_in(delay: float, time: float) -> void:
	_visual.scale = Vector3.ONE * 0.001
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(Audio.play_sfx.bind(Audio.puzzle_pop_in, 0.0, -6.0))
	tween.tween_property(_visual, "scale", Vector3.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Desaparece con un pop (se infla y se achica) y se borra.
func pop_out(delay: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(Audio.play_sfx.bind(Audio.puzzle_pop_out, 0.0, -6.0))
	tween.tween_property(_visual, "scale", Vector3.ONE * 1.25, time * 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.001, time * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Rebote cortito al encastrar.
func bounce() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 1.12, 0.07)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
