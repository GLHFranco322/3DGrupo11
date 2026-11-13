extends DemoFerreteria

# Clip: piña con □ / R2: el rival queda mareado y se le cae la herramienta.


func preparar() -> void:
	super()
	en(p1, frente.x + 7.6, frente.z - 6.0)
	en(p2, frente.x + 10.6, frente.z - 6.0)
	dar_herramienta(p2)
	mirar(p1, p2.global_position)
	mirar(p2, p1.global_position)
	fijar_camara(Vector3(frente.x + 9.4, 0.0, frente.z - 6.0), Vector3(0.0, 4.4, 2.8))


func guion() -> void:
	await esperar(0.4)
	await mover(1, Vector2(1.0, 0.0), 0.35)
	await apretar(1, "throw")
	await esperar(2.2)
