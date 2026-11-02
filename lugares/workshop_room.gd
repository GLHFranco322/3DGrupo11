@tool
class_name WorkshopRoom
extends MazeRoom

# Taller: en el centro la mesa principal de madera rubia brillante, como nueva
# (donde van los rompecabezas: ver get_puzzle_anchor), mesas de trabajo viejas
# contra las paredes, tableros perforados con herramientas colgadas, estantes y
# cosas tiradas en el piso. Dos lámparas cuelgan sobre la mesa principal.
#
# Se usa sola (nivel de los rompecabezas) o como lugar del laberinto de la
# ferretería. Todo se reparte al azar con "Decor Seed".

enum Lay { STANDING, FLAT, HUNG }

@export_group("Mesa principal")
## Largo (X) y ancho (Z) de la tabla.
@export var main_table_size: Vector2 = Vector2(3.0, 1.7)
## Altura de la mesa.
@export_range(0.5, 1.5, 0.01, "suffix:u") var main_table_height: float = 0.95
## Color de la madera rubia.
@export var main_table_color: Color = Color(0.96, 0.8, 0.55)
## Qué tan áspera es la madera. Más bajo = más brillante.
@export_range(0.0, 1.0, 0.01) var main_table_roughness: float = 0.12
## Alfombra de goma debajo de la mesa (cuánto sobresale de cada lado). 0 = sin alfombra.
@export_range(0.0, 3.0, 0.05, "suffix:u") var mat_margin: float = 0.7
@export var mat_color: Color = Color(0.16, 0.19, 0.17)

@export_group("Mesas de trabajo")
## Mesas de trabajo viejas contra las paredes.
@export_range(0, 20) var workbench_count: int = 4
## Largo de cada mesa (como fracción de una celda).
@export_range(0.3, 1.0, 0.05) var workbench_length: float = 0.75
@export_range(0.4, 2.0, 0.05, "suffix:u") var workbench_depth: float = 0.85
@export_range(0.5, 1.5, 0.01, "suffix:u") var workbench_height: float = 0.92
## Color de la madera vieja.
@export var workbench_color: Color = Color(0.42, 0.3, 0.19)
## Probabilidad de que una mesa tenga una morsa.
@export_range(0.0, 1.0, 0.05) var vise_chance: float = 0.6
## Cosas apoyadas en cada mesa (al azar entre X e Y).
@export var items_per_bench: Vector2i = Vector2i(2, 4)
## Modelos que se apoyan acostados sobre las mesas de trabajo.
@export var bench_item_scenes: Array[PackedScene] = []
@export_range(0.1, 2.0, 0.05, "suffix:u") var bench_item_size: float = 0.45

@export_group("Herramientas colgadas")
## Probabilidad de que un tramo de pared tenga tablero perforado.
@export_range(0.0, 1.0, 0.05) var pegboard_chance: float = 0.85
@export var pegboard_color: Color = Color(0.74, 0.58, 0.38)
## Herramientas por tablero (al azar entre X e Y).
@export var tools_per_board: Vector2i = Vector2i(3, 5)
## Modelos que se cuelgan en los tableros (se paran a lo largo).
@export var hang_scenes: Array[PackedScene] = []
@export_range(0.1, 2.0, 0.05, "suffix:u") var hang_size: float = 0.6

@export_group("Estantes")
## Probabilidad de que un tramo de pared tenga un estante arriba del tablero.
@export_range(0.0, 1.0, 0.05) var shelf_chance: float = 0.5
## Modelos que van parados en los estantes (latas, cajas).
@export var shelf_scenes: Array[PackedScene] = []
@export_range(0.1, 2.0, 0.05, "suffix:u") var shelf_item_size: float = 0.35

@export_group("Cosas en el piso")
## Probabilidad de que un tramo libre (sin mesa ni puerta) tenga algo en el piso.
@export_range(0.0, 1.0, 0.05) var floor_prop_chance: float = 0.75
## Modelos que van en el piso (yunque, barriles, cajas, balde).
@export var floor_prop_scenes: Array[PackedScene] = []
## Tamaño de cada modelo de "Floor Prop Scenes" (mismo orden). Si falta, 0.8.
@export var floor_prop_sizes: PackedFloat32Array = []

@export_group("Luces")
@export var lamp_color: Color = Color(1.0, 0.86, 0.62)
@export_range(0.0, 10.0, 0.05) var lamp_energy: float = 2.2
@export_range(1.0, 30.0, 0.5, "suffix:u") var lamp_range: float = 7.0
## Luz suave del techo que llega a los rincones.
@export_range(0.0, 5.0, 0.05) var fill_energy: float = 0.7
@export var lamp_shade_color: Color = Color(0.13, 0.3, 0.2)

