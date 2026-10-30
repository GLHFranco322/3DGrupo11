class_name StorePlayer
extends CharacterBody3D

# Jugador del nivel de la ferretería: camina relativo a su cámara (tercera
# persona), agarra herramientas con ✕ y las entrega en el tablero con ✕.
#
# Botones:
#   ✕ (p*_grab)        agarrar / entregar / soltar herramienta
#   □ / R2 (p*_throw)  piña (en cualquier momento): el rival queda aturdido y suelta su herramienta
#   △ (p*_place)       dejar en el piso la trampa que se tenga (banana o hielo), detrás
#   R1 (p*_run)        correr

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
## Distancia delante del jugador donde queda la herramienta al soltarla.
@export_range(0.0, 3.0, 0.1, "suffix:u") var drop_distance: float = 0.8
## Si hay una pared delante, la herramienta queda al menos a esta distancia de ella.
@export_range(0.0, 2.0, 0.05, "suffix:u") var drop_wall_margin: float = 0.4

@export_group("Piña")
## Distancia máxima al rival para pegarle.
@export_range(0.5, 5.0, 0.1, "suffix:u") var punch_range: float = 1.9
## Ancho del frente en el que tiene que estar el rival (respecto a hacia dónde mira).
@export_range(10.0, 360.0, 5.0, "suffix:°") var punch_angle: float = 110.0
## Tiempo mínimo entre piñas.
@export_range(0.0, 5.0, 0.05, "suffix:s") var punch_cooldown: float = 0.6
## Tiempo que queda aturdido el que recibe la piña.
@export_range(0.0, 10.0, 0.1, "suffix:s") var punch_stun_time: float = 2.0
## Empujón que recibe el golpeado.
@export_range(0.0, 20.0, 0.5, "suffix:u/s") var punch_push: float = 5.0
## Distancia a la que sale la herramienta del golpeado.
@export_range(0.0, 10.0, 0.1, "suffix:u") var punch_toss_distance: float = 1.5
## Animación de la piña. Si el personaje no la tiene, usa la de tirar.
@export var punch_animation: StringName = &"golpear"

@export_group("Trampas")
## Escena de la banana que se deja en el piso.
@export var banana_scene: PackedScene
## Escena del hielo que se deja en el piso.
@export var ice_scene: PackedScene
## Distancia detrás del jugador donde se deja la trampa.
@export_range(0.0, 5.0, 0.1, "suffix:u") var trap_drop_distance: float = 1.2
## Tiempo tirado en el piso después de resbalarse con una banana.
@export_range(0.0, 10.0, 0.1, "suffix:s") var banana_slip_time: float = 1.0
## Qué tan lejos sale volando la herramienta al resbalarse.
@export_range(0.0, 20.0, 0.5, "suffix:u") var banana_toss_distance: float = 6.0
## Tiempo patinando sin control en el hielo.
@export_range(0.1, 10.0, 0.1, "suffix:s") var ice_slide_time: float = 2.0
## Velocidad patinando en el hielo.
@export_range(0.5, 30.0, 0.5, "suffix:u/s") var ice_slide_speed: float = 7.0

@export_group("Skin")
## Personaje si no se eligió uno en el menú (al probar la escena directo).
@export var default_character: CharacterData
## Multiplicador de tamaño del personaje en este nivel.
@export_range(0.1, 5.0, 0.05) var size_multiplier: float = 1.5

var score: int = 0
## Herramientas que todavía le faltan entregar (las asigna StoreLevel).
var remaining: Array[ItemData] = []
var carried: Collectible = null
## Trampa que lleva para dejar con △ (si "has_trap").
var has_trap: bool = false
var trap_kind: StoreTrap.Kind = StoreTrap.Kind.BANANA

var _character: CharacterData
var _anim: AnimationPlayer
var _stun_left: float = 0.0
var _slide_left: float = 0.0
var _slide_direction: Vector3 = Vector3.FORWARD
var _punch_cooldown_left: float = 0.0
var _punch_anim_left: float = 0.0

@onready var model_root: Node3D = $ModelRoot
@onready var hold_point: Node3D = $ModelRoot/HoldPoint


func _ready() -> void:
	_character = GameSettings.get_character(player_id)
	if _character == null:
		_character = default_character
	_load_model()


func _physics_process(delta: float) -> void:
	_punch_cooldown_left = maxf(_punch_cooldown_left - delta, 0.0)
	_punch_anim_left = maxf(_punch_anim_left - delta, 0.0)
	var vertical := 0.0 if is_on_floor() else velocity.y - gravity * delta

	# Patinando en el hielo: sin control, sigue derecho (y resbala por las paredes)
	if _slide_left > 0.0:
		_slide_left -= delta
		velocity = _slide_direction * ice_slide_speed + Vector3.UP * vertical
		model_root.rotation.y += 8.0 * delta
		_play(Player.ANIM_STUNNED)
		move_and_slide()
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if flat.length() > 0.5:
			_slide_direction = flat.normalized()
		return

	# Aturdido (piña o banana): no se mueve por su cuenta
	if _stun_left > 0.0:
		_stun_left -= delta
		var slowed := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 15.0 * delta)
		velocity = slowed + Vector3.UP * vertical
		_play(Player.ANIM_STUNNED)
		move_and_slide()
		return

	var prefix := "p%d_" % player_id
	var input := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	var yaw := camera_rig.yaw if camera_rig else 0.0
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var speed := run_speed if Input.is_action_pressed(prefix + "run") else walk_speed

	var target := direction * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity = horizontal + Vector3.UP * vertical

	if direction.length() > 0.1:
		var target_angle := atan2(-direction.x, -direction.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_angle, turn_speed * delta)
	if _punch_anim_left > 0.0:
		_play(punch_animation if _has_anim(punch_animation) else Player.ANIM_THROW)
	elif direction.length() > 0.1:
		_play(Player.ANIM_WALK, 1.6 if speed == run_speed else 1.0)
	else:
		_play(Player.ANIM_IDLE)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if is_disabled():
		return
	var prefix := "p%d_" % player_id
	if event.is_action_pressed(prefix + "grab"):
		if carried:
			# El nivel decide si está frente al tablero y si la herramienta sirve;
			# si no la entrega, la suelta
			deliver_requested.emit(self)
		else:
			_try_pick_up()
	elif event.is_action_pressed(prefix + "throw"):
		punch()
	elif event.is_action_pressed(prefix + "place"):
		place_trap()
	else:
		return
	get_viewport().set_input_as_handled()


