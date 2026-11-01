@tool
class_name MazeRoom
extends Node3D

# Habitación armada por código: piso, cuatro paredes con puertas y (si se pide)
# techo. Sirve sola como escenario de un nivel, o como "lugar" del laberinto de
# la ferretería: MazeBuilder la ubica en un lugar distinto en cada partida, le
# ajusta el tamaño de celda y la altura y le dice dónde van las puertas.
#
# Cada habitación concreta (ej: WorkshopRoom) extiende esta y arma lo de
# adentro en _build_contents(). El centro del piso es el origen del nodo.
#
# Las paredes se dividen en tramos de una celda. Una puerta es Vector2i(lado,
# tramo): lado 0 = fondo (-Z), 1 = derecha (+X), 2 = frente (+Z), 3 = izquierda
# (-X); el tramo se cuenta desde -X (fondo y frente) o desde -Z (costados).

enum Side { BACK, RIGHT, FRONT, LEFT }

@export_group("Tamaño")
## Celdas que ocupa (X, Z). En el laberinto, una celda es un pasillo.
@export var size_cells: Vector2i = Vector2i(3, 3):
	set(value):
		size_cells = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
## Tamaño de cada celda (en el laberinto lo pone MazeBuilder).
@export_range(1.0, 10.0, 0.1, "suffix:u") var cell_size: float = 4.0
## Altura de las paredes (en el laberinto llegan hasta el techo).
@export_range(1.0, 10.0, 0.1, "suffix:u") var wall_height: float = 3.6
## Grosor de las paredes.
@export_range(0.05, 2.0, 0.05, "suffix:u") var wall_thickness: float = 0.3

@export_group("Puertas")
## Dónde hay puertas: Vector2i(lado, tramo). Ver el comentario de arriba.
@export var doors: Array[Vector2i] = [Vector2i(Side.FRONT, 1)]
## Ancho de cada puerta.
@export_range(0.5, 4.0, 0.05, "suffix:u") var door_width: float = 1.8
## Altura de cada puerta.
@export_range(1.0, 5.0, 0.05, "suffix:u") var door_height: float = 2.4
## Puertas cerradas (con una hoja de madera que no deja pasar). En el
## laberinto van abiertas.
@export var closed_doors: bool = true

@export_group("Techo")
## Techo propio (también en el laberinto, debajo del techo de la ferretería).
@export var build_ceiling: bool = true
@export var ceiling_color: Color = Color(0.32, 0.27, 0.22)

@export_group("Aspecto")
## Semilla de la decoración. 0 = distinta cada vez; otro número = siempre igual.
@export var decor_seed: int = 0

@export_group("Editor")
## Arma la habitación en el editor para verla.
@export_tool_button("Generar") var generate_button := build

var _built: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint() and not _built:
		build()


func is_built() -> bool:
	return _built


## Tamaño del piso (X, Z).
func get_size() -> Vector2:
	return Vector2(size_cells) * cell_size


func build() -> void:
	for child in get_children():
		child.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed if decor_seed != 0 else randi()
	_build_shell()
	_build_contents(rng)
	_built = true


## Lo implementa cada habitación: arma lo de adentro.
func _build_contents(_rng: RandomNumberGenerator) -> void:
	pass


# --- Tramos de pared ----------------------------------------------------------

## Tramos de pared (uno por celda de cada lado). Cada uno es un Dictionary con:
## side, index, center (en el piso, local, sobre la línea de la pared), along
## (a lo largo de la pared), inward (hacia adentro de la habitación) y door.
func get_wall_segments() -> Array[Dictionary]:
	var half := get_size() * 0.5
	var segments: Array[Dictionary] = []
	for side in 4:
		var count := size_cells.x if side == Side.BACK or side == Side.FRONT else size_cells.y
		for i in count:
			var offset := (i + 0.5) * cell_size
			var center: Vector3
			var along: Vector3
			var inward: Vector3
			match side:
				Side.BACK:
					center = Vector3(-half.x + offset, 0.0, -half.y)
					along = Vector3.RIGHT
					inward = Vector3.BACK
				Side.RIGHT:
					center = Vector3(half.x, 0.0, -half.y + offset)
					along = Vector3.BACK
					inward = Vector3.LEFT
				Side.FRONT:
					center = Vector3(-half.x + offset, 0.0, half.y)
					along = Vector3.RIGHT
					inward = Vector3.FORWARD
				_:
					center = Vector3(-half.x, 0.0, -half.y + offset)
					along = Vector3.BACK
					inward = Vector3.RIGHT
			segments.append({
				"side": side,
				"index": i,
				"count": count,
				"center": center,
				"along": along,
				"inward": inward,
				"door": doors.has(Vector2i(side, i)),
			})
	return segments


