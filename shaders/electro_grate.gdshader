shader_type spatial;
render_mode unshaded, cull_disabled;

// Reja eléctrica: una grilla que brilla según el estado (apagada, aviso,
// encendida con chispazos). Los valores los pone el script ElectroGrate.

uniform vec4 line_color : source_color = vec4(0.3, 0.3, 0.35, 1.0);
uniform vec4 base_color : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform float energy = 1.0;
// Celdas de la grilla (a lo ancho, a lo largo)
uniform vec2 cells = vec2(6.0, 4.0);
uniform float line_width = 0.14;
// 0 = brillo parejo, 1 = parpadea como electricidad
uniform float flicker = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 grid = fract(UV * cells);
	float line = clamp(step(grid.x, line_width) + step(grid.y, line_width), 0.0, 1.0);
	float noise = hash(floor(UV * cells * 3.0) + floor(TIME * 24.0));
	float spark = mix(1.0, 0.3 + noise * 1.4, flicker);
	ALBEDO = mix(base_color.rgb, line_color.rgb * energy * spark, line);
}
