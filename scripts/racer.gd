class_name Racer
extends Node3D

# Jugador del nivel de carreras: va parado en una carretilla y se impulsa con
# una pala (cada palada da un empujón). Si le pega una piedra o choca fuerte,
# se cae: tiene que volver caminando a la carretilla y subirse con ✕.
#
# Botones (de ejemplo, se cambian en Proyecto → Configuración → Mapa de entrada):
#   palanca izquierda  hacia dónde ir (relativo a la cámara)
#   ✕  (p*_grab)       subirse a la carretilla
#   R2 o □ (p*_throw)  usar el item: piedra adelante, pozo o clavos atrás
#   R1 (p*_run)        tomar el mate (turbo)
#   palanca derecha    mover la cámara
#
# La escena tiene dos cuerpos: "Barrow" (la carretilla, que es lo que corre) y
# "Rider" (el personaje, que solo choca y camina cuando se cae).

enum Mode { RIDING, KNOCKED, ON_FOOT, SINKING }
enum Item { NONE, ROCK, PIT, NAILS, TURBO }

const ITEM_NAMES := {
	Item.NONE: "",
	Item.ROCK: "Piedra",
	Item.PIT: "Pozo",
	Item.NAILS: "Clavos",
	Item.TURBO: "Mate",
}

@export_group("Jugador")
## Número de jugador. Define qué controles usa (acciones "p1_*" o "p2_*").
@export_range(1, 2) var player_id: int = 1
## Color del jugador (HUD, resultados).
@export var color: Color = Color.WHITE
## Cámara que sigue a este jugador (define hacia dónde es "adelante").
@export var camera_rig: ThirdPersonCamera

@export_group("Carretilla")
## Velocidad máxima.
@export_range(1.0, 50.0, 0.5, "suffix:u/s") var max_speed: float = 12.0
## Empujón que da cada palada.
@export_range(0.0, 20.0, 0.1, "suffix:u/s") var stroke_impulse: float = 4.5
## Tiempo entre paladas mientras se mantiene la palanca.
@export_range(0.1, 2.0, 0.05, "suffix:s") var stroke_interval: float = 0.55
## Cuánto frena sola entre paladas. Más alto = frena más rápido.
@export_range(0.0, 5.0, 0.05) var drag: float = 0.8
## Qué tan rápido gira la carretilla.
@export_range(0.1, 10.0, 0.1, "suffix:rad/s") var turn_speed: float = 2.6
## Agarre: qué tan rápido deja de patinar de costado. Más bajo = derrapa más.
@export_range(0.0, 30.0, 0.5) var grip: float = 8.0
@export_range(0.0, 50.0, 0.5) var gravity: float = 20.0

@export_group("Choques")
## Velocidad de choque (de frente contra la pared u obstáculo) a partir de la
## que el jugador sale volando de la carretilla.
@export_range(1.0, 50.0, 0.5, "suffix:u/s") var crash_speed: float = 9.0
## Cuánto empuja a la carretilla del rival al chocarla (1 = toda la fuerza del choque).
@export_range(0.0, 3.0, 0.05) var bump_push: float = 0.8
## Cuánto empuja a los objetos sueltos (conos, cajas).
@export_range(0.0, 10.0, 0.1) var object_push: float = 1.5
## Cuánta velocidad pierde la carretilla al llevarse puesto un objeto suelto (0 = nada).
@export_range(0.0, 1.0, 0.05) var object_slowdown: float = 0.3

@export_group("Caída")
## Tiempo tirado en el piso antes de poder levantarse.
@export_range(0.0, 5.0, 0.05, "suffix:s") var knock_time: float = 1.0
## Fuerza con la que sale despedido de la carretilla.
@export_range(0.0, 20.0, 0.5, "suffix:u/s") var eject_speed: float = 5.0
## Velocidad caminando (cuando se cayó).
@export_range(0.0, 20.0, 0.1, "suffix:u/s") var walk_speed: float = 6.0
## Distancia máxima a la carretilla para poder subirse.
@export_range(0.5, 5.0, 0.1, "suffix:u") var climb_distance: float = 2.2
## Frenado de la carretilla cuando nadie la maneja.
@export_range(0.0, 20.0, 0.5) var riderless_brake: float = 3.0

@export_group("Turbo (mate)")
## Duración del turbo.
@export_range(0.1, 10.0, 0.1, "suffix:s") var turbo_time: float = 2.5
## Velocidad máxima con turbo (multiplica "Max Speed").
@export_range(1.0, 3.0, 0.05) var turbo_speed_multiplier: float = 1.6
## Aceleración extra mientras dura el turbo.
@export_range(0.0, 100.0, 1.0, "suffix:u/s²") var turbo_thrust: float = 18.0

