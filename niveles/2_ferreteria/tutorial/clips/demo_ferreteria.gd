class_name DemoFerreteria
extends Demo

# Base de los clips del nivel 2: siempre el mismo laberinto (semilla fija), sin
# trampas tiradas al azar y con los dos jugadores en la zona de atención.

const SEMILLA := 20251113

var p1: StorePlayer
var p2: StorePlayer
# Centro de la zona de atención (en el piso) y el mostrador
var frente: Vector3
var mostrador: Vector3


func escena() -> String:
	return "res://niveles/2_ferreteria/store_level.tscn"


func configurar(n: Node) -> void:
	n.max_trap_pickups = 0
	n.trap_respawn_time = 999.0
	n.match_duration = 999.0
	n.get_node("Maze").maze_seed = SEMILLA


func preparar() -> void:
	p1 = nivel.player1
	p2 = nivel.player2
	# Sin cámara del nivel: las palancas mueven en el sentido del mundo
	for p in [p1, p2]:
		p.camera_rig = null
	frente = nivel.maze.get_front_center()
	mostrador = nivel.counter.global_position


## Pone una herramienta en el piso (de la lista del jugador "para", si se da).
func poner_herramienta(posicion: Vector3, para: StorePlayer = null) -> Collectible:
	var item := nivel.collectible_scene.instantiate() as Collectible
	item.data = para.remaining[0] if para else nivel.item_pool[0]
	nivel.items_root.add_child(item)
	item.global_position = posicion
	return item


## El jugador ya tiene esta herramienta en la mano.
func dar_herramienta(p: StorePlayer) -> void:
	var item := poner_herramienta(p.global_position)
	p.carried = item
	item.pick_up(p, p.hold_point)


## Gira el modelo del jugador hacia "punto".
func mirar(p: StorePlayer, punto: Vector3) -> void:
	var dir := punto - p.global_position
	p.model_root.rotation.y = atan2(-dir.x, -dir.z)


func en(p: StorePlayer, x: float, z: float) -> void:
	p.global_position = Vector3(x, p.global_position.y, z)
	p.velocity = Vector3.ZERO
