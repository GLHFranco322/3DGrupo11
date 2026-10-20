class_name CharacterData
extends Resource

# Un personaje elegible. Para sumar uno nuevo: crear un .tres con este script
# (clic derecho en el panel Sistema de archivos → Nuevo → Recurso → CharacterData)
# y agregarlo a la lista "Characters" de scenes/game_settings.tscn.

## Nombre que se muestra en la selección de personaje.
@export var display_name: String = ""
## Modelo 3D (.glb) del personaje.
@export var model_scene: PackedScene
## Escala del modelo dentro del jugador.
@export_range(0.01, 5.0, 0.01) var model_scale: float = 0.25
## Otros .glb con el mismo esqueleto de los que se toman animaciones que falten.
@export var extra_animations: Array[PackedScene] = []
