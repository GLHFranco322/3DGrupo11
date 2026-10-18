class_name Player
extends CharacterBody3D

@export_group("Jugador")
## Número de jugador. Define qué controles usa (acciones "p1_*" o "p2_*").
@export_range(1, 2) var player_id: int = 1
## Color del jugador (flecha de apuntar, título en la pantalla de resultados).
@export var color: Color = Color.WHITE
## Con mouse: la flecha y la retícula siguen al cursor y se dispara con clic.
@export var mouse_aim: bool = false

@export_group("Movimiento")
## Velocidad caminando (unidades por segundo).
@export_range(0.0, 20.0, 0.1, "suffix:u/s") var walk_speed: float = 4.0
## Velocidad corriendo (no se puede correr con la cortadora).
@export_range(0.0, 30.0, 0.1, "suffix:u/s") var run_speed: float = 7.0
## Velocidad mientras empuja la cortadora.
@export_range(0.0, 20.0, 0.1, "suffix:u/s") var mower_speed: float = 2.0
## Qué tan rápido llega a la velocidad máxima. Más alto = más ágil.
@export_range(1.0, 100.0, 0.5) var acceleration: float = 30.0
## Qué tan rápido frena al soltar el control. Más alto = frena en seco.
@export_range(1.0, 100.0, 0.5) var friction: float = 25.0
## Qué tan rápido gira hacia donde camina.
@export_range(1.0, 30.0, 0.5) var turn_speed: float = 12.0

@export_group("Cortadora")
## Cortadora de este jugador.
@export var mower: Mower
## Dónde se sostiene la cortadora respecto al jugador (Z negativo = adelante).
@export var mower_hold_offset: Vector3 = Vector3(0.0, 0.0, -1.4)
## Distancia máxima para poder agarrar la cortadora.
@export_range(0.5, 6.0, 0.1, "suffix:u") var mower_pickup_distance: float = 2.5

@export_group("Piedra")
## Distancia máxima para poder agarrar una piedra.
@export_range(0.5, 6.0, 0.1, "suffix:u") var rock_pickup_distance: float = 2.0
## Dónde se sostiene la piedra respecto al jugador (Z negativo = adelante).
@export var rock_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)
## Círculo con flecha que muestra hacia dónde se va a lanzar.
@export var aim_indicator: AimIndicator
## Cuánto hay que mover el analógico derecho para cambiar la dirección.
@export_range(0.0, 1.0, 0.05) var aim_deadzone: float = 0.3

@export_group("Pozo")
## Dónde se sostiene el pozo respecto al jugador (Z negativo = adelante).
@export var pit_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)
## Marca en el piso para elegir dónde colocar el pozo.
@export var reticle: Node3D
## Altura de la retícula sobre el piso.
@export_range(0.0, 1.0, 0.01, "suffix:u") var reticle_height: float = 0.1
## Velocidad de la retícula al moverla con el analógico.
@export_range(1.0, 40.0, 0.5, "suffix:u/s") var reticle_speed: float = 15.0
## Esquina mínima (X, Z) hasta donde se puede mover la retícula.
@export var map_min: Vector2 = Vector2(-20.0, -12.0)
## Esquina máxima (X, Z) hasta donde se puede mover la retícula.
@export var map_max: Vector2 = Vector2(20.0, 12.0)

@export_group("Skin")
## Modelo del personaje (.glb). Vacío = usa el nodo Model de la escena.
@export var model_scene: PackedScene
## Escala del modelo asignado en "Model Scene".
@export_range(0.01, 5.0, 0.01) var model_scale: float = 0.25
## Otros .glb con el mismo esqueleto de los que se toman animaciones que falten.
@export var extra_animations: Array[PackedScene] = []

# Nombres de animación comunes a todos los personajes. Los .glb se renombran
# al importar con scripts/import/personaje_import.gd
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"caminar"
const ANIM_MOW := &"cortar_pasto"
const ANIM_STUNNED := &"aturdido"
const ANIM_THROW := &"tirar"
const ANIM_FALL := &"caer"

signal score_changed(new_score: int)

var score: int = 0
var has_mower: bool = false
var held_rock: Rock = null
var held_pit: Pit = null
var is_aiming: bool = false
var spawn_position: Vector3
# Pozo en el que está cayendo (lo usa el estado Falling)
var falling_pit: Pit = null
var _was_aiming: bool = false
var _mower_home: Node
var _aim_direction: Vector3 = Vector3.FORWARD
# Mientras no se toque el analógico derecho, la flecha sigue hacia donde mira el jugador
var _aim_from_stick: bool = false
var _step_timer: float = 0.0

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var mower_collision: CollisionShape3D = $MowerCollision
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	spawn_position = global_position
	if model_scene:
		_swap_model()
	_load_extra_animations()
	if mower:
		_mower_home = mower.get_parent()
	else:
		push_warning("Player %d no tiene cortadora asignada" % player_id)
	if aim_indicator:
		# Toma el color del jugador pero respeta la transparencia del indicador
		aim_indicator.set_color(Color(color, aim_indicator.color.a))


