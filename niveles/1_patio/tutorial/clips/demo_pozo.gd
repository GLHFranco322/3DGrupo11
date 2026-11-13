extends DemoPatio

# Clip: pasar por encima del pozo para agarrarlo, mover la marca con la palanca
# derecha hasta el camino del rival, colocarlo con □ / R2 y el rival cae.
# Plano abierto, así se ven las tres cosas (agarrarlo, ponerlo y la caída).

# Dónde se pone el pozo (en el camino del rival)
const DESTINO := Vector3(2.6, 0.0, 1.4)


func preparar() -> void:
	super()
	ubicar(p1, -3.6, 1.4, Vector3(0.0, 0.0, 1.4))
	ubicar(p2, 2.6, -2.2, Vector3(2.6, 0.0, 5.0))
	poner_item(POZO, -2.6, 1.4)
	fijar_camara(Vector3(-0.5, 0.0, -0.1), Vector3(0.0, 6.8, 6.8))


func guion() -> void:
	await esperar(0.4)
	# Lo agarra pasando por encima
	await mover(1, Vector2(1.0, 0.0), 0.6)
	await esperar(0.3)
	# Lleva la marca con la palanca derecha hasta el camino del rival
	var tiempo := 0.0
	while tiempo < 2.5:
		var falta := DESTINO - p1.reticle.global_position
		falta.y = 0.0
		if falta.length() < 0.15:
			break
		var dir := Vector2(falta.x, falta.z).normalized() * clampf(falta.length(), 0.35, 1.0)
		_direccion(1, dir, "aim_")
		await get_tree().physics_frame
		tiempo += get_physics_process_delta_time()
	_direccion(1, Vector2.ZERO, "aim_")
	await esperar(0.3)
	await apretar(1, "throw")
	await esperar(0.4)
	# El rival baja caminando y cae
	await mover(2, Vector2(0.0, 1.0), 1.6)
	await esperar(1.6)
