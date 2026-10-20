class_name StorePlayer
extends CharacterBody3D

# Jugador del nivel de la ferretería: camina relativo a su cámara (tercera
# persona), agarra herramientas con ✕ y las entrega en el tablero con ✕.

signal deliver_requested(player: StorePlayer)

@export_group("Jugador")
## Número de jugador. Define qué controles usa (acciones "p1_*" o "p2_*").
@export_range(1, 2) var player_id: int = 1
## Color del jugador (lista, resultados).
@export var color: Color = Color.WHITE
## Cámara que sigue a este jugador (define hacia dónde es "adelante").
@export var camera_rig: ThirdPersonCamera

@export_group("Movimiento")
@export_range(0.0, 20.0, 0.1, "suffix:u/s") var walk_speed: float = 5.0
@export_range(0.0, 30.0, 0.1, "suffix:u/s") var run_speed: float = 8.0
@export_range(1.0, 100.0, 0.5) var acceleration: float = 40.0
@export_range(1.0, 30.0, 0.5) var turn_speed: float = 12.0
@export_range(0.0, 50.0, 0.5) var gravity: float = 20.0

@export_group("Herramientas")
## Distancia máxima para agarrar una herramienta.
@export_range(0.5, 5.0, 0.1, "suffix:u") var pickup_distance: float = 1.6

@export_group("Skin")
## Personaje si no se eligió uno en el menú (al probar la escena directo).
@export var default_character: CharacterData
## Multiplicador de tamaño del personaje en este nivel.
@export_range(0.1, 5.0, 0.05) var size_multiplier: float = 1.5

var score: int = 0
## Herramientas que todavía le faltan entregar (las asigna StoreLevel).
var remaining: Array[ItemData] = []
var carried: Collectible = null

var _character: CharacterData
var _anim: AnimationPlayer

@onready var model_root: Node3D = $ModelRoot
@onready var hold_point: Node3D = $ModelRoot/HoldPoint


func _ready() -> void:
	_character = GameSettings.get_character(player_id)
	if _character == null:
		_character = default_character
	_load_model()


func _physics_process(delta: float) -> void:
	var prefix := "p%d_" % player_id
	var input := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	var yaw := camera_rig.yaw if camera_rig else 0.0
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var speed := run_speed if Input.is_action_pressed(prefix + "run") else walk_speed

	var target := direction * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta

	if direction.length() > 0.1:
		var target_angle := atan2(-direction.x, -direction.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_angle, turn_speed * delta)
		_play(Player.ANIM_WALK, 1.6 if speed == run_speed else 1.0)
	else:
		_play(Player.ANIM_IDLE)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("p%d_grab" % player_id):
		return
	get_viewport().set_input_as_handled()
	if carried:
		# El nivel decide si está frente al tablero y si la herramienta sirve;
		# si no la entrega, la suelta
		deliver_requested.emit(self)
	else:
		_try_pick_up()


func needs(item: ItemData) -> bool:
	return remaining.has(item)


func drop_carried() -> void:
	if carried == null:
		return
	var forward := -model_root.global_basis.z
	carried.drop(global_position + forward * 0.8)
	carried = null


## Quita la herramienta de las manos (para colgarla en el tablero).
func take_carried() -> Collectible:
	var item := carried
	carried = null
	return item


func _try_pick_up() -> void:
	var nearest: Collectible = null
	var nearest_dist := pickup_distance
	for node in get_tree().get_nodes_in_group("collectible"):
		var item := node as Collectible
		if item == null or not item.is_available() or not item.is_inside_tree():
			continue
		var dist := global_position.distance_to(item.global_position)
		if dist <= nearest_dist:
			nearest = item
			nearest_dist = dist
	if nearest:
		carried = nearest
		nearest.pick_up(self, hold_point)
		Audio.play_sfx(Audio.rock_grab)


func _load_model() -> void:
	if _character == null or _character.model_scene == null:
		return
	var model := _character.model_scene.instantiate() as Node3D
	model.name = "Model"
	# Los modelos miran a +Z; el jugador camina hacia -Z
	model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * _character.model_scale * size_multiplier), Vector3.ZERO)
	model_root.add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	Player.merge_animations(_anim, _character.extra_animations)
	AnimNames.normalize(_anim)


func _play(anim_name: StringName, speed: float = 1.0) -> void:
	if _anim == null:
		return
	_anim.speed_scale = speed
	if _anim.has_animation(anim_name):
		if _anim.current_animation != anim_name:
			_anim.play(anim_name)
	elif _anim.is_playing():
		_anim.stop()


## Datos para la pantalla de resultados (mismo formato que Player).
func get_display_info() -> Dictionary:
	return {
		"id": player_id,
		"score": score,
		"color": color,
		"model_scene": _character.model_scene if _character else null,
		"model_scale": (_character.model_scale * size_multiplier) if _character else 1.0,
		"extra_animations": _character.extra_animations if _character else ([] as Array[PackedScene]),
	}
