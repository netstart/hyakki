// Noite e luz da Lanterna do Amanhecer (plano 8.4), num único ColorRect de tela cheia.
// Luz quente com queda suave em volta do herói (o raio da jogabilidade fica na meia-luz),
// mais as luzes do cenário (lanternas de pedra, tochas, lava, estátuas), até 24.
// A cor da noite e o calor da luz vêm do bioma (gradação por fase); a vinheta escurece os cantos
// (post_fx). Mistura normal: fora da luz, a cena puxa para a cor da noite; perto das luzes,
// um véu quente leve.
shader_type canvas_item;

uniform vec2 screen_px = vec2(678.0, 305.0);
uniform vec2 hero_px = vec2(339.0, 152.0);
uniform float radius_px = 120.0;
uniform float flicker = 0.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.72;
uniform vec4 night_tint : source_color = vec4(0.05, 0.04, 0.12, 1.0);
uniform vec4 warm_tint : source_color = vec4(1.0, 0.7, 0.36, 1.0);
uniform float warmth = 0.14;
uniform float vignette = 0.0;
uniform int light_count = 0;
// xy: posição na tela (px), z: raio (px), w: força.
uniform vec4 lights[24];
uniform vec4 light_colors[24];

void fragment() {
	vec2 p = UV * screen_px;
	float r = max(radius_px + flicker, 1.0);
	float d = length(p - hero_px);
	// Queda natural: luz cheia até ~40% do raio, meia-luz no raio, escuro em ~1,6x.
	float t = clamp((d - r * 0.4) / (r * 1.2 + 20.0), 0.0, 1.0);
	float hero = 1.0 - t * t * (3.0 - 2.0 * t);
	float light = hero;
	vec3 warm = warm_tint.rgb * hero;
	for (int i = 0; i < light_count; i++) {
		vec4 l = lights[i];
		float k = clamp(1.0 - length(p - l.xy) / max(l.z, 1.0), 0.0, 1.0);
		k = k * k * l.w;
		light = 1.0 - (1.0 - light) * (1.0 - k);
		warm += light_colors[i].rgb * k;
	}
	light = clamp(light, 0.0, 1.0);
	float dark_a = darkness * (1.0 - light);
	if (vignette > 0.0) {
		vec2 v = (UV - 0.5) * vec2(1.0, screen_px.y / screen_px.x) * 2.0;
		dark_a = max(dark_a, 0.0) + vignette * smoothstep(0.55, 1.2, length(v)) * (1.0 - dark_a);
	}
	float total = max(light, 0.0001);
	vec3 warm_col = warm / max(total, 0.25);
	float warm_a = warmth * light * (1.0 - light * 0.55);
	float a = clamp(dark_a + warm_a, 0.0, 1.0);
	vec3 col = (night_tint.rgb * dark_a + clamp(warm_col, 0.0, 1.0) * warm_a) / max(dark_a + warm_a, 0.0001);
	COLOR = vec4(col, a);
}
