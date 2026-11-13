extends DemoCarrera

# Clip: con el pozo, ✕ lo deja atrás y el rival que viene detrás se hunde.


func preparar() -> void:
	super()
	en_pista(r1, 30.0, 1.2)
	en_pista(r2, 18.0, 1.2)
	r1.give_item(Racer.Item.PIT)
	detras_de(r2.barrow, 6.5, 3.0)


func guion() -> void:
	acelerar(1)
	acelerar(2)
	await esperar(0.7)
	await apretar(1, "grab")
	await esperar(2.2)
	acelerar(1, false)
	acelerar(2, false)
