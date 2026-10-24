// Cor da morte (DeathSequence): o mundo perde a cor, esfria e escurece com uma vinheta forte,
// mas o corpo da guardiã e uma poça de luar frio em volta dele continuam à vista (~65-70%).
// Um único ColorRect de tela cheia sobre o mundo e a escuridão da lanterna, abaixo da HUD;
// só fica visível durante a sequência (custo zero no resto da partida).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// 0 = imagem normal, 1 = cor da morte completa.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cold : source_color = vec4(0.66, 0.72, 0.86, 1.0);
uniform float desaturate : hint_range(0.0, 1.0) = 0.85;
// Onde está o corpo (UV da tela) e o raio da poça de luz, em alturas de tela.
uniform vec2 focus = vec2(0.5, 0.4);
uniform float pool = 0.2;
// Escurecimento no centro (corpo) e nas bordas.
uniform float center_dim : hint_range(0.0, 1.0) = 0.18;
uniform float edge_dim : hint_range(0.0, 1.0) = 0.62;
uniform float vignette : hint_range(0.0, 1.0) = 0.9;
uniform float moonlight : hint_range(0.0, 0.3) = 0.06;
// Largura/altura da tela, para a poça e a vinheta serem redondas na tela larga.
uniform float aspect = 2.22;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c, vec3(luma) * cold.rgb, desaturate * amount);
	float r = length((SCREEN_UV - focus) * vec2(aspect, 1.0));
	float edge = smoothstep(pool, pool + 0.7, r);
	g *= 1.0 - amount * mix(center_dim, edge_dim, edge);
	g *= 1.0 - smoothstep(0.6, 1.4, r) * vignette * amount;
	// Luar frio sobre o corpo.
	g += cold.rgb * moonlight * amount * (1.0 - smoothstep(0.0, pool + 0.08, r));
	COLOR = vec4(g, 1.0);
}
