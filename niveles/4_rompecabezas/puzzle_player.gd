class_name PuzzlePlayer
extends Node3D

# Jugador del nivel de los rompecabezas. Está parado del lado +Z de su
# tablero, en primera persona: con la palanca izquierda mueve un cursor sobre
# la mesa y con ✕ agarra o suelta la pieza que tiene debajo. Si pasa un rato
# sin mover piezas, una lucecita le muestra qué pieza va y hacia dónde.
#
# Su personaje se ve desde la cámara del rival (en la propia no, para que no
# tape la mesa).
#
# Botones (se cambian en Proyecto → Configuración → Mapa de entrada):
#   palanca izquierda  mover el cursor
#   ✕  (p*_grab)       agarrar / soltar una pieza

@export_group("Jugador")
## Número de jugador. Define qué controles usa (acciones "p1_*" o "p2_*").
@export_range(1, 2) var player_id: int = 1
## Color del jugador (cursor, HUD, resultados).
@export var color: Color = Color.WHITE

@export_group("Cursor")
## Velocidad del cursor sobre la mesa.
@export_range(0.1, 5.0, 0.05, "suffix:u/s") var cursor_speed: float = 1.2
## Qué tan rápido la pieza que se lleva sigue al cursor.
@export_range(1.0, 60.0, 1.0) var carry_follow: float = 25.0

@export_group("Pista")
## Segundos sin agarrar ni soltar piezas hasta que aparece la pista.
@export_range(0.5, 60.0, 0.5, "suffix:s") var hint_delay: float = 6.0
## Si es true, mover el cursor también cuenta como movimiento (atrasa la pista).
@export var cursor_resets_hint: bool = false
@export var hint_color: Color = Color(1.0, 0.9, 0.35)
## Segundos que tarda la luz en ir de la pieza a su lugar.
@export_range(0.2, 5.0, 0.05, "suffix:s") var hint_travel_time: float = 0.9

@export_group("Cámara")
## Altura de los ojos sobre la mesa.
@export_range(0.2, 3.0, 0.01, "suffix:u") var eye_height: float = 1.1
## Distancia de los ojos al centro del tablero, hacia el jugador.
@export_range(0.2, 3.0, 0.01, "suffix:u") var eye_distance: float = 0.62
## Punto al que mira, corrido desde el centro del tablero hacia el jugador.
@export_range(-1.0, 1.0, 0.01, "suffix:u") var look_offset: float = 0.0
## Campo de visión vertical.
@export_range(20.0, 120.0, 1.0, "suffix:°") var camera_fov: float = 55.0

@export_group("Personaje")
## Personaje si no se eligió uno en el menú (al probar la escena directo).
@export var default_character: CharacterData
## Multiplicador de tamaño del personaje en este nivel.
@export_range(0.1, 5.0, 0.05) var size_multiplier: float = 1.0
## Distancia del personaje al borde de la mesa.
@export_range(0.0, 2.0, 0.01, "suffix:u") var stand_distance: float = 0.35

## Lo pone el nivel: false durante la cuenta regresiva y al terminar.
var controls_enabled: bool = false
## Puntaje para la pantalla de resultados (lo pone el nivel).
var score: int = 0
## Rompecabezas completados.
var completed: int = 0
## Su tablero (lo pone el nivel).
var board: PuzzleBoard
## La pieza que lleva, o null.
var held: PuzzlePiece

var _character: CharacterData
var _anim: AnimationPlayer
var _cursor: Node3D
var _hovered: PuzzlePiece
var _idle_time: float = 0.0
var _hint: Node3D
var _hint_piece: PuzzlePiece
var _hint_time: float = 0.0


## Capa visual de su personaje: la cámara propia no la dibuja.
func get_model_layer() -> int:
	return 10 + player_id


## Prepara al jugador frente a su tablero ("table_edge" = distancia del centro
## del tablero al borde de la mesa, hacia el jugador; "table_height" = altura de
## la mesa).
func setup(player_board: PuzzleBoard, camera: Camera3D, table_edge: float, table_height: float) -> void:
	board = player_board
	_character = GameSettings.get_character(player_id)
	if _character == null:
		_character = default_character
	# El jugador vive en el espacio del tablero
	global_transform = board.global_transform
	_build_cursor()
	_build_hint()
	_load_model(Vector3(0.0, -table_height, table_edge + stand_distance))
	if camera:
		var eye := board.to_global(Vector3(0.0, eye_height, eye_distance))
		var look := board.to_global(Vector3(0.0, 0.0, look_offset))
		camera.fov = camera_fov
		camera.look_at_from_position(eye, look, Vector3.UP)
		camera.cull_mask &= ~(1 << (get_model_layer() - 1))


## Un rompecabezas nuevo: el cursor vuelve al medio y se suelta lo que tenía.
func on_new_puzzle() -> void:
	held = null
	_hovered = null
	_idle_time = 0.0
	_hide_hint()
	_cursor.position = Vector3.ZERO


