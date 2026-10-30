class_name Collectible
extends Node3D

# Herramienta tirada en la ferretería. La crea StoreLevel; cualquier jugador la
# puede agarrar con ✕ y llevarla al tablero.

## Qué herramienta es.
@export var data: ItemData
## Cuánto sube y baja mientras está en el piso.
@export_range(0.0, 1.0, 0.01, "suffix:u") var bob_height: float = 0.12
## Velocidad de giro mientras está en el piso.
@export_range(0.0, 10.0, 0.1) var spin_speed: float = 1.5

var holder: Node3D = null

@onready var pivot: Node3D = $Pivot
@onready var label: Label3D = $Label

var _time: float = 0.0
var _home_parent: Node
# Volando por el aire (se le cayó a alguien): no se puede agarrar hasta que cae
var _flying: bool = false


func _ready() -> void:
	_home_parent = get_parent()
	_time = randf() * TAU
	if data == null:
		return
	label.text = data.display_name
	if data.model_scene:
		var model := data.model_scene.instantiate() as Node3D
		pivot.add_child(model)
		ModelUtils.fit_to_size(model, data.size)


func _process(delta: float) -> void:
	if holder or _flying:
		return
	_time += delta
	pivot.rotation.y += spin_speed * delta
	pivot.position.y = 0.35 + sin(_time * 2.0) * bob_height


func is_available() -> bool:
	return holder == null and not _flying


func pick_up(new_holder: Node3D, hold_point: Node3D) -> void:
	holder = new_holder
	label.visible = false
	reparent(hold_point)
	transform = Transform3D.IDENTITY
	pivot.position = Vector3.ZERO
	pivot.rotation = Vector3.ZERO


## Lo deja en el piso, en "world_position".
func drop(world_position: Vector3) -> void:
	holder = null
	reparent(_home_parent)
	global_transform = Transform3D(Basis.IDENTITY, Vector3(world_position.x, 0.0, world_position.z))
	label.visible = true


## Sale volando en arco desde donde está hasta "world_target" (ej: a alguien se
## le cayó al pisar una banana). Se puede agarrar recién cuando cae.
func toss(world_target: Vector3, height: float = 1.5, time: float = 0.5) -> void:
	var start := global_position
	var end := Vector3(world_target.x, 0.0, world_target.z)
	holder = null
	reparent(_home_parent)
	global_transform = Transform3D(Basis.IDENTITY, start)
	label.visible = true
	_flying = true
	var tween := create_tween()
	tween.tween_method(_toss_step.bind(start, end, height), 0.0, 1.0, time)
	tween.finished.connect(func() -> void: _flying = false)


func _toss_step(t: float, start: Vector3, end: Vector3, height: float) -> void:
	global_position = start.lerp(end, t) + Vector3.UP * 4.0 * height * t * (1.0 - t)