func _swap_model() -> void:
	var old_model := $Model as Node3D
	var new_model := model_scene.instantiate() as Node3D
	new_model.transform = Transform3D(old_model.transform.basis.orthonormalized().scaled_local(Vector3.ONE * model_scale), old_model.position)
	remove_child(old_model)
	old_model.queue_free()
	new_model.name = "Model"
	add_child(new_model)
	anim = new_model.get_node("AnimationPlayer") as AnimationPlayer


func _load_extra_animations() -> void:
	merge_animations(anim, extra_animations)


# Datos para mostrar al jugador fuera de la partida (pantalla de resultados)
func get_display_info() -> Dictionary:
	var model := $Model as Node3D
	var scene: PackedScene = model_scene if model_scene else load(model.scene_file_path)
	return {
		"id": player_id,
		"score": score,
		"color": color,
		"model_scene": scene,
		"model_scale": model.transform.basis.get_scale().x * scale.x,
		"extra_animations": extra_animations,
	}


# Agrega a "target" las animaciones de "scenes" que todavía no tenga.
# Los modelos tienen que compartir el mismo esqueleto.
static func merge_animations(target: AnimationPlayer, scenes: Array[PackedScene]) -> void:
	if target == null or scenes.is_empty():
		return
	var library := target.get_animation_library(&"")
	for scene in scenes:
		if scene == null:
			continue
		var instance := scene.instantiate()
		var other := instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if other:
			for lib_name in other.get_animation_library_list():
				var other_library := other.get_animation_library(lib_name)
				for anim_name in other_library.get_animation_list():
					if not library.has_animation(anim_name):
						library.add_animation(anim_name, other_library.get_animation(anim_name))
		instance.free()


func _unhandled_input(event: InputEvent) -> void:
	if state_machine.is_current("stunned") or state_machine.is_current("falling"):
		return

	if event.is_action_pressed("p%d_toggle_mower" % player_id):
		toggle_mower()
	elif event.is_action_pressed("p%d_grab" % player_id):
		try_grab_rock()


func _physics_process(delta: float) -> void:
	_update_aiming(delta)
	_update_rock_aim()
	_update_footsteps(delta)

	if _is_fire_pressed() \
			and not state_machine.is_current("stunned") \
			and not state_machine.is_current("falling"):
		if held_rock:
			throw_rock()
		else:
			confirm_aim()


func _is_fire_pressed() -> bool:
	return Input.is_action_just_pressed("p%d_place" % player_id) \
			or Input.is_action_just_pressed("p%d_throw" % player_id)


func get_facing_direction() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized()


func apply_movement(input: Vector2, speed: float, delta: float) -> void:
	var direction := Vector3(input.x, 0.0, input.y)
	velocity = velocity.move_toward(direction * speed, acceleration * delta)
	var target_angle := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)


func apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, friction * delta)


func get_walk_speed() -> float:
	return mower_speed if has_mower else walk_speed


func is_hands_full() -> bool:
	return has_mower or held_rock != null or held_pit != null


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	Audio.play_sfx_spam(Audio.score_ping)


func toggle_mower() -> void:
	if mower == null or held_rock != null or held_pit != null:
		return
	if has_mower:
		drop_mower()
	elif global_position.distance_to(mower.global_position) <= mower_pickup_distance:
		grab_mower()


func grab_mower() -> void:
	has_mower = true
	mower.is_held = true
	Audio.play_sfx(Audio.mower_grab)
	add_collision_exception_with(mower)
	mower.reparent(self)
	mower.global_transform = hold_transform(mower_hold_offset)

	mower_collision.shape = mower.collision_shape.shape
	mower_collision.global_transform = mower.collision_shape.global_transform
	mower_collision.set_deferred("disabled", false)


# Transform en el mundo para un objeto sostenido: sigue la posición y rotación
# del jugador pero sin heredar su escala. El offset está en unidades del mundo.
func hold_transform(offset: Vector3) -> Transform3D:
	var flat_basis := global_basis.orthonormalized()
	return Transform3D(flat_basis, global_position + flat_basis * offset)


func drop_mower() -> void:
	has_mower = false
	mower.is_held = false
	Audio.play_sfx(Audio.mower_drop)
	mower.reparent(_mower_home)
	remove_collision_exception_with(mower)
	mower_collision.set_deferred("disabled", true)


func try_grab_rock() -> void:
	if is_hands_full():
		return

	var nearest: Rock = null
	var nearest_dist := INF
	for rock in get_tree().get_nodes_in_group("rock"):
		if not rock.is_available:
			continue
		var dist := global_position.distance_to(rock.global_position)
		if dist <= rock_pickup_distance and dist < nearest_dist:
			nearest = rock
			nearest_dist = dist

	if nearest:
		held_rock = nearest
		nearest.pick_up(self)


func confirm_aim() -> void:
	if not is_aiming or reticle == null:
		return

	if held_pit:
		held_pit.place_at(reticle.global_position)
		held_pit = null

	is_aiming = false
	reticle.visible = false


