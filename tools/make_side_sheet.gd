extends SceneTree
## Monta a folha "side" de um herói desenhado de lado (ex.: Merakintsugi), reduzida para a
## escala do jogo. Uso:
##   godot --headless --path . --script res://tools/make_side_sheet.gd -- \
##       IDLE.png IDLE_W IDLE_H WALK.png WALK_W WALK_H WALK_COLS ESCALA SAIDA_DIR
## Saída: SAIDA_DIR/SpriteSheet.png (linha 0 = parado, linha 1 = andando; quadros do mesmo
## tamanho, alinhados pelos pés) e SAIDA_DIR/Faceset.png (rosto recortado do 1º quadro).
## A redução é feita com média (bilinear em fator 1/2) e o alfa volta a ser 0/1 para manter
## as bordas nítidas do pixel art.


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 9:
		printerr("argumentos insuficientes")
		quit(1)
		return
	var idle := _frames(a[0], int(a[1]), int(a[2]), 0)
	var walk := _frames(a[3], int(a[4]), int(a[5]), int(a[6]))
	var scale := float(a[7])
	var out_dir := a[8]
	var cell := Vector2i(maxi(int(a[1]), int(a[4])), maxi(int(a[2]), int(a[5])))
	var cols := maxi(idle.size(), walk.size())
	var sheet := Image.create_empty(cell.x * cols, cell.y * 2, false, Image.FORMAT_RGBA8)
	for row: int in range(2):
		var list: Array[Image] = idle if row == 0 else walk
		for i: int in range(list.size()):
			var f := list[i]
			# Alinha pelos pés (base) e centraliza na horizontal.
			var at := Vector2i(i * cell.x + (cell.x - f.get_width()) / 2, row * cell.y + cell.y - f.get_height())
			sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), at)
	var target := Vector2i(roundi(sheet.get_width() * scale), roundi(sheet.get_height() * scale))
	sheet.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)
	_crisp_alpha(sheet)
	DirAccess.make_dir_recursive_absolute(out_dir)
	sheet.save_png(out_dir.path_join("SpriteSheet.png"))
	var face := idle[0].get_region(Rect2i(8, 2, 30, 30))
	face.resize(60, 60, Image.INTERPOLATE_NEAREST)
	face.save_png(out_dir.path_join("Faceset.png"))
	print("quadro: %s  colunas: %d  folha: %s" % [Vector2(cell) * scale, cols, target])
	quit(0)


func _frames(path: String, w: int, h: int, cols: int) -> Array[Image]:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	var list: Array[Image] = []
	var per_row := cols if cols > 0 else img.get_width() / w
	var rows := img.get_height() / h
	for r: int in range(rows):
		for c: int in range(per_row):
			var f := img.get_region(Rect2i(c * w, r * h, w, h))
			if not f.is_invisible():
				list.append(f)
	return list


func _crisp_alpha(img: Image) -> void:
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a < 0.45:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.a < 1.0:
				img.set_pixel(x, y, Color(c.r / c.a, c.g / c.a, c.b / c.a, 1.0).clamp())