@export_group("Clavos")
## Tiempo con la rueda pinchada.
@export_range(0.1, 15.0, 0.1, "suffix:s") var flat_time: float = 3.0
## Velocidad máxima con la rueda pinchada (multiplica "Max Speed").
@export_range(0.05, 1.0, 0.05) var flat_speed_multiplier: float = 0.45

@export_group("Pozo")
## Tiempo quieto sobre el pozo antes de hundirse.
@export_range(0.0, 5.0, 0.05, "suffix:s") var pit_freeze_time: float = 0.5
## Tiempo que tarda en hundirse (y en volver a salir).
@export_range(0.05, 5.0, 0.05, "suffix:s") var pit_sink_time: float = 0.4
## Tiempo escondido dentro del pozo.
@export_range(0.0, 5.0, 0.05, "suffix:s") var pit_hidden_time: float = 0.8
## Cuánto se hunde.
@export_range(0.0, 10.0, 0.1, "suffix:u") var pit_depth: float = 2.5

@export_group("Items")
## Escena de la piedra que se tira.
@export var rock_scene: PackedScene
## Escena del pozo que se deja atrás.
@export var pit_scene: PackedScene
## Escena de los clavos que se dejan atrás.
@export var nails_scene: PackedScene
## Distancia detrás de la carretilla donde se dejan el pozo y los clavos.
@export_range(0.5, 10.0, 0.1, "suffix:u") var drop_distance: float = 2.4

@export_group("Animaciones")
## Animación parado en la carretilla. Si el personaje no la tiene, usa "idle".
@export var ride_animation: StringName = &"carretilla"
## Animación de la palada. Si el personaje no la tiene, usa "Ride Animation".
@export var stroke_animation: StringName = &"remar"

@export_group("Skin")
## Personaje si no se eligió uno en el menú (al probar la escena directo).
@export var default_character: CharacterData
## Multiplicador de tamaño del personaje en este nivel.
@export_range(0.1, 5.0, 0.05) var size_multiplier: float = 1.5
## Modelo de la carretilla (.glb). Vacío = usa la carretilla provisoria de la escena.
@export var barrow_model: PackedScene
## Escala del modelo de la carretilla.
@export_range(0.01, 10.0, 0.01) var barrow_model_scale: float = 1.0

## Lo pone el nivel: false durante la cuenta regresiva y al terminar.
var controls_enabled: bool = false
var state: Mode = Mode.RIDING
## Item en la mano (piedra, pozo o clavos).
var item: Item = Item.NONE
## Si tiene un mate guardado para el turbo.
var has_turbo: bool = false
## Metros recorridos sobre la pista (lo calcula el nivel).
var progress: float = 0.0
## Puntaje para la pantalla de resultados (lo pone el nivel).
var score: int = 0

var _character: CharacterData
var _anim: AnimationPlayer
var _stroke_timer: float = 0.0
var _stroke_anim_time: float = 0.0
var _knock_timer: float = 0.0
var _turbo_left: float = 0.0
var _flat_left: float = 0.0
# zona -> multiplicador de velocidad (barro, charcos)
var _zones: Dictionary = {}

@onready var barrow: CharacterBody3D = $Barrow
@onready var seat: Node3D = $Barrow/Seat
@onready var barrow_model_root: Node3D = $Barrow/Model
@onready var rider: CharacterBody3D = $Rider
@onready var rider_collision: CollisionShape3D = $Rider/CollisionShape3D
@onready var model_root: Node3D = $Rider/ModelRoot


func _ready() -> void:
	_character = GameSettings.get_character(player_id)
	if _character == null:
		_character = default_character
	_load_model()
	if barrow_model:
		_swap_barrow_model()
	barrow.add_collision_exception_with(rider)
	_set_riding_collision(true)
	_follow_seat()


func _physics_process(delta: float) -> void:
	_turbo_left = maxf(_turbo_left - delta, 0.0)
	_flat_left = maxf(_flat_left - delta, 0.0)
	_stroke_anim_time = maxf(_stroke_anim_time - delta, 0.0)

	match state:
		Mode.RIDING:
			_ride(delta)
		Mode.KNOCKED:
			_knocked(delta)
			_coast(delta)
		Mode.ON_FOOT:
			_walk(delta)
			_coast(delta)
		Mode.SINKING:
			pass

	if state == Mode.RIDING or state == Mode.SINKING:
		_follow_seat()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	var prefix := "p%d_" % player_id
	if event.is_action_pressed(prefix + "grab") and state == Mode.ON_FOOT and can_climb():
		climb()
	elif event.is_action_pressed(prefix + "throw") and state == Mode.RIDING and item != Item.NONE:
		use_item()
	elif event.is_action_pressed(prefix + "run") and state == Mode.RIDING and has_turbo:
		use_turbo()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Manejo -------------------------------------------------------------------

