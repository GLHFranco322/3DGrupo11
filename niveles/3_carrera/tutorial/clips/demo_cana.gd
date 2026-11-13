extends DemoCarrera

# Clip: el que tiene la caña va detrás del rival; con ✕ lo pesca y lo tira de
# la carretilla (sale despedido hacia atrás).
# Arrancan pasando el primer turbo (metro 22, carril izquierdo), así ninguno
# sale disparado.


func preparar() -> void:
	super()
	en_pista(r1, 27.0, 1.2)
	en_pista(r2, 39.0, 0.6)
	r1.give_item(Racer.Item.ROD)
	detras_de(r1.barrow, 9.0, 4.2)


func guion() -> void:
	acelerar(1)
	acelerar(2)
	await esperar(1.0)
	await apretar(1, "grab")
	await esperar(1.8)
	acelerar(1, false)
	acelerar(2, false)
