class_name ChunkView
extends Node2D
## Desenho de um chunk do mapa (montado uma vez, sem _draw por quadro):
##   - chão: um Sprite2D com a máscara de estruturas (34x34, 8 px por texel) e o shader
##     terrain_ground (materiais, manchas por ruído, bordas, lava);
##   - três MultiMesh com o atlas de decoração: "flat" (folhas, pedrinhas, degraus e as sombras),
##     "decor" (base dos objetos, tufos e moitas, ordenados por y, abaixo dos atores) e "canopy"
##     (copas, telhados e lances altos do bambu, acima dos atores; ficam a 35% com alguém atrás).
## Um draw call por camada por chunk. A densidade da decoração sem colisão e o tipo de sombra
## vêm do nível gráfico na hora de montar; trocar o nível remonta os chunks.

const MASK_TEXEL := 8.0
const MASK_SIZE := 34
const TRUNK := 14.0
const HOUSE_BASE := 18.0
const FADE_ALPHA := 0.35
const FADE_SPEED := 6.0

static var _quad: ArrayMesh

## Luzes deste chunk: [posição, cor, raio, força].
var lights: Array = []
## Quantos itens de decoração foram montados (testes).
var item_count: int = 0
var flat_count: int = 0
## Copas e telhados: área (mundo) de cada instância do MultiMesh "Canopy", base (y) e alfa atual.
## Quem estiver atrás (guardiã ou inimigo) faz a peça inteira ficar translúcida (FADE_ALPHA).
var fade_rects: Array[Rect2] = []
var fade_alpha := PackedFloat32Array()

var _canopy_mm: MultiMesh
var _canopy_colors: Array[Color] = []
var _near: Array[int] = []


static func quad() -> ArrayMesh:
	if _quad == null:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var square := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		arrays[Mesh.ARRAY_VERTEX] = square
		arrays[Mesh.ARRAY_TEX_UV] = square.duplicate()
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_quad = ArrayMesh.new()
		_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad


## Monta o chunk. `items`: estrutura + espalhados (já filtrados pela densidade); `mask`: paint_mask().
func build(c: Vector2i, items: Array, mask: Image, art: TerrainArt, mats: Dictionary, soft_shadows: bool) -> void:
	var origin := Vector2(c.x, c.y) * TerrainLayout.CHUNK
	_build_ground(origin, mask, mats["ground"])
	var flat: Array = []
	var shadows: Array = []
	var decor: Array = []
	var canopy: Array = []
	lights.clear()
	item_count = 0
	for it: Dictionary in items:
		var region: Rect2 = art.regions.get(String(it["s"]), Rect2())
		if region.size == Vector2.ZERO:
			continue
		item_count += 1
		var p: Vector2 = it["p"]
		var layer := String(it.get("layer", "auto"))
		var light: Array = it.get("light", [])
		if not light.is_empty():
			lights.append([p + Vector2(0, float(light[3])), Color(String(light[0])), float(light[1]), float(light[2])])
		var shadow := float(it.get("shadow", 0.0))
		if shadow > 0.0:
			shadows.append([p, shadow])
		if layer == "flat":
			flat.append([it, region])
		elif layer == "canopy":
			canopy.append([it, region])
		elif layer == "decor" or region.size.y <= 24.0:
			decor.append([it, region, 0.0])
		else:
			# Objeto alto: a base fica com os atores, o resto vai para a frente deles.
			var base := HOUSE_BASE if region.size.x >= 48.0 else TRUNK
			decor.append([it, Rect2(region.position + Vector2(0, region.size.y - base), Vector2(region.size.x, base)), 0.0])
			canopy.append([it, Rect2(region.position, Vector2(region.size.x, region.size.y - base)), base])
	flat_count = flat.size()
	var shadow_region: Rect2 = art.regions["shadow_soft" if soft_shadows else "shadow_hard"]
	_add_layer("Flat", -19, art, mats["flat"], _flat_instances(flat, shadows, shadow_region))
	decor.sort_custom(func(a: Array, b: Array) -> bool: return (a[0]["p"] as Vector2).y < (b[0]["p"] as Vector2).y)
	canopy.sort_custom(func(a: Array, b: Array) -> bool: return (a[0]["p"] as Vector2).y < (b[0]["p"] as Vector2).y)
	_add_layer("Decor", -10, art, mats["decor"], _sprite_instances(decor))
	var canopy_inst := _sprite_instances(canopy)
	_canopy_mm = _add_layer("Canopy", 20, art, mats["canopy"], canopy_inst)
	fade_rects.clear()
	_canopy_colors.clear()
	for k: int in range(canopy.size()):
		var e: Array = canopy[k]
		var p: Vector2 = e[0]["p"]
		var size: Vector2 = (e[1] as Rect2).size
		var lift := float(e[2]) if e.size() > 2 else 0.0
		var top := p.y - lift - size.y
		fade_rects.append(Rect2(p.x - size.x * 0.5 - 2.0, top - 4.0, size.x + 4.0, p.y - top + 4.0))
		_canopy_colors.append(canopy_inst[k][1])
	fade_alpha.resize(canopy.size())
	fade_alpha.fill(1.0)


## A cada quadro: peças com a guardiã ou um inimigo atrás vão para FADE_ALPHA, as outras voltam.
func update_fade(hero: Vector2, enemies: EnemyManager, dt: float, view: Rect2) -> void:
	if _canopy_mm == null:
		return
	var step := clampf(dt * FADE_SPEED, 0.0, 1.0)
	for k: int in range(fade_rects.size()):
		var r := fade_rects[k]
		var on_screen := view.intersects(r)
		var hidden := on_screen and r.has_point(hero)
		if on_screen and not hidden and enemies != null:
			enemies.query_circle(r.get_center(), maxf(r.size.x, r.size.y) * 0.5, _near)
			for j: int in _near:
				if r.has_point(enemies.pos[j]):
					hidden = true
					break
		var target := FADE_ALPHA if hidden else 1.0
		var a := fade_alpha[k]
		if absf(a - target) < 0.01:
			continue
		a = move_toward(a, target, step)
		fade_alpha[k] = a
		var col := _canopy_colors[k]
		col.a = a
		_canopy_mm.set_instance_color(k, col)


