class_name RacePickup
extends Node3D

# Item que aparece en la pista (lo crea RaceItemSpawner). Se agarra pasando por
# encima con la carretilla. Si nadie lo agarra en "lifetime" segundos, desaparece.
# Cada tipo muestra su nodo hijo: Visuals/Rock, Visuals/Pit, Visuals/Nails, Visuals/Turbo.

@export var kind: Racer.Item = Racer.Item.ROCK
## Segundos que dura en la pista. RaceItemSpawner lo pisa con su valor.
@export_range(0.5, 120.0, 0.5, "suffix:s") var lifetime: float = 10.0
## Velocidad de giro del item flotando.
@export_range(0.0, 10.0, 0.1) var spin_speed: float = 2.0

const VISUAL_NAMES := {
	Racer.Item.ROCK: "Rock",
	Racer.Item.PIT: "Pit",
	Racer.Item.NAILS: "Nails",
	Racer.Item.TURBO: "Turbo",
}

var _time: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var area: Area3D = $Area3D
@onready var item_timer: ItemTimer = $ItemTimer
@onready var label: Label3D = $Label


func _ready() -> void:
	# Los hijos que no son de ningún tipo (ej: la burbuja) se ven siempre
	for child in visuals.get_children():
		if String(child.name) in VISUAL_NAMES.values():
			child.visible = child.name == VISUAL_NAMES.get(kind, "")
	label.text = Racer.ITEM_NAMES.get(kind, "")
	item_timer.blink_node = visuals
	item_timer.expired.connect(queue_free)
	item_timer.start(lifetime)
	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	visuals.rotation.y += spin_speed * delta
	visuals.position.y = 0.6 + sin(_time * 3.0) * 0.12


func _on_body_entered(body: Node) -> void:
	var racer := Racer.from_body(body)
	if racer == null or body != racer.barrow:
		return
	if racer.give_item(kind):
		queue_free()
