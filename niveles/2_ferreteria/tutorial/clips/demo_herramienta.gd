extends DemoFerreteria

# Clip: agarrar una herramienta de la lista con ✕ y colgarla en el tablero
# del mostrador con ✕.


func preparar() -> void:
	super()
	en(p1, mostrador.x - 1.0, mostrador.z - 4.3)
	en(p2, mostrador.x + 9.0, mostrador.z - 6.0)
	poner_herramienta(p1.global_position + Vector3(0.0, 0.3, -1.0), p1)
	mirar(p1, p1.global_position + Vector3(0.0, 0.0, -1.0))
	fijar_camara(Vector3(mostrador.x - 0.5, 0.0, mostrador.z - 2.2), Vector3(4.0, 4.6, -1.9))


func guion() -> void:
	await esperar(0.5)
	await apretar(1, "grab")
	await esperar(0.4)
	# Camina hasta el tablero
	var tiempo := 0.0
	while not nivel.board.is_in_range(p1) and tiempo < 4.0:
		var hacia := mostrador - p1.global_position
		empezar_a_mover(1, Vector2(hacia.x, hacia.z).normalized())
		await get_tree().physics_frame
		tiempo += get_physics_process_delta_time()
	empezar_a_mover(1, Vector2.ZERO)
	await esperar(0.2)
	await apretar(1, "grab")
	await esperar(1.5)
