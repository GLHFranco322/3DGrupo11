class_name Racer
extends Node3D

# Jugador del nivel de carreras (estilo Motor Kombat): va parado en una
# carretilla que se maneja como un kart, con aceleración, inercia y gravedad:
# hay que ir midiendo cuándo acelerar o ir marcha atrás (que primero frena). Si
# le pega una cortadora, lo pesca una caña, choca fuerte o no se suelta a tiempo
# de un agarre, se cae: tiene que volver caminando y subirse con ✕.
#
# Botones (se cambian en Proyecto → Configuración → Mapa de entrada):
#   R1 (p*_accelerate)  acelerar (rema con la pala)
#   □  (p*_grab_rival)  agarrar al rival si está muy cerca; si te agarran a
#                       vos, apretarlo varias veces para soltarte
#   ○  (p*_reverse)     frenar y marcha atrás
#   palanca izquierda   doblar (a pie: caminar)
#   ✕  (p*_grab)        tirar el item que se tenga / subirse a la carretilla
#   palanca derecha     mover la cámara
#
# La escena tiene dos cuerpos: "Barrow" (la carretilla, que es lo que corre) y
# "Rider" (el personaje, que solo choca y camina cuando se cae).

enum Mode { RIDING, KNOCKED, ON_FOOT, SINKING }
enum Item { NONE, MOWER, PIT, ROD }

