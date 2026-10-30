@tool
class_name TrackHole
extends TrackPiece

# Piso cortado: un hueco de verdad en la pista (agujerea la calle y el suelo con
# CSG), para que la calle se angoste. Si una carretilla entra, sigue de largo
# cayendo al vacío, desaparece y reaparece en un lugar seguro cerca (lo elige
# TrackPieces). Para angostar la calle de los dos lados se ponen dos, una a cada
# costado. Abajo tiene un pozo con paredes que brillan y se apagan hacia el fondo.

const BAND_SHADER := preload("res://shaders/track_hole.gdshader")
const SHAFT_SHADER := preload("res://shaders/track_hole_shaft.gdshader")

@export_group("Caída")
## Cuánto hay que meterse en el hueco para caer (el borde perdona un poco).
@export_range(0.0, 3.0, 0.05, "suffix:u") var edge_tolerance: float = 0.3:
	set(value):
		edge_tolerance = value
		_rebuild()

@export_group("Dibujo")
@export var edge_color: Color = Color(1.0, 0.35, 0.05):
	set(value):
		edge_color = value
		_rebuild()
## Brillo del borde (más de 1 = resplandor).
@export_range(0.0, 10.0, 0.1) var energy: float = 2.5:
	set(value):
		energy = value
		_rebuild()
## Profundidad del pozo que se ve debajo.
@export_range(1.0, 100.0, 0.5, "suffix:u") var shaft_depth: float = 25.0:
	set(value):
		shaft_depth = value
		_rebuild()

var _area: Area3D
# Una caja que resta por cada forma que agujerea (calle, suelo)
var _cutters: Array[CSGBox3D] = []


func _ready() -> void:
	blocks_items = true
	super()


func _exit_tree() -> void:
	_free_cutters()


func _build(root: Node3D) -> void:
	_free_cutters()
	var band := _make_plane(root, BAND_SHADER, Vector2(width, length))
	band.set_shader_parameter("edge_color", edge_color)
	band.set_shader_parameter("energy", energy)
	band.set_shader_parameter("size_m", Vector2(width, length))

	# Pozo: una caja dada vuelta (se ven sus paredes de adentro), debajo de la calle
	var shaft_material := ShaderMaterial.new()
	shaft_material.shader = SHAFT_SHADER
	shaft_material.set_shader_parameter("edge_color", edge_color)
	shaft_material.set_shader_parameter("energy", energy)
	shaft_material.set_shader_parameter("depth", shaft_depth)
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(width, shaft_depth, length)
	shaft_mesh.flip_faces = true
	shaft_mesh.material = shaft_material
	var shaft := MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.position.y = -0.32 - shaft_depth * 0.5
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shaft)

	# El área llega bien abajo: si alguien se mete sin tocar el borde, igual cae
	_area = _make_area(root, edge_tolerance)
	var shape := _area.get_child(0) as CollisionShape3D
	(shape.shape as BoxShape3D).size.y = 12.0
	shape.position.y = -4.0


func place_on(on_track: Path3D) -> void:
	super(on_track)
	_update_cutters()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _area == null:
		return
	for body in _area.get_overlapping_bodies():
		var racer := _riding_racer(body)
		if racer and racer.fall_into_void():
			Audio.play_sfx(Audio.void_fall if Audio.void_fall else Audio.pit_fall)


## true si "point" está dentro del hueco (o a menos de "margin" de su borde).
func contains(point: Vector3, margin: float = 0.0) -> bool:
	var local := global_transform.affine_inverse() * point
	return absf(local.x) < width * 0.5 + margin and absf(local.z) < length * 0.5 + margin


# Agujerea la calle y el suelo con una caja que resta, en el mismo lugar que el hueco
func _update_cutters() -> void:
	var pieces := get_parent() as TrackPieces
	if pieces == null or not is_inside_tree():
		return
	if _cutters.is_empty():
		for target in pieces.cut_shapes:
			if target == null:
				continue
			var cutter := CSGBox3D.new()
			cutter.name = "HoleCut"
			cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
			target.add_child(cutter)
			_cutters.append(cutter)
	for cutter in _cutters:
		if not is_instance_valid(cutter):
			continue
		var size := Vector3(width, 4.0, length)
		if not cutter.size.is_equal_approx(size):
			cutter.size = size
		# Solo si cambió: mover la caja hace que se recalcule la forma
		if not cutter.global_transform.is_equal_approx(global_transform):
			cutter.global_transform = global_transform


func _free_cutters() -> void:
	for cutter in _cutters:
		if is_instance_valid(cutter):
			cutter.queue_free()
	_cutters.clear()