func _ride(delta: float) -> void:
	var input := _get_input_direction()
	var forward := get_forward()

	if input.length() > 0.1:
		var target_yaw := atan2(-input.x, -input.z)
		barrow.global_rotation.y = rotate_toward(barrow.global_rotation.y, target_yaw, turn_speed * delta)
		forward = get_forward()
		_stroke_timer -= delta
		if _stroke_timer <= 0.0:
			_stroke_timer = stroke_interval
			# Solo empuja si la carretilla ya mira más o menos hacia donde se quiere ir
			var push := maxf(forward.dot(input.normalized()), 0.0) * minf(input.length(), 1.0)
			if push > 0.0:
				_stroke(forward * stroke_impulse * push)
	else:
		# Al volver a mover la palanca, la primera palada sale enseguida
		_stroke_timer = 0.0

	var horizontal := Vector3(barrow.velocity.x, 0.0, barrow.velocity.z)
	var side := barrow.global_basis.x
	side.y = 0.0
	side = side.normalized()
	horizontal -= side * horizontal.dot(side) * minf(grip * delta, 1.0)
	horizontal *= maxf(1.0 - drag * delta, 0.0)
	if _turbo_left > 0.0:
		horizontal += forward * turbo_thrust * delta
	var limit := get_speed_limit()
	if horizontal.length() > limit:
		horizontal = horizontal.lerp(horizontal.limit_length(limit), minf(6.0 * delta, 1.0))

	_move_barrow(horizontal, delta)
	_play_ride_animation()


func _stroke(impulse: Vector3) -> void:
	barrow.velocity += impulse
	_stroke_anim_time = stroke_interval * 0.9
	Audio.play_sfx(Audio.shovel_stroke, 0.0, -4.0)


## Velocidad máxima actual (turbo, rueda pinchada, barro).
func get_speed_limit() -> float:
	var limit := max_speed
	if _turbo_left > 0.0:
		limit *= turbo_speed_multiplier
	if _flat_left > 0.0:
		limit *= flat_speed_multiplier
	for zone in _zones:
		limit *= _zones[zone]
	return limit


func _move_barrow(horizontal: Vector3, delta: float) -> void:
	var vertical := 0.0 if barrow.is_on_floor() else barrow.velocity.y - gravity * delta
	barrow.velocity = Vector3(horizontal.x, vertical, horizontal.z)
	var before := barrow.velocity
	barrow.move_and_slide()
	if state == Mode.RIDING:
		_handle_collisions(before)


func _handle_collisions(before: Vector3) -> void:
	for i in barrow.get_slide_collision_count():
		var collision := barrow.get_slide_collision(i)
		var normal := collision.get_normal()
		if normal.y > 0.7:
			continue  # el piso
		var impact := -Vector3(before.x, 0.0, before.z).dot(normal)
		if impact <= 0.0:
			continue
		var other := collision.get_collider()
		if other is RigidBody3D:
			other.apply_central_impulse(-normal * impact * object_push)
			# Lo atraviesa empujándolo, sin frenar en seco como contra una pared
			barrow.velocity.x = before.x * (1.0 - object_slowdown)
			barrow.velocity.z = before.z * (1.0 - object_slowdown)
			continue
		var rival := Racer.from_body(other)
		if rival:
			if rival != self:
				rival.bump(-normal * impact * bump_push)
			continue
		if impact >= crash_speed:
			Audio.play_sfx(Audio.barrow_crash)
			knock_off(normal)
			return


# La carretilla sin nadie sigue un poco por inercia y frena
func _coast(delta: float) -> void:
	var horizontal := Vector3(barrow.velocity.x, 0.0, barrow.velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, riderless_brake * delta)
	_move_barrow(horizontal, delta)


## Empujón de otra carretilla al chocarla.
func bump(push: Vector3) -> void:
	if state == Mode.SINKING:
		return
	barrow.velocity += Vector3(push.x, 0.0, push.z)


# --- Caerse y subirse ---------------------------------------------------------