const ITEM_NAMES := {
	Item.NONE: "",
	Item.MOWER: "Cortadora",
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
@export_range(1.0, 50.0, 0.5, "suffix:u/s") var max_speed: float = 14.0
## Cuánto gana de velocidad por segundo mientras se acelera.
@export_range(0.1, 50.0, 0.1, "suffix:u/s²") var acceleration: float = 7.5
## Cuánto pierde de velocidad por segundo frenando (○ yendo hacia adelante, en
## el barro o al agarrarse con el rival).
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
@export_range(1.0, 50.0, 0.5, "suffix:u/s") var crash_speed: float = 15.0
## Cuánto empuja a la carretilla del rival al chocarla (1 = toda la fuerza del choque).
@export_range(0.0, 3.0, 0.05) var bump_push: float = 0.8
## Cuánto empuja a los objetos sueltos (conos, cajas).
@export_range(0.0, 10.0, 0.1) var object_push: float = 1.5
## Cuánta velocidad pierde la carretilla al llevarse puesto un objeto suelto (0 = nada).
@export_range(0.0, 1.0, 0.05) var object_slowdown: float = 0.3

@export_group("Agarre")
## □ agarra al rival si su carretilla está a esta distancia o menos.
@export_range(0.5, 6.0, 0.1, "suffix:u") var grab_range: float = 2.6
## Mientras están agarrados, los dos van como mucho a esta fracción de la
## velocidad máxima.
@export_range(0.1, 1.0, 0.05) var grab_speed_factor: float = 0.45
## Si el agarrado no se suelta en este tiempo, se cae de la carretilla.
@export_range(0.5, 10.0, 0.1, "suffix:s") var grab_time: float = 2.2
## Veces que el agarrado tiene que apretar □ para soltarse.
@export_range(1, 30) var escape_presses: int = 6
## Tiempo después de un agarre hasta poder agarrar de nuevo.
@export_range(0.0, 10.0, 0.1, "suffix:s") var grab_cooldown: float = 2.0
## Color de la "mano" que une a los dos (vacío = el color del jugador).
@export var grab_line_color: Color = Color(0, 0, 0, 0)

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
## lejos, la caña se tira igual al aire y se gasta (así se puede agarrar otro item).
@export_range(1.0, 100.0, 0.5, "suffix:u") var rod_range: float = 20.0
## Tiempo que se ve la línea de la caña tirando del rival.
@export_range(0.05, 2.0, 0.05, "suffix:s") var rod_line_time: float = 0.35
## Color de la línea de la caña.
@export var rod_line_color: Color = Color(0.95, 0.95, 0.95)

@export_group("Cortadora")
## Segundos que queda tirado en el piso si le pega una cortadora.
@export_range(0.0, 10.0, 0.1, "suffix:s") var mower_knock_time: float = 2.0

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
## Escena de la cortadora que se tira hacia adelante.
@export var mower_scene: PackedScene
## Escena del pozo que se deja atrás.
@export var pit_scene: PackedScene
## Distancia detrás de la carretilla donde se deja el pozo.
@export_range(0.5, 10.0, 0.1, "suffix:u") var drop_distance: float = 2.4

@export_group("Animaciones")
## Animación parado en la carretilla. Si el personaje no la tiene, usa "idle".
@export var ride_animation: StringName = &"carretilla"
## Animación de la palada. Si el personaje no la tiene, usa "Ride Animation".
@export var stroke_animation: StringName = &"remar"
## Animación al salir despedido de la carretilla. Si el personaje no la tiene, usa "aturdido".
@export var knock_animation: StringName = &"caer_carretilla"
## Animación al tirar un item desde la carretilla. Si el personaje no la tiene, no se anima.
@export var throw_animation: StringName = &"tirar_carretilla"
## Animación al soltar el pozo (cae detrás). Si el personaje no la tiene, usa "Throw Animation".
@export var drop_animation: StringName = &"soltar_carretilla"

@export_group("Skin")
## Personaje si no se eligió uno en el menú (al probar la escena directo).
@export var default_character: CharacterData
## Multiplicador de tamaño del personaje en este nivel.
@export_range(0.1, 5.0, 0.05) var size_multiplier: float = 1.5
## Modelo de la carretilla (.glb). Vacío = usa la carretilla provisoria de la escena.
@export var barrow_model: PackedScene
## Escala del modelo de la carretilla.
@export_range(0.01, 10.0, 0.01) var barrow_model_scale: float = 1.0
## Partes de la carretilla (nombres de sus mallas) que se pintan con el color del
## jugador. Si se cambia el modelo, poner acá los nombres de sus partes.
@export var barrow_paint_parts: PackedStringArray = ["Tray"]
## Brillo del color de la carretilla (la pista es oscura).
@export_range(0.0, 2.0, 0.05) var barrow_paint_glow: float = 0.35

@export_group("Sonido del turbo")
## El sonido del turbo suena solo mientras dura el turbo: sube en "Fade In" y
## se desvanece en "Fade Out" cuando termina.
@export_range(0.0, 2.0, 0.05, "suffix:s") var boost_sound_fade_in: float = 0.1
@export_range(0.05, 3.0, 0.05, "suffix:s") var boost_sound_fade_out: float = 0.8
@export_range(-30.0, 10.0, 0.5, "suffix:dB") var boost_sound_volume_db: float = 0.0

@export_group("Señal de la carretilla")
## Flechita sobre la carretilla vacía cuando el jugador se cae (del color del
## jugador; se ve a través de las paredes).
@export var barrow_marker: bool = true
## Altura de la flechita sobre la carretilla.
@export_range(0.5, 5.0, 0.1, "suffix:u") var barrow_marker_height: float = 1.8
## Opacidad de la flechita.
@export_range(0.1, 1.0, 0.05) var barrow_marker_alpha: float = 0.7

## Lo pone el nivel: false durante la cuenta regresiva y al terminar.
var controls_enabled: bool = false
var state: Mode = Mode.RIDING
## Item en la mano (cortadora, pozo o caña de pescar). Se usa con ✕.
var item: Item = Item.NONE
## Metros recorridos sobre la pista (lo calcula el nivel).
var progress: float = 0.0
## Puntaje para la pantalla de resultados (lo pone el nivel).
var score: int = 0
## Rival al que tiene agarrado (null = a nadie).
var grabbing: Racer = null
## Rival que lo tiene agarrado (null = nadie).
var grabbed_by: Racer = null
## Veces que le falta apretar □ para soltarse (si lo agarraron).
var escape_left: int = 0
var _grab_left: float = 0.0
var _grab_cooldown_left: float = 0.0
var _grab_line: MeshInstance3D

var _character: CharacterData
var _anim: AnimationPlayer
var _stroke_timer: float = 0.0
var _stroke_anim_time: float = 0.0
var _throw_anim_time: float = 0.0
# La que se está viendo mientras corre _throw_anim_time (ver _play_action)
var _action_animation: StringName = &""
# Flechita sobre la carretilla (ver _build_barrow_marker)
var _marker: MeshInstance3D
# Sonido del turbo de esta carretilla y su volumen (0 a 1)
var _boost_player: AudioStreamPlayer
var _boost_level: float = 0.0
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
	_paint_barrow()
	if barrow_marker:
		_build_barrow_marker()
	if Audio.boost_pad:
		_boost_player = Audio.create_loop_player(self, Audio.boost_pad)
		_boost_player.volume_db = -80.0
	barrow.add_collision_exception_with(rider)
	_set_riding_collision(true)
	_follow_seat()


func _physics_process(delta: float) -> void:
	_update_grab(delta)
	_stroke_anim_time = maxf(_stroke_anim_time - delta, 0.0)
	_throw_anim_time = maxf(_throw_anim_time - delta, 0.0)
	_boost_timer = maxf(_boost_timer - delta, 0.0)
	_update_blink(delta)
	_update_barrow_marker()
	_update_boost_sound(delta)
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
	# □ agarra al rival que está muy cerca, o forcejea si lo agarraron
	if event.is_action_pressed("p%d_grab_rival" % player_id):
		if grabbed_by:
			_struggle()
		elif state == Mode.RIDING and grabbing == null:
			try_grab_rival()
		get_viewport().set_input_as_handled()
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
	var reversing := controls_enabled and Input.is_action_pressed(prefix + "reverse")
	# Con R1 y ○ apretados a la vez no acelera: gana ○ (frena y va marcha atrás)
	var throttle := controls_enabled and Input.is_action_pressed(prefix + "accelerate") and not reversing
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
		if throttle:
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
		var decay := brake_deceleration if not _zones.is_empty() or is_in_grab() else boost_decay
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
	if is_in_grab():
		limit = minf(limit, max_speed * grab_speed_factor)
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
	# La cámara se abre y aparecen las líneas de velocidad
	if camera_rig:
		camera_rig.play_boost(time)
	if _boost_player and not _boost_player.playing:
		_boost_player.play(Audio.sfx_start_offsets.get(Audio.boost_pad, 0.0))
	return true


# Sube mientras dura el turbo y se desvanece cuando termina (o si se cae)
func _update_boost_sound(delta: float) -> void:
	if _boost_player == null or not _boost_player.playing:
		return
	if _boost_timer > 0.0 and state == Mode.RIDING:
		_boost_level = move_toward(_boost_level, 1.0, delta / maxf(boost_sound_fade_in, 0.001))
	else:
		_boost_level = move_toward(_boost_level, 0.0, delta / boost_sound_fade_out)
		if _boost_level <= 0.0:
			_boost_player.stop()
			return
	_boost_player.volume_db = Audio.get_sfx_db() + boost_sound_volume_db + linear_to_db(maxf(_boost_level, 0.0001))


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

## Tira al jugador de la carretilla. "away" = hacia dónde sale despedido;
## "stun_time" = segundos tirado (negativo = "Knock Time").
func knock_off(away: Vector3 = Vector3.ZERO, stun_time: float = -1.0) -> void:
	if state == Mode.SINKING:
		return
	end_grab()
	if state == Mode.RIDING:
		var direction := Vector3(away.x, 0.0, away.z)
		if direction.length() < 0.1:
			direction = barrow.global_basis.x
		direction = direction.normalized()
		_set_riding_collision(false)
		rider.global_position = seat.global_position + direction * 0.8
		rider.velocity = barrow.velocity * 0.5 + direction * eject_speed + Vector3.UP * eject_speed * 0.8
	state = Mode.KNOCKED
	_knock_timer = stun_time if stun_time >= 0.0 else knock_time
	_boost_timer = 0.0
	_throw_anim_time = 0.0
	_play(knock_animation if _has_anim(knock_animation) else Player.ANIM_STUNNED)


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
	var used := item
	match item:
		Item.MOWER:
			var mower := _spawn(mower_scene, barrow.global_position + forward * 1.3 + Vector3.UP * 0.5)
			if mower:
				mower.throw(forward, self)
				Metrics.add(player_id, "cortadoras")
		Item.PIT:
			var pit := _spawn(pit_scene, barrow.global_position - forward * drop_distance)
			if pit:
				pit.placed_by = self
				Audio.play_sfx(Audio.pit_place)
				Metrics.add(player_id, "pozos")
		Item.ROD:
			Metrics.add(player_id, "canas")
			if cast_rod():
				Metrics.add(player_id, "canas_acertadas")
			else:
				# Nadie a tiro: se tira al aire hacia adelante y se gasta igual
				_show_rod_line(seat.global_position + Vector3.UP * 1.2,
						seat.global_position + forward * rod_range * 0.4 + Vector3.UP * 0.4)
				Audio.play_sfx(Audio.rod_miss)
		Item.NONE:
			return
	item = Item.NONE
	_play_action(drop_animation if used == Item.PIT else throw_animation)


# Animación de una acción desde la carretilla (tirar, soltar, agarrar): se ve
# mientras dura y después vuelve la de andar. Si no está, prueba con la de tirar.
func _play_action(anim_name: StringName) -> void:
	if not _has_anim(anim_name):
		anim_name = throw_animation
	if _has_anim(anim_name):
		_action_animation = anim_name
		_throw_anim_time = _anim.get_animation(anim_name).length


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
## si no hay nadie a tiro.
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
	get_tree().create_timer(rod_line_time, false).timeout.connect(line.queue_free)


## Le pega una cortadora: queda aturdido "Mower Knock Time" y se cae de la
## carretilla (si ya estaba en el piso, vuelve a quedar tirado). Devuelve false
## si no le pudo pegar (ej: está adentro de un pozo).
func hit_by_mower(direction: Vector3) -> bool:
	if state == Mode.SINKING:
		return false
	Audio.play_sfx(Audio.rock_hit_player)
	knock_off(direction, mower_knock_time)
	return true


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


# --- Agarre -------------------------------------------------------------------

## Agarrado o agarrando: los dos van más despacio.
func is_in_grab() -> bool:
	return grabbing != null or grabbed_by != null


## □: si el rival está muy cerca (y los dos arriba de la carretilla), lo agarra.
## Los dos van más lento; si en "Grab Time" no se suelta, se cae.
func try_grab_rival() -> bool:
	if _grab_cooldown_left > 0.0:
		return false
	var target: Racer = null
	for node in get_tree().get_nodes_in_group("racer"):
		var other := node as Racer
		if other == null or other == self or other.state != Mode.RIDING or other.is_in_grab():
			continue
		var offset := other.barrow.global_position - barrow.global_position
		offset.y = 0.0
		if offset.length() <= grab_range:
			target = other
	if target == null:
		return false
	grabbing = target
	target.grabbed_by = self
	target.escape_left = escape_presses
	_grab_left = grab_time
	_grab_cooldown_left = grab_cooldown
	Audio.play_sfx(Audio.rival_grab if Audio.rival_grab else Audio.punch_hit)
	Metrics.add(player_id, "agarres")
	_play_action(throw_animation)
	return true


## □ del agarrado: cada toque descuenta; al llegar a 0 se suelta.
func _struggle() -> void:
	escape_left -= 1
	Audio.play_sfx(Audio.ui_hover, 0.0, -6.0)
	if escape_left <= 0 and grabbed_by:
		Audio.play_sfx(Audio.grab_escape if Audio.grab_escape else Audio.ui_click)
		grabbed_by.end_grab()


## Termina el agarre en el que esté (agarrando o agarrado), sin que nadie se caiga.
func end_grab() -> void:
	if grabbing:
		grabbing.grabbed_by = null
		grabbing.escape_left = 0
		grabbing = null
	if grabbed_by:
		var other := grabbed_by
		grabbed_by = null
		escape_left = 0
		other.grabbing = null
	if _grab_line:
		_grab_line.visible = false


func _update_grab(delta: float) -> void:
	_grab_cooldown_left = maxf(_grab_cooldown_left - delta, 0.0)
	if grabbing == null:
		return
	var target := grabbing
	var offset := target.barrow.global_position - barrow.global_position
	offset.y = 0.0
	# Se cortó solo (uno se cayó, se separaron mucho)
	if state != Mode.RIDING or target.state != Mode.RIDING or offset.length() > grab_range * 2.5:
		end_grab()
		return
	_draw_grab_line(target)
	_grab_left -= delta
	if _grab_left <= 0.0:
		# No se soltó: se cae (hacia el lado contrario al que lo agarró) y este sigue
		end_grab()
		target.knock_off(offset.normalized() if offset.length() > 0.01 else -get_forward())
		Audio.play_sfx(Audio.barrow_crash)
		Metrics.add(player_id, "agarres_acertados")


# "Mano" entre los dos mientras dura el agarre
func _draw_grab_line(target: Racer) -> void:
	var from := seat.global_position + Vector3.UP * 1.0
	var to := target.seat.global_position + Vector3.UP * 1.0
	if _grab_line == null:
		_grab_line = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.06
		mesh.bottom_radius = 0.06
		mesh.height = 1.0
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = grab_line_color if grab_line_color.a > 0.0 else color
		mesh.material = material
		_grab_line.mesh = mesh
		_grab_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(_grab_line)
	var length := from.distance_to(to)
	if length < 0.05:
		_grab_line.visible = false
		return
	_grab_line.visible = true
	_grab_line.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	_grab_line.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	_grab_line.scale = Vector3(1.0, length, 1.0)


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
	if _throw_anim_time > 0.0:
		_play(_action_animation)
	elif _stroke_anim_time > 0.0 and _has_anim(stroke_animation):
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


# La carretilla del color del jugador (sobre una copia del material: las dos
# carretillas comparten el de la escena)
func _paint_barrow() -> void:
	for node in barrow_model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not String(mesh_instance.name) in barrow_paint_parts or mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as BaseMaterial3D
			if material == null:
				continue
			var copy := material.duplicate() as BaseMaterial3D
			copy.albedo_color = color
			# Un brillo suave: la pista es de noche y si no el color no se distingue
			copy.emission_enabled = true
			copy.emission = color
			copy.emission_energy_multiplier = barrow_paint_glow
			mesh_instance.set_surface_override_material(i, copy)


# Flechita apuntando para abajo sobre la carretilla, para encontrarla al caerse
func _build_barrow_marker() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.22
	cone.bottom_radius = 0.0
	cone.height = 0.38
	cone.radial_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, barrow_marker_alpha)
	material.no_depth_test = true
	material.render_priority = 1
	cone.material = material
	_marker = MeshInstance3D.new()
	_marker.name = "BarrowMarker"
	_marker.mesh = cone
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# No gira con la carretilla (que puede quedar volcada)
	_marker.top_level = true
	_marker.visible = false
	barrow.add_child(_marker)


func _update_barrow_marker() -> void:
	if _marker == null:
		return
	var fallen := state == Mode.KNOCKED or state == Mode.ON_FOOT
	_marker.visible = fallen
	if fallen:
		var time := Time.get_ticks_msec() / 1000.0
		var bob := sin(time * 3.0) * 0.12
		_marker.global_transform = Transform3D(Basis(Vector3.UP, time * 1.5), barrow.global_position + Vector3.UP * (barrow_marker_height + bob))


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
