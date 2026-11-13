extends DemoCarrera

# Clip: con la caña, ✕ pesca al rival que está cerca y lo tira.


func preparar() -> void:
	super()
	en_pista(r1, 22.0, -1.6)
	en_pista(r2, 25.0, 1.6)
	r1.give_item(Racer.Item.ROD)
	detras_de(r1.barrow, 9.0, 4.2)


func guion() -> void:
	acelerar(1)
	acelerar(2)
	await esperar(0.9)
	await apretar(1, "grab")
	await esperar(1.5)
	acelerar(1, false)
	acelerar(2, false)
