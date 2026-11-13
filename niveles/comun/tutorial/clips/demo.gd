class_name Demo
extends Node

# Base de los clips de video de los tutoriales. Cada clip es un script que
# extiende esta clase: abre el nivel de verdad, acomoda a los jugadores y los
# maneja "apretando" las mismas acciones que el mando (p1_grab, p1_left...),
# así el clip muestra el juego tal cual es. Se graba con grabar.tscn (ver
# LEEME.md en esta carpeta).
#
# Para hacer un clip nuevo: extender Demo, devolver la escena del nivel en
# escena(), acomodar todo en preparar() y escribir lo que pasa en guion().

## Cuadros por segundo con los que se graba (lo usa grabar.tscn).
const FPS := 30

var nivel: Node
var camara: Camera3D
# Cámara que sigue a estos nodos (su punto medio + "_offset_camara")
var _seguir: Array[Node3D] = []
var _offset_camara := Vector3(0.0, 7.0, 6.0)
var _suavizado: float = 4.0
# Acciones que el clip mantiene apretadas (acción -> fuerza). Se vuelven a
# apretar en cada cuadro: si hay un mando conectado, sus eventos las soltarían
var _mantenidas: Dictionary = {}
# Cámara detrás de un nodo (ej: la carretilla), mirando hacia donde va
var _detras: Node3D = null
var _detras_distancia: float = 6.0
var _detras_altura: float = 3.0


## Escena del nivel en el que pasa el clip.
func escena() -> String:
	return ""


## Ajustes del nivel antes de agregarlo (ej: sacar la cuenta regresiva).
func configurar(_nivel: Node) -> void:
	pass


## Acomoda jugadores, items y cámara (antes del primer cuadro).
func preparar() -> void:
	pass


## Lo que pasa en el clip. Al terminar, se corta la grabación.
func guion() -> void:
	await esperar(1.0)


func _ready() -> void:
	nivel = load(escena()).instantiate()
	configurar(nivel)
	add_child(nivel)
	# Sin HUD (el tutorial ya explica) ni cámaras del nivel
	for node in nivel.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	camara = Camera3D.new()
	camara.fov = 55.0
	add_child(camara)
	camara.make_current()
	preparar()
	_mover_camara(1.0)


func correr_guion() -> void:
	await guion()


func _process(delta: float) -> void:
	_mover_camara(1.0 - exp(-_suavizado * delta))


func _physics_process(_delta: float) -> void:
	for accion in _mantenidas:
		Input.action_press(accion, _mantenidas[accion])


## Mantiene apretada una acción (ej: "p1_accelerate") hasta soltar().
func apretar_accion(accion: String, fuerza: float = 1.0) -> void:
	_mantenidas[accion] = fuerza
	Input.action_press(accion, fuerza)


func soltar(accion: String) -> void:
	_mantenidas.erase(accion)
	Input.action_release(accion)


# --- Cámara -------------------------------------------------------------------

## Cámara quieta mirando a "centro" desde "offset".
func fijar_camara(centro: Vector3, offset: Vector3) -> void:
	var marca := Node3D.new()
	add_child(marca)
	marca.global_position = centro
	seguir([marca], offset)


## Cámara detrás de "nodo" (su +Z es atrás), como en la carrera.
func detras_de(nodo: Node3D, distancia: float = 6.0, altura: float = 3.0, suavizado: float = 5.0) -> void:
	_detras = nodo
	_detras_distancia = distancia
	_detras_altura = altura
	_suavizado = suavizado


## La cámara sigue el punto medio de estos nodos, desde "offset".
func seguir(nodos: Array, offset: Vector3 = _offset_camara, suavizado: float = 4.0) -> void:
	_detras = null
	_seguir.clear()
	for n in nodos:
		_seguir.append(n)
	_offset_camara = offset
	_suavizado = suavizado


