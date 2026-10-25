extends RefCounted
## Clima dinâmico (scripts/core/weather_model.gd e scripts/systems/weather_system.gd):
## - ciclo determinístico: mesma semente → mesmo clima; semente diferente → outro ciclo; passa
##   por todos os estados; transições contínuas; dunas seguem a janela do ash_storm;
## - umidade sobe com a chuva e seca depois, e vira lama (mud_level); a lama da vila (superfície
##   "rain" do SurfaceField) cresce com ela; a lentidão em si é testada em surface_tests.gd;
## - partida: nó "Weather" na cena, globais de shader, relâmpago com clarão e trovão atrasado,
##   reduce_flashes suaviza, orçamentos por nível e troca ao vivo.
## Chamado por tests/integration_tests.gd.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	_test_data()
	_test_cycle()
	_test_wetness_and_mud()
	_test_dunes_sync()
	await _test_game()


func _test_data() -> void:
	var data := WeatherModel.data()
	var stages: Dictionary = data.get("stages", {})
	for id: StringName in DB.ids("stages"):
		_check.call(stages.has(String(id)), "clima: weather.json tem a fase %s" % id)
	for id: String in stages:
		_check.call(DB.stages.has(StringName(id)), "clima: fase %s do weather.json existe" % id)
		var p := WeatherModel.profile_for(id)
		_check.call(String(p["precip"]) in ["rain", "snow", "sand", "ash", "spirit"], "clima: %s precip válida" % id)


func _test_cycle() -> void:
	var a := WeatherModel.new("village", 42)
	var b := WeatherModel.new("village", 42)
	var c := WeatherModel.new("village", 43)
	var same := true
	var differs := false
	var seen: Dictionary = {}
	var t := 0.0
	var prev_wind := a.wind_strength_at(0.0)
	var max_jump := 0.0
	while t < 900.0:
		same = same and a.state_at(t) == b.state_at(t) and a.wind_vector_at(t) == b.wind_vector_at(t) \
				and a.rain_at(t) == b.rain_at(t) and a.wetness_at(t) == b.wetness_at(t)
		differs = differs or a.state_at(t) != c.state_at(t)
		seen[a.state_name_at(t)] = true
		var w := a.wind_strength_at(t)
		max_jump = maxf(max_jump, absf(w - prev_wind))
		prev_wind = w
		t += 0.5
	_check.call(same, "clima: mesma semente → mesmo clima (estado, vento, chuva, umidade)")
	_check.call(differs, "clima: outra semente → outro ciclo")
	_check.call(seen.size() == WeatherModel.STATE_NAMES.size(),
			"clima: 15 min passam por todos os estados (%s)" % [seen.keys()])
	_check.call(max_jump < 0.2, "clima: vento muda suave (maior salto %.3f em 0,5 s)" % max_jump)
	_check.call(a.state_at(0.0) == WeatherModel.State.CALM, "clima: partida começa na calmaria")
	# Ordem de consulta não muda o resultado (função pura): de trás para frente.
	var d := WeatherModel.new("village", 42)
	var back := true
	for k: int in range(20):
		var tt := 800.0 - k * 40.0
		back = back and d.state_at(tt) == a.state_at(tt) and is_equal_approx(d.wetness_at(tt), a.wetness_at(tt))
	_check.call(back, "clima: consultar fora de ordem dá o mesmo clima")
	var dir := a.wind_dir_at(123.0)
	_check.call(is_equal_approx(dir.length(), 1.0), "clima: wind_dir normalizado")
	var forced := WeatherModel.new("village", 42, {}, WeatherModel.State.STORM)
	_check.call(forced.state_name_at(5.0) == "storm" and forced.rain_at(5.0) > 0.9 and forced.wetness_at(0.0) >= 1.0,
			"clima: estado forçado (--weather=storm) já chove e molha")
	var strikes := forced.strikes_between(0.0, 60.0)
	_check.call(strikes.size() >= 3, "clima: tempestade da vila tem relâmpagos (%d em 60 s)" % strikes.size())
	_check.call(WeatherModel.new("temple", 1, {}, WeatherModel.State.STORM).strikes_between(0.0, 60.0).is_empty(),
			"clima: templo (neve) sem relâmpagos")


func _test_wetness_and_mud() -> void:
	var m := WeatherModel.new("village", 42)
	var t_storm := -1.0
	var t := 0.0
	while t < 900.0 and t_storm < 0.0:
		if m.state_at(t) == WeatherModel.State.STORM and m.state_at(t - 25.0) == WeatherModel.State.STORM:
			t_storm = t
		t += 1.0
	_check.call(t_storm > 0.0, "clima: há tempestade longa na partida")
	_check.call(m.wetness_at(5.0) == 0.0, "clima: chão seco no começo")
	_check.call(m.wetness_at(t_storm) > 0.7 and m.mud_level_at(t_storm) > 0.5,
			"clima: tempestade encharca e faz lama (umidade %.2f, lama %.2f)" % [m.wetness_at(t_storm), m.mud_level_at(t_storm)])
	var dry_t := t_storm
	while m.rain_at(dry_t) > 0.05:
		dry_t += 1.0
	_check.call(m.wetness_at(dry_t + 90.0) < m.wetness_at(dry_t), "clima: chão seca depois da chuva")
	_check.call(WeatherModel.new("temple", 42).wetness_at(t_storm) == 0.0, "clima: templo nunca molha")
	_check.call(WeatherModel.new("dunes", 42).mud_level_at(t_storm) == 0.0, "clima: dunas não encharcam")
	# A lama da vila (SurfaceField, "rain") cresce com a chuva e some no seco.
	var field := SurfaceField.new("village", 42, m)
	var mud := field.type_index("mud")
	var grown := 0
	var dry := 0
	for cy: int in range(-3, 4):
		for cx: int in range(-3, 4):
			for p: Dictionary in field.patches(Vector2i(cx, cy)):
				if int(p["type"]) == mud:
					grown += int(field.scale_of(p, t_storm) > 0.0)
					dry += int(field.scale_of(p, 3.0) > 0.0)
	_check.call(grown > 0 and dry == 0, "clima: lama cresce na tempestade (%d) e não existe no seco (%d)" % [grown, dry])


