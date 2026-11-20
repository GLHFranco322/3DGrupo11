extends Node3D

@onready var presentacion = $CinematicaInicial

func _ready():
	presentacion.play("CinematicaPresentacion")
