class_name ModelUtils
extends RefCounted


## Escala "model" para que su lado más largo mida "target_size" y lo apoya
## centrado sobre el origen de su padre. "model" tiene que estar en la escena
## y sin rotación.
static func fit_to_size(model: Node3D, target_size: float) -> void:
	model.scale = Vector3.ONE
	model.position = Vector3.ZERO
	var bounds := get_bounds(model)
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest <= 0.0:
		return
	var factor := target_size / longest
	model.scale = Vector3.ONE * factor
	var center := bounds.get_center()
	model.position = -Vector3(center.x, bounds.position.y, center.z) * factor


## Caja que encierra todas las mallas de "root", en el espacio local de "root".
static func get_bounds(root: Node3D) -> AABB:
	var to_local := root.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box := (to_local * visual.global_transform) * visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
