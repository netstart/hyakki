// Chão procedural dos biomas (scripts/game/chunk_view.gd). Um quadrado por chunk; o TEXTURE é a
// máscara de estruturas do chunk (8 px por texel, borda de 1 texel): R = caminhos de terra,
// G = calçamento, B = especial (lava/água). Os materiais vêm de um atlas montado com os tiles do
// Ninja Adventure (terrain_art.gd): 6 linhas de 8 variações (ou um bloco de até 5x5 tiles).
// Manchas orgânicas (grama alta, folhas, terra batida) saem de dois campos de ruído em
// coordenadas do mundo, iguais aos de terrain_noise.gd. Bordas com contorno de pixel, como os
// tiles de transição do pacote, e variação de tile por célula (sem repetição visível).
shader_type canvas_item;

global uniform float wetness;
global uniform float weather_time;

uniform sampler2D materials : filter_nearest, repeat_disable;
uniform vec2 materials_px = vec2(128.0, 480.0);
// x: y do slot em px, y: variações (0 = bloco), z/w: tamanho do bloco em tiles.
uniform vec4 mat_info[6];
// rgb: tinta, a: +1 = pode espelhar, +2 = monocromático.
uniform vec4 mat_tint[6];
// Para as camadas 1..5 (índice 0 ignorado): x: campo (0 n1, 1 n2, -1 só máscara), y/z: faixa,
// w: canal da máscara (-1 nenhum).
uniform vec4 bands[6];
// rgb: cor do contorno, a: força.
uniform vec4 rims[6];
uniform vec2 scales = vec2(0.012, 0.018);
uniform vec2 noise_offset = vec2(0.0);
uniform float shade = 0.07;
uniform float ripple = 0.0;
uniform float cracks = 0.0;
uniform vec4 crack_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
uniform float lava_slot = -1.0;
// 0 = Baixa, 1 = Média, 2 = Alta.
uniform float detail = 2.0;

varying vec2 world;

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	return (vnoise(p) * 0.5 + vnoise(p * 2.03 + vec2(17.3, 9.1)) * 0.25) / 0.75;
}

vec3 tile(int k, vec2 cell, vec2 inpx) {
	vec4 info = mat_info[k];
	vec2 src;
	if (info.y > 0.5) {
		float v = floor(hash2(cell + float(k) * 31.7) * info.y);
		vec2 q = inpx;
		if (mod(mat_tint[k].a, 2.0) > 0.5 && hash2(cell * 1.37 + 5.0) > 0.5) {
			q.x = 16.0 - q.x;
		}
		src = vec2(v * 16.0, info.x) + q;
	} else {
		src = vec2(0.0, info.x) + mod(cell, info.zw) * 16.0 + inpx;
	}
	vec3 c = texture(materials, src / materials_px).rgb;
	if (mat_tint[k].a > 1.5) {
		// Monocromático: só a luz do tile, a cor vem toda da tinta (paletas de cinza, basalto, roxo).
		c = vec3(dot(c, vec3(0.3, 0.59, 0.11))) * 1.5;
	}
	return c * mat_tint[k].rgb;
}

vec3 lava(vec2 p, float w) {
	float t = weather_time;
	float n = fbm(p * 0.06 + vec2(t * 0.15, -t * 0.11));
	float m = fbm(p * 0.13 - vec2(t * 0.2, t * 0.07));
	float heat = clamp(n * 0.7 + m * 0.5 + w * 1.6 - 0.35, 0.0, 1.0);
	heat = floor(heat * 5.0) / 5.0;
	vec3 crust = vec3(0.22, 0.05, 0.04);
	vec3 hot = vec3(1.0, 0.42, 0.08);
	vec3 white = vec3(1.0, 0.86, 0.45);
	return heat < 0.5 ? mix(crust, hot, heat * 2.0) : mix(hot, white, (heat - 0.5) * 2.0);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = floor(world) + 0.5;
	vec2 cell = floor(p / 16.0);
	vec2 inpx = p - cell * 16.0;
	vec4 m = texture(TEXTURE, UV);
	float n1 = fbm(p * scales.x + noise_offset);
	float n2 = fbm(p * scales.y + noise_offset.yx + 17.0);
	// Recorte de 2 px nas bordas: tufos e pedrinhas em vez de curva lisa.
	float jag = (hash2(floor(p / 2.0) + 3.1) - 0.5) * 0.018;
	vec3 col = tile(0, cell, inpx);
	bool hot = false;
	for (int k = 1; k < 6; k++) {
		vec4 b = bands[k];
		float w = -1.0;
		if (b.x > -0.5) {
			float f = b.x < 0.5 ? n1 : n2;
			w = min(f - b.y, b.z - f) * 1.4;
		}
		if (b.w > -0.5) {
			float mv = b.w < 0.5 ? m.r : (b.w < 1.5 ? m.g : m.b);
			w = max(w, (mv - 0.5) * 0.35);
		}
		w += jag;
		if (w > 0.0) {
			if (float(k) == lava_slot) {
				col = lava(p, w);
				hot = true;
			} else {
				hot = false;
				col = tile(k, cell, inpx);
				// Borda interna um pouco mais clara: dá volume ao material.
				if (w < 0.012 && detail > 0.5) {
					col *= 1.06;
				}
			}
		} else if (w > -0.016 && rims[k].a > 0.0) {
			col = mix(col, rims[k].rgb, rims[k].a);
		}
	}
	// Variação larga de luz: quebra a repetição sem mexer no pixel art.
	float big = vnoise(p * 0.004 + noise_offset * 0.3);
	col *= 1.0 + (floor(big * 4.0) / 4.0 - 0.4) * shade * 2.0;
	if (ripple > 0.0) {
		float r = sin(p.y * 0.21 + n1 * 18.0 + p.x * 0.03);
		if (r > 0.93) {
			col *= 0.86;
		} else if (r < -0.96) {
			col *= 1.07;
		}
	}
	if (hot) {
		COLOR = vec4(col, 1.0);
	} else if (cracks > 0.0) {
		float c = abs(n2 - 0.5) + max(0.0, 0.45 - n1) * 0.08;
		if (c < 0.0035 && m.g < 0.4) {
			float pulse = detail > 1.5 ? 0.75 + 0.25 * sin(weather_time * 2.0 + p.x * 0.05) : 0.9;
			col = mix(col, crack_color.rgb, pulse);
		} else if (c < 0.008 && m.g < 0.4) {
			col = mix(col, crack_color.rgb * 0.45, 0.5);
		}
	}
	if (!hot) {
		col *= 1.0 - wetness * 0.22;
		col = mix(col, col * vec3(0.86, 0.92, 1.06), wetness * 0.6);
	}
	COLOR = vec4(col, 1.0);
}
