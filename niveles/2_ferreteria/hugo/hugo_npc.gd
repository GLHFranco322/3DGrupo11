class_name HugoNPC
extends Node3D

# Hugo, el cubo: decoración de la ferretería. Está parado al lado del tablero
# donde se cuelgan las herramientas, quieto y anotando (animación "take note"
# del .glb). Lo pone StoreLevel.
#
# Si el .glb viniera sin la malla (solo esqueleto y animaciones, como una
# versión anterior), se arma un Hugo provisorio con formas simples pegadas a
# los huesos. Con el .glb actual, que trae el modelo, el provisorio no se arma.

## Modelo de Hugo (.glb con esqueleto y animaciones).
@export var model_scene: PackedScene = preload("res://assets/personajes/Hugo/Sebuscagerente-Personaje-Hugo-Cubo-antesderiggear-take-animacion-note-2.glb")
## Animación que hace en loop (nombre ya normalizado, ver AnimNames).
@export var animation: StringName = &"anotar"
## Alto de Hugo (se escala el modelo para que mida esto, con los pies en el piso).
@export_range(0.5, 5.0, 0.05, "suffix:u") var height: float = 1.5
## Radio de la colisión (para que no lo atraviesen).
@export_range(0.1, 3.0, 0.05, "suffix:u") var collision_radius: float = 0.55

@export_group("Provisorio (sin malla)")
@export var body_color: Color = Color(0.35, 0.7, 1.0)
@export var limb_color: Color = Color.BLACK
@export var glove_color: Color = Color.WHITE

var _model: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
# Provisorio: [MeshInstance3D, hueso desde, hueso hasta] de brazos y piernas,
# y [MeshInstance3D, hueso, offset] de lo que va pegado a un hueso
var _limbs: Array = []
var _attached: Array = []


func _ready() -> void:
	_model = model_scene.instantiate() as Node3D
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	AnimNames.normalize(_anim)
	if _anim and _anim.has_animation(animation):
		_anim.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
		_anim.play(animation)
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] if not skeletons.is_empty() else null
	if _skeleton and _model.find_children("*", "MeshInstance3D", true, false).is_empty():
		_build_placeholder()
	_fit_height()
	_build_collision()


func _process(_delta: float) -> void:
	_update_placeholder()


# Lo escala para que mida "height". El .glb ya viene con los pies en el piso
# (en el origen), así que no se lo mueve. Se mide la malla del cuerpo (la que
# tiene esqueleto) en su propio espacio: llevada al mundo queda corrida hacia
# arriba por el "Armature" del .glb, y moverlo según eso lo hundía en el piso.
func _fit_height() -> void:
	var model_height := 0.0
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.skin != null:
			model_height = maxf(model_height, mesh.get_aabb().size.y)
	if model_height <= 0.0:
		return
	_model.scale = Vector3.ONE * (height / model_height)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	# En la capa de los objetos sueltos: los jugadores lo chocan, pero la cámara
	# no lo esquiva como si fuera una pared
	body.collision_layer = 1 << (ObjetoSuelto.LAYER - 1)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = collision_radius
	capsule.height = maxf(height, collision_radius * 2.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	body.add_child(shape)
	add_child(body)


# --- Provisorio ---------------------------------------------------------------

func _build_placeholder() -> void:
	# Bone.002 es el que mueve la animación de anotar (se inclina)
	var body_bone := _bone("Bone.002")
	# El cuerpo: un cubo (los brazos salen de los costados)
	_attach(_box(Vector3(3.4, 3.2, 2.2), body_color), body_bone, Vector3.ZERO)
	# Ojos mirando al frente (+Z)
	for side in [-1.0, 1.0]:
		var eye := _sphere(0.42, Color.WHITE)
		eye.scale = Vector3(1.0, 1.25, 0.45)
		_attach(eye, body_bone, Vector3(side * 0.65, 0.65, 1.12))
		_attach(_sphere(0.18, Color.BLACK), body_bone, Vector3(side * 0.6, 0.6, 1.3))
	# Brazos y piernas: cadenas de huesos
	for side in ["L", "R"]:
		var arm := ["Bone.004.%s", "Bone.005.%s", "Bone.006.%s", "Bone.007.%s", "Bone.021.%s"]
		var leg := ["Bone.010.%s", "Bone.011.%s", "Bone.012.%s", "Bone.022.%s"]
		for chain in [arm, leg]:
			for i in chain.size() - 1:
				var from := _bone(chain[i] % side)
				var to := _bone(chain[i + 1] % side)
				if from >= 0 and to >= 0:
					_limbs.append([_cylinder(0.14, limb_color), from, to])
		# Guante en la mano y zapato en el pie
		_attach(_sphere(0.45, glove_color), _bone("Bone.021.%s" % side), Vector3.ZERO)
		_attach(_box(Vector3(0.8, 0.45, 1.2), glove_color), _bone("Bone.022.%s" % side), Vector3(0.0, -0.1, 0.25))
	# La libreta en la mano izquierda y el lápiz en la derecha (está anotando)
	_attach(_box(Vector3(1.1, 1.4, 0.18), Color(0.95, 0.93, 0.85)), _bone("Bone.021.L"), Vector3(0.0, 0.5, 0.35))
	_attach(_box(Vector3(1.15, 1.45, 0.08), Color(0.55, 0.3, 0.15)), _bone("Bone.021.L"), Vector3(0.0, 0.5, 0.24))
	var pen := _cylinder(0.07, Color(0.15, 0.25, 0.8))
	pen.scale = Vector3(1.0, 1.1, 1.0)
	_attach(pen, _bone("Bone.021.R"), Vector3(0.0, 0.3, 0.3))
	for limb in _limbs:
		_skeleton.add_child(limb[0])
	_update_placeholder()


func _update_placeholder() -> void:
	if _skeleton == null:
		return
	for item in _attached:
		var pose := _skeleton.get_bone_global_pose(item[1])
		# Solo la posición y el giro del hueso (no su escala)
		item[0].transform = Transform3D(pose.basis.orthonormalized(), pose.origin) * Transform3D(item[0].get_meta("base_basis"), item[2])
	for limb in _limbs:
		var a := _skeleton.get_bone_global_pose(limb[1]).origin
		var b := _skeleton.get_bone_global_pose(limb[2]).origin
		var length := a.distance_to(b)
		if length < 0.001:
			continue
		var up := (b - a) / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var basis := Basis(side, up, side.cross(up)).scaled(Vector3(1.0, length, 1.0))
		limb[0].transform = Transform3D(basis, (a + b) * 0.5)


func _bone(bone_name: String) -> int:
	return _skeleton.find_bone(bone_name)


func _attach(mesh: MeshInstance3D, bone: int, offset: Vector3) -> void:
	if bone < 0:
		mesh.queue_free()
		return
	mesh.set_meta("base_basis", mesh.basis)
	_skeleton.add_child(mesh)
	_attached.append([mesh, bone, offset])


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


# Cilindro de alto 1 (se estira entre dos huesos)
func _cylinder(radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance
