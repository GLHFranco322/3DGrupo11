class_name RaceRock
extends Node3D

# Piedra que tira un jugador en la carrera: va derecho hacia adelante y, si le
# pega al rival (a la carretilla o al personaje), lo tira al piso.

## Velocidad de la piedra (conviene más rápida que la carretilla con turbo).
@export_range(1.0, 100.0, 0.5, "suffix:u/s") var speed: float = 32.0
## Si no choca con nada, desaparece después de recorrer esta distancia.
@export_range(1.0, 300.0, 1.0, "suffix:u") var max_distance: float = 60.0
## Radio con el que pega (más grande = más fácil acertar).
@export_range(0.05, 3.0, 0.05, "suffix:u") var hit_radius: float = 0.6

var _direction: Vector3 = Vector3.FORWARD
var _traveled: float = 0.0
var _flying: bool = false
var _exclude: Array[RID] = []
var _hit_shape := SphereShape3D.new()


func _ready() -> void:
	_hit_shape.radius = hit_radius


## Lanza la piedra en línea recta (se ignora el componente Y).
func throw(direction: Vector3, thrower: Racer) -> void:
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_exclude = thrower.get_camera_exclusions()
	_flying = true
	Audio.play_sfx(Audio.rock_throw)


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	var from := global_position
	var motion := _direction * speed * delta

	# Avanza una esfera de radio "hit_radius" en vez de un rayo finito
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _hit_shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = motion
	query.exclude = _exclude
	var fractions := space.cast_motion(query)
	if fractions[1] < 1.0:
		global_position = from + motion * fractions[1]
		query.transform = Transform3D(Basis.IDENTITY, global_position)
		query.motion = Vector3.ZERO
		var hits := space.intersect_shape(query, 1)
		_on_hit(hits[0].collider if not hits.is_empty() else null)
		return

	global_position = from + motion
	_traveled += motion.length()
	if _traveled >= max_distance:
		queue_free()


func _on_hit(collider: Object) -> void:
	_flying = false
	var racer := Racer.from_body(collider)
	if racer:
		racer.hit_by_rock(_direction)
	elif collider is RigidBody3D:
		collider.apply_central_impulse(_direction * 4.0)
		Audio.play_sfx(Audio.rock_hit_wall)
	elif collider != null:
		Audio.play_sfx(Audio.rock_hit_wall)
	queue_free()
