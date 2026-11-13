class_name DemoCarrera
extends Demo

# Base de los clips del nivel 3: sin cuenta regresiva, con los dos ya
# corriendo, y cada carretilla se puede poner en cualquier punto de la pista.

var r1: Racer
var r2: Racer


func escena() -> String:
	return "res://niveles/3_carrera/race_level.tscn"


func configurar(n: Node) -> void:
	n.countdown = 0
	n.match_duration = 999.0


func preparar() -> void:
	r1 = nivel.racer1
	r2 = nivel.racer2
	# Sin cámara del nivel: las palancas mueven en el sentido del mundo
	for r in [r1, r2]:
		r.camera_rig = null


## Pone la carretilla a "metros" del largo de la pista (desde la meta), corrida
## "lateral" metros a la derecha, mirando hacia adelante.
func en_pista(r: Racer, metros: float, lateral: float = 0.0) -> void:
	var track: Path3D = nivel.track
	var at: Transform3D = track.global_transform * track.curve.sample_baked_with_rotation(metros)
	var basis := at.basis.orthonormalized()
	r.barrow.global_transform = Transform3D(basis, at.origin + basis.x * lateral + Vector3.UP * 0.3)
	r.barrow.velocity = Vector3.ZERO
	r._follow_seat()
	nivel._tracked.erase(r)


## Mantiene acelerado (R1) a uno o a los dos mientras dure el clip.
func acelerar(id: int, si: bool = true) -> void:
	if si:
		apretar_accion("p%d_accelerate" % id)
	else:
		soltar("p%d_accelerate" % id)
