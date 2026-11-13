extends DemoRompecabezas

# Clip: el jugador se queda quieto, aparece la pista (una lucecita va de la
# pieza que sigue a su lugar) y él la pone ahí.


func preparar() -> void:
	super()
	# En el juego tarda más; acá aparece enseguida
	p1.hint_delay = 1.2


func guion() -> void:
	await esperar(3.4)
	var pieza: PuzzlePiece = p1._hint_piece
	if pieza == null:
		pieza = sueltas(p1)[0]
	await colocar(p1, pieza)
	await esperar(0.8)
