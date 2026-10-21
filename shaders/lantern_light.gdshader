// Escuridão fora do raio da Lanterna do Amanhecer (plano 8.4).
// Um único ColorRect de tela cheia, custo fixo, sem Light2D.
shader_type canvas_item;

uniform vec2 hero_screen_uv = vec2(0.5);
uniform float radius_px = 120.0;
uniform float soft_px = 48.0;
uniform vec2 screen_px = vec2(678.0, 305.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.72;
uniform vec4 night_tint : source_color = vec4(0.05, 0.04, 0.12, 1.0);
uniform float flicker = 0.0;

void fragment() {
	vec2 d = (UV - hero_screen_uv) * screen_px;
	float r = radius_px + flicker;
	float t = smoothstep(r, r + soft_px, length(d));
	COLOR = vec4(night_tint.rgb, t * darkness);
}
