class_name SurfaceLook
extends RefCounted
## Desenho de cada superfície lenta (só visual; quem decide onde ela está é o SurfaceField):
##   lama   marrom úmida com borda escura, centro encharcado e brilho que cintila;
##   barro  avermelhado e rachado, quase seco;
##   pântano verde-escuro com algas, bolhas que estouram e lírios (flor em Alta);
##   óleo   mancha escura com reflexo arco-íris (Alta: três faixas que mudam de cor);
##   piche  preto brilhante com bolhas lentas, brasa na borda e fumaça (Alta);
##   areia movediça grãos claros com redemoinho girando devagar para o centro.
## Bordas orgânicas: polígonos de bolhas com raio ondulado. Baixa: borda + corpo com textura +
## um detalhe barato; Média: + detalhes principais; Alta: tudo.

const TEX_SIZE := 32
const POLY_POINTS := 14
## Paleta por tipo: escuro e claro da textura, pinta, borda, centro, pegada, gotícula.
const PALETTE := {
	"mud": [Color(0.27, 0.19, 0.12), Color(0.36, 0.26, 0.17), Color(0.2, 0.15, 0.1), Color(0.11, 0.08, 0.06, 0.55),
			Color(0.2, 0.14, 0.1, 0.5), Color(0.09, 0.06, 0.04), Color(0.24, 0.17, 0.11)],
	"clay": [Color(0.5, 0.25, 0.15), Color(0.62, 0.34, 0.21), Color(0.3, 0.13, 0.08), Color(0.26, 0.12, 0.07, 0.45),
			Color(0.42, 0.2, 0.12, 0.0), Color(0.32, 0.15, 0.09), Color(0.55, 0.28, 0.16)],
	"swamp": [Color(0.09, 0.16, 0.1), Color(0.15, 0.24, 0.13), Color(0.3, 0.42, 0.18), Color(0.05, 0.09, 0.06, 0.55),
			Color(0.04, 0.08, 0.07, 0.55), Color(0.06, 0.1, 0.06), Color(0.35, 0.5, 0.3)],
	"oil": [Color(0.06, 0.05, 0.06), Color(0.1, 0.08, 0.09), Color(0.16, 0.13, 0.12), Color(0.04, 0.03, 0.03, 0.35),
			Color(0.02, 0.02, 0.03, 0.5), Color(0.05, 0.04, 0.05), Color(0.12, 0.1, 0.12)],
	"tar": [Color(0.03, 0.025, 0.04), Color(0.07, 0.06, 0.08), Color(0.12, 0.1, 0.12), Color(0.02, 0.02, 0.02, 0.6),
			Color(0.01, 0.01, 0.02, 0.6), Color(0.03, 0.02, 0.03), Color(0.05, 0.04, 0.05)],
	"quicksand": [Color(0.72, 0.56, 0.34), Color(0.84, 0.68, 0.44), Color(0.6, 0.45, 0.27), Color(0.45, 0.33, 0.2, 0.45),
			Color(0.62, 0.47, 0.28, 0.4), Color(0.5, 0.38, 0.24), Color(0.8, 0.64, 0.42)],
}

static var _textures: Dictionary = {}


static func colors(type_name: String) -> Array:
	return PALETTE.get(type_name, PALETTE["mud"])


static func print_color(type_name: String) -> Color:
	return colors(type_name)[5]


static func droplet_color(type_name: String) -> Color:
	return colors(type_name)[6]