## Aturdido o patinando: no puede hacer nada.
func is_disabled() -> bool:
	return _stun_left > 0.0 or _slide_left > 0.0


func is_sliding() -> bool:
	return _slide_left > 0.0


func needs(item: ItemData) -> bool:
	return remaining.has(item)


func drop_carried() -> void:
	if carried == null:
		return
	carried.drop(_get_drop_position(get_facing()))
	carried = null


## Hacia dónde mira (sin componente vertical).
func get_facing() -> Vector3:
	var forward := -model_root.global_basis.z
	forward.y = 0.0
	return forward.normalized()


# Hasta "distance" en "direction", pero si hay una pared en el medio queda de
# este lado (si no, pegados a una pared se podían esconder cosas del otro lado)
func _get_drop_position(direction: Vector3, distance: float = -1.0) -> Vector3:
	if distance < 0.0:
		distance = drop_distance
	var from := global_position + Vector3.UP * 0.5
	var to := from + direction * distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	return from + direction * maxf(from.distance_to(hit.position) - drop_wall_margin, 0.0)


## Quita la herramienta de las manos (para colgarla en el tablero).
func take_carried() -> Collectible:
	var item := carried
	carried = null
	return item


# --- Piña -----------------------------------------------------------------------

## Pega una piña hacia adelante. Si el rival está cerca y adelante, queda
## aturdido y suelta su herramienta.
func punch() -> void:
	if _punch_cooldown_left > 0.0:
		return
	_punch_cooldown_left = punch_cooldown
	_punch_anim_left = 0.4
	var forward := get_facing()
	var min_dot := cos(deg_to_rad(punch_angle * 0.5))
	for node in get_tree().get_nodes_in_group("player"):
		var other := node as StorePlayer
		if other == null or other == self or other.is_disabled():
			continue
		var to_other := other.global_position - global_position
		to_other.y = 0.0
		if to_other.length() > punch_range:
			continue
		if to_other.length() > 0.01 and to_other.normalized().dot(forward) < min_dot:
			continue
		Audio.play_sfx(Audio.punch_hit)
		other.get_punched(forward)
		return
	Audio.play_sfx(Audio.punch_whiff)


func get_punched(direction: Vector3) -> void:
	_stun_left = punch_stun_time
	_slide_left = 0.0
	velocity = direction * punch_push
	_toss_carried(direction, punch_toss_distance)


# --- Trampas --------------------------------------------------------------------

## Agarra una banana o un hielo del piso. Devuelve false si ya tiene una trampa.
func give_trap(kind: StoreTrap.Kind) -> bool:
	if has_trap:
		return false
	has_trap = true
	trap_kind = kind
	Audio.play_sfx(Audio.trap_pickup)
	return true


## Nombre de la trampa que lleva ("" si no tiene).
func get_trap_name() -> String:
	return StoreTrap.KIND_NAMES[trap_kind] if has_trap else ""


## △: deja la trampa en el piso, detrás.
func place_trap() -> void:
	if not has_trap:
		return
	var scene := banana_scene if trap_kind == StoreTrap.Kind.BANANA else ice_scene
	if scene == null:
		push_warning("StorePlayer %d: falta asignar la escena de la trampa" % player_id)
		return
	var spot := _get_drop_position(-get_facing(), trap_drop_distance)
	var trap := scene.instantiate() as StoreTrap
	trap.placed_by = self
	get_parent().add_child(trap)
	trap.global_position = Vector3(spot.x, global_position.y, spot.z)
	has_trap = false
	Audio.play_sfx(Audio.trap_place)


## Pisó una banana: se resbala, queda tirado y la herramienta le sale volando lejos.
func slip_on_banana() -> void:
	_stun_left = banana_slip_time
	_slide_left = 0.0
	Audio.play_sfx(Audio.banana_slip)
	_toss_carried(get_facing(), banana_toss_distance)


## Pisó hielo: patina sin control hacia donde caminaba y suelta la herramienta.
func slide_on_ice() -> void:
	if _slide_left > 0.0:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_slide_direction = flat.normalized() if flat.length() > 0.5 else get_facing()
	_slide_left = ice_slide_time
	_stun_left = 0.0
	Audio.play_sfx(Audio.ice_slide)
	_toss_carried(_slide_direction, 1.0)


# La herramienta sale volando en arco (sin pasar del otro lado de una pared)
func _toss_carried(direction: Vector3, distance: float) -> void:
	if carried == null:
		return
	var item := carried
	carried = null
	item.toss(_get_drop_position(direction, distance))


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
	ModelUtils.tint(model, GameSettings.get_character_tint(player_id))
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	Player.merge_animations(_anim, _character.extra_animations)
	AnimNames.normalize(_anim)


func _has_anim(anim_name: StringName) -> bool:
	return _anim != null and _anim.has_animation(anim_name)


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
		"tint": GameSettings.get_character_tint(player_id),
	}
