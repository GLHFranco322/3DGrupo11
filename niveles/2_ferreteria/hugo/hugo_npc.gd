class_name HugoNPC
extends Node3D

# Hugo, el cubo: está parado en la zona de atención de la ferretería, al lado
# de la mesa, anotando (animación "take note" del .glb) y girando de a poco
# hacia el jugador que tenga más cerca. Lo pone StoreLevel.
#
# El .glb de Hugo que hay ahora trae solo el esqueleto y las animaciones (se
# exportó sin la malla). Mientras sea así, se arma un Hugo provisorio con
# formas simples pegadas a los huesos (cubo, ojos, brazos, guantes y zapatos),
# que siguen la animación. Cuando el .glb traiga el modelo, el provisorio no
# se arma.

## Modelo de Hugo (.glb con esqueleto y animaciones).
@export var model_scene: PackedScene = preload("res://assets/personajes/Hugo/Sebuscagerente-Personaje-Hugo-Cubo-takenote-2.glb")
## Animación que hace en loop (nombre ya normalizado, ver AnimNames).
@export var animation: StringName = &"anotar"
## Alto de Hugo (se escala el modelo para que mida esto, con los pies en el piso).
@export_range(0.5, 5.0, 0.05, "suffix:u") var height: float = 2.0
## Qué tan rápido gira hacia el jugador.
@export_range(0.1, 20.0, 0.1) var turn_speed: float = 3.0
## Mira a los jugadores que estén a esta distancia o menos (si no hay, mira al frente).
@export_range(1.0, 100.0, 0.5, "suffix:u") var look_range: float = 25.0
## A quiénes mira (los pone StoreLevel).
@export var targets: Array[Node3D] = []
## Radio de la colisión (para que no lo atraviesen).
@export_range(0.1, 3.0, 0.05, "suffix:u") var collision_radius: float = 0.7

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
var _front_yaw: float = 0.0


func _ready() -> void:
	_front_yaw = rotation.y
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


func _process(delta: float) -> void:
	_turn_to_target(delta)
	_update_placeholder()


# Gira (solo en Y) hacia el jugador más cercano; si no hay ninguno cerca, al frente
func _turn_to_target(delta: float) -> void:
	var goal := _front_yaw
	var best := look_range
	for target in targets:
		if not is_instance_valid(target):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() < best and offset.length() > 0.1:
			best = offset.length()
			# Los modelos miran a +Z
			goal = atan2(offset.x, offset.z)
	rotation.y = lerp_angle(rotation.y, goal, minf(turn_speed * delta, 1.0))


# Lo escala para que mida "height" y lo apoya en el piso. Se mide lo que se ve
# (el .glb trae el esqueleto achicado adentro, así que los huesos no sirven)
func _fit_height() -> void:
	var to_model := global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = to_model * (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first or box.size.y <= 0.0:
		return
	var factor := height / box.size.y
	_model.scale = Vector3.ONE * factor
	_model.position.y = -box.position.y * factor


func _build_collision() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = collision_radius
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
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