func _test_dunes_sync() -> void:
	var stage := DB.stage(&"dunes")
	var hazard: Dictionary = stage.get("hazard", {})
	var m := WeatherModel.new("dunes", 9, stage)
	var ok := true
	var interval := float(hazard.get("interval", 90))
	var duration := float(hazard.get("duration", 15))
	var t := 0.25
	while t < 400.0:
		var world_storm := fmod(t, interval) > interval - duration
		ok = ok and (m.state_at(t) == WeatherModel.State.STORM) == world_storm
		t += 0.5
	_check.call(ok, "clima: tempestade das dunas acompanha o ash_storm do mapa")


func _test_game() -> void:
	var saved_flash: Variant = Settings.get_value("reduce_flashes")
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 21, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	var weather := WeatherSystem.of(game)
	_check.call(weather != null, "clima: Game.tscn tem o nó Weather")
	if weather == null:
		game.queue_free()
		return
	game.player.god_mode = true
	weather.force_state("storm")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	_check.call(weather.state_name() == "storm" and weather.rain_amount() > 0.9 and weather.wetness() > 0.9,
			"clima: partida em tempestade forçada")
	_check.call(weather.wind_vector().length() > 0.3, "clima: vento forte na tempestade")
	# Sem tela (--headless) o RenderingServer é falso e não guarda os globais.
	var g_wet: Variant = RenderingServer.global_shader_parameter_get(&"wetness")
	if g_wet != null:
		_check.call(is_equal_approx(float(g_wet), weather.wetness()), "clima: global wetness do shader acompanha o sistema")
		var gdir: Vector2 = RenderingServer.global_shader_parameter_get(&"wind_dir")
		_check.call(gdir.is_equal_approx(weather.wind_dir()), "clima: global wind_dir acompanha o sistema")
	_check.call(ProjectSettings.has_setting("shader_globals/wind_dir") and ProjectSettings.has_setting(
			"shader_globals/wind_strength") and ProjectSettings.has_setting("shader_globals/wetness")
			and ProjectSettings.has_setting("shader_globals/weather_time"), "clima: globais declarados em project.godot")
	_check.call(weather.mud_level() > 0.9 and weather.surfaces != null and weather.surfaces.field != null,
			"clima: lama cheia na tempestade e superfícies montadas")
	# Relâmpago: clarão e trovão agendado.
	Settings.set_value("reduce_flashes", false)
	var sky := weather.sky()
	var flashes := sky.flash_count()
	var strike: Array = weather.model.strikes_between(0.0, 120.0)[0]
	GameClock.game_time = float(strike[0]) - 0.2
	await _host.get_tree().process_frame
	GameClock.game_time = float(strike[0]) + 0.05
	await _host.get_tree().process_frame
	_check.call(sky.flash_count() > flashes, "clima: relâmpago dispara o clarão")
	_check.call(weather.pending_thunders() > 0, "clima: trovão vem depois do clarão")
	_check.call(WeatherSky._flash_curve(0.07, false) > 0.9 and WeatherSky._flash_curve(0.07, true) < 0.25,
			"clima: reduce_flashes suaviza o clarão")
	var calm_peak := 0.0
	for k: int in range(60):
		calm_peak = maxf(calm_peak, WeatherSky._flash_curve(k * 0.02, true))
	_check.call(calm_peak <= 0.22, "clima: com reduce_flashes o clarão nunca passa de 0,22")
	# Orçamentos e troca ao vivo.
	for lv: int in [GfxQuality.LOW, GfxQuality.MEDIUM, GfxQuality.HIGH]:
		GfxQuality.set_override(lv)
		Settings.changed.emit(GfxQuality.changed_signal_key())
		await _host.get_tree().process_frame
		_check.call(sky.drop_capacity() == int(GfxQuality.budget_at("weather_drops", lv))
				and sky.layer_count() == int(GfxQuality.budget_at("weather_layers", lv)),
				"clima: nível %d usa %d gotas em %d camadas" % [lv, sky.drop_capacity(), sky.layer_count()])
		_check.call(sky.active_drops() > 0 and sky.active_drops() <= sky.drop_capacity(),
				"clima: gotas ativas no nível %d" % lv)
	GfxQuality.clear_override()
	Settings.changed.emit(GfxQuality.changed_signal_key())
	weather.force_state("")
	Settings.set_value("reduce_flashes", saved_flash)
	game.queue_free()
	await _host.get_tree().process_frame
	var g_wind: Variant = RenderingServer.global_shader_parameter_get(&"wind_strength")
	_check.call(g_wind == null or float(g_wind) == 0.0, "clima: fora da partida a grama fica quieta")
	GameClock.paused = false
