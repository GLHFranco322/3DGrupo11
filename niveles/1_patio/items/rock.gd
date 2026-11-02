class_name Rock
extends Node3D

# Piedra que aparece en el piso (la crea ItemSpawner). Si nadie la agarra antes
# de "lifetime" segundos, desaparece. Al lanzarla, desaparece cuando choca.

## Segundos que dura en el piso antes de desaparecer. ItemSpawner lo pisa con su valor.
@export_range(0.5, 60.0, 0.5, "suffix:s") var lifetime: float = 5.0
## Velocidad de la piedra en el aire.
@export_range(1.0, 60.0, 0.5, "suffix:u/s") var throw_speed: float = 14.0
## Daño que le hace a la cortadora del rival.
@export_range(0, 100) var damage: int = 20
## Si no choca con nada, desaparece después de recorrer esta distancia.
@export_range(1.0, 200.0, 1.0, "suffix:u") var max_distance: float = 40.0
## Radio de la zona de golpe de la piedra en el aire. Más grande = más fácil pegar.
@export_range(0.05, 3.0, 0.05, "suffix:u") var hit_radius: float = 0.5

var is_held: bool = false
var is_available: bool = true

var _home_parent: Node
var _direction: Vector3
var _traveled: float = 0.0
var _flying: bool = false
var _thrower: Player = null
var _exclude: Array[RID] = []
var _hit_shape := SphereShape3D.new()

@onready var item_timer: ItemTimer = $ItemTimer


func _ready() -> void:
	_home_parent = get_parent()
	_hit_shape.radius = hit_radius
	item_timer.expired.connect(queue_free)
	item_timer.start(lifetime)


func _physics_process(delta: float) -> void:
	if not _flying:
		return

	var from := global_position
	var motion := _direction * throw_speed * delta

	# Avanza una esfera de radio "hit_radius" en vez de un rayo finito
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _hit_shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = motion
	query.exclude = _exclude
	var fractions := space.cast_motion(query)
	if fractions[1] < 1.0:
		# Choca en este paso: busca contra qué, en el punto del choque
		global_position = from + motion * fractions[1]
		query.transform = Transform3D(Basis.IDENTITY, global_position)
		query.motion = Vector3.ZERO
		var hits := space.intersect_shape(query, 1)
		_on_hit(hits[0].collider if not hits.is_empty() else null)
		return

	global_position = from + motion
	_traveled += throw_speed * delta
	if _traveled >= max_distance:
		_on_hit(null)


func pick_up(holder: Player) -> void:
	is_held = true
	is_available = false
	item_timer.stop()
	Audio.play_sfx(Audio.rock_grab)
	reparent(holder)
	global_transform = holder.hold_transform(holder.rock_hold_offset)


# Lanza la piedra en línea recta en "direction" (se ignora el componente Y)
func throw(direction: Vector3, thrower: Player) -> void:
	var world_transform := global_transform
	reparent(_home_parent)
	global_transform = world_transform
	is_held = false
	_flying = true
	_traveled = 0.0
	Audio.play_sfx(Audio.rock_throw)
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_thrower = thrower

	# La piedra no choca contra quien la tiró ni contra la cortadora que lleva
	_exclude = [thrower.get_rid()]
	if thrower.has_mower and thrower.mower:
		_exclude.append(thrower.mower.get_rid())


# La suelta en el piso donde está (ej: el jugador cayó a un pozo) y vuelve a
# correr su tiempo
func drop() -> void:
	if not is_held:
		return
	var world_position := global_position
	reparent(_home_parent)
	global_transform = Transform3D(Basis.IDENTITY, Vector3(world_position.x, 0.0, world_position.z))
	is_held = false
	is_available = true
	item_timer.start(lifetime)


func _on_hit(collider: Object) -> void:
	_flying = false

	# Si pega en una cortadora que alguien lleva, cuenta como golpe a ese jugador
	var target := collider
	if target is Mower and target.get_parent() is Player:
		target = target.get_parent()
	if target is Player and target != _thrower:
		Audio.play_sfx(Audio.rock_hit_player)
		target.get_hit_by_rock(damage)
	elif collider != null:
		Audio.play_sfx(Audio.rock_hit_wall)

	queue_free()