func _flat_instances(flat: Array, shadows: Array, shadow_region: Rect2) -> Array:
	var out: Array = []
	for e: Array in flat:
		out.append(_instance(e[0], e[1], 0.0, 0.0))
	for s: Array in shadows:
		var w := float(s[1])
		var h := maxf(3.0, w * 0.3)
		var xf := Transform2D(0.0, Vector2(w, h), 0.0, (s[0] as Vector2) - Vector2(w * 0.5, h * 0.6))
		out.append([xf, Color(0, 0.25, 0.5, 1.0), shadow_region])
	return out


func _sprite_instances(list: Array) -> Array:
	var out: Array = []
	for e: Array in list:
		out.append(_instance(e[0], e[1], float(e[2]) if e.size() > 2 else 0.0, 1.0))
	return out


## [transform, cor (balanço, tipo, brilho, alfa), região]. `lift`: px acima da base (copas).
func _instance(it: Dictionary, region: Rect2, lift: float, sway_mult: float) -> Array:
	var p: Vector2 = it["p"]
	var size := region.size
	var pos := p - Vector2(size.x * 0.5, size.y + lift)
	var scale := size
	if bool(it.get("flip", false)):
		pos.x += size.x
		scale.x = -size.x
	var xf := Transform2D(0.0, scale, 0.0, pos)
	var sway := float(it.get("sway", 0.0)) * sway_mult
	return [xf, Color(sway, 0.0, float(it.get("tone", 0.5)), 1.0), region]


func _add_layer(layer_name: String, z: int, art: TerrainArt, mat: Material, instances: Array) -> MultiMesh:
	if instances.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad()
	mm.instance_count = instances.size()
	var atlas := Vector2(art.decor_texture.get_size())
	for i: int in range(instances.size()):
		var e: Array = instances[i]
		var r: Rect2 = e[2]
		mm.set_instance_transform_2d(i, e[0])
		mm.set_instance_color(i, e[1])
		mm.set_instance_custom_data(i, Color(r.position.x / atlas.x, r.position.y / atlas.y,
				r.size.x / atlas.x, r.size.y / atlas.y))
	var mmi := MultiMeshInstance2D.new()
	mmi.name = layer_name
	mmi.multimesh = mm
	mmi.texture = art.decor_texture
	mmi.material = mat
	mmi.z_index = z
	add_child(mmi)
	return mm


# --- Chão --------------------------------------------------------------------------------

func _build_ground(origin: Vector2, mask: Image, mat: Material) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Ground"
	sprite.texture = ImageTexture.create_from_image(mask)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(1, 1, MASK_SIZE - 2, MASK_SIZE - 2)
	sprite.scale = Vector2(MASK_TEXEL, MASK_TEXEL)
	sprite.position = origin
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = mat
	sprite.z_index = -20
	add_child(sprite)


## Máscara RGBA do chunk (1 texel de borda): valor 0.5 na borda de cada forma, sobe 0.5 a
## cada texel para dentro. Assim o filtro linear dá contornos lisos no limiar do shader.
static func paint_mask(origin: Vector2, paint: Array) -> Image:
	var img := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var base := origin - Vector2(MASK_TEXEL, MASK_TEXEL) * 0.5
	for op: Array in paint:
		var channel := int(op[1])
		var box := _op_box(op).grow(MASK_TEXEL * 2.0)
		var lo := Vector2i(clampi(floori((box.position.x - base.x) / MASK_TEXEL), 0, MASK_SIZE - 1),
				clampi(floori((box.position.y - base.y) / MASK_TEXEL), 0, MASK_SIZE - 1))
		var hi := Vector2i(clampi(ceili((box.end.x - base.x) / MASK_TEXEL), 0, MASK_SIZE - 1),
				clampi(ceili((box.end.y - base.y) / MASK_TEXEL), 0, MASK_SIZE - 1))
		for ty: int in range(lo.y, hi.y + 1):
			for tx: int in range(lo.x, hi.x + 1):
				var w := origin + Vector2((tx - 0.5) * MASK_TEXEL, (ty - 0.5) * MASK_TEXEL)
				var v := clampf(0.5 + _inside(op, w) / (MASK_TEXEL * 2.0), 0.0, 1.0)
				if v <= 0.0:
					continue
				var col := img.get_pixel(tx, ty)
				col[channel] = maxf(col[channel], v)
				img.set_pixel(tx, ty, col)
	return img


static func _op_box(op: Array) -> Rect2:
	match String(op[0]):
		"rect":
			return op[2]
		"circle":
			var r := float(op[3])
			return Rect2((op[2] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0)
		"line":
			var w := float(op[4])
			return Rect2(op[2], Vector2.ZERO).expand(op[3]).grow(w)
	return Rect2()


## Distância com sinal para dentro da forma (positiva dentro).
static func _inside(op: Array, p: Vector2) -> float:
	match String(op[0]):
		"rect":
			var r: Rect2 = op[2]
			var dx := minf(p.x - r.position.x, r.end.x - p.x)
			var dy := minf(p.y - r.position.y, r.end.y - p.y)
			return minf(dx, dy)
		"circle":
			return float(op[3]) - p.distance_to(op[2])
		"line":
			var a: Vector2 = op[2]
			var b: Vector2 = op[3]
			return float(op[4]) - p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
	return -1.0
