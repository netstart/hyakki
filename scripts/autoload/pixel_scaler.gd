extends Node
## Escala inteira da tela (plano 8.2): k = round(altura / 300).
## No Redmi (2712×1220) dá k = 4 e 678×305 pixels lógicos, nítidos.

const TARGET_HEIGHT := 300.0

var scale_factor: int = 1


func _ready() -> void:
	get_tree().root.size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var root := get_tree().root
	var window_size := root.size
	if window_size.y <= 0:
		return
	scale_factor = maxi(1, roundi(window_size.y / TARGET_HEIGHT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(
		floori(float(window_size.x) / scale_factor),
		floori(float(window_size.y) / scale_factor)
	)
