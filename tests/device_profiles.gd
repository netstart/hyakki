extends RefCounted
## Resoluções-alvo dos testes de layout (fonte única; ver "Resoluções-alvo" no AGENTS.md). A
## regra de qualidade é por RESOLUÇÃO LÓGICA, não por aparelho: o PixelScaler usa
## k = round(altura / 300) e stretch "viewport", então lógico = físico / k. Os aparelhos ficam
## só como exemplo no comentário de cada linha.
##
## Toda tela, painel e HUD percorre layout_cases(): cada resolução sem recorte (todos os
## idiomas) e com a área segura de um furo de câmera à esquerda e à direita (MenuKit.test_insets).
## Em paisagem o furo vai para um lado curto; com o modo imersivo o Godot desenha por baixo dele e
## a área segura do Android desconta a faixa (~ altura da barra de status em retrato), em pixels
## físicos no campo "cutout".

const RESOLUTIONS: Array[Dictionary] = [
	# 2712x1220 (20:9), ×4. Ex.: Redmi Note 14 Pro+ 5G.
	{"label": "678x305", "view": Vector2(678, 305), "physical": Vector2i(2712, 1220), "scale": 4, "cutout": 120.0},
	# 2400x1080 (20:9), ×4. Ex.: Samsung Galaxy M55 5G (SM-M556B), Google Pixel 7.
	{"label": "600x270", "view": Vector2(600, 270), "physical": Vector2i(2400, 1080), "scale": 4, "cutout": 118.0},
	# 2340x1080 (19.5:9), ×4. Ex.: Samsung Galaxy A15 / A15 5G, Samsung Galaxy A56 5G, Xiaomi POCO M3,
	# Samsung Galaxy S24 Ultra / S25 Ultra em FHD+ (padrão de fábrica).
	{"label": "585x270", "view": Vector2(585, 270), "physical": Vector2i(2340, 1080), "scale": 4, "cutout": 110.0},
	# 3120x1440 (19.5:9), ×5. Ex.: Samsung Galaxy S24 Ultra / S25 Ultra em QHD+ (resolução nativa).
	{"label": "624x288", "view": Vector2(624, 288), "physical": Vector2i(3120, 1440), "scale": 5, "cutout": 160.0},
	# 1560x720 (19.5:9), ×2. Ex.: Samsung Galaxy S24 Ultra / S25 Ultra em HD+ (opção de economia de bateria).
	{"label": "780x360", "view": Vector2(780, 360), "physical": Vector2i(1560, 720), "scale": 2, "cutout": 80.0},
	# 1920x1080 (16:9), ×4. Ex.: telas 16:9 / desktop.
	{"label": "480x270", "view": Vector2(480, 270), "physical": Vector2i(1920, 1080), "scale": 4, "cutout": 118.0},
]
## Idiomas dos casos com recorte (os mais longos e o padrão), para o tempo da suíte não
## triplicar; sem recorte, cada resolução roda em todos os idiomas.
const INSET_LANGS: Array[String] = ["pt_BR", "de", "ru"]


## Fator inteiro do PixelScaler para uma altura física.
static func scale_for(physical: Vector2i) -> int:
	return maxi(1, roundi(physical.y / 300.0))


## Tela lógica que o PixelScaler dá para um tamanho físico.
static func logical_for(physical: Vector2i) -> Vector2:
	var k := scale_for(physical)
	return Vector2(floorf(float(physical.x) / k), floorf(float(physical.y) / k))


## Faixa do recorte em pixels lógicos.
static func cutout_logical(res: Dictionary) -> float:
	return float(res["cutout"]) / int(res["scale"])


## Telas lógicas da lista, na ordem (a primeira é a de referência, 678x305).
static func views() -> Array[Vector2]:
	var list: Array[Vector2] = []
	for r: Dictionary in RESOLUTIONS:
		list.append(r["view"])
	return list


## Tela de referência (os testes de comportamento rodam nela).
static func main_view() -> Vector2:
	return RESOLUTIONS[0]["view"]


## Casos de layout: {label, view, insets (esquerda, direita), langs}. Para cada resolução:
## sem recorte (todos os idiomas), câmera à esquerda e câmera à direita (INSET_LANGS).
static func layout_cases() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for r: Dictionary in RESOLUTIONS:
		list.append({"label": r["label"], "view": r["view"], "insets": Vector2.ZERO, "langs": Locale.SUPPORTED})
	for r: Dictionary in RESOLUTIONS:
		var c := cutout_logical(r)
		list.append({"label": "%s câmera à esquerda (%.1f)" % [r["label"], c], "view": r["view"],
				"insets": Vector2(c, 0.0), "langs": INSET_LANGS})
		list.append({"label": "%s câmera à direita (%.1f)" % [r["label"], c], "view": r["view"],
				"insets": Vector2(0.0, c), "langs": INSET_LANGS})
	return list


## Área segura (onde ficam textos e botões) de uma tela lógica com o recorte dado.
static func safe_rect(view: Vector2, insets: Vector2) -> Rect2:
	return Rect2(insets.x, 0.0, view.x - insets.x - insets.y, view.y)


## Liga a área segura simulada (vale para MenuKit.safe_insets e os painéis que o usam).
## Avisa na hora as telas abertas (PixelScaler.safe_insets_changed), como o giro de 180°.
static func simulate_insets(insets: Vector2) -> void:
	MenuKit.set_test_insets(insets)


static func clear_insets() -> void:
	MenuKit.set_test_insets(Vector2.ZERO)


## Capturas (--shots, sem --headless): janela 2x da tela lógica (k = 2 no PixelScaler, que
## dá a mesma tela lógica). Devolve a tela lógica aplicada.
static func set_window_view(host: Node, view: Vector2) -> Vector2:
	DisplayServer.window_set_size(Vector2i(view) * 2)
	await host.get_tree().create_timer(0.3).timeout
	host.get_tree().root.get_node(^"PixelScaler").call("_apply")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return Vector2(host.get_tree().root.content_scale_size)


## Confere a tabela contra o PixelScaler de verdade: põe o tamanho físico na raiz, chama o
## _apply dele e lê o content_scale_size; depois restaura a raiz.
static func check_scaler(host: Node, check: Callable) -> void:
	var root := host.get_tree().root
	var scaler := root.get_node_or_null(^"PixelScaler")
	check.call(scaler != null, "Resoluções: PixelScaler carregado")
	if scaler == null:
		return
	var size := root.size
	var css := root.content_scale_size
	var mode := root.content_scale_mode
	var aspect := root.content_scale_aspect
	var factor: int = scaler.get("scale_factor")
	for r: Dictionary in RESOLUTIONS:
		root.size = r["physical"]
		scaler.call("_apply")
		check.call(Vector2(root.content_scale_size) == r["view"] and logical_for(r["physical"]) == r["view"]
				and int(scaler.get("scale_factor")) == int(r["scale"]),
				"Resoluções: %s físico dá %s lógico (×%d; obtido %s ×%d)" % [r["physical"], r["label"], r["scale"],
				root.content_scale_size, scaler.get("scale_factor")])
		var c := cutout_logical(r)
		check.call(c >= 20.0 and c <= 40.0, "Resoluções: recorte de %s com %.1f pontos lógicos" % [r["label"], c])
	root.size = size
	root.content_scale_size = css
	root.content_scale_mode = mode
	root.content_scale_aspect = aspect
	scaler.set("scale_factor", factor)