func _mover_camara(peso: float) -> void:
	if is_instance_valid(_detras):
		var atras := _detras.global_basis.z
		atras.y = 0.0
		atras = atras.normalized()
		var pos := _detras.global_position + atras * _detras_distancia + Vector3.UP * _detras_altura
		camara.global_position = camara.global_position.lerp(pos, peso)
		camara.look_at(_detras.global_position - atras * 4.0 + Vector3.UP * 0.8, Vector3.UP)
		return
	if _seguir.is_empty():
		return
	var centro := Vector3.ZERO
	var cuenta := 0
	for n in _seguir:
		if is_instance_valid(n) and n.is_inside_tree():
			centro += n.global_position
			cuenta += 1
	if cuenta == 0:
		return
	centro /= cuenta
	var destino := centro + _offset_camara
	camara.global_position = camara.global_position.lerp(destino, peso)
	camara.look_at(camara.global_position - _offset_camara, Vector3.UP)


# --- Jugadores ----------------------------------------------------------------

## Nodo del jugador "id" (el que tenga player_id == id).
func jugador(id: int) -> Node3D:
	for node in nivel.find_children("*", "Node3D", true, false):
		if "player_id" in node and node.player_id == id and node.get_script() != null \
				and node.has_method("get_display_info"):
			return node
	return null


## Mantiene apretadas las direcciones de "dir" (x = izquierda/derecha, y =
## arriba/abajo, como la palanca) durante "segundos".
func mover(id: int, dir: Vector2, segundos: float, extra: Array[String] = []) -> void:
	_direccion(id, dir)
	for accion in extra:
		apretar_accion("p%d_%s" % [id, accion])
	await esperar(segundos)
	_direccion(id, Vector2.ZERO)
	for accion in extra:
		soltar("p%d_%s" % [id, accion])


## Como mover() pero sin esperar (para mover a los dos jugadores a la vez).
func empezar_a_mover(id: int, dir: Vector2) -> void:
	_direccion(id, dir)


func _direccion(id: int, dir: Vector2, prefijo: String = "") -> void:
	var p := "p%d_%s" % [id, prefijo]
	_eje(p + "left", p + "right", dir.x)
	_eje(p + "up", p + "down", dir.y)


func _eje(negativo: String, positivo: String, valor: float) -> void:
	soltar(negativo)
	soltar(positivo)
	if valor < -0.01:
		apretar_accion(negativo, -valor)
	elif valor > 0.01:
		apretar_accion(positivo, valor)


## Mueve la palanca derecha (apuntar) durante "segundos".
func apuntar(id: int, dir: Vector2, segundos: float) -> void:
	_direccion(id, dir, "aim_")
	await esperar(segundos)
	_direccion(id, Vector2.ZERO, "aim_")


## Toca un botón (acción "p<id>_<accion>"), como apretarlo y soltarlo.
func apretar(id: int, accion: String) -> void:
	var nombre := "p%d_%s" % [id, accion]
	var evento := InputEventAction.new()
	evento.action = nombre
	evento.pressed = true
	Input.parse_input_event(evento)
	Input.action_press(nombre)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(nombre)
	var suelta := InputEventAction.new()
	suelta.action = nombre
	suelta.pressed = false
	Input.parse_input_event(suelta)


## Mantiene un botón apretado durante "segundos".
func mantener(id: int, accion: String, segundos: float) -> void:
	apretar_accion("p%d_%s" % [id, accion])
	await esperar(segundos)
	soltar("p%d_%s" % [id, accion])


func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, false, true).timeout


## Pone un nodo en una posición (X, Z) del piso, mirando hacia "mirar_a".
func ubicar(nodo: Node3D, x: float, z: float, mirar_a: Vector3 = Vector3.INF) -> void:
	nodo.global_position = Vector3(x, nodo.global_position.y, z)
	if mirar_a != Vector3.INF:
		var dir := mirar_a - nodo.global_position
		nodo.rotation.y = atan2(-dir.x, -dir.z)
