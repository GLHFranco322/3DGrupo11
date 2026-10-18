class_name AimIndicator
extends Node3D

# Círculo alrededor del jugador con una flecha que marca hacia dónde se va a
# lanzar la piedra. Se dibuja en coordenadas del mundo (top_level) para no
# heredar la escala ni la rotación del jugador.

## Radio del círculo.
@export_range(0.1, 5.0, 0.05, "suffix:u") var radius: float = 0.65
## Grosor de la línea del círculo.
@export_range(0.01, 1.0, 0.01, "suffix:u") var thickness: float = 0.08
## Tamaño de la flecha.
@export_range(0.05, 3.0, 0.05, "suffix:u") var arrow_size: float = 0.5
## Altura sobre el piso.
@export_range(0.0, 2.0, 0.01, "suffix:u") var height: float = 0.1
## Color base. El jugador reemplaza el tono por el suyo pero se respeta la
## transparencia (canal A): más bajo = más transparente.
@export var color: Color = Color(1.0, 1.0, 1.0, 0.3)

var _material: StandardMaterial3D


func _ready() -> void:
	top_level = true
	visible = false

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.albedo_color = color

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius - thickness
	ring_mesh.outer_radius = radius
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = _material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	# PrismMesh apunta a +Y; lo acostamos para que apunte a -Z (el "frente")
	var arrow_mesh := PrismMesh.new()
	arrow_mesh.size = Vector3(arrow_size, arrow_size, 0.02)
	var arrow := MeshInstance3D.new()
	arrow.mesh = arrow_mesh
	arrow.material_override = _material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.rotation.x = -PI / 2.0
	arrow.position = Vector3(0.0, 0.0, -(radius + arrow_size * 0.5))
	add_child(arrow)


func set_color(new_color: Color) -> void:
	color = new_color
	if _material:
		_material.albedo_color = new_color


# Ubica el indicador en "center" y gira la flecha hacia "direction"
func update_aim(center: Vector3, direction: Vector3) -> void:
	global_position = Vector3(center.x, height, center.z)
	rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
