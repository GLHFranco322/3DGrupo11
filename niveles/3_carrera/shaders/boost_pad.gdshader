shader_type spatial;
render_mode unshaded, cull_disabled;

// Rampa de turbo: flechas que avanzan hacia adelante (-Z). Los valores los pone
// el script BoostPad.

uniform vec4 arrow_color : source_color = vec4(0.1, 0.9, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(0.02, 0.04, 0.08, 1.0);
uniform float energy = 3.0;
// Flechas a lo largo de la rampa
uniform float arrows = 4.0;
// Qué tan en punta (a lo largo / a lo ancho)
uniform float sharpness = 0.6;
uniform float scroll_speed = 1.5;
// Grosor de cada flecha (0 a 1)
uniform float thickness = 0.4;

void fragment() {
	float x = abs(UV.x - 0.5);
	float phase = fract((UV.y - x * sharpness) * arrows + TIME * scroll_speed);
	float arrow = step(phase, thickness);
	// Borde fino alrededor
	float border = step(0.46, x) + step(UV.y, 0.02) + step(0.98, UV.y);
	float mask = clamp(arrow + border, 0.0, 1.0);
	ALBEDO = mix(base_color.rgb, arrow_color.rgb * energy, mask);
}
