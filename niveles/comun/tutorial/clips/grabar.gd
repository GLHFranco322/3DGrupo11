extends Node

# Corre un clip (un script que extiende Demo) y cierra el juego al terminar.
# Con el Movie Maker de Godot queda grabado en .ogv (ver LEEME.md):
#   Godot_console.exe --path . --resolution 640x360 --fixed-fps 30
#       --write-movie clip.ogv res://niveles/comun/tutorial/clips/grabar.tscn
#       -- res://niveles/1_patio/tutorial/clips/demo_bota.gd
# Con "--capturas=CARPETA" (después del script) guarda una imagen cada medio
# segundo, para revisar el clip sin grabarlo.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("grabar.tscn: falta el script del clip")
		get_tree().quit(1)
		return
	# Nada de esto tiene que ir a la planilla ni depender del teclado
	Metrics.web_app_url = ""
	Controls.set_keyboard_player(0)
	var demo: Demo = load(args[0]).new()
	add_child(demo)
	for arg in args:
		if arg.begins_with("--capturas="):
			_capturar(arg.trim_prefix("--capturas="), args[0].get_file().get_basename())
	await demo.correr_guion()
	get_tree().quit()


func _capturar(carpeta: String, nombre: String) -> void:
	var i := 0
	while true:
		await get_tree().create_timer(0.5, true, false, true).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("%s_%02d.png" % [nombre, i]))
		i += 1
