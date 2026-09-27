class_name Mower
extends AnimatableBody3D

# Lo escribe Player. El corte de pasto va a consultar esto.
var is_held: bool = false

@export var grass_grid: GrassGrid
@export var cut_radius: float = 0.6

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _physics_process(_delta: float) -> void:
	if is_held and grass_grid:
		grass_grid.cut_area(global_position, cut_radius)
