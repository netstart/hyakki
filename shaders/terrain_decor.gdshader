// Decoração dos chunks em MultiMesh (scripts/game/chunk_view.gd): um quadrado unitário por item,
// recortado do atlas de decoração pelo INSTANCE_CUSTOM (x, y, w, h normalizados).
// Cor da instância: r = balanço no vento (0..1), g = tipo (0 normal, 0.25 sombra), b = brilho
// (0.5 = neutro), a = opacidade. Vento pelos globais do clima (wind_dir, wind_strength,
// weather_time); a umidade escurece um pouco a folhagem. Na copa (fade_on), um buraco suave
// deixa o herói visível quando passa por trás das árvores.
shader_type canvas_item;

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wetness;
global uniform float weather_time;

uniform float sway_on = 1.0;
uniform float fade_on = 0.0;
uniform vec2 hero_pos = vec2(0.0);
uniform float shadow_alpha = 0.32;

varying vec4 v_data;
varying vec2 v_world;

void vertex() {
	v_data = COLOR;
	vec2 base_uv = UV;
	UV = INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw;
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (sway_on > 0.5 && v_data.r > 0.0) {
		float top = 1.0 - base_uv.y;
		float phase = w.x * 0.045 + w.y * 0.021;
		float gust = clamp(wind_strength, 0.0, 1.0);
		float wave = sin(weather_time * (1.4 + gust * 2.4) + phase) * (0.5 + gust * 1.3);
		float lean = wind_dir.x * gust * 2.4;
		float px = (wave + lean) * v_data.r * top * top * 1.6;
		float sx = max(length(MODEL_MATRIX[0].xy), 0.0001);
		VERTEX.x += px / sx;
		w.x += px;
	}
	v_world = w;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (v_data.g > 0.2 && v_data.g < 0.3) {
		COLOR = vec4(0.02, 0.01, 0.04, t.a * shadow_alpha * v_data.a);
	} else {
		vec3 c = t.rgb * (0.7 + v_data.b * 0.6);
		c *= 1.0 - wetness * 0.12;
		float a = t.a * v_data.a;
		if (fade_on > 0.5) {
			float d = distance(v_world, hero_pos);
			a *= mix(0.35, 1.0, smoothstep(12.0, 30.0, d));
		}
		COLOR = vec4(c, a);
	}
}
