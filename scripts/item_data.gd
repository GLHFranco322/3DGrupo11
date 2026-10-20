class_name ItemData
extends Resource

# Un objeto que se puede pedir en la lista del nivel de la ferretería. Para
# sumar uno nuevo: crear un .tres con este script (Nuevo → Recurso → ItemData)
# y agregarlo a "Item Pool" del nodo StoreLevel.

## Nombre que se ve en la lista y flotando sobre el objeto.
@export var display_name: String = ""
## Modelo 3D del objeto.
@export var model_scene: PackedScene
## Tamaño del objeto en el mundo (se escala solo para medir esto de largo).
@export_range(0.1, 3.0, 0.05, "suffix:u") var size: float = 0.7