## Punto sobre la cara de adentro de un tramo, "out" metros hacia adentro y a
## "height" de altura. "shift" corre a lo largo de la pared.
func segment_point(segment: Dictionary, out: float, height: float, shift: float = 0.0) -> Vector3:
	return segment.center + segment.inward * (wall_thickness * 0.5 + out) \
			+ segment.along * shift + Vector3.UP * height


## Base que mira hacia adentro de la habitación desde un tramo (su -Z mira a la
## pared, su +X va a lo largo).
func segment_basis(segment: Dictionary) -> Basis:
	return Basis(segment.along, Vector3.UP, segment.inward)


# --- Cáscara: piso, paredes, techo --------------------------------------------

# Paredes: cada tramo es una caja (con hueco si tiene puerta). Adentro van
# forradas con tablas de madera; afuera se ven lisas.
func _build_shell() -> void:
	var size := get_size()

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)
	floor_body.add_child(box_collision(Vector3(size.x, 0.2, size.y), Vector3(0.0, -0.1, 0.0)))
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = size
	floor_plane.material = _get_floor_material()
	floor_mesh.mesh = floor_plane
	# Un poco arriba, para no pelearse con el piso del laberinto
	floor_mesh.position.y = 0.01
	floor_body.add_child(floor_mesh)

	var walls := StaticBody3D.new()
	walls.name = "Walls"
	add_child(walls)
	var shell: Array[Transform3D] = []
	var planks: Array[Transform3D] = []
	var plank_colors: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed + 11

	for segment in get_wall_segments():
		var half_cell := cell_size * 0.5
		# Las puntas de cada lado se estiran medio grosor para tapar las esquinas
		var start := -half_cell - (wall_thickness * 0.5 if segment.index == 0 else 0.0)
		var end := half_cell + (wall_thickness * 0.5 if segment.index == segment.count - 1 else 0.0)
		var pieces: Array[Rect2] = []  # x = a lo largo, y = altura
		if segment.door:
			var half_door := minf(door_width, cell_size - 0.2) * 0.5
			var top := minf(door_height, wall_height - 0.1)
			pieces.append(Rect2(start, 0.0, -half_door - start, wall_height))
			pieces.append(Rect2(half_door, 0.0, end - half_door, wall_height))
			pieces.append(Rect2(-half_door, top, half_door * 2.0, wall_height - top))
			if closed_doors:
				_add_door_leaf(walls, segment, half_door * 2.0, top)
		else:
			pieces.append(Rect2(start, 0.0, end - start, wall_height))

		for piece in pieces:
			if piece.size.x <= 0.01 or piece.size.y <= 0.01:
				continue
			var center: Vector3 = segment.center + segment.along * (piece.position.x + piece.size.x * 0.5) \
					+ Vector3.UP * (piece.position.y + piece.size.y * 0.5)
			var box_size := Vector3(piece.size.x, piece.size.y, wall_thickness)
			shell.append(box_transform(center, segment.along, segment.inward, box_size))
			walls.add_child(box_collision(Basis(segment.along, Vector3.UP, segment.inward) * box_size.abs(), center, true))
			_add_planks(segment, piece, planks, plank_colors, rng)

	walls.add_child(make_multimesh("Shell", shell, [], _get_outer_wall_material()))
	walls.add_child(make_multimesh("Planks", planks, plank_colors, vertex_color_material(0.85)))

	if build_ceiling:
		var ceiling := StaticBody3D.new()
		ceiling.name = "Ceiling"
		add_child(ceiling)
		ceiling.add_child(box_collision(Vector3(size.x, 0.2, size.y), Vector3(0.0, wall_height + 0.1, 0.0)))
		var ceiling_mesh := MeshInstance3D.new()
		var ceiling_plane := PlaneMesh.new()
		ceiling_plane.size = size
		ceiling_plane.flip_faces = true
		ceiling_plane.material = flat_material(ceiling_color, 0.9)
		ceiling_mesh.mesh = ceiling_plane
		# Un poco abajo, para no pelearse con el techo del laberinto
		ceiling_mesh.position.y = wall_height - 0.02
		ceiling.add_child(ceiling_mesh)


