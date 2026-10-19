class_name Mower
extends AnimatableBody3D

signal health_changed(new_health: int)
signal broken
signal repaired

# Lo escribe Player. El corte de pasto va a consultar esto.
var is_held: bool = false

@export_group("Corte")
## Pasto que corta esta cortadora.
@export var grass_grid: GrassGrid
## Radio alrededor de la cortadora en el que se corta el pasto.
@export_range(0.1, 5.0, 0.05, "suffix:u") var cut_radius: float = 0.6
## Puntos que se ganan por cada celda de pasto cortada.
@export_range(0, 1000) var points_per_cell: int = 20

@export_group("Vida")
## Vida de la cortadora. Al llegar a 0 se rompe.
@export_range(1, 1000) var max_health: int = 100
## Tiempo que hay que sostener la cortadora rota para repararla.
@export_range(0.0, 30.0, 0.5, "suffix:s") var repair_time: float = 4.0

@export_group("Modelo")
## Modelo 3D de la cortadora. Vacío = usa la caja de prueba.
@export var model_scene: PackedScene
## Largo que va a tener el modelo (se escala solo para medir esto).
@export_range(0.2, 5.0, 0.05, "suffix:u") var model_length: float = 1.4
## Giro del modelo. El mango tiene que quedar del lado del jugador (+Z).
@export_range(-180.0, 180.0, 1.0, "suffix:°") var model_yaw: float = 180.0
## Animación del modelo que se reproduce con el motor en marcha.
@export var running_animation: StringName = &"Vibration"

@export_group("Efectos")
## Partículas mientras corta pasto.
@export var cutting_effect: PackedScene
## Partículas mientras está rota (ej: humo negro).
@export var broken_effect: PackedScene
## Dónde salen las partículas de "rota", respecto a la cortadora.
@export var broken_effect_offset: Vector3 = Vector3(0.0, 0.6, 0.0)
## Escala de las partículas de "rota".
@export_range(0.05, 3.0, 0.05) var broken_effect_scale: float = 0.4
## Color de la caja de prueba cuando está rota (solo sin modelo).
@export var broken_color: Color = Color(0.35, 0.35, 0.35)

var health: int = 100
var is_broken: bool = false

var _repair_progress: float = 0.0
var _body_material: StandardMaterial3D
var _original_color: Color
var _engine_player: AudioStreamPlayer
var _model_anim: AnimationPlayer
var _cutting_particles: Array[Node] = []
var _broken_particles: Array[Node] = []
var _cut_timer: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body: MeshInstance3D = $Body
@onready var handle: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health = max_health
	sync_to_physics = false

	if model_scene:
		_setup_model()
	else:
		# Material propio para que el gris de "rota" no afecte a la otra cortadora
		var mat := body.get_active_material(0) as StandardMaterial3D
		if mat:
			_body_material = mat.duplicate()
			body.material_override = _body_material
			_original_color = _body_material.albedo_color

	_cutting_particles = _add_effect(cutting_effect, Vector3.ZERO, 1.0)
	_broken_particles = _add_effect(broken_effect, broken_effect_offset, broken_effect_scale)

	broken.connect(_on_broken)
	repaired.connect(_on_repaired)

	if Audio.mower_engine:
		_engine_player = Audio.create_loop_player(self, Audio.mower_engine, Audio.mower_engine_volume_db)


func take_damage(amount: int) -> void:
	if is_broken:
		return
	health = max(health - amount, 0)
	health_changed.emit(health)
	if health == 0:
		is_broken = true
		broken.emit()


func _physics_process(delta: float) -> void:
	_update_running_feedback()
	_cut_timer = maxf(_cut_timer - delta, 0.0)
	_set_emitting(_cutting_particles, _cut_timer > 0.0)

	if is_broken:
		if is_held:
			_repair_progress += delta
			if _repair_progress >= repair_time:
				_finish_repair()
		else:
			_repair_progress = 0.0
		return

	if is_held and grass_grid:
		var newly_cut := grass_grid.cut_area(global_position, cut_radius)
		if newly_cut > 0:
			_cut_timer = 0.15
			Audio.play_sfx_spam(Audio.grass_cut)
			var player := get_parent() as Player
			if player:
				player.add_score(newly_cut * points_per_cell)


func _finish_repair() -> void:
	health = max_health
	is_broken = false
	_repair_progress = 0.0
	health_changed.emit(health)
	repaired.emit()


# Motor y vibración: solo mientras se empuja y no está rota
func _update_running_feedback() -> void:
	var running := is_held and not is_broken

	if _engine_player:
		if running and not _engine_player.playing:
			_engine_player.play()
		elif not running and _engine_player.playing:
			_engine_player.stop()

	if _model_anim and _model_anim.has_animation(running_animation):
		if running and not _model_anim.is_playing():
			_model_anim.play(running_animation)
		elif not running and _model_anim.is_playing():
			_model_anim.stop()


func _setup_model() -> void:
	body.visible = false
	handle.visible = false

	var model := model_scene.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	_fit_model(model)

	_model_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _model_anim and _model_anim.has_animation(running_animation):
		_model_anim.get_animation(running_animation).loop_mode = Animation.LOOP_LINEAR


# Escala el modelo para que mida "model_length" y lo apoya en el piso centrado
func _fit_model(model: Node3D) -> void:
	model.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(model_yaw)), Vector3.ZERO)
	var bounds := _get_local_bounds(model)
	var longest := maxf(bounds.size.x, bounds.size.z)
	if longest <= 0.0:
		return
	model.scale = Vector3.ONE * (model_length / longest)

	bounds = _get_local_bounds(model)
	var center := bounds.get_center()
	model.position -= Vector3(center.x, bounds.position.y, center.z)


func _get_local_bounds(root: Node) -> AABB:
	var to_local := global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box := (to_local * visual.global_transform) * visual.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _add_effect(scene: PackedScene, offset: Vector3, effect_scale: float) -> Array[Node]:
	var particles: Array[Node] = []
	if scene == null:
		return particles
	var effect := scene.instantiate() as Node3D
	effect.position = offset
	effect.scale = Vector3.ONE * effect_scale
	add_child(effect)
	var nodes: Array[Node] = [effect]
	nodes.append_array(effect.find_children("*", "", true, false))
	for node in nodes:
		if node is GPUParticles3D or node is CPUParticles3D:
			node.emitting = false
			particles.append(node)
	return particles


func _set_emitting(particles: Array[Node], value: bool) -> void:
	for p in particles:
		if p.emitting != value:
			p.emitting = value


func _on_broken() -> void:
	Audio.play_sfx(Audio.mower_broken)
	_set_emitting(_broken_particles, true)
	if _body_material:
		_body_material.albedo_color = broken_color


func _on_repaired() -> void:
	Audio.play_sfx(Audio.mower_repaired)
	_set_emitting(_broken_particles, false)
	if _body_material:
		_body_material.albedo_color = _original_color