func throw_rock() -> void:
	# Gira al jugador hacia donde apunta la flecha; la piedra (hija) gira con él
	rotation.y = atan2(-_aim_direction.x, -_aim_direction.z)
	play_anim(ANIM_THROW, true)
	held_rock.throw(_aim_direction, self)
	held_rock = null
	_aim_from_stick = false


func get_hit_by_rock(damage: int) -> void:
	if has_mower:
		drop_mower()
	if mower:
		mower.take_damage(damage)
	state_machine.force_state("stunned")


func fall_into_pit(pit: Pit) -> void:
	falling_pit = pit
	if has_mower:
		drop_mower()
	if held_rock:
		held_rock.drop()
		held_rock = null
	if held_pit:
		held_pit.drop()
		held_pit = null
	state_machine.force_state("falling")


func _update_aiming(delta: float) -> void:
	if reticle == null:
		return

	# La retícula solo se usa para colocar el pozo
	if state_machine.is_current("stunned") or state_machine.is_current("falling") or held_pit == null:
		is_aiming = false
		_was_aiming = false
		reticle.visible = false
		return

	# Con mouse la retícula sigue al cursor siempre que se tenga el pozo
	if mouse_aim:
		var point = _get_mouse_ground_point()
		if point != null:
			is_aiming = true
			reticle.visible = true
			_was_aiming = true
			reticle.global_position = Vector3(
					clampf(point.x, map_min.x, map_max.x),
					reticle_height,
					clampf(point.z, map_min.y, map_max.y))
			return

	is_aiming = Input.is_action_pressed("p%d_aim" % player_id)
	reticle.visible = is_aiming
	if not is_aiming:
		_was_aiming = false
		return

	if not _was_aiming:
		_was_aiming = true
		reticle.global_position = Vector3(global_position.x, reticle_height, global_position.z)

	var prefix := "p%d_" % player_id
	var aim_input := Input.get_vector(prefix + "aim_left", prefix + "aim_right", prefix + "aim_up", prefix + "aim_down")
	var pos := reticle.global_position
	pos.x = clampf(pos.x + aim_input.x * reticle_speed * delta, map_min.x, map_max.x)
	pos.z = clampf(pos.z + aim_input.y * reticle_speed * delta, map_min.y, map_max.y)
	pos.y = reticle_height
	reticle.global_position = pos


func _update_rock_aim() -> void:
	if aim_indicator == null:
		return

	var can_aim := held_rock != null \
			and not state_machine.is_current("stunned") \
			and not state_machine.is_current("falling")
	aim_indicator.visible = can_aim
	if not can_aim:
		_aim_from_stick = false
		return

	var prefix := "p%d_" % player_id
	var stick := Input.get_vector(prefix + "aim_left", prefix + "aim_right", prefix + "aim_up", prefix + "aim_down")
	var mouse_direction := _get_mouse_aim_direction() if mouse_aim else Vector3.ZERO
	if stick.length() > aim_deadzone:
		_aim_direction = Vector3(stick.x, 0.0, stick.y).normalized()
		_aim_from_stick = true
	elif mouse_direction != Vector3.ZERO:
		_aim_direction = mouse_direction
	elif not _aim_from_stick:
		_aim_direction = get_facing_direction()

	aim_indicator.update_aim(global_position, _aim_direction)


# Dirección desde el jugador hacia el punto del piso bajo el cursor.
# Devuelve Vector3.ZERO si no se puede calcular.
func _get_mouse_aim_direction() -> Vector3:
	var hit = _get_mouse_ground_point()
	if hit == null:
		return Vector3.ZERO
	var to_mouse: Vector3 = hit - global_position
	to_mouse.y = 0.0
	if to_mouse.length() < 0.1:
		return Vector3.ZERO
	return to_mouse.normalized()


# Punto del piso (a la altura del jugador) que está bajo el cursor, o null
func _get_mouse_ground_point() -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var mouse_pos := get_viewport().get_mouse_position()
	var ground := Plane(Vector3.UP, global_position.y)
	return ground.intersects_ray(camera.project_ray_origin(mouse_pos), camera.project_ray_normal(mouse_pos))


func _get_rival() -> Player:
	var rival_id := 2 if player_id == 1 else 1
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.player_id == rival_id:
			return p
	return null

func play_anim(anim_name: StringName, force: bool = false) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if not force and anim.current_animation == ANIM_THROW and anim.is_playing():
		return
	if anim.current_animation != anim_name or not anim.is_playing():
		anim.play(anim_name)


func stop_anim() -> void:
	if anim == null:
		return
	if anim.current_animation == ANIM_THROW and anim.is_playing():
		return
	anim.stop()


func _update_footsteps(delta: float) -> void:
	var moving := velocity.length() > 1.0 \
			and (state_machine.is_current("walk") or state_machine.is_current("run"))
	if not moving:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		Audio.play_sfx(Audio.footstep, 0.0, -6.0)
		_step_timer = Audio.footstep_run_interval if state_machine.is_current("run") else Audio.footstep_interval
