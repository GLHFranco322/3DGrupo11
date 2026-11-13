@tool
class_name VentanaVideo
extends Control

# Clip del juego pegado en la libreta como una foto: marco blanco, cinta arriba
# y un epígrafe corto debajo (acepta los botones del mando, ver
# TextoConBotones: "{CUADRADO} Tirar"). El video se repite sin sonido.
# Los clips se graban con niveles/comun/tutorial/clips/ (ver LEEME.md).

## Clip (.ogv).
@export var video: VideoStream:
	set(value):
		video = value
		_actualizar()
## Epígrafe debajo de la foto (vacío = sin epígrafe).
@export_multiline var texto: String = "":
	set(value):
		texto = value
		_actualizar()
## Inclinación de la foto (como pegada a mano).
@export_range(-10.0, 10.0, 0.1, "suffix:°") var inclinacion: float = 0.0:
	set(value):
		inclinacion = value
		_actualizar()
## Borde blanco alrededor del video.
@export_range(0, 40, 1, "suffix:px") var marco: int = 10:
	set(value):
		marco = value
		_actualizar()
## Alto de los botones dentro del epígrafe.
@export_range(16, 80, 1, "suffix:px") var alto_botones: int = 40:
	set(value):
		alto_botones = value
		_actualizar()

var _reproductor: VideoStreamPlayer
var _epigrafe: TextoConBotones


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reproductor = VideoStreamPlayer.new()
	_reproductor.expand = true
	_reproductor.loop = true
	_reproductor.volume_db = -80.0
	_reproductor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reproductor, false, Node.INTERNAL_MODE_FRONT)
	_epigrafe = TextoConBotones.new()
	_epigrafe.fit_content = true
	_epigrafe.scroll_active = false
	_epigrafe.autowrap_mode = TextServer.AUTOWRAP_OFF
	_epigrafe.alineacion = HORIZONTAL_ALIGNMENT_CENTER
	_epigrafe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_epigrafe, false, Node.INTERNAL_MODE_BACK)


func _ready() -> void:
	resized.connect(_actualizar)
	_actualizar()
	if not Engine.is_editor_hint():
		_reproductor.play()


func _actualizar() -> void:
	if _reproductor == null:
		return
	pivot_offset = size * 0.5
	rotation_degrees = inclinacion
	_reproductor.stream = video
	_reproductor.position = Vector2(marco, marco)
	_reproductor.size = size - Vector2(marco, marco) * 2.0
	_epigrafe.button_height = alto_botones
	_epigrafe.texto = texto
	_epigrafe.visible = texto != ""
	_epigrafe.position = Vector2(-40.0, size.y + 6.0)
	_epigrafe.size = Vector2(size.x + 80.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Sombra, papel de foto y un fino borde
	draw_rect(Rect2(rect.position + Vector2(5, 7), rect.size), Color(0, 0, 0, 0.22))
	draw_rect(rect, Color(0.985, 0.98, 0.965))
	draw_rect(rect, Color(0, 0, 0, 0.12), false, 1.0)
	# Fondo del video (por si tarda en arrancar)
	draw_rect(Rect2(Vector2(marco, marco), size - Vector2(marco, marco) * 2.0), Color(0.12, 0.13, 0.16))
	# Cinta arriba al centro, un poco torcida
	var cinta := Vector2(minf(size.x * 0.32, 130.0), 30.0)
	draw_set_transform(Vector2(size.x * 0.5, -6.0), deg_to_rad(-3.0 - inclinacion * 0.5))
	draw_rect(Rect2(-cinta * 0.5, cinta), Color(0.93, 0.9, 0.78, 0.72))
	draw_set_transform(Vector2.ZERO)
