class_name ObjetoSuelto
extends RigidBody3D

# Mueble chico que se puede chocar, como los conos: lo arma MazeBuilder con una
# pieza del kit. Los jugadores lo empujan al chocarlo (StorePlayer): caminando
# se corre, corriendo (o patinando en el hielo) se cae.
#
# Va en su propia capa de colisión ("Objetos sueltos"), así la cámara no lo
# esquiva como si fuera una pared.

## Capa de colisión de los objetos sueltos.
const LAYER := 4


## Arma un objeto suelto con una pieza del kit (con el metadato "bounds"). El
## origen queda en el piso, en el medio de la pieza.
static func from_piece(scene: PackedScene, piece_mass: float = 1.5) -> ObjetoSuelto:
	var body := ObjetoSuelto.new()
	var visual := scene.instantiate() as Node3D
	var bounds: AABB = visual.get_meta("bounds", AABB())
	var center := bounds.get_center()
	visual.position = -Vector3(center.x, 0.0, center.z)
	body.add_child(visual)
	body.set_meta("base_offset", Vector3(center.x, 0.0, center.z))

	# Colisión: la forma convexa de sus mallas
	var points := PackedVector3Array()
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var xform := mesh_instance.transform
		var parent := mesh_instance.get_parent()
		while parent != body:
			xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		var shape := mesh_instance.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		for point in shape.points:
			points.append(xform * point)
	var collision := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	collision.shape = convex
	body.add_child(collision)

	body.mass = piece_mass
	# Se frena solo (rozamiento con el piso, aunque ruede tirado)
	body.linear_damp = 1.5
	body.angular_damp = 1.5
	# Pesado abajo, como un cono de verdad: se para solo si apenas se lo toca
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0.0, bounds.size.y * 0.25, 0.0)
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.1
	body.physics_material_override = material
	body.collision_layer = 1 << (LAYER - 1)
	body.collision_mask = 1 | (1 << (LAYER - 1))
	return body
