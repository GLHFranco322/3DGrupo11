class_name Pit
extends Node3D

# Pozo que cae del cielo (lo crea ItemSpawner). Al tocar el piso arranca su
# tiempo: si nadie lo agarra antes de "lifetime" segundos, desaparece. Una vez
# colocado como trampa queda hasta que alguien lo pisa, y después desaparece.

enum State { SPAWNING, LANDED, HELD, PLACED, TRIGGERED }

@export_group("Aparición")
## Segundos que dura en el piso antes de desaparecer. ItemSpawner lo pisa con su valor.
@export_range(0.5, 60.0, 0.5, "suffix:s") var lifetime: float = 5.0
## Velocidad con la que el pozo baja del cielo.
@export_range(0.1, 20.0, 0.1, "suffix:u/s") var descent_speed: float = 2.0
## Altura desde la que empieza a bajar.
@export_range(0.0, 30.0, 0.5, "suffix:u") var start_height: float = 6.0

@export_group("Caída")
## Tiempo que el jugador queda congelado sobre el pozo antes de caer.
@export_range(0.0, 5.0, 0.05, "suffix:s") var freeze_time: float = 0.6
## Tiempo que tarda el jugador en hundirse dentro del pozo.
@export_range(0.05, 5.0, 0.05, "suffix:s") var sink_time: float = 0.5
## Cuánto se hunde el jugador.
@export_range(0.0, 10.0, 0.1, "suffix:u") var sink_depth: float = 2.5
## Tiempo que tarda el pozo en cerrarse después de la caída.
@export_range(0.05, 5.0, 0.05, "suffix:s") var close_time: float = 0.4
## Color del pozo abierto.
@export var hole_color: Color = Color.BLACK

@onready var bubble: MeshInstance3D = $Bubble
@onready var trap_visual: MeshInstance3D = $TrapVisual
@onready var pickup_area: Area3D = $PickupArea
@onready var trap_area: Area3D = $TrapArea
@onready var item_timer: ItemTimer = $ItemTimer

var state: int = State.SPAWNING
var holder: Player = null
var placed_by: Player = null

var _home_parent: Node
var _home_position: Vector3


func _ready() -> void:
	_home_parent = get_parent()
	_home_position = global_position
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	trap_area.body_entered.connect(_on_trap_area_body_entered)
	item_timer.expired.connect(_on_expired)
	_enter_spawning()


func _process(delta: float) -> void:
	if state != State.SPAWNING:
		return
	global_position.y -= descent_speed * delta
	if global_position.y <= _home_position.y:
		global_position.y = _home_position.y
		_enter_landed()


func pick_up(player: Player) -> void:
	if state != State.LANDED:
		return
	state = State.HELD
	holder = player
	player.held_pit = self
	item_timer.stop()
	pickup_area.set_deferred("monitoring", false)
	reparent(player)
	global_transform = player.hold_transform(player.pit_hold_offset)


func place_at(world_position: Vector3) -> void:
	if state != State.HELD:
		return
	placed_by = holder
	holder = null
	reparent(_home_parent)
	global_position = world_position
	global_position.y = _home_position.y

	bubble.visible = false
	trap_visual.visible = true
	Audio.play_sfx(Audio.pit_place)
	trap_area.set_deferred("monitoring", true)
	state = State.PLACED


# Lo suelta en el piso donde está (ej: el jugador cayó a un pozo) y vuelve a
# correr su tiempo
func drop() -> void:
	if state != State.HELD:
		return
	var world_position := global_position
	reparent(_home_parent)
	holder = null
	_home_position = Vector3(world_position.x, 0.0, world_position.z)
	global_transform = Transform3D(Basis.IDENTITY, _home_position)
	_enter_landed()


func _enter_spawning() -> void:
	state = State.SPAWNING
	Audio.play_sfx(Audio.pit_spawn)
	global_position = _home_position + Vector3(0.0, start_height, 0.0)
	bubble.visible = true
	trap_visual.visible = false
	pickup_area.set_deferred("monitoring", false)
	trap_area.set_deferred("monitoring", false)


func _enter_landed() -> void:
	state = State.LANDED
	pickup_area.set_deferred("monitoring", true)
	item_timer.start(lifetime)


func _on_expired() -> void:
	if state == State.LANDED:
		queue_free()


func _on_pickup_area_body_entered(body: Node) -> void:
	if state != State.LANDED:
		return
	# Las señales de física no permiten mover nodos con colisión: se posterga
	if body is Player and not body.is_hands_full():
		pick_up.call_deferred(body)


func _on_trap_area_body_entered(body: Node) -> void:
	if state != State.PLACED:
		return
	# Cualquier jugador cae, incluso el que lo colocó
	if body is Player:
		state = State.TRIGGERED
		body.fall_into_pit.call_deferred(self)
		_trigger.call_deferred()


func _trigger() -> void:
	state = State.TRIGGERED
	trap_area.set_deferred("monitoring", false)

	# El pozo se abre (negro) mientras el jugador queda congelado y se hunde
	trap_visual.material_override = _hole_material()
	Audio.play_sfx(Audio.pit_fall)
	await get_tree().create_timer(freeze_time + sink_time).timeout

	# Se cierra achicándose hacia el centro
	Audio.play_sfx(Audio.pit_close)
	var tween := create_tween()
	tween.tween_property(trap_visual, "scale", Vector3(0.001, 1.0, 0.001), close_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func _hole_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = hole_color
	return mat
