@tool
class_name CyberCity
extends Node3D

# Arma una ciudad cyberpunk (estilo Edgerunners) a los costados de la pista con
# los modelos de assets/escenario/FreeSample: una fila de edificios pegada a la
# vereda, otra fila más alta detrás (la silueta de rascacielos), carteles
# luminosos y luces de neón de colores sobre la calle.
#
# Cada modelo se dibuja con un MultiMesh (un solo dibujo para todas sus copias),
# y los edificios están en la capa visual 2: las luces de neón no los iluminan
# (ya brillan con su textura), así alcanzan para la calle y los jugadores.
# Con la misma semilla sale siempre la misma ciudad. En el editor se ve con el
# botón "Generar".

const BLOCK_HEIGHT := 2.5
const CITY_LAYER := 2

@export_group("Modelos")
## Bloques que se apilan para hacer edificios (todos del mismo ancho por pila).
@export var block_scenes: Array[PackedScene] = []
## Torres enteras (un solo modelo alto).
@export var tower_scenes: Array[PackedScene] = []
## Carteles publicitarios que se cuelgan en las fachadas.
@export var ad_scenes: Array[PackedScene] = []
## Cosas para los techos (antenas, parabólicas).
@export var roof_scenes: Array[PackedScene] = []
## Material que reemplaza al que trae cada modelo (por nombre del material del
## .fbx): los del pack vienen sin la textura de brillo.
@export var material_overrides: Dictionary = {}

@export_group("Recorrido")
## La pista: la ciudad se arma a sus costados.
@export var track: Path3D
## Distancia del centro de la pista a la primera fila de edificios.
@export_range(1.0, 50.0, 0.5, "suffix:u") var setback: float = 11.0
## Distancia extra a la segunda fila (la de atrás, más alta).
@export_range(0.0, 50.0, 0.5, "suffix:u") var back_row_distance: float = 7.0
## Espacio entre edificios (al azar entre X e Y).
@export var gap: Vector2 = Vector2(0.3, 2.0)
## Metros extra antes de la largada y después de la llegada (no se usa si la
## pista es un circuito cerrado).
@export_range(0.0, 100.0, 1.0, "suffix:u") var extra_length: float = 20.0

@export_group("Edificios")
## Pisos de la primera fila (al azar entre X e Y).
@export var front_floors: Vector2i = Vector2i(2, 6)
## Pisos de la fila de atrás.
@export var back_floors: Vector2i = Vector2i(5, 12)
## Probabilidad de que en vez de una pila salga una torre entera.
@export_range(0.0, 1.0, 0.05) var tower_chance: float = 0.2
## Probabilidad de que un edificio de adelante tenga un cartel.
@export_range(0.0, 1.0, 0.05) var ad_chance: float = 0.8
## Tamaño de los carteles.
@export_range(0.5, 10.0, 0.1) var ad_scale: float = 4.5
## Probabilidad de algo en el techo.
@export_range(0.0, 1.0, 0.05) var roof_chance: float = 0.35

@export_group("Carteles de neón")
## Textos de los carteles luminosos de las fachadas.
@export var sign_texts: PackedStringArray = ["CALIENTE", "24 HRS", "RAMEN", "KARAOKE", "NIGHT CITY", "BAR", "MOTEL", "NOODLES", "SE BUSCA GERENTE", "FERRETERÍA", "OPEN", "HOTEL"]
## Colores de los carteles (más de 1 = brillan más con el resplandor).
@export var sign_colors: PackedColorArray = [Color(3.0, 0.3, 1.5), Color(0.4, 2.5, 3.0), Color(3.0, 0.4, 0.4), Color(3.0, 2.4, 0.4), Color(1.6, 0.5, 3.0)]
## Probabilidad de que un edificio de adelante tenga un cartel con texto.
@export_range(0.0, 1.0, 0.05) var sign_chance: float = 0.55
## Probabilidad de que el cartel sea vertical.
@export_range(0.0, 1.0, 0.05) var vertical_sign_chance: float = 0.4

@export_group("Arcos")
## Arco con faroles que cruza la calle.
@export var gate_scene: PackedScene
## Un arco cada tantos metros de pista.
@export_range(10.0, 300.0, 1.0, "suffix:u") var gate_spacing: float = 65.0

@export_group("Neón")
## Una luz de neón cada tantos metros de pista (alternando de lado).
@export_range(5.0, 200.0, 1.0, "suffix:u") var neon_spacing: float = 24.0
## Colores de los neones (se van alternando).
@export var neon_colors: PackedColorArray = [Color(1.0, 0.1, 0.25), Color(1.0, 0.1, 0.6), Color(0.1, 0.85, 1.0), Color(1.0, 0.2, 0.15), Color(0.6, 0.2, 1.0)]
@export_range(0.0, 16.0, 0.1) var neon_energy: float = 4.0
@export_range(1.0, 50.0, 0.5, "suffix:u") var neon_range: float = 13.0
## Altura de las luces de neón.
@export_range(0.0, 20.0, 0.5, "suffix:u") var neon_height: float = 3.0

