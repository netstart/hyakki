extends Node
## Roda os testes da Loja sozinhos (tests/shop_layout_tests.gd: layout e rolagem; e a Loja
## sem anúncios de tests/ads_off_tests.gd), com os autoloads e arquivos de save e opções
## próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/shop_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava capturas da Loja de verdade (App.tscn) em
## cada resolução de tests/device_profiles.gd, sem recorte e com o furo da câmera de cada lado
## (a faixa do recorte aparece escurecida), com e sem anúncios, em pt_BR, de e ru.

const ShopLayoutTests := preload("res://tests/shop_layout_tests.gd")
const AdsOffTests := preload("res://tests/ads_off_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const SHOT_LANGS: Array[String] = ["pt_BR", "de", "ru"]

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}


func _ready() -> void:
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	var shots := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	if shots != "":
		await _screenshots(shots)
	else:
		await ShopLayoutTests.new().run_layout(self, _check)
		await ShopLayoutTests.new().run_scroll(self, _check)
		await _ads_off()
	for path: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path: String in _real_files:
		var now := FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
		_check(now == _real_files[path], "testes não mexeram em %s do jogador" % path)
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Só a parte da Loja do modo sem anúncios (o resto roda na suíte de integração).
func _ads_off() -> void:
	var was_enabled := AdsManager.ads_enabled
	var was_fill := AdsManager.mock_fill
	var was_auto := AdsManager.auto_answer
	AdsManager.ads_enabled = false
	AdsManager.auto_answer = false
	AdsManager.mock_fill = false
	var tests := AdsOffTests.new()
	tests.set("_host", self)
	tests.set("_check", _check)
	await tests.call("_test_shop_screen")
	AdsManager.ads_enabled = was_enabled
	AdsManager.mock_fill = was_fill
	AdsManager.auto_answer = was_auto
	SaveManager.data = SaveManager.default_profile()


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


## Capturas: a Loja dentro do App (fundo e tema de verdade), com 12 840 ryō e um reforço guardado.
func _screenshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var native := get_window().size
	var was_enabled := AdsManager.ads_enabled
	var app := (load("res://scenes/app/App.tscn") as PackedScene).instantiate() as App
	add_child(app)
	await get_tree().process_frame
	for node: Node in app.find_children("*", "SplashScreen", true, false):
		node.get_parent().queue_free()
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.8)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	overlay.add_child(strip)
	add_child(overlay)
	for res: Dictionary in DeviceProfiles.shot_resolutions():
		var view: Vector2 = await DeviceProfiles.set_window_view(self, res["view"])
		var c := DeviceProfiles.cutout_logical(res)
		for insets: Vector2 in [Vector2.ZERO, Vector2(c, 0.0), Vector2(0.0, c)]:
			DeviceProfiles.simulate_insets(insets)
			strip.visible = insets != Vector2.ZERO
			strip.position = Vector2(0.0 if insets.x > 0.0 else view.x - insets.y, 0.0)
			strip.size = Vector2(maxf(insets.x, insets.y), view.y)
			var side := "none" if insets == Vector2.ZERO else ("left" if insets.x > 0.0 else "right")
			for ads: bool in [true, false]:
				AdsManager.ads_enabled = ads
				for lang: String in SHOT_LANGS:
					Locale.set_language(lang, false)
					SaveManager.data = SaveManager.default_profile()
					SaveManager.data["ryo"] = 12840
					ShopManager.buy_coin(&"coin_bag")
					app.go(&"shop")
					var screen := app.get("_screens")[&"shop"] as Control
					screen.call("on_show")
					await get_tree().create_timer(0.4).timeout
					await _shot(dir, "shop_%s_%dx%d_%s_%s" % [lang, view.x, view.y, side, "ads" if ads else "noads"])
					if ads and lang == "pt_BR":
						var scroll := screen.get("_scroll") as ScrollContainer
						scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
						await get_tree().create_timer(0.2).timeout
						await _shot(dir, "shop_%s_%dx%d_%s_ads_end" % [lang, view.x, view.y, side])
						scroll.scroll_vertical = 0
	DeviceProfiles.clear_insets()
	AdsManager.ads_enabled = was_enabled
	app.queue_free()
	DisplayServer.window_set_size(native)
	Locale.set_language("pt_BR", false)


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: " + path)
