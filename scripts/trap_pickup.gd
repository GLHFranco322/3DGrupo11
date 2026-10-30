class_name TrapPickup
extends Node3D

# Banana o hielo tirado en el laberinto (lo crea StoreLevel). Se agarra pasando
# por encima, si no se tiene ya una trampa. Después se deja en el piso con △.
# Cada tipo muestra su nodo hijo: Visuals/Banana o Visuals/Ice.

const VISUAL_NAMES := {
	StoreTrap.Kind.BANANA: "Banana",
	StoreTrap.Kind.ICE: "Ice",
}

@export var kind: StoreTrap.Kind = StoreTrap.Kind.BANANA
## Velocidad de giro flotando.
@export_range(0.0, 10.0, 0.1) var spin_speed: float = 2.0

var _time: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var area: Area3D = $Area3D
@onready var label: Label3D = $Label


func _ready() -> void:
	_time = randf() * TAU
	for child in visuals.get_children():
		child.visible = child.name == VISUAL_NAMES.get(kind, "")
	label.text = StoreTrap.KIND_NAMES.get(kind, "")
	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	visuals.rotation.y += spin_speed * delta
	visuals.position.y = 0.5 + sin(_time * 3.0) * 0.1


func _on_body_entered(body: Node) -> void:
	var player := body as StorePlayer
	if player and player.give_trap(kind):
		queue_free()
