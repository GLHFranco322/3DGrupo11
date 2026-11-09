@tool
class_name Indicacion
extends HBoxContainer

# Indicación de un botón del mando y lo que hace: el ícono del botón y al lado
# la leyenda (ej: [✕] Seleccionar). Es el formato de todas las ayudas de la
# interfaz; para mostrar varias juntas se ponen en un HBoxContainer (ver
# Botones.llenar para armarlas por código).

## Botón del mando (ver Botones.ICONOS).
@export_enum("X", "O", "CUADRADO", "TRIANGULO", "R1", "R2", "OPTIONS", "PALANCA_IZQ", "PALANCA_DER")
var boton: String = "X":
	set(value):
		boton = value
		_actualizar()
## Lo que hace el botón.
@export var leyenda: String = "Seleccionar":
	set(value):
		leyenda = value
		_actualizar()
## Alto del ícono del botón (el texto usa el estilo "Indicacion" del tema).
@export_range(16, 128, 1, "suffix:px") var alto_icono: int = 36:
	set(value):
		alto_icono = value
		_actualizar()

var _icono: TextureRect
var _texto: Label


static func crear(boton_mando: String, texto: String) -> Indicacion:
	var indicacion := Indicacion.new()
	indicacion.boton = boton_mando
	indicacion.leyenda = texto
	return indicacion


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	_icono = TextureRect.new()
	_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icono, false, Node.INTERNAL_MODE_FRONT)
	_texto = Label.new()
	_texto.theme_type_variation = &"Indicacion"
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_texto, false, Node.INTERNAL_MODE_FRONT)
	_actualizar()


func _actualizar() -> void:
	if _icono == null:
		return
	var textura: Texture2D = Botones.ICONOS.get(boton)
	_icono.texture = textura
	if textura:
		var ancho := alto_icono * float(textura.get_width()) / textura.get_height()
		_icono.custom_minimum_size = Vector2(ancho, alto_icono)
	_texto.text = leyenda
