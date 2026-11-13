extends DemoPatio

# Clip: agarrar la bota con ✕, correr hasta el rival y patearlo con □ / R2.


func preparar() -> void:
	super()
	ubicar(p1, -4.0, 2.0, Vector3(3.0, 0.0, 2.0))
	ubicar(p2, 1.2, 2.0, Vector3(-3.0, 0.0, 2.0))
	poner_item(BOTA, -3.2, 2.0)
	fijar_camara(Vector3(-1.2, 0.0, 2.0), Vector3(0.0, 4.8, 5.6))


func guion() -> void:
	await esperar(0.5)
	await apretar(1, "grab")
	await esperar(0.3)
	await mover(1, Vector2(1.0, 0.0), 0.55, ["run"])
	await apretar(1, "throw")
	await esperar(2.2)
