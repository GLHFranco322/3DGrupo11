class_name Racer
extends Node3D

# Jugador del nivel de carreras (estilo Motor Kombat): va parado en una
# carretilla que se maneja como un kart, con aceleración, inercia y gravedad:
# hay que ir midiendo cuándo acelerar, frenar o ir marcha atrás. Si le pega una
# piedra o choca fuerte, se cae: tiene que volver caminando y subirse con ✕.
#
# Botones (se cambian en Proyecto → Configuración → Mapa de entrada):
#   R1 (p*_accelerate)  acelerar (rema con la pala)
#   □  (p*_brake)       frenar
#   ○  (p*_reverse)     marcha atrás
#   palanca izquierda   doblar (a pie: caminar)
#   ✕  (p*_grab)        tirar el item que se tenga / subirse a la carretilla
#   palanca derecha     mover la cámara
#
# La escena tiene dos cuerpos: "Barrow" (la carretilla, que es lo que corre) y
# "Rider" (el personaje, que solo choca y camina cuando se cae).

enum Mode { RIDING, KNOCKED, ON_FOOT, SINKING }
enum Item { NONE, ROCK, PIT, ROD }

const ITEM_NAMES := {
	Item.NONE: "",
	Item.ROCK: "Piedra",
	Item.PIT: "Pozo",
	Item.ROD: "Caña de pescar",
}

@export_group("Jugador")
## Número de jugador. Define qué controles usa (acciones "p1_*" o "p2_*").
@export_range(1, 2) var player_id: int = 1
## Color del jugador (HUD, resultados).
@export var color: Color = Color.WHITE
## Cámara que sigue a este jugador (define hacia dónde es "adelante").
@export var camera_rig: ThirdPersonCamera

@export_group("Carretilla")
## Velocidad máxima hacia adelante.
@export_range(1.0, 50.0, 0.5, "suffix:u/s") var max_speed: float = 11.0
## Cuánto gana de velocidad por segundo mientras se acelera.
@export_range(0.1, 50.0, 0.1, "suffix:u/s²") var acceleration: float = 6.0
## Cuánto pierde de velocidad por segundo mientras se frena.
@export_range(0.1, 100.0, 0.5, "suffix:u/s²") var brake_deceleration: float = 20.0
## Cuánto gana de velocidad marcha atrás por segundo.
@export_range(0.1, 50.0, 0.1, "suffix:u/s²") var reverse_acceleration: float = 4.0
## Velocidad máxima marcha atrás.
@export_range(0.5, 30.0, 0.5, "suffix:u/s") var max_reverse_speed: float = 3.0
## Cuánto frena sola sin acelerar (rozamiento). Más bajo = sigue más por inercia.
@export_range(0.0, 20.0, 0.1, "suffix:u/s²") var rolling_resistance: float = 1.5
## Qué tan rápido dobla (a partir de "Full Steer Speed").
@export_range(0.1, 10.0, 0.1, "suffix:rad/s") var turn_speed: float = 2.5
## Quieta no dobla: a esta velocidad (o más) ya dobla del todo.
@export_range(0.1, 20.0, 0.1, "suffix:u/s") var full_steer_speed: float = 5.0
## Agarre: qué tan rápido deja de patinar de costado. Más bajo = derrapa más.
@export_range(0.0, 30.0, 0.5) var grip: float = 8.0
@export_range(0.0, 50.0, 0.5) var gravity: float = 20.0
## Cuánto la frenan las subidas y la empujan las bajadas (1 = gravedad real).
@export_range(0.0, 3.0, 0.05) var slope_factor: float = 1.0
## Tiempo entre paladas mientras se acelera (sonido y animación).
@export_range(0.1, 2.0, 0.05, "suffix:s") var stroke_interval: float = 0.55
## Después de un turbo (o pasando la velocidad máxima), cuánto pierde por segundo
## hasta volver a la normal. Más bajo = el turbo se estira más.
@export_range(0.5, 50.0, 0.5, "suffix:u/s²") var boost_decay: float = 5.0

@export_group("Choques")
## Velocidad de choque (de frente contra la pared u obstáculo) a partir de la
## que el jugador sale volando de la carretilla.
@export_range(1.0, 50.0, 0.5, "suffix:u/s") var crash_speed: float = 12.0
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

@export_group("Caña de pescar")
## Hasta qué distancia engancha al rival (en cualquier dirección). Si está más
## lejos, la caña no se usa y se sigue teniendo.
@export_range(1.0, 100.0, 0.5, "suffix:u") var rod_range: float = 20.0
## Tiempo que se ve la línea de la caña tirando del rival.
@export_range(0.05, 2.0, 0.05, "suffix:s") var rod_line_time: float = 0.35
## Color de la línea de la caña.
@export var rod_line_color: Color = Color(0.95, 0.95, 0.95)

