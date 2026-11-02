class_name ToolBoard
extends Node3D

# Tablero de la pared donde se cuelgan las herramientas entregadas. El frente
# del tablero es su +Z local. Los jugadores entregan parados en "DeliveryArea".

## Herramientas por fila en el tablero.
@export_range(1, 20) var slots_per_row: int = 6
## Separación entre herramientas colgadas.
@export var slot_spacing: Vector2 = Vector2(0.48, 0.85)
## Tamaño máximo de una herramienta colgada (las más grandes se achican).
@export_range(0.1, 2.0, 0.05, "suffix:u") var hung_size: float = 0.65

@onready var slots: Node3D = $Slots
@onready var delivery_area: Area3D = $DeliveryArea

var _used_slots: int = 0


func is_in_range(body: Node3D) -> bool:
	return delivery_area.overlaps_body(body)


## Cuelga la herramienta en el próximo lugar libre del tablero.
func hang(item: Collectible) -> void:
	@warning_ignore("integer_division")
	var row := _used_slots / slots_per_row
	var column := _used_slots % slots_per_row
	_used_slots += 1
	var width := (slots_per_row - 1) * slot_spacing.x

	# Queda "tomada" por el tablero para que nadie la vuelva a agarrar
	item.holder = self
	item.reparent(slots)
	item.transform = Transform3D(Basis.IDENTITY, Vector3(column * slot_spacing.x - width * 0.5, -row * slot_spacing.y, 0.0))
	item.set_process(false)
	item.label.visible = false
	item.pivot.position = Vector3.ZERO
	item.pivot.rotation = Vector3.ZERO
	if item.data and item.data.size > hung_size:
		item.pivot.scale = Vector3.ONE * (hung_size / item.data.size)
