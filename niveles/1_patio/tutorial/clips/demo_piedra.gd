extends DemoPatio

# Clip: agarrar la piedra con ✕ y tirársela al rival con □ / R2.


func preparar() -> void:
	super()
	ubicar(p1, -2.5, 2.0, Vector3(3.0, 0.0, 2.0))
	ubicar(p2, 2.5, 2.0, Vector3(-3.0, 0.0, 2.0))
	poner_item(ROCA, -1.7, 2.0)
	fijar_camara(Vector3(0.0, 0.0, 2.0), Vector3(0.0, 4.5, 5.2))


func guion() -> void:
	await esperar(0.5)
	await apretar(1, "grab")
	await esperar(0.5)
	# Apunta con la palanca derecha hacia el rival y tira
	_direccion(1, Vector2(1.0, 0.0), "aim_")
	await esperar(0.35)
	await apretar(1, "throw")
	_direccion(1, Vector2.ZERO, "aim_")
	await esperar(2.2)
