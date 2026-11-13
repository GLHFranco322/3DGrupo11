extends DemoPatio

# Clip: agarrar la cortadora con ✕ y cortar pasto.


func preparar() -> void:
	super()
	ubicar(p1, 9.0, 4.9, Vector3(9.0, 0.0, 3.5))
	ubicar(p2, -12.0, -5.0)
	seguir([p1], Vector3(0.0, 4.2, 4.2))


func guion() -> void:
	await esperar(0.6)
	await apretar(1, "grab")
	await esperar(0.3)
	await mover(1, Vector2(0.0, -1.0), 1.4)
	await mover(1, Vector2(-1.0, -0.3), 1.2)
	await mover(1, Vector2(-0.3, 1.0), 1.2)
	await esperar(0.4)
