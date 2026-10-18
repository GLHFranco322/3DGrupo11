@tool
extends EditorScenePostImport

# Se ejecuta al importar los .glb de los personajes. Renombra las animaciones
# para que todos los personajes usen los mismos nombres (ver constantes ANIM_*
# en player.gd). Para sumar un personaje nuevo, agregar sus nombres acá.
const RENAMES := {
	# Carlos
	"Walk": "caminar",
	"Mow the lawn": "cortar_pasto",
	"Stunned": "aturdido",
	"Throw": "tirar",
	"Falling": "caer",
	"Idle": "idle",
	# Triángulo
	"cortarPasto": "cortar_pasto",
	"estuniado": "aturdido",
	"tirarOPiedra": "tirar",
	"falling": "caer",
}

const LOOPED := ["idle", "caminar", "cortar_pasto"]


func _post_import(scene: Node) -> Object:
	var anim_player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		return scene

	for lib_name in anim_player.get_animation_library_list():
		var library := anim_player.get_animation_library(lib_name)
		for old_name in library.get_animation_list():
			var new_name: String = RENAMES.get(String(old_name), String(old_name))
			if new_name != String(old_name) and not library.has_animation(new_name):
				library.rename_animation(old_name, new_name)
			if new_name in LOOPED:
				library.get_animation(new_name).loop_mode = Animation.LOOP_LINEAR

	return scene
