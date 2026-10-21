extends Node
## Idiomas (plano 7.7): lê i18n/strings.csv em tempo de execução e registra uma
## Translation por idioma no TranslationServer. Também escolhe a variante regional
## da Fusion Pixel Font, porque os ideogramas têm desenho diferente em ja/ko/zh.

signal language_changed(code: String)

const CSV_PATH := "res://i18n/strings.csv"
const SUPPORTED: Array[String] = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko",
		"zh_TW", "zh_CN"]
const NATIVE_NAMES := {
	"pt_BR": "Português (Brasil)", "en": "English", "es": "Español", "de": "Deutsch",
	"fr": "Français", "ru": "Русский", "id": "Bahasa Indonesia", "ja": "日本語",
	"ko": "한국어", "zh_TW": "繁體中文", "zh_CN": "简体中文",
}
const FONT_FILES := {
	"ja": "res://assets/fonts/fusion_pixel_12_ja.woff2",
	"ko": "res://assets/fonts/fusion_pixel_12_ko.woff2",
	"zh_TW": "res://assets/fonts/fusion_pixel_12_zh_tw.woff2",
	"zh_CN": "res://assets/fonts/fusion_pixel_12_zh_hans.woff2",
}
const DEFAULT_FONT := "res://assets/fonts/fusion_pixel_12_latin.woff2"

var current: String = "en"
var font: Font
var keys: PackedStringArray = []
## Texto por idioma: { "en": { chave: texto } }, usado pelos testes de cobertura.
var table: Dictionary = {}

var _translations: Dictionary = {}
var _fonts: Dictionary = {}


func _ready() -> void:
	_load_csv()
	var chosen := String(Settings.get_value("language"))
	if chosen.is_empty() or not SUPPORTED.has(chosen):
		chosen = detect_system_language()
	set_language(chosen, false)


## Primeira abertura: usa o idioma do aparelho; se não houver suporte, inglês (plano 7.7.1).
func detect_system_language() -> String:
	var system := OS.get_locale()
	if SUPPORTED.has(system):
		return system
	var lang := OS.get_locale_language()
	if lang == "pt":
		return "pt_BR"
	if lang == "zh":
		return "zh_TW" if system.contains("TW") or system.contains("HK") or system.contains("Hant") else "zh_CN"
	if SUPPORTED.has(lang):
		return lang
	return "en"


func set_language(code: String, persist: bool = true) -> void:
	if not SUPPORTED.has(code):
		code = "en"
	current = code
	TranslationServer.set_locale(code)
	font = _font_for(code)
	if persist:
		Settings.set_value("language", code)
	language_changed.emit(code)


func text(key: String, lang: String = "") -> String:
	var lang_table: Dictionary = table.get(lang if not lang.is_empty() else current, {})
	return String(lang_table.get(key, key))


## Formata números com o separador de milhar do idioma (plano 7.7.1).
func format_number(value: int) -> String:
	var digits := str(absi(value))
	var sep := ","
	match current:
		"pt_BR", "es", "de", "id":
			sep = "."
		"fr", "ru":
			sep = " "
	var out := ""
	var count := 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = sep + out
	return ("-" if value < 0 else "") + out


func _font_for(code: String) -> Font:
	var path: String = FONT_FILES.get(code, DEFAULT_FONT)
	if _fonts.has(path):
		return _fonts[path]
	# Pelo ResourceLoader: no APK só existe a fonte importada, não o .woff2 bruto.
	var file := load(path) as FontFile
	if file == null:
		push_error("Locale: fonte não carregou: " + path)
		return ThemeDB.fallback_font
	file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	file.hinting = TextServer.HINTING_NONE
	file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	file.generate_mipmaps = false
	_fonts[path] = file
	return file


func _load_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("Locale: não abriu " + CSV_PATH)
		return
	var header := file.get_csv_line()
	var columns: Dictionary = {}
	for i: int in range(header.size()):
		columns[header[i]] = i
	for code: String in SUPPORTED:
		var translation := Translation.new()
		translation.locale = code
		_translations[code] = translation
		table[code] = {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].is_empty() or row[0].begins_with("#"):
			continue
		var key := row[0]
		keys.append(key)
		for code: String in SUPPORTED:
			var index: int = columns.get(code, -1)
			var value := ""
			if index >= 0 and index < row.size():
				value = row[index]
			if value.is_empty() and columns.has("en") and int(columns["en"]) < row.size():
				value = row[int(columns["en"])]
			value = value.replace("\\n", "\n")
			(_translations[code] as Translation).add_message(key, value)
			(table[code] as Dictionary)[key] = value
	for code: String in SUPPORTED:
		TranslationServer.add_translation(_translations[code])
