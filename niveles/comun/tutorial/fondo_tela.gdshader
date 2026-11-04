shader_type canvas_item;

// Tela gris de fondo (como la mesa de la foto) con sombra en una esquina.

uniform vec3 base_color : source_color = vec3(0.70, 0.68, 0.66);
// Tamaño en píxeles de cada hilo de la trama
uniform float thread_size = 3.0;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = FRAGCOORD.xy / thread_size;
	// Trama: hilos horizontales y verticales que se cruzan
	float weave = sin(p.x * 3.1416) * sin(p.y * 3.1416);
	float grain = noise(p * 0.35) * 0.6 + noise(p * 2.0) * 0.4;
	float shade = 0.94 + 0.05 * weave + 0.08 * (grain - 0.5);
	// Sombra suave abajo a la izquierda, como en la foto
	float corner = smoothstep(0.75, 0.0, distance(UV, vec2(0.0, 1.05)));
	shade *= 1.0 - corner * shadow_strength;
	shade *= 1.0 - 0.12 * smoothstep(0.4, 1.2, distance(UV, vec2(0.5)));
	COLOR = vec4(base_color * shade, 1.0);
}
