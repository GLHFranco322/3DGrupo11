extends CanvasLayer

# Autoload "SceneLoader" (escena scenes/scene_loader.tscn): cambia de escena
# mostrando una pantalla de carga con imagen y barra de progreso. La escena se
# carga en segundo plano y la pantalla se saca recién cuando ya está armada.
# Uso: SceneLoader.change_scene("res://scenes/main.tscn")

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

@onready var image: TextureRect = %Image
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var label: Label = %LoadingLabel

var _path: String = ""
var _elapsed: float = 0.0
var _progress: Array = []


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
	_elapsed = 0.0
	progress_bar.value = 0.0
	label.text = loading_text
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	var status := ResourceLoader.load_threaded_get_status(_path, _progress)
	if not _progress.is_empty():
		progress_bar.value = maxf(progress_bar.value, _progress[0] * 100.0)

	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("SceneLoader: falló la carga de %s" % _path)
		_finish()
	elif status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= min_display_time:
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