@export_group("Forma")
## Semilla: el mismo número da siempre la misma ciudad.
@export var city_seed: int = 2077

@export_group("Editor")
@export_tool_button("Generar") var generate_button := build

var _rng := RandomNumberGenerator.new()
# PackedScene -> { mesh, offset (Transform3D del mesh en el modelo), bounds (AABB) }
var _models: Dictionary = {}
# PackedScene -> Array[Transform3D] de cada copia
var _instances: Dictionary = {}
var _placed: Array[Vector3] = []


func _ready() -> void:
	if not Engine.is_editor_hint():
		build()


func build() -> void:
	for child in get_children():
		child.free()
	if track == null:
		return
	_rng.seed = city_seed
	_models.clear()
	_instances.clear()
	_placed.clear()

	for side in [-1.0, 1.0]:
		_build_row(side, setback, front_floors, true)
		_build_row(side, setback + back_row_distance, back_floors, false)
	_build_multimeshes()
	_build_neons()
	_build_gates()


# Una fila de edificios a un costado de la pista, a "distance" del centro
func _build_row(side: float, distance: float, floors: Vector2i, front: bool) -> void:
	var length := track.curve.get_baked_length()
	var extra := 0.0 if track.curve.closed else extra_length
	var offset := -extra
	while offset < length + extra:
		var tower := not tower_scenes.is_empty() and _rng.randf() < tower_chance
		var scene: PackedScene = _pick(tower_scenes if tower else block_scenes)
		if scene == null:
			return
		var bounds := _model(scene).bounds as AABB
		var width := bounds.size.x
		offset += width * 0.5
		var spot := _sample(offset)
		var out := spot.basis.x * side
		out.y = 0.0
		out = out.normalized()
		var depth := bounds.size.z
		var base := spot.origin + out * (distance + depth * 0.5)
		base.y = 0.0
		# La fachada (+Z del modelo) mira hacia la pista
		var basis := Basis.looking_at(-out, Vector3.UP, true)
		if _is_free(base, distance, maxf(width, depth) * 0.5):
			_placed.append(base)
			var height := _add_building(scene, tower, base, basis, floors)
			if front and not ad_scenes.is_empty() and _rng.randf() < ad_chance:
				_add_ad(base, basis, depth, height)
			if front and not sign_texts.is_empty() and _rng.randf() < sign_chance:
				_add_sign(base, basis, depth, width, height)
			if not roof_scenes.is_empty() and _rng.randf() < roof_chance:
				_add_instance(_pick(roof_scenes), Transform3D(basis, base + Vector3.UP * height))
		offset += width * 0.5 + _rng.randf_range(gap.x, gap.y)


# Pila de bloques (o una torre). Devuelve la altura total.
func _add_building(scene: PackedScene, tower: bool, base: Vector3, basis: Basis, floors: Vector2i) -> float:
	var block_height := (_model(scene).bounds as AABB).size.y
	if tower:
		_add_instance(scene, Transform3D(basis, base))
		return block_height
	var count := _rng.randi_range(floors.x, floors.y)
	for i in count:
		_add_instance(scene, Transform3D(basis, base + Vector3.UP * block_height * i))
	return block_height * count


func _add_ad(base: Vector3, basis: Basis, depth: float, height: float) -> void:
	var scene: PackedScene = _pick(ad_scenes)
	var y := _rng.randf_range(2.5, maxf(3.0, height - 3.0))
	var front := basis.z * (depth * 0.5 + 0.1)
	_add_instance(scene, Transform3D(basis.scaled(Vector3.ONE * ad_scale), base + front + Vector3.UP * y))


# Que no quede encima de otra parte de la pista (en las curvas) ni de otro edificio
func _is_free(point: Vector3, distance: float, radius: float) -> bool:
	var local := track.global_transform.affine_inverse() * point
	var closest := track.global_transform * track.curve.get_closest_point(local)
	if Vector2(point.x - closest.x, point.z - closest.z).length() < distance - 0.5:
		return false
	for other in _placed:
		if Vector2(point.x - other.x, point.z - other.z).length() < radius + 1.5:
			return false
	return true


func _sample(offset: float) -> Transform3D:
	var length := track.curve.get_baked_length()
	if track.curve.closed:
		return track.global_transform * track.curve.sample_baked_with_rotation(fposmod(offset, length))
	var clamped := clampf(offset, 0.0, length)
	var at := track.global_transform * track.curve.sample_baked_with_rotation(clamped)
	# Antes de la largada o después de la llegada: sigue derecho
	var forward := -at.basis.z
	at.origin += forward * (offset - clamped)
	return at


