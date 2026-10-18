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

var health: int = 100
var is_broken: bool = false

var _repair_progress: float = 0.0
var _body_material: StandardMaterial3D
var _original_color: Color
var _engine_player: AudioStreamPlayer

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body: MeshInstance3D = $Body


func _ready() -> void:
	health = max_health
	sync_to_physics = false

	_body_material = body.get_active_material(0) as StandardMaterial3D
	if _body_material:
		_original_color = _body_material.albedo_color

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
	_update_engine_sound()

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


func _update_engine_sound() -> void:
	if _engine_player == null:
		return
	var running := is_held and not is_broken
	if running and not _engine_player.playing:
		_engine_player.play()
	elif not running and _engine_player.playing:
		_engine_player.stop()


func _on_broken() -> void:
	Audio.play_sfx(Audio.mower_broken)
	if _body_material:
		_body_material.albedo_color = Color(0.35, 0.35, 0.35)


func _on_repaired() -> void:
	Audio.play_sfx(Audio.mower_repaired)
	if _body_material:
		_body_material.albedo_color = _original_color
