@tool
class_name TrackPieces
extends Node3D

# Agrupa las piezas de la pista (TrackPiece: rampas de turbo, rejas eléctricas,
# piso cortado) y las acomoda sobre el recorrido según su "Track Offset" y
# "Lateral". En el editor las reacomoda todo el tiempo, así que si se mueven los
# puntos de la pista, las piezas la siguen.
#
# También busca el lugar seguro donde reaparece quien se cae al vacío.

## La pista sobre la que van las piezas.
@export var track: Path3D
## Formas CSG que el piso cortado agujerea (la calle y el suelo).
@export var cut_shapes: Array[CSGShape3D] = []

@export_group("Reaparecer")
## Distancias al centro de la pista que se prueban (en orden) para reaparecer.
@export var safe_laterals: PackedFloat32Array = [0.0, -3.5, 3.5, -5.5, 5.5, -2.0, 2.0]
## Distancia mínima al borde de un hueco para que el lugar cuente como seguro.
@export_range(0.0, 5.0, 0.1, "suffix:u") var safe_margin: float = 1.5
## Si al costado no hay lugar seguro, se prueba hasta estos metros más atrás.
@export_range(0.0, 50.0, 1.0, "suffix:u") var max_step_back: float = 20.0


func _ready() -> void:
	add_to_group("track_pieces")
	place_all()
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	place_all()


func place_all() -> void:
	if track == null:
		return
	for child in get_children():
		if child is TrackPiece:
			child.place_on(track)


## Lugar seguro sobre la pista cerca de "near", mirando hacia adelante: a la
## misma altura del recorrido, en el primer carril sin hueco. Si no hay, prueba
## un poco más atrás.
func find_safe_spot(near: Vector3) -> Transform3D:
	var curve := track.curve
	var offset := curve.get_closest_offset(track.global_transform.affine_inverse() * near)
	var back := 0.0
	while back <= max_step_back:
		var at := _sample(offset - back)
		for lateral in safe_laterals:
			var point := at.origin + at.basis.x * lateral
			if _is_safe(point):
				return Transform3D(at.basis, point)
		back += 4.0
	var fallback := _sample(offset)
	return Transform3D(fallback.basis, fallback.origin)


# Punto de la pista, ya sin inclinación (mirando hacia adelante)
func _sample(offset: float) -> Transform3D:
	var length := track.curve.get_baked_length()
	offset = fposmod(offset, length) if track.curve.closed else clampf(offset, 0.0, length)
	var at := track.global_transform * track.curve.sample_baked_with_rotation(offset)
	var forward := -at.basis.z
	forward.y = 0.0
	return Transform3D(Basis.looking_at(forward.normalized(), Vector3.UP), at.origin)


func _is_safe(point: Vector3) -> bool:
	for child in get_children():
		if child is TrackHole and child.contains(point, safe_margin):
			return false
	return true
