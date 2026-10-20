extends Node

# Autoload: guarda el resultado de cada nivel y el torneo completo. Cada nivel
# ganado suma una victoria; al terminar el último nivel es campeón el que tiene
# más victorias.

# Ganadores del último nivel (más de uno si hay empate). Cada uno es un Dictionary:
# { id, score, color, model_scene, model_scale, extra_animations }
var winners: Array[Dictionary] = []
var scores: Dictionary = {}
# Escena del nivel que se jugó (para saber cuál sigue)
var last_level_scene: String = ""

# Torneo: player_id -> niveles ganados
var wins: Dictionary = {1: 0, 2: 0}
# player_id -> datos para mostrarlo (del último nivel que jugó)
var player_info: Dictionary = {}


## Arranca un torneo nuevo (al apretar "Jugar" en el menú).
func reset_tournament() -> void:
	wins = {1: 0, 2: 0}
	player_info.clear()
	winners.clear()
	scores.clear()
	last_level_scene = ""


func is_tie() -> bool:
	return winners.size() > 1


func save_from(players: Array) -> void:
	winners.clear()
	scores.clear()

	var best := -1
	for p in players:
		scores[p.player_id] = p.score
		player_info[p.player_id] = p.get_display_info()
		best = maxi(best, p.score)

	for p in players:
		if p.score == best:
			winners.append(p.get_display_info())

	# En empate nadie suma la victoria
	if winners.size() == 1:
		var id: int = winners[0].id
		wins[id] = wins.get(id, 0) + 1


## Campeones del torneo: el o los que tienen más victorias.
func get_champions() -> Array[Dictionary]:
	var best := -1
	for id in wins:
		best = maxi(best, wins[id])
	var result: Array[Dictionary] = []
	for id in wins:
		if wins[id] == best and player_info.has(id):
			result.append(player_info[id])
	return result
