@tool
class_name BoostPad
extends TrackPiece

# Rampa de turbo en el piso: al pasar por encima, la carretilla sale disparada a
# "Boost Speed" durante "Boost Time" y después vuelve de a poco a su velocidad
# normal. Las flechas se mueven hacia adelante.

const SHADER := preload("res://shaders/boost_pad.gdshader")

@export_group("Turbo")
## Velocidad a la que sale disparada.
@export_range(1.0, 60.0, 0.5, "suffix:u/s") var boost_speed: float = 17.0
## Segundos que mantiene esa velocidad.
@export_range(0.1, 10.0, 0.1, "suffix:s") var boost_time: float = 1.2

@export_group("Dibujo")
@export var arrow_color: Color = Color(0.1, 0.9, 1.0):
	set(value):
		arrow_color = value
		_rebuild()
## Brillo de las flechas (más de 1 = resplandor).
@export_range(0.0, 10.0, 0.1) var energy: float = 3.0:
	set(value):
		energy = value
		_rebuild()
## Metros entre flecha y flecha.
@export_range(0.5, 10.0, 0.1, "suffix:u") var arrow_spacing: float = 1.6:
	set(value):
		arrow_spacing = value
		_rebuild()
## Velocidad a la que avanzan las flechas.
@export_range(0.0, 10.0, 0.1) var scroll_speed: float = 1.5:
	set(value):
		scroll_speed = value
		_rebuild()


func _build(root: Node3D) -> void:
	var material := _make_plane(root, SHADER, Vector2(width, length))
	material.set_shader_parameter("arrow_color", arrow_color)
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("arrows", length / arrow_spacing)
	# Misma punta en metros sin importar el tamaño de la rampa
	material.set_shader_parameter("sharpness", 0.9 * width / length)
	material.set_shader_parameter("scroll_speed", scroll_speed)
	var area := _make_area(root)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	var racer := _riding_racer(body)
	if racer and racer.boost(boost_speed, boost_time):
		Audio.play_sfx(Audio.boost_pad)
