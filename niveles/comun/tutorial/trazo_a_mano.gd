extends SceneTree

# Pasa los dibujos SVG de los tutoriales a PNG con trazo de mano alzada: las
# líneas ondulan un poco (como hechas de un solo trazo, sin regla) y cambian de
# grosor como la presión de una birome. Queda solo la tinta, azul, con el
# fondo transparente (igual que los dibujos escaneados).
#
# Uso (de a pares entrada/salida; se puede pasar una semilla con "--semilla=N"):
#   Godot_console.exe --headless --path . -s res://niveles/comun/tutorial/trazo_a_mano.gd -- dibujo.svg dibujo.png [otro.svg otro.png ...]

const INK := Color(0.11, 0.12, 0.22)
## Se dibuja más grande y se achica al final, para que los bordes queden suaves.
const OVERSAMPLE := 2.0
## Tamaño final respecto del SVG.
const OUTPUT_SCALE := 1.2
## Cuánto se corren las líneas (en px del resultado) y cada cuánto cambian.
const WOBBLE := 2.6
const WOBBLE_LENGTH := 70.0
## Cada cuánto cambia la presión (grosor) del trazo, en px del resultado.
const PRESSURE_LENGTH := 28.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := 7
	var files: Array[String] = []
	for arg in args:
		if arg.begins_with("--semilla="):
			seed_value = int(arg.trim_prefix("--semilla="))
		else:
			files.append(arg)
	for i in range(0, files.size() - 1, 2):
		_convert(files[i], files[i + 1], seed_value + i)
	quit()


func _convert(svg_path: String, png_path: String, seed_value: int) -> void:
	var scale := OUTPUT_SCALE * OVERSAMPLE
	var source := Image.new()
	if source.load_svg_from_string(FileAccess.get_file_as_string(svg_path), scale) != OK:
		push_error("No se pudo leer " + svg_path)
		return
	source.convert(Image.FORMAT_RGBA8)
	var w := source.get_width()
	var h := source.get_height()

	# Tinta = lo oscuro (el relleno color papel y el fondo quedan transparentes)
	var ink := PackedFloat32Array()
	ink.resize(w * h)
	for y in h:
		for x in w:
			var c := source.get_pixel(x, y)
			ink[y * w + x] = clampf((0.85 - c.get_luminance()) / 0.55, 0.0, 1.0) * c.a

	# Ruido suave (calculado en una grilla y estirado): ondulación y presión
	var step := 8
	var wobble_x := _noise_grid(w, h, step, seed_value, WOBBLE_LENGTH * OVERSAMPLE)
	var wobble_y := _noise_grid(w, h, step, seed_value + 1, WOBBLE_LENGTH * OVERSAMPLE)
	var pressure := _noise_grid(w, h, step, seed_value + 2, PRESSURE_LENGTH * OVERSAMPLE)
	var amplitude := WOBBLE * OVERSAMPLE

	var wavy := PackedFloat32Array()
	wavy.resize(w * h)
	for y in h:
		for x in w:
			var dx := _grid_sample(wobble_x, w, h, step, x, y) * amplitude
			var dy := _grid_sample(wobble_y, w, h, step, x, y) * amplitude
			wavy[y * w + x] = _bilinear(ink, w, h, x + dx, y + dy)

	# Presión: donde aprieta más, el trazo engorda; donde aprieta menos, aclara
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var a := wavy[i]
			var p := _grid_sample(pressure, w, h, step, x, y)
			if p > 0.15 and x > 0 and y > 0 and x < w - 1 and y < h - 1:
				var grow := maxf(maxf(wavy[i - 1], wavy[i + 1]), maxf(wavy[i - w], wavy[i + w]))
				a = maxf(a, grow * clampf((p - 0.15) * 4.0, 0.0, 1.0))
			elif p < -0.3:
				a *= 0.82
			out.set_pixel(x, y, Color(INK, a))
	out.resize(int(w / OVERSAMPLE), int(h / OVERSAMPLE), Image.INTERPOLATE_LANCZOS)
	out.save_png(png_path)
	print(svg_path.get_file(), " -> ", png_path.get_file(), " ", out.get_size())


# Ruido en una grilla de "step" px (es mucho más rápido que pedirlo por píxel)
func _noise_grid(w: int, h: int, step: int, seed_value: int, length: float) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / length
	var gw := w / step + 2
	var gh := h / step + 2
	var grid := PackedFloat32Array()
	grid.resize(gw * gh)
	for gy in gh:
		for gx in gw:
			grid[gy * gw + gx] = noise.get_noise_2d(gx * step, gy * step)
	return grid


func _grid_sample(grid: PackedFloat32Array, w: int, h: int, step: int, x: float, y: float) -> float:
	var gw := w / step + 2
	return _bilinear(grid, gw, h / step + 2, x / step, y / step)


func _bilinear(values: PackedFloat32Array, w: int, h: int, x: float, y: float) -> float:
	x = clampf(x, 0.0, w - 1.001)
	y = clampf(y, 0.0, h - 1.001)
	var x0 := int(x)
	var y0 := int(y)
	var fx := x - x0
	var fy := y - y0
	var top := lerpf(values[y0 * w + x0], values[y0 * w + x0 + 1], fx)
	var bottom := lerpf(values[(y0 + 1) * w + x0], values[(y0 + 1) * w + x0 + 1], fx)
	return lerpf(top, bottom, fy)
