shader_type canvas_item;

// Líneas de velocidad (como en los juegos de carreras): rayas finas que salen
// del centro hacia los bordes y titilan. Las usa ThirdPersonCamera con el turbo.

// 0 = no se ven, 1 = a pleno
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.75);
// Cantidad de rayas alrededor de la pantalla
uniform float line_count = 90.0;
// Ancho / alto del rectángulo (para que las rayas salgan derechas)
uniform float aspect = 1.777;
// Qué tan seguido cambian las rayas
uniform float flicker_speed = 14.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= aspect;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	float id = floor(a * line_count);
	float step_time = floor(TIME * flicker_speed + hash(id) * 7.0);
	// Cada raya aparece y desaparece al azar
	float on = step(0.5, hash(id * 1.7 + step_time * 13.1));
	// Finita en el medio de su gajo
	float f = fract(a * line_count);
	float thin = smoothstep(0.1, 0.45, f) * smoothstep(0.9, 0.55, f);
	// Arrancan lejos del centro (el medio queda limpio) y se marcan hacia el borde
	float start = 0.32 + 0.18 * hash(id * 3.7 + step_time);
	float mask = smoothstep(start, start + 0.3, r);
	COLOR = vec4(line_color.rgb, on * thin * mask * intensity * line_color.a);
}
