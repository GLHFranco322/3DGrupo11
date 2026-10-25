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
## Distancia máxima para poder agarrar una piedra o una bota.
@export_range(0.5, 6.0, 0.1, "suffix:u") var rock_pickup_distance: float = 2.0
## Dónde se sostiene la piedra respecto al jugador (Z negativo = adelante).
@export var rock_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)
## Círculo con flecha que muestra hacia dónde se va a lanzar.
@export var aim_indicator: AimIndicator
## Cuánto hay que mover el analógico derecho para cambiar la dirección.
@export_range(0.0, 1.0, 0.05) var aim_deadzone: float = 0.3

@export_group("Bota")
## Dónde se sostiene la bota respecto al jugador (Z negativo = adelante).
@export var boot_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)
## Con la bota se camina y se corre más rápido (2 = el doble).
@export_range(1.0, 5.0, 0.1) var boot_speed_multiplier: float = 2.0
## Distancia al rival a la que lo patea solo, al pasarle por encima (los jugadores
## miden unas 2 unidades de ancho, así que 2.2 es casi tocarse).
@export_range(0.5, 6.0, 0.1, "suffix:u") var kick_range: float = 2.2
## Cuánto se aleja la cámara al patear (0.15 = 15% más lejos), para darle efecto.
@export_range(0.0, 1.0, 0.05) var kick_camera_zoom_out: float = 0.2

@export_group("Pozo")
## Dónde se sostiene el pozo respecto al jugador (Z negativo = adelante).
@export var pit_hold_offset: Vector3 = Vector3(0.0, 0.6, -0.9)
## Marca en el piso para elegir dónde colocar el pozo.
@export var reticle: Node3D
## Opacidad de la marca del pozo (toma el color del jugador). 1 = sólida.
@export_range(0.0, 1.0, 0.05) var reticle_alpha: float = 0.75
## Al agarrar el pozo, la marca aparece a esta distancia delante del jugador.
@export_range(0.0, 10.0, 0.1, "suffix:u") var reticle_start_distance: float = 2.5
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
const ANIM_EMOTE := &"festejo"
const ANIM_KICK := &"patear"

signal score_changed(new_score: int)

var score: int = 0
var has_mower: bool = false
var held_rock: Rock = null
var held_pit: Pit = null
var held_boot: Boot = null
var is_aiming: bool = false
var spawn_position: Vector3
# Pozo en el que está cayendo (lo usa el estado Falling)
var falling_pit: Pit = null
# Hacia dónde sale volando al ser pateado (lo usa el estado Kicked)
var kick_direction: Vector3 = Vector3.FORWARD
# Segundos de invencibilidad que quedan (al reaparecer después de una patada)
var _invincible_left: float = 0.0
var _was_aiming: bool = false
var _mower_home: Node
var _aim_direction: Vector3 = Vector3.FORWARD
# Mientras no se toque el analógico derecho, la flecha sigue hacia donde mira el jugador
var _aim_from_stick: bool = false
# Con "mouse_aim": true si lo último que se usó fue el mouse, false si el mando
var _using_mouse: bool = true
var _step_timer: float = 0.0

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var mower_collision: CollisionShape3D = $MowerCollision
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	spawn_position = global_position
	_apply_chosen_character()
	if model_scene:
		_swap_model()
	_load_extra_animations()
	# Por si el .glb no se reimportó con los nombres comunes
	AnimNames.normalize(anim)
	ModelUtils.tint($Model, GameSettings.get_character_tint(player_id))
	if mower:
		_mower_home = mower.get_parent()
	else:
		push_warning("Player %d no tiene cortadora asignada" % player_id)
	if aim_indicator:
		# Toma el color del jugador pero respeta la transparencia del indicador
		aim_indicator.set_color(Color(color, aim_indicator.color.a))
	_color_reticle()


# La marca del pozo toma el color del jugador (material propio: la malla es
# compartida entre los dos jugadores)
func _color_reticle() -> void:
	var mesh_instance := reticle as MeshInstance3D
	if mesh_instance == null:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, reticle_alpha)
	# Se ve aunque quede debajo de una mesa o de otro objeto
	material.no_depth_test = true
	material.render_priority = 1
	mesh_instance.material_override = material


