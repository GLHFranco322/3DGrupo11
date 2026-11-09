class_name Botones

# Íconos de los botones del mando (estilo PS4) que usa toda la interfaz: las
# indicaciones de los menús (Indicacion), los textos con botones en línea
# (TextoConBotones) y los tutoriales. Se nombran con estas claves.

const ICONOS := {
	"X": preload("res://ui/botones/boton_cruz.svg"),
	"O": preload("res://ui/botones/boton_circulo.svg"),
	"CUADRADO": preload("res://ui/botones/boton_cuadrado.svg"),
	"TRIANGULO": preload("res://ui/botones/boton_triangulo.svg"),
	"R1": preload("res://ui/botones/boton_r1.svg"),
	"R2": preload("res://ui/botones/boton_r2.svg"),
	"OPTIONS": preload("res://ui/botones/boton_options.svg"),
	"PALANCA_IZQ": preload("res://ui/botones/palanca_izq.svg"),
	"PALANCA_DER": preload("res://ui/botones/palanca_der.svg"),
}


## Reemplaza las indicaciones de "contenedor" por las de "lista": cada una es
## [botón, leyenda], ej: [["X", "Seleccionar"], ["O", "Volver"]].
static func llenar(contenedor: Container, lista: Array) -> void:
	for hijo in contenedor.get_children():
		if hijo is Indicacion:
			contenedor.remove_child(hijo)
			hijo.queue_free()
	for par in lista:
		contenedor.add_child(Indicacion.crear(par[0], par[1]))
