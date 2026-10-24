class_name RaceTrap
extends Node3D

# Trampa que un jugador deja atrás en la carrera. La pisa cualquier carretilla
# (también la de quien la dejó, pasado "Grace Time").
#   Pozo:   la carretilla se hunde y pierde unos segundos.
#   Clavos: se pincha la rueda y anda más lento un rato.

enum Kind { PIT, NAILS }

@export var kind: Kind = Kind.PIT
## Segundos en los que no la pisa quien la dejó (para que no caiga enseguida).
@export_range(0.0, 5.0, 0.1, "suffix:s") var grace_time: float = 1.0
## Si nadie la pisa, desaparece después de este tiempo. 0 = nunca.
@export_range(0.0, 120.0, 1.0, "suffix:s") var lifetime: float = 25.0

@export_group("Pozo")
## Color del pozo cuando alguien cae.
@export var hole_color: Color = Color.BLACK
## Tiempo que tarda en cerrarse después de que alguien cayó.
@export_range(0.05, 5.0, 0.05, "suffix:s") var close_time: float = 0.4

## Quién la dejó (lo pone Racer).
var placed_by: Racer = null

var _age: float = 0.0
var _triggered: bool = false

@onready var area: Area3D = $Area3D
@onready var visual: Node3D = $Visual


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime and not _triggered:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	var racer := Racer.from_body(body)
	if racer == null or body != racer.barrow:
		return
	if racer == placed_by and _age < grace_time:
		return
	# Las señales de física no permiten cambiar colisiones: se posterga
	_trigger.call_deferred(racer)


func _trigger(racer: Racer) -> void:
	if _triggered:
		return
	match kind:
		Kind.NAILS:
			_triggered = true
			racer.run_over_nails()
			queue_free()
		Kind.PIT:
			if not racer.fall_into_pit(global_position):
				return
			_triggered = true
			area.set_deferred("monitoring", false)
			Audio.play_sfx(Audio.pit_fall)
			_paint_hole()
			var wait := racer.pit_freeze_time + racer.pit_sink_time * 2.0 + racer.pit_hidden_time
			await get_tree().create_timer(wait).timeout
			# Se cierra achicándose hacia el centro
			Audio.play_sfx(Audio.pit_close)
			var tween := create_tween()
			tween.tween_property(visual, "scale", Vector3(0.001, 1.0, 0.001), close_time) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			await tween.finished
			queue_free()


func _paint_hole() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = hole_color
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = mat
