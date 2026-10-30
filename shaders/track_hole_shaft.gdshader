shader_type spatial;
render_mode unshaded;

// Paredes del pozo debajo del piso cortado: brillan arriba y se apagan hacia el
// fondo, con líneas como pisos de una estructura. El fondo es negro. Los
// valores los pone el script TrackHole.

uniform vec4 edge_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float energy = 2.5;
uniform float depth = 25.0;
// Metros entre líneas
uniform float line_spacing = 2.5;

varying float from_top;

void vertex() {
	// La caja está centrada: arriba es +depth/2
	from_top = depth * 0.5 - VERTEX.y;
}

void fragment() {
	float fade = pow(clamp(1.0 - from_top / (depth * 0.6), 0.0, 1.0), 2.5);
	float line = step(0.92, fract(from_top / line_spacing));
	ALBEDO = edge_color.rgb * energy * fade * (0.55 + line * 0.9);
}
