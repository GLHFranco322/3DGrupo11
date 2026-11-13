#!/usr/bin/env bash
# Graba los clips de los tutoriales (.ogv) con el Movie Maker de Godot.
# Se corre desde Git Bash, en la carpeta del proyecto:
#   bash niveles/comun/tutorial/clips/grabar_clips.sh            (todos)
#   bash niveles/comun/tutorial/clips/grabar_clips.sh niveles/1_patio/tutorial/clips/demo_bota.gd
# Cada demo_X.gd se graba como X.ogv en su misma carpeta. Ruta de Godot:
# variable GODOT (si no, la de abajo).
set -e
GODOT="${GODOT:-C:/Users/Franc/Documents/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe}"
cd "$(dirname "$0")/../../../.."

if [ $# -eq 0 ]; then
	# Todos los demo_*.gd que no son bases (las bases tienen class_name)
	set -- $(grep -L "^class_name" niveles/*/tutorial/clips/demo_*.gd)
fi

# Ventana chica y calidad baja solo mientras se graba (override.cfg pisa la
# configuración del proyecto y se borra al terminar)
cat > override.cfg <<'CFG'
[display]

window/size/window_width_override=480
window/size/window_height_override=270

[editor]

movie_writer/video_quality=0.1
CFG
trap 'rm -f override.cfg' EXIT

for demo in "$@"; do
	salida="$(dirname "$demo")/$(basename "$demo" .gd | sed 's/^demo_//').ogv"
	echo "Grabando $demo -> $salida"
	"$GODOT" --path . --fixed-fps 30 --write-movie "$salida" \
		res://niveles/comun/tutorial/clips/grabar.tscn -- "res://$demo" 2>&1 | grep -E "SCRIPT ERROR|Done recording" || true
done