var _anchor: Marker3D


## Punto en el centro de la mesa principal, sobre la tabla (ahí van los
## rompecabezas). Su -Z mira al fondo de la habitación.
func get_puzzle_anchor() -> Marker3D:
	return _anchor


func _build_contents(rng: RandomNumberGenerator) -> void:
	_build_main_table()
	_build_lamps()

	var segments := get_wall_segments()
	var free: Array[Dictionary] = []
	for segment in segments:
		if not segment.door:
			free.append(segment)
	_shuffle(free, rng)
	var benches := free.slice(0, mini(workbench_count, free.size()))
	var rest := free.slice(benches.size())

	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	_build_workbenches(benches, props, rng)
	_build_walls_decor(free, props, rng)
	_build_floor_props(rest, props, rng)


# --- Mesa principal -----------------------------------------------------------

func _build_main_table() -> void:
	var body := StaticBody3D.new()
	body.name = "MainTable"
	add_child(body)
	var size := Vector3(main_table_size.x, main_table_height, main_table_size.y)
	body.add_child(box_collision(size, Vector3.UP * size.y * 0.5))

	var top := 0.08
	var parts: Array[Transform3D] = []
	parts.append(box_transform(Vector3(0.0, size.y - top * 0.5, 0.0), Vector3.RIGHT, Vector3.BACK,
			Vector3(size.x, top, size.z)))
	var leg := 0.13
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.append(box_transform(Vector3(sx * (size.x * 0.5 - 0.18), (size.y - top) * 0.5, sz * (size.z * 0.5 - 0.18)),
					Vector3.RIGHT, Vector3.BACK, Vector3(leg, size.y - top, leg)))
	# Faldón debajo de la tabla
	var apron_y := size.y - top - 0.07
	for sz in [-1.0, 1.0]:
		parts.append(box_transform(Vector3(0.0, apron_y, sz * (size.z * 0.5 - 0.18)), Vector3.RIGHT, Vector3.BACK,
				Vector3(size.x - 0.36, 0.14, 0.04)))
	for sx in [-1.0, 1.0]:
		parts.append(box_transform(Vector3(sx * (size.x * 0.5 - 0.18), apron_y, 0.0), Vector3.RIGHT, Vector3.BACK,
				Vector3(0.04, 0.14, size.z - 0.36)))
	var wood := flat_material(main_table_color, main_table_roughness)
	wood.metallic_specular = 0.8
	body.add_child(make_multimesh("Wood", parts, [], wood))

	if mat_margin > 0.0:
		var mat := MeshInstance3D.new()
		mat.name = "Mat"
		var plane := PlaneMesh.new()
		plane.size = main_table_size + Vector2.ONE * mat_margin * 2.0
		plane.material = flat_material(mat_color, 0.95)
		mat.mesh = plane
		mat.position.y = 0.02
		body.add_child(mat)

	_anchor = Marker3D.new()
	_anchor.name = "PuzzleAnchor"
	_anchor.position = Vector3(0.0, size.y, 0.0)
	body.add_child(_anchor)


# Dos lámparas colgadas sobre la mesa principal, más una luz suave general
func _build_lamps() -> void:
	var lamps := Node3D.new()
	lamps.name = "Lamps"
	add_child(lamps)
	var lamp_y := minf(main_table_height + 1.75, wall_height - 0.4)
	var shade_material := flat_material(lamp_shade_color, 0.4, 0.5)
	var cord_material := flat_material(Color(0.05, 0.05, 0.05), 0.8)
	var bulb_material := StandardMaterial3D.new()
	bulb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_material.albedo_color = lamp_color.lightened(0.5)

	for sx in [-1.0, 1.0]:
		var at := Vector3(sx * main_table_size.x * 0.25, lamp_y, 0.0)
		var cord := MeshInstance3D.new()
		var cord_mesh := CylinderMesh.new()
		cord_mesh.top_radius = 0.012
		cord_mesh.bottom_radius = 0.012
		cord_mesh.height = wall_height - lamp_y
		cord_mesh.material = cord_material
		cord.mesh = cord_mesh
		cord.position = at + Vector3.UP * cord_mesh.height * 0.5
		lamps.add_child(cord)

		var shade := MeshInstance3D.new()
		var shade_mesh := CylinderMesh.new()
		shade_mesh.top_radius = 0.07
		shade_mesh.bottom_radius = 0.34
		shade_mesh.height = 0.28
		shade_mesh.cap_bottom = false
		shade_mesh.material = shade_material
		shade.mesh = shade_mesh
		shade.position = at - Vector3.UP * 0.14
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamps.add_child(shade)

		var bulb := MeshInstance3D.new()
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.08
		bulb_mesh.height = 0.16
		bulb_mesh.material = bulb_material
		bulb.mesh = bulb_mesh
		bulb.position = at - Vector3.UP * 0.26
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamps.add_child(bulb)

		var light := OmniLight3D.new()
		light.position = at - Vector3.UP * 0.4
		light.light_color = lamp_color
		light.light_energy = lamp_energy
		light.omni_range = lamp_range
		lamps.add_child(light)

	if fill_energy > 0.0:
		var fill := OmniLight3D.new()
		fill.name = "Fill"
		fill.position = Vector3(0.0, wall_height - 0.3, 0.0)
		fill.light_color = lamp_color
		fill.light_energy = fill_energy
		fill.omni_range = maxf(get_size().x, get_size().y) * 0.9
		lamps.add_child(fill)


