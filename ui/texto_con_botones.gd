@tool
class_name TextoConBotones
extends RichTextLabel

# Texto con los botones del mando dibujados en línea. En "texto" se escriben
# las marcas {X}, {O}, {CUADRADO}, {TRIANGULO}, {R1}, {R2}, {OPTIONS},
# {PALANCA_IZQ} o {PALANCA_DER} donde va cada botón (ver Botones.ICONOS); el
# resto acepta BBCode ([b], [color], etc.). Se usa en los tutoriales y en las
# ayudas de los niveles (ej: "{X} Subite a la carretilla").

@export_multiline var texto: String = "":
	set(value):
		texto = value
		_rebuild()
## Alto de los botones dentro del texto.
@export var button_height: int = 50:
	set(value):
		button_height = value
		_rebuild()
## Alineación del texto.
@export var alineacion: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		alineacion = value
		_rebuild()


func _ready() -> void:
	bbcode_enabled = true
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	clear()
	match alineacion:
		HORIZONTAL_ALIGNMENT_CENTER:
			push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
		HORIZONTAL_ALIGNMENT_RIGHT:
			push_paragraph(HORIZONTAL_ALIGNMENT_RIGHT)
	var regex := RegEx.create_from_string("\\{([A-Z_0-9]+)\\}")
	var pos := 0
	for m in regex.search_all(texto):
		append_text(texto.substr(pos, m.get_start() - pos))
		var texture: Texture2D = Botones.ICONOS.get(m.get_string(1))
		if texture:
			var w := int(button_height * float(texture.get_width()) / texture.get_height())
			add_image(texture, w, button_height, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		else:
			append_text(m.get_string())
		pos = m.get_end()
	append_text(texto.substr(pos))
