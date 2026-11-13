class_name RacePickup
extends Node3D

# Item que aparece en la pista (lo crea RaceItemSpawner). Se agarra pasando por
# encima con la carretilla. Queda en la pista hasta que alguien lo agarra (con
# "lifetime" mayor a 0, desaparece pasado ese tiempo).
# Cada tipo muestra su nodo hijo: Visuals/Mower, Visuals/Pit, Visuals/Rod.

@export var kind: Racer.Item = Racer.Item.MOWER
## Segundos que dura en la pista (0 = no desaparece). RaceItemSpawner lo pisa
## con su valor.
@export_range(0.0, 120.0, 0.5, "suffix:s") var lifetime: float = 0.0
## Velocidad de giro del item flotando.
@export_range(0.0, 10.0, 0.1) var spin_speed: float = 2.0

const VISUAL_NAMES := {
	Racer.Item.MOWER: "Mower",
	Racer.Item.PIT: "Pit",
	Racer.Item.ROD: "Rod",
}

## Alguien lo agarró (RaceItemSpawner vuelve a poner uno en su lugar).
signal taken

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
	if lifetime > 0.0:
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
		taken.emit()
		queue_free()