# Personaje elegido en la selección de personaje. Si no se eligió (por ejemplo
# al abrir la escena directo desde el editor) se usa el de la escena.
func _apply_chosen_character() -> void:
	var character := GameSettings.get_character(player_id)
	if character == null or character.model_scene == null:
		return
	model_scene = character.model_scene
	model_scale = character.model_scale
	extra_animations = character.extra_animations


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
		"tint": GameSettings.get_character_tint(player_id),
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


# Con "mouse_aim", se apunta con el último dispositivo usado: mouse o mando
func _input(event: InputEvent) -> void:
	if not mouse_aim:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_mouse = true
	elif _is_my_joypad_event(event):
		_using_mouse = false


func _is_my_joypad_event(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) < aim_deadzone:
			return false
	elif not (event is InputEventJoypadButton and event.pressed):
		return false
	var prefix := "p%d_" % player_id
	for action in InputMap.get_actions():
		if String(action).begins_with(prefix) and event.is_action(action):
			return true
	return false


# Botones (los mismos en todos los niveles donde se puede):
#   ✕ (p*_grab)   agarrar / soltar: cortadora, piedra, bota
#   R2 o □ (p*_throw)  usar lo que se tiene: tirar la piedra o colocar el pozo (mouse: clic)
#   △ (p*_place)  también coloca el pozo
#   palanca derecha  apuntar (flecha de la piedra, marca del pozo)
# Con la bota se corre el doble de rápido y se patea al rival solo con tocarlo.
func _unhandled_input(event: InputEvent) -> void:
	if is_disabled():
		return
	if event.is_action_pressed("p%d_grab" % player_id):
		grab_or_drop()


func _physics_process(delta: float) -> void:
	_update_invincibility(delta)
	_update_aiming(delta)
	_update_rock_aim()
	_update_footsteps(delta)

	if is_disabled():
		return
	if held_boot:
		_try_kick()
	var prefix := "p%d_" % player_id
	if Input.is_action_just_pressed(prefix + "throw"):
		# R2 usa lo que se tenga en la mano: tira la piedra o coloca el pozo
		if held_rock:
			throw_rock()
		elif held_pit:
			confirm_aim()
	elif Input.is_action_just_pressed(prefix + "place"):
		confirm_aim()


## Queda invencible (titilando) "seconds" segundos: no le pegan piedras, no
## cae en pozos y no lo pueden patear.
func make_invincible(seconds: float) -> void:
	_invincible_left = seconds


func is_invincible() -> bool:
	return _invincible_left > 0.0


func _update_invincibility(delta: float) -> void:
	var model := get_node_or_null("Model") as Node3D
	if _invincible_left <= 0.0:
		return
	_invincible_left -= delta
	if model:
		# Titila: 10 veces por segundo, y al terminar queda visible
		model.visible = _invincible_left <= 0.0 or fmod(_invincible_left * 10.0, 1.0) > 0.4


## Aturdido, cayendo al pozo o volando por una patada: no puede hacer nada.
func is_disabled() -> bool:
	return state_machine.is_current("stunned") or state_machine.is_current("falling") \
			or state_machine.is_current("kicked")


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
	if has_mower:
		return mower_speed
	return walk_speed * (boot_speed_multiplier if held_boot else 1.0)


func get_run_speed() -> float:
	return run_speed * (boot_speed_multiplier if held_boot else 1.0)


func is_hands_full() -> bool:
	return has_mower or held_rock != null or held_pit != null or held_boot != null


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	Audio.play_sfx_spam(Audio.score_ping)


## ✕: suelta la cortadora si la lleva; si tiene las manos libres agarra lo que
## tenga más cerca (piedra, bota o su cortadora).
func grab_or_drop() -> void:
	if has_mower:
		drop_mower()
		return
	if is_hands_full():
		return

	var item := _get_nearest_item()
	var item_dist := global_position.distance_to(item.global_position) if item else INF
	var mower_dist := global_position.distance_to(mower.global_position) if mower else INF
	if mower_dist <= mower_pickup_distance and mower_dist < item_dist:
		grab_mower()
	elif item is Rock:
		held_rock = item
		item.pick_up(self)
	elif item is Boot:
		held_boot = item
		item.pick_up(self)


