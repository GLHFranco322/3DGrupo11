extends DemoCarrera

# Clip: con el rival al lado, □ lo agarra; los dos frenan y, como no se suelta
# a tiempo (apretando □ varias veces), se cae y el que agarró sigue.


func preparar() -> void:
	super()
	en_pista(r1, 70.0, -1.1)
	en_pista(r2, 70.8, 1.1)
	detras_de(r1.barrow, 7.5, 3.6)


func guion() -> void:
	acelerar(1)
	acelerar(2)
	await esperar(0.9)
	await apretar(1, "grab_rival")
	print("agarre: ", r1.grabbing != null, " limite=", r1.get_speed_limit())
	await esperar(2.6)
	print("r2 estado=", r2.state, " (1 = tirado)")
	await esperar(1.0)
	acelerar(1, false)
	acelerar(2, false)