## Textura 32x32 que emenda sem costura (ondas com período da textura + ruído fixo).
static func texture(type_name: String) -> ImageTexture:
	if _textures.has(type_name):
		return _textures[type_name]
	var pal := colors(type_name)
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = hash(type_name)
	var k := TAU / TEX_SIZE
	for y: int in range(TEX_SIZE):
		for x: int in range(TEX_SIZE):
			var n := sin(x * k * 2.0 + 1.3) * sin(y * k * 3.0 + 0.4) * 0.5 \
					+ sin((x + y) * k + 2.1) * 0.3 + sin((x - 2 * y) * k * 2.0) * 0.2
			var v := clampf(0.5 + n * 0.5 + r.randf_range(-0.12, 0.12), 0.0, 1.0)
			var c := (pal[0] as Color).lerp(pal[1], v)
			if r.randf() < 0.06:
				c = pal[2]
			img.set_pixel(x, y, c)
	if type_name == "clay":
		# Rachaduras: caminhos tortos escuros que atravessam a textura.
		for _j: int in range(4):
			var p := Vector2i(r.randi_range(0, TEX_SIZE - 1), r.randi_range(0, TEX_SIZE - 1))
			for _s: int in range(14):
				img.set_pixelv(Vector2i(posmod(p.x, TEX_SIZE), posmod(p.y, TEX_SIZE)), Color(0.24, 0.1, 0.06))
				p += Vector2i(r.randi_range(0, 1) * 2 - 1, r.randi_range(-1, 1))
	elif type_name in ["mud", "quicksand"]:
		for _j: int in range(9):
			var p := Vector2i(r.randi_range(0, TEX_SIZE - 2), r.randi_range(0, TEX_SIZE - 2))
			img.set_pixel(p.x, p.y, (pal[1] as Color).lightened(0.25))
			img.set_pixel(p.x + 1, p.y, (pal[1] as Color).lightened(0.1))
	var tex := ImageTexture.create_from_image(img)
	_textures[type_name] = tex
	return tex


## Polígonos irregulares (um por bolha) em coordenadas locais da mancha: [[polígono, centro]].
static func polys(patch: Dictionary) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = int(patch["seed"])
	var out: Array = []
	for b: Vector3 in patch["blobs"]:
		var poly := PackedVector2Array()
		var w0 := r.randf() * TAU
		var w1 := r.randf() * TAU
		var amp := r.randf_range(0.08, 0.16)
		for k: int in range(POLY_POINTS):
			var a := TAU * k / POLY_POINTS
			var rad := b.z * (1.0 + amp * sin(a * 3.0 + w0) + 0.06 * sin(a * 5.0 + w1))
			poly.append(Vector2(b.x + cos(a) * rad * 1.15, b.y + sin(a) * rad * 0.78))
		out.append([poly, Vector2(b.x, b.y), b.z])
	return out