# --- Mesas de trabajo ---------------------------------------------------------

# Mesas viejas contra la pared: tabla de tablones gastados (cada uno de un tono),
# patas, estante de abajo, un listón atrás y a veces una morsa en la punta
func _build_workbenches(segments: Array, props: Node3D, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "Workbenches"
	add_child(body)
	var wood: Array[Transform3D] = []
	var wood_colors: Array[Color] = []
	var metal: Array[Transform3D] = []
	var length := cell_size * workbench_length
	var depth := workbench_depth
	var height := workbench_height

	for segment in segments:
		var frame := Transform3D(segment_basis(segment), segment_point(segment, depth * 0.5 + 0.03, 0.0))
		var shade := rng.randf_range(0.8, 1.1)
		var add_wood := func(center: Vector3, size: Vector3, tint: float) -> void:
			wood.append(frame * box_transform(center, Vector3.RIGHT, Vector3.BACK, size))
			wood_colors.append(workbench_color * shade * tint)

		# Tablones de la tabla, de distinto tono y apenas desparejos
		var boards := 4
		for i in boards:
			var z := -depth * 0.5 + (i + 0.5) * depth / boards
			add_wood.call(Vector3(0.0, height - 0.035 + rng.randf_range(-0.004, 0.004), z),
					Vector3(length, 0.07, depth / boards - 0.01), rng.randf_range(0.75, 1.15))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				add_wood.call(Vector3(sx * (length * 0.5 - 0.12), (height - 0.07) * 0.5, sz * (depth * 0.5 - 0.1)),
						Vector3(0.1, height - 0.07, 0.1), 0.7)
		add_wood.call(Vector3(0.0, 0.22, 0.0), Vector3(length - 0.12, 0.04, depth - 0.12), 0.8)
		add_wood.call(Vector3(0.0, height + 0.06, -depth * 0.5 + 0.02), Vector3(length, 0.12, 0.04), 0.9)

		body.add_child(box_collision(segment_basis(segment) * Vector3(length, height, depth),
				frame * Vector3(0.0, height * 0.5, 0.0), true))

		var vise := rng.randf() < vise_chance
		if vise:
			var x := length * 0.5 - 0.25
			var z := depth * 0.5 - 0.1
			for part in [
				[Vector3(x, height + 0.04, z), Vector3(0.22, 0.08, 0.18)],
				[Vector3(x, height + 0.15, z - 0.05), Vector3(0.24, 0.14, 0.05)],
				[Vector3(x, height + 0.15, z + 0.1), Vector3(0.24, 0.14, 0.05)],
				[Vector3(x, height + 0.12, z + 0.22), Vector3(0.03, 0.03, 0.26)],
				[Vector3(x, height + 0.12, z + 0.35), Vector3(0.26, 0.025, 0.025)],
			]:
				metal.append(frame * box_transform(part[0], Vector3.RIGHT, Vector3.BACK, part[1]))

		# Cosas acostadas arriba de la mesa (lejos de la morsa)
		if bench_item_scenes.is_empty():
			continue
		var count := rng.randi_range(items_per_bench.x, maxi(items_per_bench.x, items_per_bench.y))
		var max_x := length * 0.5 - (0.55 if vise else 0.3)
		for i in count:
			var slot := lerpf(-length * 0.5 + 0.3, max_x, (i + 0.5) / count)
			var local := Vector3(slot + rng.randf_range(-0.1, 0.1), height,
					rng.randf_range(-depth * 0.5 + 0.18, depth * 0.5 - 0.18))
			var holder := _add_model(_pick(bench_item_scenes, rng), props,
					bench_item_size * rng.randf_range(0.75, 1.15), Lay.FLAT)
			if holder:
				holder.transform = frame * Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)), local)

	body.add_child(make_multimesh("Wood", wood, wood_colors, vertex_color_material(0.9)))
	var metal_material := flat_material(Color(0.28, 0.36, 0.44), 0.45, 0.6)
	body.add_child(make_multimesh("Vises", metal, [], metal_material))