@export_group("Pozo")
## Tiempo quieto sobre el pozo antes de hundirse.
@export_range(0.0, 5.0, 0.05, "suffix:s") var pit_freeze_time: float = 0.5
## Tiempo que tarda en hundirse (y en volver a salir).
@export_range(0.05, 5.0, 0.05, "suffix:s") var pit_sink_time: float = 0.4
## Tiempo escondido dentro del pozo.
@export_range(0.0, 5.0, 0.05, "suffix:s") var pit_hidden_time: float = 0.8
## Cuánto se hunde.
@export_range(0.0, 10.0, 0.1, "suffix:u") var pit_depth: float = 2.5

@export_group("Caída al vacío")
## Segundos que se lo ve cayendo (sigue de largo con su impulso) antes de desaparecer.
@export_range(0.1, 5.0, 0.05, "suffix:s") var void_fall_time: float = 1.1
## Segundos desaparecido antes de reaparecer en la pista.
@export_range(0.0, 5.0, 0.05, "suffix:s") var void_hidden_time: float = 0.5
## Qué tan rápido da vueltas mientras cae.
@export_range(0.0, 20.0, 0.1, "suffix:rad/s") var void_tumble_speed: float = 3.0
## Por debajo de esta altura se lo da por caído (también a pie o la carretilla sola).
@export_range(-100.0, 0.0, 0.5, "suffix:u") var void_height: float = -4.0
## Segundos que titila al reaparecer.
@export_range(0.0, 5.0, 0.05, "suffix:s") var respawn_blink_time: float = 1.2

@export_group("Items")
## Escena de la piedra que se tira.
@export var rock_scene: PackedScene
## Escena del pozo que se deja atrás.
@export var pit_scene: PackedScene
## Distancia detrás de la carretilla donde se deja el pozo.
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
## Item en la mano (piedra, pozo, clavos o mate). Se tira con ✕.
var item: Item = Item.NONE
## Metros recorridos sobre la pista (lo calcula el nivel).
var progress: float = 0.0
## Puntaje para la pantalla de resultados (lo pone el nivel).
var score: int = 0

var _character: CharacterData
var _anim: AnimationPlayer
var _stroke_timer: float = 0.0
var _stroke_anim_time: float = 0.0
var _knock_timer: float = 0.0
# Turbo de las rampas: segundos que quedan y velocidad
var _boost_timer: float = 0.0
var _boost_speed: float = 0.0
# Caída al vacío: cuánto lleva cayendo, desde dónde cayó y dónde mira la cámara
var _void_falling: bool = false
var _void_timer: float = 0.0
var _fall_from: Vector3
var _frozen_focus: Vector3
var _blink_left: float = 0.0
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
	_stroke_anim_time = maxf(_stroke_anim_time - delta, 0.0)
	_boost_timer = maxf(_boost_timer - delta, 0.0)
	_update_blink(delta)
	if not _void_falling and (barrow.global_position.y < void_height or rider.global_position.y < void_height):
		_lost_in_void()

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
			if _void_falling:
				_fall_in_void(delta)

	if state == Mode.RIDING or state == Mode.SINKING:
		_follow_seat()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	# ✕ hace lo que corresponda: arriba tira el item, a pie se sube
	if not event.is_action_pressed("p%d_grab" % player_id):
		return
	if state == Mode.ON_FOOT and can_climb():
		climb()
	elif state == Mode.RIDING and item != Item.NONE:
		use_item()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Manejo -------------------------------------------------------------------

