extends DemoRompecabezas

# Clip: con la palanca va hasta una pieza, la agarra con ✕, la lleva a su
# lugar en la bandeja y la suelta con ✕: encastra sola. Pone dos.


func guion() -> void:
	# Que terminen de aparecer las piezas
	await esperar(0.9)
	for i in 2:
		await colocar(p1, sueltas(p1)[0])
		await esperar(0.5)
	await esperar(0.6)