# --- Paredes: tableros perforados y estantes ----------------------------------

func _build_walls_decor(segments: Array, props: Node3D, rng: RandomNumberGenerator) -> void:
	var boards: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var holes: Array[Transform3D] = []
	var pegs: Array[Transform3D] = []
	var shelves: Array[Transform3D] = []
	var board_width := minf(cell_size * 0.7, 2.8)
	var board_height := 1.3
	var board_y := 1.75
	var board_out := 0.06
	var shelf_y := board_y + board_height * 0.5 + 0.4

	for segment in segments:
		var basis := segment_basis(segment)
		var at := func(out: float, height: float, shift: float = 0.0) -> Vector3:
			return segment_point(segment, out, height, shift)

		if rng.randf() < pegboard_chance:
			boards.append(box_transform(at.call(board_out, board_y), segment.along, segment.inward,
					Vector3(board_width, board_height, 0.03)))
			# Marco
			for side in [-1.0, 1.0]:
				frames.append(box_transform(at.call(board_out + 0.01, board_y + side * (board_height * 0.5 + 0.03)),
						segment.along, segment.inward, Vector3(board_width + 0.12, 0.06, 0.05)))
				frames.append(box_transform(at.call(board_out + 0.01, board_y, side * (board_width * 0.5 + 0.03)),
						segment.along, segment.inward, Vector3(0.06, board_height, 0.05)))
			# Agujeritos
			var spacing := 0.1
			var columns := int(board_width / spacing) - 1
			var rows := int(board_height / spacing) - 1
			for cx in columns:
				for cy in rows:
					var shift := -board_width * 0.5 + (cx + 1) * spacing
					var y := board_y - board_height * 0.5 + (cy + 1) * spacing
					holes.append(box_transform(at.call(board_out + 0.016, y, shift), segment.along, segment.inward,
							Vector3(0.022, 0.022, 0.002)))

			if not hang_scenes.is_empty():
				var count := rng.randi_range(tools_per_board.x, maxi(tools_per_board.x, tools_per_board.y))
				for i in count:
					var shift := -board_width * 0.5 + (i + 0.5) * board_width / count + rng.randf_range(-0.05, 0.05)
					var size := hang_size * rng.randf_range(0.8, 1.1)
					var tool_y := board_y - 0.05
					var holder := _add_model(_pick(hang_scenes, rng), props, size, Lay.HUNG)
					if holder:
						holder.transform = Transform3D(basis, at.call(board_out + 0.07, tool_y, shift))
					# Gancho arriba de cada herramienta
					pegs.append(box_transform(at.call(board_out + 0.05, tool_y + size * 0.5 + 0.03, shift),
							segment.along, segment.inward, Vector3(0.02, 0.02, 0.07)))

		if shelf_y + 0.5 < wall_height and rng.randf() < shelf_chance:
			var shelf_depth := 0.32
			shelves.append(box_transform(at.call(shelf_depth * 0.5, shelf_y), segment.along, segment.inward,
					Vector3(board_width, 0.05, shelf_depth)))
			for side in [-1.0, 1.0]:
				shelves.append(box_transform(at.call(shelf_depth * 0.3, shelf_y - 0.12, side * board_width * 0.4),
						segment.along, segment.inward, Vector3(0.04, 0.2, shelf_depth * 0.6)))
			if not shelf_scenes.is_empty():
				var count := rng.randi_range(2, 4)
				for i in count:
					var shift := -board_width * 0.5 + (i + 0.5) * board_width / count + rng.randf_range(-0.12, 0.12)
					var holder := _add_model(_pick(shelf_scenes, rng), props,
							shelf_item_size * rng.randf_range(0.75, 1.15), Lay.STANDING)
					if holder:
						holder.transform = Transform3D(basis.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4)),
								at.call(shelf_depth * 0.5, shelf_y + 0.025, shift))

	var decor := Node3D.new()
	decor.name = "WallDecor"
	add_child(decor)
	decor.add_child(make_multimesh("Pegboards", boards, [], flat_material(pegboard_color, 0.85)))
	decor.add_child(make_multimesh("Frames", frames, [], flat_material(workbench_color * 0.8, 0.85)))
	var hole_material := StandardMaterial3D.new()
	hole_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole_material.albedo_color = Color(0.12, 0.08, 0.05)
	decor.add_child(make_multimesh("Holes", holes, [], hole_material))
	decor.add_child(make_multimesh("Pegs", pegs, [], flat_material(Color(0.6, 0.6, 0.62), 0.35, 0.8)))
	decor.add_child(make_multimesh("Shelves", shelves, [], flat_material(workbench_color, 0.85)))


