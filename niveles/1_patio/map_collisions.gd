extends Node3D

## Nodos del mapa cuyos modelos deben ser sólidos. A cada malla que tengan
## adentro se le genera una colisión convexa al arrancar el juego.
@export var solid_nodes: Array[NodePath] = []


func _ready() -> void:
	for path in solid_nodes:
		var node := get_node_or_null(path)
		if node == null:
			push_warning("map_collisions: no existe el nodo %s" % path)
			continue
		_add_collisions(node)


func _add_collisions(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		node.create_convex_collision(true, true)
	for child in node.get_children():
		_add_collisions(child)
