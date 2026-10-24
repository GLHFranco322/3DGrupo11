class_name SlowZone
extends Area3D

# Zona de la pista que frena a las carretillas (barro, charco, pasto alto).
# Se le cambia el tamaño con su CollisionShape3D y el dibujo con su malla.

## Velocidad máxima dentro de la zona (multiplica la de la carretilla). 0.5 = la mitad.
@export_range(0.05, 1.0, 0.05) var speed_multiplier: float = 0.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	var racer := Racer.from_body(body)
	if racer and body == racer.barrow:
		racer.enter_zone(self, speed_multiplier)


func _on_body_exited(body: Node) -> void:
	var racer := Racer.from_body(body)
	if racer and body == racer.barrow:
		racer.exit_zone(self)
