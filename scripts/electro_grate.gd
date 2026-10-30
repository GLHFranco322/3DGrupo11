@tool
class_name ElectroGrate
extends TrackPiece

# Reja eléctrica en el piso: se prende y se apaga sola. Avisa parpadeando antes
# de prenderse, y mientras está prendida tira de la carretilla a quien pase por
# encima. Con "Start Delay" se desfasan dos rejas para que se turnen.

const SHADER := preload("res://shaders/electro_grate.gdshader")

@export_group("Ciclo")
## Segundos apagada.
@export_range(0.1, 30.0, 0.1, "suffix:s") var off_time: float = 2.5
## Segundos de aviso (parpadea) antes de prenderse.
@export_range(0.0, 10.0, 0.1, "suffix:s") var warning_time: float = 1.0
## Segundos prendida.
@export_range(0.1, 30.0, 0.1, "suffix:s") var on_time: float = 1.5
## Desfase del ciclo (para que dos rejas se turnen).
@export_range(0.0, 30.0, 0.1, "suffix:s") var start_delay: float = 0.0
## Fuerza con la que sale despedido el jugador.
@export_range(0.0, 3.0, 0.05) var knock_strength: float = 1.0

@export_group("Dibujo")
@export var off_color: Color = Color(0.25, 0.25, 0.3)
@export var warning_color: Color = Color(1.0, 0.8, 0.1)
@export var on_color: Color = Color(0.3, 0.8, 1.0)
## Brillo cuando está prendida (más de 1 = resplandor).
@export_range(0.0, 10.0, 0.1) var on_energy: float = 4.0
## Metros por celda de la grilla.
@export_range(0.2, 5.0, 0.1, "suffix:u") var cell_size: float = 0.8:
	set(value):
		cell_size = value
		_rebuild()

var _time: float = 0.0
var _material: ShaderMaterial
var _area: Area3D
var _tips: Array[StandardMaterial3D] = []


func _build(root: Node3D) -> void:
	_material = _make_plane(root, SHADER, Vector2(width, length))
	_material.set_shader_parameter("cells", Vector2(width, length) / cell_size)
	_area = _make_area(root, 0.3)
	# Postes a los costados con una luz arriba (avisan el estado de lejos)
	_tips.clear()
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.25, 1.6, 0.25)
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.08, 0.08, 0.1)
		dark.metallic = 0.6
		post_mesh.material = dark
		post.mesh = post_mesh
		post.position = Vector3(side * (width * 0.5 + 0.3), 0.8, 0.0)
		root.add_child(post)
		var tip := MeshInstance3D.new()
		var tip_mesh := SphereMesh.new()
		tip_mesh.radius = 0.22
		tip_mesh.height = 0.44
		var tip_material := StandardMaterial3D.new()
		tip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tip_mesh.material = tip_material
		tip.mesh = tip_mesh
		tip.position = Vector3(side * (width * 0.5 + 0.3), 1.75, 0.0)
		root.add_child(tip)
		_tips.append(tip_material)
	_time = -start_delay
	_show(off_color, 1.0, 0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _area == null:
		return
	_time += delta
	var cycle := off_time + warning_time + on_time
	var t := fposmod(_time, cycle)
	if t < off_time:
		_show(off_color, 1.0, 0.0)
	elif t < off_time + warning_time:
		# Parpadea cada vez más rápido
		var blink := sin((t - off_time) * TAU * 4.0) > 0.0
		_show(warning_color if blink else off_color, 2.0 if blink else 1.0, 0.0)
	else:
		_show(on_color, on_energy, 1.0)
		_zap_riders()


func is_on() -> bool:
	var cycle := off_time + warning_time + on_time
	return fposmod(_time, cycle) >= off_time + warning_time


func _zap_riders() -> void:
	for body in _area.get_overlapping_bodies():
		var racer := _riding_racer(body)
		if racer == null:
			continue
		Audio.play_sfx(Audio.grate_zap)
		# Sale despedido hacia un costado al azar
		var away := global_basis.x * (1.0 if randf() < 0.5 else -1.0) + Vector3.UP
		var eject := racer.eject_speed
		racer.eject_speed = eject * knock_strength
		racer.knock_off(away)
		racer.eject_speed = eject


func _show(color: Color, energy: float, flicker: float) -> void:
	_material.set_shader_parameter("line_color", color)
	_material.set_shader_parameter("energy", energy)
	_material.set_shader_parameter("flicker", flicker)
	for tip in _tips:
		tip.albedo_color = color * maxf(energy, 1.0)
