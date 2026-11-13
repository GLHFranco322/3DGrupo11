extends DemoCarrera

# Clip: con la cortadora, ✕ la tira hacia adelante y persigue al rival que va
# primero hasta tirarlo de la carretilla.


func preparar() -> void:
	super()
	en_pista(r1, 18.0, -1.5)
	en_pista(r2, 30.0, 1.5)
	r1.give_item(Racer.Item.MOWER)
	detras_de(r1.barrow, 10.0, 4.6)


func guion() -> void:
	acelerar(1)
	acelerar(2)
	await esperar(0.8)
	await apretar(1, "grab")
	await esperar(1.7)
	acelerar(1, false)
	acelerar(2, false)
