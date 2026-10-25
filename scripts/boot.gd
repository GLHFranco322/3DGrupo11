class_name Boot
extends Node3D

# Bota que aparece en el piso (la crea ItemSpawner). Se agarra con ✕: el que la
# tiene corre el doble de rápido y, al pasarle por encima al rival, lo patea
# fuera de la cancha (como la patada de Tusk en Dota 2). Si nadie la agarra
# antes de "lifetime" segundos, desaparece.

## Segundos que dura en el piso antes de desaparecer. ItemSpawner lo pisa con su valor.
@export_range(0.5, 60.0, 0.5, "suffix:s") var lifetime: float = 5.0

var is_held: bool = false
var is_available: bool = true

var _home_parent: Node

@onready var item_timer: ItemTimer = $ItemTimer


func _ready() -> void:
	_home_parent = get_parent()
	item_timer.expired.connect(queue_free)
	item_timer.start(lifetime)


func pick_up(holder: Player) -> void:
	is_held = true
	is_available = false
	item_timer.stop()
	Audio.play_sfx(Audio.boot_grab)
	reparent(holder)
	global_transform = holder.hold_transform(holder.boot_hold_offset)


## Se usó para patear: desaparece.
func consume() -> void:
	queue_free()


# La suelta en el piso donde está (ej: el jugador cayó a un pozo) y vuelve a
# correr su tiempo
func drop() -> void:
	if not is_held:
		return
	var world_position := global_position
	reparent(_home_parent)
	global_transform = Transform3D(Basis.IDENTITY, Vector3(world_position.x, 0.0, world_position.z))
	is_held = false
	is_available = true
	item_timer.start(lifetime)
