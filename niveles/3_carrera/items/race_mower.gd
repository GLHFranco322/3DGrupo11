class_name RaceMower
extends Node3D

# Cortadora de pasto que tira un jugador en la carrera. Si el rival va adelante
# en la carrera (no importa cuán lejos), sale a buscarlo siguiendo la pista y,
# cuando lo alcanza, lo aturde y lo tira de la carretilla. Si el rival va
# atrás, sale derecho hacia adelante y solo le pega a lo que se cruce.

## Velocidad de la cortadora (conviene más rápida que la carretilla con turbo).
@export_range(1.0, 100.0, 0.5, "suffix:u/s") var speed: float = 38.0
## Persiguiendo: a esta distancia del rival deja la pista y va directo a él.
@export_range(1.0, 30.0, 0.5, "suffix:u") var home_distance: float = 6.0
## Qué tan rápido se corre hacia el costado de la pista donde va el rival.
@export_range(0.1, 20.0, 0.1, "suffix:u/s") var lateral_speed: float = 3.0
## Derecho (sin rival adelante): desaparece después de recorrer esta distancia.
@export_range(1.0, 300.0, 1.0, "suffix:u") var max_distance: float = 60.0
## Radio con el que pega (más grande = más fácil acertar).
@export_range(0.05, 3.0, 0.05, "suffix:u") var hit_radius: float = 0.8
## Altura sobre la pista a la que va.
@export_range(0.0, 3.0, 0.05, "suffix:u") var hover_height: float = 0.35
## Si en este tiempo no le pegó a nada, desaparece.
@export_range(1.0, 60.0, 1.0, "suffix:s") var max_time: float = 20.0

var _thrower: Racer
var _target: Racer
var _track: Path3D
# Persiguiendo: punto de la pista donde va y distancia al centro de la pista
var _offset: float = 0.0
var _lateral: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _traveled: float = 0.0
var _time: float = 0.0
var _flying: bool = false
var _exclude: Array[RID] = []
var _hit_shape := SphereShape3D.new()

@onready var model: Node3D = $Model


func _ready() -> void:
	_hit_shape.radius = hit_radius


## La tira "thrower" hacia "direction" (se ignora el componente Y).
func throw(direction: Vector3, thrower: Racer) -> void:
	_thrower = thrower
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_exclude = thrower.get_camera_exclusions()
	_track = thrower.get_parent().get("track") as Path3D
	_target = _find_target() if _track else null
	if _target:
		_offset = _track.curve.get_closest_offset(_track.to_local(global_position))
		_lateral = _lateral_at(global_position, _offset)
	_face(_direction)
	_flying = true
	Audio.play_sfx(Audio.rock_throw)


# El rival, si va adelante en la carrera
func _find_target() -> Racer:
	for node in get_tree().get_nodes_in_group("racer"):
		var other := node as Racer
		if other and other != _thrower and other.progress > _thrower.progress:
			return other
	return null


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_time += delta
	if _time >= max_time:
		queue_free()
		return
	if _target:
		_chase(delta)
	else:
		_fly_straight(delta)
	# Va dando saltitos
	model.position.y = absf(sin(_time * 14.0)) * 0.15


func _chase(delta: float) -> void:
	var target_position := _target.get_focus_body().global_position
	var curve := _track.curve
	var length := curve.get_baked_length()
	var target_offset := curve.get_closest_offset(_track.to_local(target_position))
	var to_target := target_position - global_position
	var step := speed * delta
	# Cerca: directo al rival
	if fposmod(target_offset - _offset, length) <= home_distance or to_target.length() <= home_distance:
		if to_target.length() <= hit_radius + step:
			_hit(_target, to_target)
			return
		global_position += to_target.normalized() * step
		_face(to_target)
		return
	# Lejos: sigue la pista, corriéndose de a poco hacia el costado donde va él
	_offset = fposmod(_offset + step, length)
	_lateral = move_toward(_lateral, _lateral_at(target_position, target_offset), lateral_speed * delta)
	var sample := _track.global_transform * curve.sample_baked_with_rotation(_offset)
	var next := sample.origin + sample.basis.x.normalized() * _lateral + Vector3.UP * hover_height
	_face(next - global_position)
	global_position = next


# Distancia (con signo) de "point" al centro de la pista, en el punto "offset"
func _lateral_at(point: Vector3, offset: float) -> float:
	var sample := _track.global_transform * _track.curve.sample_baked_with_rotation(offset)
	return (point - sample.origin).dot(sample.basis.x.normalized())


# Sin rival adelante: derecho, chocando con lo que haya (como la piedra del nivel 1)
func _fly_straight(delta: float) -> void:
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
		var collider: Object = hits[0].collider if not hits.is_empty() else null
		var racer := Racer.from_body(collider)
		if racer:
			_hit(racer, _direction)
		else:
			if collider is RigidBody3D:
				collider.apply_central_impulse(_direction * 4.0)
			Audio.play_sfx(Audio.rock_hit_wall)
			queue_free()
		return
	global_position = from + motion
	_traveled += motion.length()
	if _traveled >= max_distance:
		queue_free()


func _hit(racer: Racer, direction: Vector3) -> void:
	_flying = false
	if racer != _thrower and racer.hit_by_mower(Vector3(direction.x, 0.0, direction.z)):
		Metrics.add(_thrower.player_id, "cortadoras_acertadas")
	queue_free()


# El frente del modelo mira hacia -Z
func _face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		rotation.y = atan2(-direction.x, -direction.z)
