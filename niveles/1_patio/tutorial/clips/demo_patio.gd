class_name DemoPatio
extends Demo

# Base de los clips del nivel 1: sin items al azar (cada clip pone los suyos)
# y sin que se termine la partida.

const ROCA := preload("res://niveles/1_patio/items/rock.tscn")
const POZO := preload("res://niveles/1_patio/items/pit.tscn")
const BOTA := preload("res://niveles/1_patio/items/boot.tscn")

var p1: Player
var p2: Player


func escena() -> String:
	return "res://niveles/1_patio/patio.tscn"


func configurar(n: Node) -> void:
	n.countdown = 0


func preparar() -> void:
	nivel.match_duration = 999.0
	nivel.time_left = 999.0
	var spawner := nivel.get_node("ItemSpawner")
	spawner.set_process(false)
	spawner.set_physics_process(false)
	for timer in spawner.find_children("*", "Timer", false, false):
		timer.stop()
	p1 = jugador(1)
	p2 = jugador(2)
	# Con la ventana de grabación abierta apuntarían al mouse
	p1.mouse_aim = false
	p2.mouse_aim = false


## Pone un item (roca, pozo o bota) en el piso, ya listo para agarrar.
func poner_item(item_escena: PackedScene, x: float, z: float) -> Node3D:
	var item := item_escena.instantiate() as Node3D
	item.set("start_height", 0.0)
	item.position = Vector3(x, 0.0, z)
	nivel.add_child(item)
	return item
