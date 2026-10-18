extends Node

# Autoload: guarda el resultado de la última partida para mostrarlo en la
# escena de resultados.

# Jugadores ganadores (más de uno si hay empate). Cada uno es un Dictionary:
# { id, score, color, model_scene, model_scale, extra_animations }
var winners: Array[Dictionary] = []
var scores: Dictionary = {}


func is_tie() -> bool:
	return winners.size() > 1


func save_from(players: Array) -> void:
	winners.clear()
	scores.clear()

	var best := -1
	for p in players:
		scores[p.player_id] = p.score
		best = maxi(best, p.score)

	for p in players:
		if p.score == best:
			winners.append(p.get_display_info())
