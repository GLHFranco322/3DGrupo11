extends CharacterBody3D

@export var player_id: int = 1
@export var color: Color = Color.WHITE
@export var max_speed: float = 6.0
@export var acceleration: float = 30.0
@export var friction: float = 25.0
@export var turn_speed: float = 12.0

@onready var body: MeshInstance3D = $Body


func _ready() -> void:
	# Material propio por instancia para que cada jugador tenga su color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat


func _physics_process(delta: float) -> void:
	var prefix := "p%d_" % player_id
	var input := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	var direction := Vector3(input.x, 0.0, input.y)

	if direction != Vector3.ZERO:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
		var target_angle := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, friction * delta)

	move_and_slide()
