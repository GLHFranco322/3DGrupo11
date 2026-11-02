shader_type spatial;
render_mode unshaded, cull_disabled;

// Borde del piso cortado: una franja de peligro animada alrededor del hueco. El
// centro no se dibuja (ahí está el hueco de verdad). Los valores los pone el
// script TrackHole.

uniform vec4 edge_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float energy = 2.5;
// Tamaño en metros (ancho, largo)
uniform vec2 size_m = vec2(4.0, 12.0);
// Ancho de la franja de peligro
uniform float stripe_width = 0.3;

void fragment() {
	vec2 to_edge = min(UV, 1.0 - UV) * size_m;
	float d = min(to_edge.x, to_edge.y);
	if (d > stripe_width) {
		discard;
	}
	float stripes = step(0.5, fract((UV.x * size_m.x + UV.y * size_m.y) * 1.2 + TIME * 0.6));
	ALBEDO = edge_color.rgb * energy * mix(0.25, 1.0, stripes);
}
