extends "res://niveles/2_ferreteria/tutorial/clips/demo_banana.gd"

# Clip: con el hielo, △ lo deja atrás y el rival patina sin control.


func preparar() -> void:
	trampa = StoreTrap.Kind.ICE
	super()
