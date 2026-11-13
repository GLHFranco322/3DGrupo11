extends DemoCarrera

# Clip: la reja eléctrica te tira de la carretilla; caminás hasta ella y te
# subís con ✕.

var _reja: Node3D


func preparar() -> void:
	super()
	_reja = nivel.get_node("TrackPieces/Grate1")
	en_pista(r1, _reja.track_offset - 13.0, 0.0)
	en_pista(r2, 60.0, 0.0)
	_reja.off_time = 999.0
	_reja._time = 0.0
	detras_de(r1.barrow, 6.5, 3.2)


func guion() -> void:
	acelerar(1)
	# La reja avisa y se prende justo cuando llega
	var avisó := false
	var tiempo := 0.0
	while r1.state == Racer.Mode.RIDING and tiempo < 6.0:
		var lejos: float = _reja.global_position.distance_to(r1.barrow.global_position)
		if not avisó and lejos < 9.0:
			avisó = true
			_reja._time = _reja.off_time
		await get_tree().physics_frame
		tiempo += get_physics_process_delta_time()
	acelerar(1, false)
	# Se apaga y queda apagada
	_reja._time = 0.0
	detras_de(r1.rider, 6.0, 3.0)
	await esperar(1.1)
	# Camina hasta la carretilla y se sube
	tiempo = 0.0
	while not r1.can_climb() and tiempo < 4.0:
		var hacia: Vector3 = r1.barrow.global_position - r1.rider.global_position
		empezar_a_mover(1, Vector2(hacia.x, hacia.z).normalized())
		await get_tree().physics_frame
		tiempo += get_physics_process_delta_time()
	empezar_a_mover(1, Vector2.ZERO)
	await apretar(1, "grab")
	detras_de(r1.barrow, 6.5, 3.2)
	acelerar(1)
	await esperar(1.5)
	acelerar(1, false)
