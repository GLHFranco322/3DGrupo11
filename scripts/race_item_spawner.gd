class_name RaceItemSpawner
extends Node3D

# Cada cierto tiempo pone una fila de items atravesada en la pista, por delante
# del que va primero: uno de cada tipo (piedra, pozo y caña de pescar), en orden
# al azar. Todo el azar de los items se decide acá (en online lo va a decidir
# solo el anfitrión).

@export_group("Items")
@export var pickup_scene: PackedScene
## Items de cada fila (se reparten en este orden, mezclado en cada fila).
@export var row_items: Array[Racer.Item] = [Racer.Item.ROCK, Racer.Item.PIT, Racer.Item.ROD]
## Separación entre los items de una fila (a lo ancho de la pista).
@export_range(0.5, 5.0, 0.1, "suffix:u") var item_spacing: float = 3.6
## Segundos que dura cada item en la pista antes de desaparecer.
@export_range(0.5, 120.0, 0.5, "suffix:s") var item_lifetime: float = 15.0

@export_group("Ritmo")
## Filas que ya están en la pista al largar (repartidas a lo largo del recorrido).
@export_range(0, 20) var initial_rows: int = 4
## Cada cuánto aparece una fila nueva.
@export_range(0.5, 60.0, 0.5, "suffix:s") var row_interval: float = 6.0
## Máximo de filas en la pista al mismo tiempo.
@export_range(1, 20) var max_rows: int = 5

@export_group("Zona")
## Recorrido de la pista (el mismo Path3D que usa el nivel).
@export var track: Path3D
## No aparecen en los metros después de la meta (la largada).
@export_range(0.0, 100.0, 1.0, "suffix:u") var start_margin: float = 20.0
## No aparecen en los metros antes de la meta.
@export_range(0.0, 100.0, 1.0, "suffix:u") var end_margin: float = 12.0
## Las filas nuevas aparecen entre estas dos distancias delante del primero.
@export var ahead_of_leader: Vector2 = Vector2(25.0, 60.0)
## Distancia mínima (a lo largo de la pista) entre dos filas.
@export_range(0.0, 100.0, 1.0, "suffix:u") var min_row_gap: float = 18.0
## Intentos para encontrar un lugar libre antes de saltear esa fila.
@export_range(1, 50) var max_attempts: int = 15
## Distancia mínima entre una fila y el piso cortado.
@export_range(0.0, 30.0, 0.5, "suffix:u") var item_clearance: float = 4.0

## Lo pone el nivel: false durante la cuenta regresiva y al terminar.
var active: bool = false
## Metros totales del primero (lo pone el nivel, sumando las vueltas), para que
## los items aparezcan por delante.
var leader_progress: float = 0.0

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
# Fila -> metros sobre la vuelta donde está (para no amontonarlas)
var _rows: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_timer = row_interval


## Filas que ya están en la pista al largar (lo llama el nivel cuando los
## jugadores ya están listos).
func spawn_initial_items() -> void:
	if track == null or initial_rows <= 0:
		return
	var from := start_margin
	var to := track.curve.get_baked_length() - end_margin
	for i in initial_rows:
		var offset := lerpf(from, to, (i + 0.5) / initial_rows) + _rng.randf_range(-5.0, 5.0)
		# Si cae sobre el piso cortado, se corre un poco hacia adelante
		var tries := 0
		while _is_blocked(offset, to + end_margin) and tries < 10:
			offset += 4.0
			tries += 1
		spawn_row(offset)


func _process(delta: float) -> void:
	if not active:
		return
	_clean_rows()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = row_interval
	if _rows.size() >= max_rows:
		return
	var offset = _find_row_offset()
	if offset != null:
		spawn_row(offset)


## Pone una fila de items atravesada en la pista, a "offset" metros de la meta.
func spawn_row(offset: float) -> void:
	if pickup_scene == null or track == null:
		return
	var along := track.global_transform * track.curve.sample_baked_with_rotation(offset)
	var side := along.basis.x
	side.y = 0.0
	side = side.normalized()

	var kinds := row_items.duplicate()
	for i in range(kinds.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = temp

	var row := Node3D.new()
	row.name = "Row"
	add_child(row)
	_rows[row] = offset
	for i in kinds.size():
		var pickup := pickup_scene.instantiate() as RacePickup
		pickup.kind = kinds[i]
		pickup.lifetime = item_lifetime
		var slot := i - (kinds.size() - 1) * 0.5
		row.add_child(pickup)
		pickup.global_position = along.origin + side * slot * item_spacing


func _find_row_offset() -> Variant:
	var length := track.curve.get_baked_length()
	for i in max_attempts:
		# El circuito es cerrado: pasando la meta se sigue contando desde 0
		var offset := fposmod(leader_progress + _rng.randf_range(ahead_of_leader.x, ahead_of_leader.y), length)
		if offset < start_margin or offset > length - end_margin:
			continue
		var free := not _is_blocked(offset, length)
		for row in _rows:
			var gap := absf(_rows[row] - offset)
			if minf(gap, length - gap) < min_row_gap:
				free = false
				break
		if free:
			return offset
	return null


# true si en ese lugar hay una pieza que no lleva items encima (piso cortado)
func _is_blocked(offset: float, length: float) -> bool:
	for piece in get_tree().get_nodes_in_group("track_piece"):
		if not piece.blocks_items:
			continue
		var gap := absf(fposmod(piece.track_offset, length) - offset)
		if minf(gap, length - gap) < piece.length * 0.5 + item_clearance:
			return true
	return false


# Saca de la cuenta las filas que ya no tienen items (agarrados o vencidos)
func _clean_rows() -> void:
	for row in _rows.keys():
		if not is_instance_valid(row):
			_rows.erase(row)
		elif row.get_child_count() == 0:
			_rows.erase(row)
			row.queue_free()