## Tira al jugador de la carretilla. "away" = hacia dónde sale despedido.
func knock_off(away: Vector3 = Vector3.ZERO) -> void:
	if state == Mode.SINKING:
		return
	if state == Mode.RIDING:
		var direction := Vector3(away.x, 0.0, away.z)
		if direction.length() < 0.1:
			direction = barrow.global_basis.x
		direction = direction.normalized()
		_set_riding_collision(false)
		rider.global_position = seat.global_position + direction * 0.8
		rider.velocity = barrow.velocity * 0.5 + direction * eject_speed + Vector3.UP * eject_speed * 0.8
		_turbo_left = 0.0
	state = Mode.KNOCKED
	_knock_timer = knock_time
	_play(Player.ANIM_STUNNED)


func _knocked(delta: float) -> void:
	var horizontal := Vector3(rider.velocity.x, 0.0, rider.velocity.z).move_toward(Vector3.ZERO, 10.0 * delta)
	_move_rider(horizontal, delta)
	_knock_timer -= delta
	if _knock_timer <= 0.0 and rider.is_on_floor():
		state = Mode.ON_FOOT


func _walk(delta: float) -> void:
	var input := _get_input_direction()
	var target := input * walk_speed
	var horizontal := Vector3(rider.velocity.x, 0.0, rider.velocity.z).move_toward(target, 40.0 * delta)
	_move_rider(horizontal, delta)
	if input.length() > 0.1:
		var target_angle := atan2(-input.x, -input.z)
		rider.global_rotation.y = lerp_angle(rider.global_rotation.y, target_angle, 12.0 * delta)
		_play(Player.ANIM_WALK)
	else:
		_play(Player.ANIM_IDLE)


func _move_rider(horizontal: Vector3, delta: float) -> void:
	var vertical := 0.0 if rider.is_on_floor() and rider.velocity.y <= 0.0 else rider.velocity.y - gravity * delta
	rider.velocity = Vector3(horizontal.x, vertical, horizontal.z)
	rider.move_and_slide()


func can_climb() -> bool:
	return state == Mode.ON_FOOT and rider.global_position.distance_to(barrow.global_position) <= climb_distance


func climb() -> void:
	state = Mode.RIDING
	barrow.velocity = Vector3.ZERO
	_stroke_timer = 0.0
	_set_riding_collision(true)
	_follow_seat()
	Audio.play_sfx(Audio.barrow_climb)


# Arriba de la carretilla el personaje no choca: choca la carretilla
func _set_riding_collision(riding: bool) -> void:
	rider_collision.set_deferred("disabled", riding)


func _follow_seat() -> void:
	rider.global_transform = Transform3D(Basis(Vector3.UP, barrow.global_rotation.y), seat.global_position)
	rider.velocity = Vector3.ZERO


# --- Items --------------------------------------------------------------------

## Intenta agarrar un item de la pista. Devuelve false si ya tiene uno de ese tipo.
func give_item(kind: Item) -> bool:
	if state != Mode.RIDING:
		return false
	if kind == Item.TURBO:
		if has_turbo:
			return false
		has_turbo = true
	else:
		if item != Item.NONE:
			return false
		item = kind
	Audio.play_sfx(Audio.item_pickup)
	return true


func use_item() -> void:
	var forward := get_forward()
	match item:
		Item.ROCK:
			var rock := _spawn(rock_scene, barrow.global_position + forward * 1.3 + Vector3.UP * 0.9)
			if rock:
				rock.throw(forward, self)
		Item.PIT:
			var pit := _spawn(pit_scene, barrow.global_position - forward * drop_distance)
			if pit:
				pit.placed_by = self
				Audio.play_sfx(Audio.pit_place)
		Item.NAILS:
			var nails := _spawn(nails_scene, barrow.global_position - forward * drop_distance)
			if nails:
				nails.placed_by = self
				Audio.play_sfx(Audio.nails_drop)
	item = Item.NONE


func _spawn(scene: PackedScene, world_position: Vector3) -> Node3D:
	if scene == null:
		push_warning("Racer %d: falta asignar la escena del item" % player_id)
		return null
	var node := scene.instantiate() as Node3D
	# Se agrega al nivel, no a la carretilla, para que no la siga
	get_parent().add_child(node)
	node.global_position = world_position
	return node


func use_turbo() -> void:
	has_turbo = false
	_turbo_left = turbo_time
	barrow.velocity += get_forward() * stroke_impulse
	Audio.play_sfx(Audio.turbo_boost)