func _ride(delta: float) -> void:
	var prefix := "p%d_" % player_id
	var steer := Input.get_axis(prefix + "left", prefix + "right") if controls_enabled else 0.0
	var throttle := controls_enabled and Input.is_action_pressed(prefix + "accelerate")
	var braking := controls_enabled and Input.is_action_pressed(prefix + "brake")
	var reversing := controls_enabled and Input.is_action_pressed(prefix + "reverse")
	var on_floor := barrow.is_on_floor()

	var horizontal := Vector3(barrow.velocity.x, 0.0, barrow.velocity.z)
	var forward := get_forward()
	# Velocidad hacia adelante (negativa = marcha atrás) y de costado (derrape)
	var speed := horizontal.dot(forward)
	var lateral := horizontal.dot(_get_side())

	# Doblar: quieta no dobla, y marcha atrás dobla al revés (como un auto). En
	# el aire no dobla.
	if on_floor:
		var steer_amount := clampf(absf(speed) / full_steer_speed, 0.0, 1.0) * signf(speed)
		barrow.global_rotation.y -= steer * turn_speed * steer_amount * delta

	# Adelante / atrás: sin tocar el piso no hay tracción ni freno
	if on_floor:
		if braking:
			speed = move_toward(speed, 0.0, brake_deceleration * delta)
		elif throttle:
			# Si iba marcha atrás, primero frena. Pasando la máxima (turbo) no suma.
			var limit_now := get_speed_limit()
			if speed < limit_now:
				speed = minf(speed + (acceleration + (brake_deceleration * 0.5 if speed < 0.0 else 0.0)) * delta, limit_now)
		elif reversing:
			speed -= (reverse_acceleration + (brake_deceleration * 0.5 if speed > 0.0 else 0.0)) * delta
		else:
			speed = move_toward(speed, 0.0, rolling_resistance * delta)
		if _boost_timer > 0.0:
			speed = maxf(speed, _boost_speed)
		# Gravedad en las pendientes: las subidas frenan, las bajadas empujan
		var downhill := (Vector3.DOWN * gravity).slide(barrow.get_floor_normal())
		speed += downhill.dot(forward) * slope_factor * delta
		lateral *= maxf(1.0 - grip * delta, 0.0)

	var limit := get_speed_limit()
	if speed > limit:
		# Frenando o en el barro baja de golpe; después de un turbo, de a poco
		var decay := brake_deceleration if braking or not _zones.is_empty() else boost_decay
		speed = move_toward(speed, limit, decay * delta)
	speed = maxf(speed, -max_reverse_speed)

	# Remar con la pala mientras acelera (sonido y animación, al ritmo de las paladas)
	if throttle and on_floor and speed > 0.0:
		_stroke_timer -= delta
		if _stroke_timer <= 0.0:
			_stroke_timer = stroke_interval
			_stroke_anim_time = stroke_interval * 0.9
			Audio.play_sfx(Audio.shovel_stroke, 0.0, -4.0)
	else:
		_stroke_timer = 0.0

	horizontal = get_forward() * speed + _get_side() * lateral
	_move_barrow(horizontal, delta)
	_play_ride_animation()


func _get_side() -> Vector3:
	var side := barrow.global_basis.x
	side.y = 0.0
	return side.normalized()


## Velocidad actual hacia adelante (negativa = marcha atrás).
func get_speed() -> float:
	return Vector3(barrow.velocity.x, 0.0, barrow.velocity.z).dot(get_forward())


## Velocidad máxima actual (el barro la baja, el turbo la sube).
func get_speed_limit() -> float:
	var limit := max_speed
	for zone in _zones:
		limit *= _zones[zone]
	if _boost_timer > 0.0:
		limit = maxf(limit, _boost_speed)
	return limit


## Turbo de una rampa: durante "time" segundos va a "speed" (o más). Devuelve
## false si no se aplica (por ejemplo, si no va arriba de la carretilla).
func boost(speed: float, time: float) -> bool:
	if state != Mode.RIDING:
		return false
	_boost_speed = speed
	_boost_timer = time
	return true


func _move_barrow(horizontal: Vector3, delta: float) -> void:
	# En el piso la sigue pegada (también en bajadas); en el aire cae con
	# gravedad y conserva el impulso de una rampa
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
	state = Mode.KNOCKED
	_knock_timer = knock_time
	_boost_timer = 0.0
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

## Intenta agarrar un item de la pista. Devuelve false si ya tiene uno.
func give_item(kind: Item) -> bool:
	if state != Mode.RIDING or item != Item.NONE:
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
		Item.ROD:
			# Siempre acierta: si el rival está fuera de alcance, no se gasta
			if not cast_rod():
				Audio.play_sfx(Audio.rod_miss)
				return
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


## Caña de pescar: engancha al rival más cercano (en cualquier dirección, hasta
## "Rod Range") y lo tira de la carretilla, hacia quien lo pescó. Devuelve false
## si no hay nadie a tiro (la caña no se gasta).
func cast_rod() -> bool:
	var target := _find_rod_target()
	if target == null:
		return false
	var hook := target.get_focus_body().global_position
	_show_rod_line(seat.global_position + Vector3.UP * 1.2, hook + Vector3.UP * 1.0)
	Audio.play_sfx(Audio.rod_hook)
	var pull := barrow.global_position - hook
	pull.y = 0.0
	target.knock_off(pull.normalized() if pull.length() > 0.01 else -get_forward())
	return true


func _find_rod_target() -> Racer:
	var best: Racer = null
	var best_distance := rod_range
	for node in get_tree().get_nodes_in_group("racer"):
		var other := node as Racer
		if other == null or other == self or other.state == Mode.SINKING:
			continue
		var to_other := other.get_focus_body().global_position - barrow.global_position
		to_other.y = 0.0
		var distance := to_other.length()
		if distance > best_distance:
			continue
		best = other
		best_distance = distance
	return best


