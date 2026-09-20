class_name Mower
extends AnimatableBody3D

# Lo escribe Player. El corte de pasto va a consultar esto.
var is_held: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