func is_turbo_active() -> bool:
	return _turbo_left > 0.0


func is_tire_flat() -> bool:
	return _flat_left > 0.0


## Le pega una piedra: se cae (si ya está en el piso, vuelve a quedar tirado).
func hit_by_rock(direction: Vector3) -> void:
	if state == Mode.SINKING:
		return
	Audio.play_sfx(Audio.rock_hit_player)
	knock_off(direction)


## Pisa clavos: rueda pinchada por un rato.
func run_over_nails() -> void:
	_flat_left = flat_time
	Audio.play_sfx(Audio.tire_pop)


## Cae en un pozo con carretilla y todo. Devuelve false si no cae (ej: a pie).
func fall_into_pit(pit_position: Vector3) -> bool:
	if state != Mode.RIDING:
		return false
	state = Mode.SINKING
	_turbo_left = 0.0
	barrow.velocity = Vector3.ZERO
	var floor_y := barrow.global_position.y
	barrow.global_position = Vector3(pit_position.x, floor_y, pit_position.z)
	_play(Player.ANIM_FALL)
	_sink_and_return(floor_y)
	return true


func _sink_and_return(floor_y: float) -> void:
	var tween := create_tween()
	tween.tween_interval(pit_freeze_time)
	tween.tween_property(barrow, "global_position:y", floor_y - pit_depth, pit_sink_time).set_ease(Tween.EASE_IN)
	tween.tween_interval(pit_hidden_time)
	tween.tween_property(barrow, "global_position:y", floor_y, pit_sink_time).set_ease(Tween.EASE_OUT)
	await tween.finished
	state = Mode.RIDING
	_stroke_timer = 0.0


## Lo llama una zona de barro o charco al entrar (multiplier < 1 frena).
func enter_zone(zone: Node, multiplier: float) -> void:
	_zones[zone] = multiplier


func exit_zone(zone: Node) -> void:
	_zones.erase(zone)


# --- Utilidades ---------------------------------------------------------------

## El Racer al que pertenece un cuerpo (carretilla o personaje), o null.
static func from_body(body: Object) -> Racer:
	if body is Node and body.get_parent() is Racer:
		return body.get_parent()
	return null


## Hacia dónde mira la carretilla (sin componente vertical).
func get_forward() -> Vector3:
	var forward := -barrow.global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Cuerpo que mira la cámara: la carretilla, o el personaje si se cayó.
func get_focus_body() -> Node3D:
	return barrow if state == Mode.RIDING or state == Mode.SINKING else rider


func get_camera_focus() -> Vector3:
	return get_focus_body().global_position


func get_heading() -> float:
	return get_focus_body().global_rotation.y


func get_camera_exclusions() -> Array[RID]:
	return [barrow.get_rid(), rider.get_rid()]


func _get_input_direction() -> Vector3:
	if not controls_enabled:
		return Vector3.ZERO
	var prefix := "p%d_" % player_id
	var input := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	var yaw: float = camera_rig.yaw if camera_rig else 0.0
	return Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)


func _play_ride_animation() -> void:
	if _stroke_anim_time > 0.0 and _has_anim(stroke_animation):
		_play(stroke_animation)
	elif _has_anim(ride_animation):
		_play(ride_animation)
	else:
		_play(Player.ANIM_IDLE)


func _load_model() -> void:
	if _character == null or _character.model_scene == null:
		return
	var model := _character.model_scene.instantiate() as Node3D
	model.name = "Model"
	# Los modelos miran a +Z; la carretilla avanza hacia -Z
	model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * _character.model_scale * size_multiplier), Vector3.ZERO)
	model_root.add_child(model)
	ModelUtils.tint(model, GameSettings.get_character_tint(player_id))
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	Player.merge_animations(_anim, _character.extra_animations)
	AnimNames.normalize(_anim)


func _swap_barrow_model() -> void:
	for child in barrow_model_root.get_children():
		child.queue_free()
	var model := barrow_model.instantiate() as Node3D
	model.scale = Vector3.ONE * barrow_model_scale
	barrow_model_root.add_child(model)


func _has_anim(anim_name: StringName) -> bool:
	return _anim != null and _anim.has_animation(anim_name)


func _play(anim_name: StringName) -> void:
	if _anim == null:
		return
	if _anim.has_animation(anim_name):
		if _anim.current_animation != anim_name:
			_anim.play(anim_name)
	elif _anim.has_animation(Player.ANIM_IDLE):
		if _anim.current_animation != Player.ANIM_IDLE:
			_anim.play(Player.ANIM_IDLE)


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