static func scaled(poly: PackedVector2Array, center: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i: int in range(poly.size()):
		out[i] = center + (poly[i] - center) * k
	return out


## Uma passada da mancha (0 borda, 1 corpo, 2 centro, 3 detalhes). O canvas já está com a
## transformação da mancha (centro e escala).
static func draw_pass(canvas: CanvasItem, type_name: String, patch: Dictionary, entries: Array, pass_id: int,
		time: float, quality: int, wet: float) -> void:
	var pal := colors(type_name)
	var center: Vector2 = patch["center"]
	var ph := float(int(patch["seed"]) & 1023) / 1023.0 * TAU
	match pass_id:
		0:
			var rim: Color = pal[3]
			for e: Array in entries:
				canvas.draw_colored_polygon(scaled(e[0], e[1], 1.18), rim)
			if type_name == "tar":
				# Piche fervente: borda em brasa (pulsa devagar em Média/Alta).
				var glow := 0.2 + (0.08 * sin(time * 1.3 + ph) if quality > GfxQuality.LOW else 0.0)
				for e: Array in entries:
					canvas.draw_colored_polygon(scaled(e[0], e[1], 1.06), Color(0.85, 0.28, 0.06, glow))
		1:
			var tex := texture(type_name)
			var alpha := 0.82 if type_name == "oil" else 0.96
			for e: Array in entries:
				var poly: PackedVector2Array = e[0]
				var uvs := PackedVector2Array()
				for v: Vector2 in poly:
					uvs.append((v + center) / float(TEX_SIZE))
				canvas.draw_colored_polygon(poly, Color(1, 1, 1, alpha), uvs, tex)
		2:
			var core: Color = pal[4]
			if core.a > 0.0:
				var a := core.a * (wet if type_name == "mud" else 1.0)
				for e: Array in entries:
					canvas.draw_colored_polygon(scaled(e[0], e[1], 0.55), Color(core, a))
			if type_name in ["tar", "oil"]:
				# Reflexo da lua no líquido escuro: faixa clara deslocada para cima/esquerda.
				for e: Array in entries:
					var sheen := scaled(e[0], e[1], 0.62)
					for i: int in range(sheen.size()):
						sheen[i] += Vector2(-1.5, -2.0)
					canvas.draw_colored_polygon(sheen, Color(0.32, 0.3, 0.42, 0.3 if type_name == "tar" else 0.22))
			if type_name == "mud" and quality == GfxQuality.HIGH and wet > 0.7:
				for e: Array in entries:
					canvas.draw_colored_polygon(scaled(e[0], e[1], 0.28), Color(0.16, 0.18, 0.24, 0.55 * (wet - 0.7) / 0.3))
		3:
			_draw_details(canvas, type_name, entries, time, quality, wet, ph)


static func _draw_details(canvas: CanvasItem, type_name: String, entries: Array, time: float, quality: int,
		wet: float, ph: float) -> void:
	var main: Array = entries[0]
	var c0: Vector2 = main[1]
	var r0: float = main[2]
	var rich := quality == GfxQuality.HIGH
	match type_name:
		"mud":
			_gloss(canvas, c0, r0, 0.22 * maxf(wet, 0.4), time, ph, 1 if quality == GfxQuality.LOW else (2 if not rich else 3))
		"clay":
			if quality > GfxQuality.LOW:
				_gloss(canvas, c0, r0, 0.08, time, ph, 1)
		"swamp":
			var bubbles := 1 if quality == GfxQuality.LOW else (2 if not rich else 4)
			_bubbles(canvas, entries, bubbles, 2.2, time, ph, Color(0.45, 0.6, 0.35, 0.8), 2.0)
			var lilies := 1 if quality == GfxQuality.LOW else 2 + int(rich)
			for k: int in range(lilies):
				var a := ph + k * 2.4
				var at := c0 + Vector2(cos(a), sin(a) * 0.6) * r0 * 0.55
				canvas.draw_circle(at, 3.0, Color(0.22, 0.42, 0.18))
				canvas.draw_circle(at + Vector2(0.5, -0.5), 2.0, Color(0.3, 0.55, 0.24))
				canvas.draw_colored_polygon(PackedVector2Array([at, at + Vector2(3.2, -1.2), at + Vector2(3.2, 1.2)]),
						Color(0.09, 0.16, 0.1))
				if rich and k == 0:
					canvas.draw_rect(Rect2((at + Vector2(-1, -2)).round(), Vector2(2, 2)), Color(0.98, 0.62, 0.78))
					canvas.draw_rect(Rect2((at + Vector2(-0.5, -1.5)).round(), Vector2(1, 1)), Color(1.0, 0.92, 0.5))
		"oil":
			var bands := 1 if quality < GfxQuality.HIGH else 3
			if quality == GfxQuality.LOW:
				canvas.draw_line(c0 + Vector2(-r0 * 0.4, -r0 * 0.2), c0 + Vector2(r0 * 0.1, -r0 * 0.2),
						Color(0.7, 0.6, 0.9, 0.3), 1.0)
				return
			for k: int in range(bands):
				var hue := fposmod(time * 0.08 + k * 0.33 + ph / TAU, 1.0)
				var col := Color.from_hsv(hue, 0.7, 1.0, 0.2 if rich else 0.14)
				for e: Array in entries:
					var band := scaled(e[0], e[1], 0.85 - k * 0.22)
					for i: int in range(band.size()):
						band[i] += Vector2(sin(time * 0.5 + k + ph) * 1.5, -1.0 - k)
					canvas.draw_colored_polygon(band, col)
			_gloss(canvas, c0, r0, 0.3, time, ph, 1)
		"tar":
			_bubbles(canvas, entries, 1 if quality == GfxQuality.LOW else (2 if not rich else 3), 3.6, time, ph,
					Color(0.16, 0.14, 0.17, 0.95), 2.6)
			_gloss(canvas, c0, r0, 0.55, time, ph, 1 if not rich else 2)
			if quality > GfxQuality.LOW:
				# Fumaça do piche fervente: fiapos que sobem e somem.
				for k: int in range(1 if not rich else 3):
					var age := fposmod(time * 0.45 + k * 0.37 + ph, 1.0)
					var at := c0 + Vector2(sin(ph + k * 2.0) * r0 * 0.4 + sin(time * 1.5 + k) * 2.0, -age * 22.0)
					canvas.draw_circle(at, 2.0 + age * 3.0, Color(0.35, 0.32, 0.36, 0.28 * (1.0 - age)))
		"quicksand":
			for k: int in range(1 if quality == GfxQuality.LOW else (2 if not rich else 3)):
				var rad := r0 * (0.65 - k * 0.2)
				var start := time * (0.5 + 0.25 * k) + ph + k
				_ellipse_arc(canvas, c0, rad, start, 2.2, Color(0.56, 0.41, 0.24, 0.65))
			canvas.draw_circle(c0, 1.5, Color(0.5, 0.36, 0.2, 0.8))


static func _ellipse_arc(canvas: CanvasItem, c: Vector2, r: float, start: float, span: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k: int in range(10):
		var a := start + span * k / 9.0
		pts.append(c + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.7))
	canvas.draw_polyline(pts, col, 1.0)


static func _gloss(canvas: CanvasItem, c: Vector2, r: float, strength: float, time: float, ph: float,
		lines: int) -> void:
	for k: int in range(lines):
		var tw := 0.5 + 0.5 * sin(time * (1.2 + 0.3 * k) + ph + k * 2.0)
		var y := c.y - r * 0.3 + k * 3.0
		var x := c.x - r * (0.45 - 0.1 * k)
		canvas.draw_line(Vector2(x, y), Vector2(x + r * (0.4 + 0.1 * k), y), Color(0.85, 0.9, 1.0, strength * tw), 1.0)
	canvas.draw_rect(Rect2((c + Vector2(r * 0.3, -r * 0.2)).round(), Vector2(1, 1)),
			Color(1, 1, 1, strength * 1.8 * (0.5 + 0.5 * sin(time * 2.6 + ph))))


## Bolhas que crescem e estouram (anel) em ciclos de `period` segundos.
static func _bubbles(canvas: CanvasItem, entries: Array, count: int, period: float, time: float, ph: float,
		col: Color, size: float) -> void:
	for k: int in range(count):
		var e: Array = entries[k % entries.size()]
		var c: Vector2 = e[1]
		var r: float = e[2]
		var cyc := fposmod(time / period + k * 0.37 + ph * 0.1, 1.0)
		var a := ph * 3.0 + k * 2.1 + floorf(time / period + k * 0.37) * 1.7
		var at := c + Vector2(cos(a), sin(a) * 0.6) * r * 0.45
		if cyc < 0.8:
			var g := cyc / 0.8
			canvas.draw_circle(at, 0.6 + size * g, col)
			canvas.draw_rect(Rect2((at + Vector2(-size * g * 0.4, -size * g * 0.5)).round(), Vector2(1, 1)),
					Color(1, 1, 1, 0.5 * g))
		else:
			var p := (cyc - 0.8) / 0.2
			canvas.draw_arc(at, size + p * 3.0, 0.0, TAU, 10, Color(col, 0.6 * (1.0 - p)), 1.0)
