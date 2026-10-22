@tool
class_name AnimNames
extends RefCounted

# Nombres de animación comunes a todos los personajes (ver constantes ANIM_* en
# player.gd). Se aplica al importar los .glb y también al cargar el modelo en
# el juego, así funciona aunque el .glb no se haya reimportado.
# Para un personaje nuevo, agregar acá sus nombres originales.
const RENAMES := {
	# Carlos
	"Walk": "caminar",
	"Mow the lawn": "cortar_pasto",
	"Stunned": "aturdido",
	"Throw": "tirar",
	"Falling": "caer",
	# El modelo "Nivel1" trae solo Falling2 (si hay las dos, gana Falling)
	"Falling2": "caer",
	"Idle": "idle",
	"Iddle": "idle",
	"Emote": "festejo",
	# Triángulo
	"cortarPasto": "cortar_pasto",
	"estuniado": "aturdido",
	"tirarOPiedra": "tirar",
	"falling": "caer",
	"celebration": "festejo",
}

const LOOPED := ["idle", "caminar", "cortar_pasto", "festejo"]


static func normalize(anim_player: AnimationPlayer) -> void:
	if anim_player == null:
		return
	for lib_name in anim_player.get_animation_library_list():
		var library := anim_player.get_animation_library(lib_name)
		for old_name in library.get_animation_list():
			var new_name: String = RENAMES.get(String(old_name), String(old_name))
			if new_name != String(old_name) and not library.has_animation(new_name):
				library.rename_animation(old_name, new_name)
			if new_name in LOOPED and library.has_animation(new_name):
				library.get_animation(new_name).loop_mode = Animation.LOOP_LINEAR