# Piedra o bota más cercana que se pueda agarrar, o null
func _get_nearest_item() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := rock_pickup_distance
	for group in ["rock", "boot"]:
		for item in get_tree().get_nodes_in_group(group):
			if not item.is_available:
				continue
			var dist := global_position.distance_to(item.global_position)
			if dist <= nearest_dist:
				nearest = item
				nearest_dist = dist
	return nearest


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
	if is_invincible():
		return
	if has_mower:
		drop_mower()
	if mower:
		mower.take_damage(damage)
	state_machine.force_state("stunned")


## Con la bota no hace falta apretar nada: al pasarle por encima al rival lo
## patea fuera de la cancha, hacia donde va corriendo.
func _try_kick() -> void:
	var rival := _get_rival()
	if rival == null or not _can_kick(rival):
		return

	var to_rival := rival.global_position - global_position
	to_rival.y = 0.0
	var direction := get_facing_direction() + to_rival.normalized()
	if direction.length() < 0.1:
		direction = to_rival
	direction = direction.normalized()

	rotation.y = atan2(-direction.x, -direction.z)
	play_anim(ANIM_KICK if anim and anim.has_animation(ANIM_KICK) else ANIM_THROW, true)
	held_boot.consume()
	held_boot = null
	Audio.play_sfx(Audio.kick_hit)
	rival.get_kicked(direction)
	var camera := get_viewport().get_camera_3d() as CameraRig
	if camera:
		camera.zoom_punch(kick_camera_zoom_out)


func _can_kick(rival: Player) -> bool:
	if rival.is_invincible():
		return false
	if rival.state_machine.is_current("falling") or rival.state_machine.is_current("kicked"):
		return false
	var to_rival := rival.global_position - global_position
	to_rival.y = 0.0
	return to_rival.length() <= kick_range


## Lo patearon con la bota: suelta todo y sale volando hacia "direction".
func get_kicked(direction: Vector3) -> void:
	kick_direction = direction
	_drop_everything()
	state_machine.force_state("kicked")


func fall_into_pit(pit: Pit) -> void:
	falling_pit = pit
	_drop_everything()
	state_machine.force_state("falling")


func _drop_everything() -> void:
	if has_mower:
		drop_mower()
	if held_rock:
		held_rock.drop()
		held_rock = null
	if held_pit:
		held_pit.drop()
		held_pit = null
	if held_boot:
		held_boot.drop()
		held_boot = null


func _update_aiming(delta: float) -> void:
	if reticle == null:
		return

	# La retícula solo se usa para colocar el pozo: aparece al agarrarlo y se
	# mueve con la palanca derecha (sin apretar nada). △ lo coloca.
	if is_disabled() or held_pit == null:
		is_aiming = false
		_was_aiming = false
		reticle.visible = false
		return

	# Con mouse la retícula sigue al cursor siempre que se tenga el pozo
	if mouse_aim and _using_mouse:
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

	is_aiming = true
	reticle.visible = true
	if not _was_aiming:
		_was_aiming = true
		var start := global_position + get_facing_direction() * reticle_start_distance
		reticle.global_position = Vector3(
				clampf(start.x, map_min.x, map_max.x),
				reticle_height,
				clampf(start.z, map_min.y, map_max.y))

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

	var can_aim := held_rock != null and not is_disabled()
	aim_indicator.visible = can_aim
	if not can_aim:
		_aim_from_stick = false
		return

	var prefix := "p%d_" % player_id
	var stick := Input.get_vector(prefix + "aim_left", prefix + "aim_right", prefix + "aim_up", prefix + "aim_down")
	var mouse_direction := _get_mouse_aim_direction() if mouse_aim and _using_mouse else Vector3.ZERO
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