# Tablas verticales en la cara de adentro de un pedazo de pared, con un zócalo
# oscuro abajo
func _add_planks(segment: Dictionary, piece: Rect2, planks: Array[Transform3D], colors: Array[Color], rng: RandomNumberGenerator) -> void:
	var plank_width := 0.3
	var count := maxi(roundi(piece.size.x / plank_width), 1)
	var width := piece.size.x / count
	var base_color := _get_plank_color()
	for i in count:
		var along_pos: float = piece.position.x + (i + 0.5) * width
		var center: Vector3 = segment.center + segment.along * along_pos \
				+ segment.inward * (wall_thickness * 0.5 + 0.02) + Vector3.UP * (piece.position.y + piece.size.y * 0.5)
		planks.append(box_transform(center, segment.along, segment.inward, Vector3(width - 0.025, piece.size.y, 0.04)))
		colors.append(base_color * rng.randf_range(0.8, 1.12))
	if piece.position.y < 0.01:
		var skirting: Vector3 = segment.center + segment.along * (piece.position.x + piece.size.x * 0.5) \
				+ segment.inward * (wall_thickness * 0.5 + 0.05) + Vector3.UP * 0.09
		planks.append(box_transform(skirting, segment.along, segment.inward, Vector3(piece.size.x, 0.18, 0.06)))
		colors.append(base_color * 0.45)


# Hoja de puerta de madera, cerrada, con picaporte
func _add_door_leaf(walls: StaticBody3D, segment: Dictionary, width: float, height: float) -> void:
	var leaf := MeshInstance3D.new()
	leaf.name = "Door"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, 0.08)
	mesh.material = flat_material(_get_plank_color() * 0.7, 0.8)
	leaf.mesh = mesh
	leaf.transform = Transform3D(segment_basis(segment), segment.center + Vector3.UP * height * 0.5)
	walls.add_child(leaf)
	walls.add_child(box_collision(segment_basis(segment) * mesh.size, leaf.position, true))
	var knob := MeshInstance3D.new()
	var knob_mesh := SphereMesh.new()
	knob_mesh.radius = 0.05
	knob_mesh.height = 0.1
	knob_mesh.material = flat_material(Color(0.75, 0.6, 0.25), 0.3, 0.8)
	knob.mesh = knob_mesh
	knob.position = Vector3(width * 0.38, -height * 0.5 + 1.0, 0.07)
	leaf.add_child(knob)


## Material del piso (lo puede cambiar cada habitación).
func _get_floor_material() -> Material:
	return flat_material(Color(0.42, 0.41, 0.39), 0.95)


## Material de la cara de afuera de las paredes.
func _get_outer_wall_material() -> Material:
	return flat_material(Color(0.55, 0.36, 0.28), 0.9)


## Color de las tablas de adentro.
func _get_plank_color() -> Color:
	return Color(0.55, 0.4, 0.27)


# --- Utilidades para armar ----------------------------------------------------

## Transform de una caja de 1x1x1 estirada a "size" (largo, alto, profundidad)
## y orientada con "along" / "across".
static func box_transform(position: Vector3, along: Vector3, across: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis(along * size.x, Vector3.UP * size.y, across * size.z), position)


## Colisión de caja. "size" puede venir girado (se usan los valores absolutos).
static func box_collision(size: Vector3, position: Vector3, absolute: bool = false) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size.abs() if absolute else size
	shape.shape = box
	shape.position = position
	return shape


## Muchas cajas iguales en un solo dibujo. "colors" vacío = sin tinte.
static func make_multimesh(node_name: String, transforms: Array, colors: Array, material: Material) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


static func flat_material(color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func vertex_color_material(roughness: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	return material
