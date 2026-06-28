extends SceneTree

# Chroma-key: убирает магента-фон (#FF00FF) в прозрачность, затем обрезает по спрайту.
# Запуск: godot --headless --script res://tools/trim_png.gd -- <src.png> <dst.png>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: trim_png.gd -- <src> <dst>"); quit(1); return
	var src: String = args[0]
	var dst: String = args[1]
	var img := Image.load_from_file(src)
	if img == null:
		push_error("cannot load " + src); quit(1); return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	# 1) Магента-пиксели -> прозрачные (R высокий, B высокий, G низкий).
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.g < 0.45 and c.r - c.g > 0.22 and c.b - c.g > 0.22:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	# 2) bbox по непрозрачным.
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.0:
				minx = min(minx, x); maxx = max(maxx, x)
				miny = min(miny, y); maxy = max(maxy, y)
	if maxx < minx:
		push_error("empty after keying"); quit(1); return
	var rect := Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
	print("src ", img.get_size(), " bbox ", rect)
	var cropped := img.get_region(rect)
	cropped.save_png(dst)
	print("saved ", dst, " ", cropped.get_size(), " aspect ", float(cropped.get_size().x) / float(cropped.get_size().y))
	quit(0)
