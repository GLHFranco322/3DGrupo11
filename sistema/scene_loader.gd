extends CanvasLayer

# Autoload "SceneLoader" (escena sistema/scene_loader.tscn): cambia de escena
# mostrando una pantalla de carga con imagen y barra de progreso. La escena se
# carga en segundo plano y la pantalla se saca recién cuando ya está armada.
# Si el nivel tiene tutorial (ver "tutorials") se muestra ese en lugar de la
# imagen, y el nivel arranca cuando los dos jugadores apretaron ✕.
# Uso: SceneLoader.change_scene("res://niveles/1_patio/patio.tscn")

## Imagen de fondo de la pantalla de carga.
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			image.texture = value
## Tiempo mínimo que se muestra la pantalla (para que no parpadee).
@export_range(0.0, 5.0, 0.1, "suffix:s") var min_display_time: float = 0.6
## Texto que se muestra arriba de la barra.
@export var loading_text: String = "Cargando..."
## Tutorial de cada nivel (ruta de la escena del nivel -> pantalla de tutorial,
## ver niveles/comun/tutorial/tutorial.gd).
@export var tutorials: Dictionary[String, PackedScene] = {}
## Con tutorial: segundos que tarda en apagarse la música antes de mostrarlo
## (la pantalla del tutorial va sin música).
@export_range(0.0, 5.0, 0.1, "suffix:s") var tutorial_music_fade: float = 0.8

@onready var root: Control = $Root
@onready var image: TextureRect = %Image
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var label: Label = %LoadingLabel

var _path: String = ""
var _elapsed: float = 0.0
var _progress: Array = []
var _tutorial: Tutorial = null
# Escena que queda debajo del tutorial; se congela para que no reciba los botones
var _old_scene: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	image.texture = background
	visible = false
	set_process(false)


func change_scene(path: String) -> void:
	if _path != "":
		return
	if ResourceLoader.load_threaded_request(path) != OK:
		push_error("SceneLoader: no se pudo cargar %s" % path)
		return
	_path = path
	var tutorial_scene: PackedScene = tutorials.get(path)
	# El tutorial va sin música: primero se termina de apagar (mientras tanto
	# el nivel ya se va cargando)
	if tutorial_scene and Audio.is_music_playing():
		Audio.fade_out_music(tutorial_music_fade)
		await get_tree().create_timer(tutorial_music_fade, true, false, true).timeout
	_elapsed = 0.0
	progress_bar.value = 0.0
	label.text = loading_text
	visible = true
	set_process(true)
	if tutorial_scene:
		_tutorial = tutorial_scene.instantiate() as Tutorial
		root.add_child(_tutorial)
		_old_scene = get_tree().current_scene
		if _old_scene:
			_old_scene.process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_elapsed += delta
	var status := ResourceLoader.load_threaded_get_status(_path, _progress)
	if not _progress.is_empty():
		progress_bar.value = maxf(progress_bar.value, _progress[0] * 100.0)
	if _tutorial:
		_tutorial.set_progress(progress_bar.value / 100.0)

	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("SceneLoader: falló la carga de %s" % _path)
		if is_instance_valid(_old_scene):
			_old_scene.process_mode = Node.PROCESS_MODE_INHERIT
		_finish()
	elif status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= min_display_time:
		# Con tutorial se espera a que los dos jugadores aprieten ✕
		if _tutorial and not _tutorial.is_finished():
			_tutorial.set_loaded()
			return
		set_process(false)
		progress_bar.value = 100.0
		var scene := ResourceLoader.load_threaded_get(_path) as PackedScene
		# Los niveles quedan en pausa al terminar; la escena nueva arranca sin pausa
		get_tree().paused = false
		get_tree().change_scene_to_packed(scene)
		# Espera a que la escena nueva esté armada antes de sacar la pantalla
		await get_tree().scene_changed
		await get_tree().process_frame
		_finish()


func _finish() -> void:
	_path = ""
	set_process(false)
	visible = false
	_old_scene = null
	if _tutorial:
		_tutorial.queue_free()
		_tutorial = null
