extends DemoFerreteria

# Clip: con la banana, △ la deja atrás y el rival que viene corriendo se
# resbala y pierde la herramienta.

var trampa := StoreTrap.Kind.BANANA


func preparar() -> void:
	super()
	en(p1, frente.x + 7.0, frente.z - 6.0)
	en(p2, frente.x + 3.5, frente.z - 6.0)
	p1.give_trap(trampa)
	dar_herramienta(p2)
	mirar(p1, p1.global_position + Vector3.RIGHT)
	mirar(p2, p2.global_position + Vector3.RIGHT)
	fijar_camara(Vector3(frente.x + 8.0, 0.0, frente.z - 6.0), Vector3(0.0, 5.8, 3.6))


func guion() -> void:
	empezar_a_mover(1, Vector2(1.0, 0.0))
	await esperar(0.5)
	await apretar(1, "place")
	empezar_a_mover(1, Vector2.ZERO)
	await esperar(0.2)
	empezar_a_mover(2, Vector2(1.0, 0.0))
	await esperar(0.9)
	await esperar(0.5)
	empezar_a_mover(2, Vector2.ZERO)
	await esperar(1.6)
