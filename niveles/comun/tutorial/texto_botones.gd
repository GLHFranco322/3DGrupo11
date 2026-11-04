@tool
class_name TextoConBotones
extends RichTextLabel

# Texto con los botones del mando dibujados en línea. En "texto" se escriben
# las marcas {X}, {O}, {CUADRADO}, {TRIANGULO}, {R1}, {R2} o {PALANCA_DER}
# donde va cada botón; el resto acepta BBCode ([b], [color], etc.).

const BUTTONS := {
	"X": preload("res://niveles/comun/tutorial/botones/boton_cruz.svg"),
	"O": preload("res://niveles/comun/tutorial/botones/boton_circulo.svg"),
	"CUADRADO": preload("res://niveles/comun/tutorial/botones/boton_cuadrado.svg"),
	"TRIANGULO": preload("res://niveles/comun/tutorial/botones/boton_triangulo.svg"),
	"R1": preload("res://niveles/comun/tutorial/botones/boton_r1.svg"),
	"R2": preload("res://niveles/comun/tutorial/botones/boton_r2.svg"),
	"PALANCA_DER": preload("res://niveles/comun/tutorial/botones/palanca_der.svg"),
}

@export_multiline var texto: String = "":
	set(value):
		texto = value
		_rebuild()
## Alto de los botones dentro del texto.
@export var button_height: int = 50:
	set(value):
		button_height = value
		_rebuild()


func _ready() -> void:
	bbcode_enabled = true
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	clear()
	var regex := RegEx.create_from_string("\\{([A-Z_0-9]+)\\}")
	var pos := 0
	for m in regex.search_all(texto):
		append_text(texto.substr(pos, m.get_start() - pos))
		var texture: Texture2D = BUTTONS.get(m.get_string(1))
		if texture:
			var w := int(button_height * float(texture.get_width()) / texture.get_height())
			add_image(texture, w, button_height, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		else:
			append_text(m.get_string())
		pos = m.get_end()
	append_text(texto.substr(pos))
