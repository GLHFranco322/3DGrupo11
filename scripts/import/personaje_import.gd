@tool
extends EditorScenePostImport

# Se ejecuta al importar los .glb de los personajes. Renombra las animaciones
# para que todos los personajes usen los mismos nombres. La tabla de nombres
# está en scripts/anim_names.gd.


func _post_import(scene: Node) -> Object:
	var anim_player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	AnimNames.normalize(anim_player)
	return scene