# Línea de la caña (un cilindro finito) entre dos puntos, que desaparece sola
func _show_rod_line(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = length
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = rod_line_color
	mesh.material = material
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(line)
	# El cilindro va a lo largo de su Y: se lo apunta hacia "to" y se lo acuesta
	line.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	line.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	get_tree().create_timer(rod_line_time).timeout.connect(line.queue_free)


## Le pega una piedra: se cae (si ya está en el piso, vuelve a quedar tirado).
func hit_by_rock(direction: Vector3) -> void:
	if state == Mode.SINKING:
		return
	Audio.play_sfx(Audio.rock_hit_player)
	knock_off(direction)


## Cae en un pozo con carretilla y todo. Devuelve false si no cae (ej: a pie).
func fall_into_pit(pit_position: Vector3) -> bool:
	if state != Mode.RIDING:
		return false
	state = Mode.SINKING
	barrow.velocity = Vector3.ZERO
	var floor_y := barrow.global_position.y
	barrow.global_position = Vector3(pit_position.x, floor_y, pit_position.z)
	_boost_timer = 0.0
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


# --- Caída al vacío -----------------------------------------------------------

## Se cae por un hueco del piso: sigue de largo con su impulso cayendo al
## vacío, desaparece y reaparece en un lugar seguro de la pista cerca de donde
## cayó. Devuelve false si no cae (ej: si ya estaba cayendo).
func fall_into_void() -> bool:
	if state != Mode.RIDING or _void_falling:
		return false
	_fall_from = barrow.global_position
	_frozen_focus = get_camera_focus()
	state = Mode.SINKING
	_void_falling = true
	_void_timer = 0.0
	_blink_left = 0.0
	_boost_timer = 0.0
	# Sin colisión, para que pase por el borde del hueco y siga cayendo
	barrow.get_node("CollisionShape3D").set_deferred("disabled", true)
	barrow.velocity.y = 0.0
	_play(Player.ANIM_FALL)
	return true


func _fall_in_void(delta: float) -> void:
	_void_timer += delta
	if _void_timer < void_fall_time:
		barrow.velocity.y -= gravity * delta
		barrow.global_position += barrow.velocity * delta
		# Se va de punta mientras cae
		barrow.rotate_object_local(Vector3.RIGHT, -void_tumble_speed * delta)
	elif barrow.visible:
		barrow.visible = false
		rider.visible = false
	elif _void_timer >= void_fall_time + void_hidden_time:
		_respawn_safe()


# Quedó debajo del piso sin pasar por fall_into_void (a pie, tirado o la
# carretilla sola): se lo trae de vuelta escondido, ya arriba de la carretilla
func _lost_in_void() -> void:
	var below := rider if state == Mode.ON_FOOT or state == Mode.KNOCKED else barrow
	_fall_from = below.global_position
	_frozen_focus = get_camera_focus()
	state = Mode.SINKING
	_void_falling = true
	_void_timer = void_fall_time
	_blink_left = 0.0
	_boost_timer = 0.0
	barrow.get_node("CollisionShape3D").set_deferred("disabled", true)
	_set_riding_collision(true)


func _respawn_safe() -> void:
	var spot := _find_safe_spot(_fall_from)
	barrow.global_transform = Transform3D(spot.basis, spot.origin + Vector3.UP * 0.05)
	barrow.velocity = Vector3.ZERO
	barrow.get_node("CollisionShape3D").set_deferred("disabled", false)
	barrow.visible = true
	rider.visible = true
	_void_falling = false
	state = Mode.RIDING
	_stroke_timer = 0.0
	_set_riding_collision(true)
	_follow_seat()
	_blink_left = respawn_blink_time
	if camera_rig:
		camera_rig.yaw = get_heading()
	Audio.play_sfx(Audio.barrow_climb)


# Lugar seguro de la pista cerca de "near" (lo calcula TrackPieces). Si no hay
# pista, vuelve arriba en el mismo lugar.
func _find_safe_spot(near: Vector3) -> Transform3D:
	var pieces := get_tree().get_first_node_in_group("track_pieces")
	if pieces:
		return pieces.find_safe_spot(near)
	return Transform3D(Basis(Vector3.UP, barrow.global_rotation.y), Vector3(near.x, 0.0, near.z))


# Titila al reaparecer
func _update_blink(delta: float) -> void:
	if _blink_left <= 0.0:
		return
	_blink_left = maxf(_blink_left - delta, 0.0)
	var shown := _blink_left == 0.0 or int(_blink_left * 12.0) % 2 == 0
	barrow.visible = shown
	rider.visible = shown


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
	# Cayendo al vacío la cámara se queda en el borde
	return _frozen_focus if _void_falling else get_focus_body().global_position


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
