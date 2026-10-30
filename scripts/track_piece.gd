@tool
class_name TrackPiece
extends Node3D

# Pieza apoyada sobre la pista del nivel 3 (rampa de turbo, reja eléctrica,
# piso cortado). No se mueve a mano: se ubica sola con "Track Offset" (metros
# desde la meta) y "Lateral" (metros al costado del centro). La acomoda el nodo
# TrackPieces, que es su padre y tiene la referencia a la pista.
#
# El dibujo y el área se arman por código según "Length" y "Width", así que se
# ven en el editor al cambiar los valores.

@export_group("Ubicación")
## Metros desde la meta, a lo largo de la pista.
@export_range(0.0, 2000.0, 0.5, "suffix:u") var track_offset: float = 0.0
## Metros al costado del centro de la pista (+ = derecha, mirando hacia adelante).
## La pista mide 14 de ancho: de -7 a 7.
@export_range(-20.0, 20.0, 0.1, "suffix:u") var lateral: float = 0.0

@export_group("Tamaño")
## Largo (a lo largo de la pista).
@export_range(0.5, 60.0, 0.5, "suffix:u") var length: float = 6.0:
	set(value):
		length = value
		_rebuild()
## Ancho (a lo ancho de la pista).
@export_range(0.5, 30.0, 0.5, "suffix:u") var width: float = 4.0:
	set(value):
		width = value
		_rebuild()

## La pista donde está (la pone TrackPieces).
var track: Path3D
## Si es true, el spawner no pone items encima.
var blocks_items: bool = false

var _parts: Node3D


func _ready() -> void:
	add_to_group("track_piece")
	_rebuild()


## Ubica la pieza sobre la pista, mirando hacia adelante.
func place_on(on_track: Path3D) -> void:
	track = on_track
	if track == null or track.curve == null:
		return
	var at := sample_track(track_offset)
	var forward := -at.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		return
	var basis := Basis.looking_at(forward.normalized(), Vector3.UP)
	global_transform = Transform3D(basis, at.origin + basis.x * lateral)


## Punto de la pista a "offset" metros de la meta (da la vuelta si es un circuito).
func sample_track(offset: float) -> Transform3D:
	var length_total := track.curve.get_baked_length()
	if track.curve.closed:
		offset = fposmod(offset, length_total)
	else:
		offset = clampf(offset, 0.0, length_total)
	return track.global_transform * track.curve.sample_baked_with_rotation(offset)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _parts:
		_parts.free()
	_parts = Node3D.new()
	_parts.name = "Parts"
	add_child(_parts)
	_build(_parts)


## Lo implementa cada pieza: arma su dibujo y su área dentro de "root".
func _build(_root: Node3D) -> void:
	pass


# Rectángulo plano apoyado en la pista con un shader
func _make_plane(root: Node3D, shader: Shader, size: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = 0.03
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return material


# Área que detecta las carretillas (más chica que el dibujo según "inset")
func _make_area(root: Node3D, inset: float = 0.0) -> Area3D:
	var area := Area3D.new()
	area.monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(width - inset * 2.0, 0.1), 2.0, maxf(length - inset * 2.0, 0.1))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.0
	area.add_child(collision)
	root.add_child(area)
	return area


# El Racer cuya carretilla es "body" y que va arriba de ella, o null
func _riding_racer(body: Node) -> Racer:
	var racer := Racer.from_body(body)
	if racer and body == racer.barrow and racer.state == Racer.Mode.RIDING:
		return racer
	return null