func _pick(list: Array) -> PackedScene:
	if list.is_empty():
		return null
	return list[_rng.randi_range(0, list.size() - 1)]


func _add_instance(scene: PackedScene, xform: Transform3D) -> void:
	if scene == null:
		return
	_model(scene)
	if not _instances.has(scene):
		_instances[scene] = [] as Array[Transform3D]
	# Transform en el espacio de este nodo
	_instances[scene].append(global_transform.affine_inverse() * xform)


# Malla, posición dentro del modelo y tamaño de cada .fbx (centrado en X y Z,
# apoyado en el piso)
func _model(scene: PackedScene) -> Dictionary:
	if _models.has(scene):
		return _models[scene]
	var instance := scene.instantiate() as Node3D
	var mesh_instance := instance.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var offset := Transform3D.IDENTITY
	var node: Node = mesh_instance
	while node != instance:
		offset = (node as Node3D).transform * offset
		node = node.get_parent()
	var bounds := offset * mesh_instance.get_aabb()
	var center := bounds.get_center()
	offset.origin -= Vector3(center.x, bounds.position.y, center.z)
	var data := {"mesh": mesh_instance.mesh, "offset": offset, "bounds": bounds}
	instance.free()
	_models[scene] = data
	return data


func _build_multimeshes() -> void:
	for scene in _instances:
		var data: Dictionary = _models[scene]
		var transforms: Array = _instances[scene]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = data.mesh
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i] * data.offset)
		var node := MultiMeshInstance3D.new()
		node.name = scene.resource_path.get_file().get_basename()
		node.multimesh = multimesh
		node.layers = 1 << (CITY_LAYER - 1)
		var source := (data.mesh as Mesh).surface_get_material(0)
		if source and material_overrides.has(source.resource_name):
			node.material_override = material_overrides[source.resource_name]
		add_child(node)


# Luces de colores sobre la calle, alternando de lado. No iluminan los edificios
# (capa 2): solo la calle, los jugadores y los objetos.
func _build_neons() -> void:
	var length := track.curve.get_baked_length()
	var index := 0
	var offset := neon_spacing * 0.5
	while offset < length:
		var spot := _sample(offset)
		var side := 1.0 if index % 2 == 0 else -1.0
		var out := spot.basis.x * side
		out.y = 0.0
		var light := OmniLight3D.new()
		light.name = "Neon%d" % index
		light.light_color = neon_colors[index % neon_colors.size()] if not neon_colors.is_empty() else Color.WHITE
		light.light_energy = neon_energy
		light.omni_range = neon_range
		light.light_cull_mask = 0xFFFFF & ~(1 << (CITY_LAYER - 1))
		light.shadow_enabled = false
		add_child(light)
		light.global_position = spot.origin + out.normalized() * (setback - 2.0) + Vector3.UP * neon_height
		index += 1
		offset += neon_spacing


# Cartel luminoso con texto en la fachada (a veces vertical, como en Night City)
func _add_sign(base: Vector3, basis: Basis, depth: float, width: float, height: float) -> void:
	var label := Label3D.new()
	label.text = sign_texts[_rng.randi_range(0, sign_texts.size() - 1)]
	label.modulate = sign_colors[_rng.randi_range(0, sign_colors.size() - 1)] if not sign_colors.is_empty() else Color.WHITE
	label.outline_modulate = Color(label.modulate.r * 0.15, label.modulate.g * 0.15, label.modulate.b * 0.15, 1.0)
	label.outline_size = 12
	label.font_size = 128
	label.double_sided = false
	var vertical := _rng.randf() < vertical_sign_chance
	# Que entre en el ancho de la fachada (o en la altura, si es vertical)
	var room := (height - 2.0) if vertical else (width * 0.9)
	label.pixel_size = clampf(room / maxf(label.text.length() * 0.6 * label.font_size, 1.0), 0.004, 0.02)
	var y := _rng.randf_range(3.0, maxf(3.5, height - 2.0)) if not vertical else maxf(height * 0.5, 3.0)
	var sign_basis := basis
	if vertical:
		sign_basis = basis * Basis(Vector3.BACK, -PI / 2.0)
	add_child(label)
	label.global_transform = Transform3D(sign_basis, base + basis.z * (depth * 0.5 + 0.15) + Vector3.UP * y)


# Arcos con faroles rojos que cruzan la calle
func _build_gates() -> void:
	if gate_scene == null:
		return
	var length := track.curve.get_baked_length()
	var offset := gate_spacing * 0.6
	while offset < length - 10.0:
		var spot := _sample(offset)
		var gate := gate_scene.instantiate() as Node3D
		add_child(gate)
		gate.global_transform = Transform3D(spot.basis.orthonormalized(), Vector3(spot.origin.x, 0.0, spot.origin.z))
		offset += gate_spacing
