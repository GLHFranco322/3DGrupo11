@tool
class_name VistaItem3D
extends SubViewportContainer

# Muestra un item del juego en 3D, girando despacio, para que en el tutorial se
# vea igual que en la partida. Copia solo lo que se ve (mallas y materiales):
# no ejecuta los scripts del item ni crea sus áreas.

## Escena del item (por ejemplo res://niveles/1_patio/items/rock.tscn).
@export var item_scene: PackedScene:
	set(value):
		item_scene = value
		_rebuild()
## Parte de la escena que se muestra (vacío = toda). Ej: "Visuals/Banana".
@export var node_path: NodePath:
	set(value):
		node_path = value
		_rebuild()
## Vueltas por segundo.
@export var spin_speed: float = 0.2
## Cuánto mira la cámara hacia abajo, en grados.
@export_range(0.0, 89.0) var camera_pitch: float = 28.0
## Aire alrededor del item (1 = justo).
@export var padding: float = 1.1
@export var light_energy: float = 1.3
@export var ambient_energy: float = 0.7

var _viewport: SubViewport
var _pivot: Node3D


func _ready() -> void:
	stretch = true
	mouse_filter = MOUSE_FILTER_IGNORE
	_rebuild()


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotate_y(TAU * spin_speed * delta)


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _viewport:
		_viewport.queue_free()
		_pivot = null
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	# Interno: no se guarda en la escena aunque se arme en el editor
	add_child(_viewport, false, INTERNAL_MODE_BACK)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = ambient_energy
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.light_energy = light_energy
	light.rotation_degrees = Vector3(-50, 35, 0)
	_viewport.add_child(light)

	if item_scene == null:
		return
	var source := item_scene.instantiate()
	var shown: Node = source.get_node_or_null(node_path) if not node_path.is_empty() else source
	if shown == null:
		push_warning("VistaItem3D: no existe %s en %s" % [node_path, item_scene.resource_path])
		source.free()
		return
	var model := _visual_copy(shown, true)
	source.free()
	var box := _mesh_bounds(model, Transform3D.IDENTITY)
	var center := box.get_center()
	model.position = -Vector3(center.x, 0.0, center.z)
	_pivot = Node3D.new()
	_pivot.add_child(model)
	_viewport.add_child(_pivot)

	var camera := Camera3D.new()
	camera.fov = 30.0
	var radius := maxf(box.size.length() / 2.0, 0.01) * padding
	var distance := radius / sin(deg_to_rad(camera.fov / 2.0))
	var pitch := deg_to_rad(camera_pitch)
	var target := Vector3(0.0, center.y, 0.0)
	_viewport.add_child(camera)
	camera.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.look_at_from_position(camera.position, target)


# Copia la jerarquía visible (Node3D y mallas). Se saltean los nodos con
# script propio (temporizadores, etc.) y las áreas de colisión.
func _visual_copy(source: Node, is_root: bool = false) -> Node3D:
	var copy: Node3D
	if source is MeshInstance3D:
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.mesh = source.mesh
		mesh_copy.material_override = source.material_override
		for i in source.get_surface_override_material_count():
			mesh_copy.set_surface_override_material(i, source.get_surface_override_material(i))
		copy = mesh_copy
	else:
		copy = Node3D.new()
	if not is_root and source is Node3D:
		copy.transform = source.transform
	for child in source.get_children():
		if not child is Node3D or child is CollisionObject3D or not child.visible:
			continue
		if child.get_script() != null:
			continue
		copy.add_child(_visual_copy(child))
	return copy


func _mesh_bounds(node: Node3D, parent_xform: Transform3D) -> AABB:
	var xform := parent_xform * node.transform
	var box := AABB()
	var has_box := false
	if node is MeshInstance3D and node.mesh:
		box = xform * node.mesh.get_aabb()
		has_box = true
	for child in node.get_children():
		var child_box := _mesh_bounds(child, xform)
		if child_box.size != Vector3.ZERO:
			box = child_box if not has_box else box.merge(child_box)
			has_box = true
	return box
