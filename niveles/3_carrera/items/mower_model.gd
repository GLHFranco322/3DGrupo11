@tool
class_name MowerModel
extends Node3D

# Modelo de la cortadora de pasto (el mismo del nivel 1) escalado para medir
# "length" de largo, centrado y apoyado en Y = 0, con el frente hacia -Z. Lo
# usan el item de la pista y la cortadora que se tira.

const MODEL := preload("res://assets/maquinas de pasto/maquina naranja/still/CortadoradepastoModeloNaranja.glb")

## Largo de la cortadora.
@export_range(0.2, 5.0, 0.05, "suffix:u") var length: float = 1.4:
	set(value):
		length = value
		_build()
## Giro del modelo para que el frente (donde está el manubrio, atrás) quede bien.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var yaw_degrees: float = 180.0:
	set(value):
		yaw_degrees = value
		_build()

var _model: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _model:
		_model.free()
	_model = MODEL.instantiate() as Node3D
	# Interno: no se guarda en la escena aunque se arme en el editor
	add_child(_model, false, INTERNAL_MODE_BACK)
	_model.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), Vector3.ZERO)
	var bounds := _bounds()
	var longest := maxf(bounds.size.x, bounds.size.z)
	if longest <= 0.0:
		return
	_model.scale = Vector3.ONE * (length / longest)
	bounds = _bounds()
	var center := bounds.get_center()
	_model.position -= Vector3(center.x, bounds.position.y, center.z)


func _bounds() -> AABB:
	var to_local := global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for node in _model.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box := (to_local * visual.global_transform) * visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
