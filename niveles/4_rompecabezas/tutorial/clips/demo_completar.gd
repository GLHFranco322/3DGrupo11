extends DemoRompecabezas

# Clip: pone las últimas piezas del primero (2x2), el rompecabezas se completa
# y desaparece, y aparece el siguiente, más grande (3x3).


func guion() -> void:
	await esperar(0.7)
	# Ya estaban puestas las dos primeras
	var faltan := sueltas(p1)
	for i in 2:
		p1.board.drop(_en_su_lugar(faltan[i]))
	await esperar(0.4)
	while p1.completed == 0 and not sueltas(p1).is_empty():
		await colocar(p1, sueltas(p1)[0], 0.1)
	# Se completa, desaparece y aparece el de 3x3
	await esperar(2.6)


func _en_su_lugar(pieza: PuzzlePiece) -> PuzzlePiece:
	pieza.position = pieza.target
	return pieza