# --- Piso ---------------------------------------------------------------------

# En los tramos que quedaron libres: algo grande en el piso contra la pared
# (yunque, barril, cajas, balde), a veces dos juntos
func _build_floor_props(segments: Array, props: Node3D, rng: RandomNumberGenerator) -> void:
	if floor_prop_scenes.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "FloorProps"
	add_child(body)
	for segment in segments:
		if rng.randf() >= floor_prop_chance:
			continue
		var count := 2 if rng.randf() < 0.35 else 1
		for i in count:
			var index := rng.randi_range(0, floor_prop_scenes.size() - 1)
			var size := floor_prop_sizes[index] if index < floor_prop_sizes.size() else 0.8
			var holder := _add_model(floor_prop_scenes[index], props, size, Lay.STANDING)
			if holder == null:
				continue
			var shift := rng.randf_range(-0.3, 0.3) * cell_size + (i - (count - 1) * 0.5) * size * 1.1
			holder.transform = Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)),
					segment_point(segment, size * 0.6 + 0.1, 0.0, shift))
			var bounds := ModelUtils.get_bounds(holder)
			var shape := box_collision(bounds.size, Vector3.ZERO)
			shape.transform = Transform3D(holder.basis, holder.transform * bounds.get_center())
			body.add_child(shape)


# --- Modelos ------------------------------------------------------------------

# Pone un modelo dentro de un nodo nuevo hijo de "parent", con su lado más
# largo midiendo "size":
#   STANDING  como viene, apoyado en el piso del nodo
#   FLAT      acostado (lo más fino para arriba), apoyado en el piso del nodo
#   HUNG      parado a lo largo (lo más largo para arriba, lo más fino hacia
#             +Z) y centrado en el nodo, para colgarlo de una pared
func _add_model(scene: PackedScene, parent: Node3D, size: float, lay: Lay) -> Node3D:
	if scene == null:
		return null
	var holder := Node3D.new()
	parent.add_child(holder)
	var model := scene.instantiate() as Node3D
	if model == null:
		holder.free()
		return null
	holder.add_child(model)
	var bounds := ModelUtils.get_bounds(model)
	var extents := [bounds.size.x, bounds.size.y, bounds.size.z]
	var longest: float = extents.max()
	if longest <= 0.0:
		return holder

	var basis := Basis.IDENTITY
	if lay != Lay.STANDING:
		# Ejes del modelo de más corto a más largo
		var order := [0, 1, 2]
		order.sort_custom(func(a: int, b: int) -> bool: return extents[a] < extents[b])
		var targets := [Vector3.UP, Vector3.BACK, Vector3.RIGHT] if lay == Lay.FLAT \
				else [Vector3.BACK, Vector3.RIGHT, Vector3.UP]
		var columns := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
		for i in 3:
			columns[order[i]] = targets[i]
		basis = Basis(columns[0], columns[1], columns[2])
		# Sin espejar el modelo
		if basis.determinant() < 0.0:
			columns[order[1]] = -columns[order[1]]
			basis = Basis(columns[0], columns[1], columns[2])

	basis = basis.scaled(Vector3.ONE * size / longest)
	var placed := Transform3D(basis, Vector3.ZERO) * bounds
	var center := placed.get_center()
	var offset := -center if lay == Lay.HUNG else -Vector3(center.x, placed.position.y, center.z)
	model.transform = Transform3D(basis, offset)
	return holder


func _pick(scenes: Array[PackedScene], rng: RandomNumberGenerator) -> PackedScene:
	return scenes[rng.randi_range(0, scenes.size() - 1)]


func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp


func _get_floor_material() -> Material:
	return flat_material(Color(0.36, 0.35, 0.33), 0.95)
