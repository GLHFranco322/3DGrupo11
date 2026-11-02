class_name StoreTrap
extends Node3D

# Trampa que un jugador deja en el piso de la ferretería. Solo la pisa el rival.
#   Banana: se resbala, queda tirado un momento y la herramienta le sale volando lejos.
#   Hielo:  patina sin control hacia donde caminaba y suelta la herramienta.

enum Kind { BANANA, ICE }

const KIND_NAMES := {
	Kind.BANANA: "Banana",
	Kind.ICE: "Hielo",
}

@export var kind: Kind = Kind.BANANA
## Si nadie la pisa, desaparece después de este tiempo. 0 = nunca.
@export_range(0.0, 300.0, 1.0, "suffix:s") var lifetime: float = 40.0
## Si se gasta al pisarla (la banana sí; el hielo queda para el próximo).
@export var single_use: bool = true

## Quién la dejó (no le hace nada a él). Lo pone StorePlayer.
var placed_by: StorePlayer = null

var _age: float = 0.0

@onready var area: Area3D = $Area3D


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	var player := body as StorePlayer
	if player == null or player == placed_by or player.is_disabled():
		return
	# Las señales de física no permiten mover cosas con colisión: se posterga
	match kind:
		Kind.BANANA:
			player.slip_on_banana.call_deferred()
		Kind.ICE:
			player.slide_on_ice.call_deferred()
	if single_use:
		area.set_deferred("monitoring", false)
		queue_free()
