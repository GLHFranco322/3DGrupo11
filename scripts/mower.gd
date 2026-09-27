class_name Mower
extends AnimatableBody3D

signal health_changed(new_health: int)
signal broken
signal repaired

# Lo escribe Player. El corte de pasto va a consultar esto.
var is_held: bool = false

@export var grass_grid: GrassGrid
@export var cut_radius: float = 0.6
@export var points_per_cell: int = 20

@export var max_health: int = 100
@export var damage_per_hit: int = 20
@export var repair_time: float = 4.0

var health: int = 100
var is_broken: bool = false

var _repair_progress: float = 0.0
var _body_material: StandardMaterial3D
var _original_color: Color

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


func take_damage(amount: int) -> void:
	if is_broken:
		return
	health = max(health - amount, 0)
	health_changed.emit(health)
	if health == 0:
		is_broken = true
		broken.emit()


func _physics_process(delta: float) -> void:
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
			var player := get_parent() as Player
			if player:
				player.add_score(newly_cut * points_per_cell)


func _finish_repair() -> void:
	health = max_health
	is_broken = false
	_repair_progress = 0.0
	health_changed.emit(health)
	repaired.emit()


func _on_broken() -> void:
	if _body_material:
		_body_material.albedo_color = Color(0.35, 0.35, 0.35)


func _on_repaired() -> void:
	if _body_material:
		_body_material.albedo_color = _original_color