func _process(delta: float) -> void:
	if board == null:
		return
	_update_hint(delta)
	if not controls_enabled:
		return

	var prefix := "p%d_" % player_id
	var input := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	if input.length() > 0.1:
		_cursor.position = board.clamp_to_area(_cursor.position + Vector3(input.x, 0.0, input.y) * cursor_speed * delta)
		if cursor_resets_hint:
			_on_action()

	if held:
		var target := Vector3(_cursor.position.x, held.position.y, _cursor.position.z)
		held.position = held.position.lerp(target, minf(carry_follow * delta, 1.0))
	else:
		var under := board.piece_at(_cursor.position)
		if under != _hovered:
			if is_instance_valid(_hovered):
				_hovered.set_highlight(false)
			_hovered = under
			if _hovered:
				_hovered.set_highlight(true)

	_idle_time += delta
	if _idle_time >= hint_delay and _hint_piece == null and not board.is_done():
		_show_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or board == null or board.is_done():
		return
	if not event.is_action_pressed("p%d_grab" % player_id):
		return
	if held:
		var piece := held
		held = null
		piece.set_highlight(false)
		board.drop(piece)
	else:
		var piece := board.piece_at(_cursor.position)
		if piece == null:
			return
		held = piece
		_hovered = null
		board.lift(piece)
		piece.set_highlight(true)
		Audio.play_sfx(Audio.piece_grab, 0.0, -4.0)
	_on_action()
	get_viewport().set_input_as_handled()


# Agarró o soltó una pieza: la pista se va y el reloj vuelve a cero
func _on_action() -> void:
	_idle_time = 0.0
	_hide_hint()


# --- Cursor -------------------------------------------------------------------

# Aro del color del jugador apoyado en la mesa, con un punto en el medio
func _build_cursor() -> void:
	_cursor = Node3D.new()
	_cursor.name = "Cursor"
	board.add_child(_cursor)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	material.render_priority = 2

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.035
	torus.outer_radius = 0.048
	torus.material = material
	ring.mesh = torus
	ring.position.y = 0.09
	_cursor.add_child(ring)
	var dot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024
	sphere.material = material
	dot.mesh = sphere
	dot.position.y = 0.09
	_cursor.add_child(dot)
	on_new_puzzle()


# --- Pista --------------------------------------------------------------------

# Lucecita que va y viene de la pieza a su lugar, y un brillo en el lugar
func _build_hint() -> void:
	_hint = Node3D.new()
	_hint.name = "Hint"
	_hint.visible = false
	board.add_child(_hint)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = hint_color
	glow.no_depth_test = true
	glow.render_priority = 1

	var spark := MeshInstance3D.new()
	spark.name = "Spark"
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	sphere.material = glow
	spark.mesh = sphere
	_hint.add_child(spark)
	var light := OmniLight3D.new()
	light.light_color = hint_color
	light.light_energy = 1.5
	light.omni_range = 0.35
	spark.add_child(light)

	var mark := MeshInstance3D.new()
	mark.name = "Mark"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4
	ring.outer_radius = 0.5
	var mark_material := glow.duplicate() as StandardMaterial3D
	mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = mark_material
	mark.mesh = ring
	_hint.add_child(mark)


func _show_hint() -> void:
	_hint_piece = held if held else board.nearest_loose_piece(_cursor.position)
	if _hint_piece == null:
		return
	_hint_time = 0.0
	_hint.visible = true
	# El aro marca el lugar donde va, del tamaño de la pieza
	var mark := _hint.get_node("Mark") as Node3D
	mark.position = _hint_piece.target + Vector3.UP * 0.01
	mark.scale = Vector3.ONE * _hint_piece.size
	Audio.play_sfx(Audio.puzzle_hint, 0.0, -6.0)


func _hide_hint() -> void:
	_hint_piece = null
	if _hint:
		_hint.visible = false


func _update_hint(delta: float) -> void:
	if _hint_piece == null:
		return
	if not is_instance_valid(_hint_piece) or _hint_piece.placed:
		_hide_hint()
		return
	_hint_time += delta
	var t := fmod(_hint_time, hint_travel_time + 0.3) / hint_travel_time
	var from := _hint_piece.position + Vector3.UP * 0.06
	var to := _hint_piece.target + Vector3.UP * 0.06
	var spark := _hint.get_node("Spark") as Node3D
	spark.visible = t <= 1.0
	# Salta en un arquito de la pieza a su lugar
	var k := ease(clampf(t, 0.0, 1.0), -1.6)
	spark.position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 0.12
	var pulse := 0.6 + 0.4 * sin(_hint_time * 8.0)
	var mark := _hint.get_node("Mark") as MeshInstance3D
	(mark.mesh.material as StandardMaterial3D).albedo_color.a = pulse


# --- Personaje ----------------------------------------------------------------

func _load_model(local_position: Vector3) -> void:
	if _character == null or _character.model_scene == null:
		return
	var model := _character.model_scene.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	# Los modelos miran a +Z; el jugador mira hacia el tablero (-Z)
	model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * _character.model_scale * size_multiplier), local_position)
	ModelUtils.tint(model, GameSettings.get_character_tint(player_id))
	for node in model.find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = 1 << (get_model_layer() - 1)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	Player.merge_animations(_anim, _character.extra_animations)
	AnimNames.normalize(_anim)
	play_animation(Player.ANIM_IDLE)


## Reproduce una animación del personaje (si la tiene; si no, "idle").
func play_animation(anim_name: StringName) -> void:
	if _anim == null:
		return
	if _anim.has_animation(anim_name):
		_anim.play(anim_name)
	elif _anim.has_animation(Player.ANIM_IDLE):
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
