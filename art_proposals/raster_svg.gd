extends SceneTree

## 通用探针：把 SVG 光栅成 PNG（与 Godot 引擎同源渲染），供美术自验与提案评审。
## 用法：godot --headless --path <项目> --script res://tests/raster_svg.gd -- <in.svg> <out.png> [scale]
## 注：Godot 4.x 的 Image.load_svg_from_string 须实例调用（静态调用直接 parse error）。
## 来源：svg-game-art skill；原版 Space_War_Ship/tests/probe_svg_raster.gd。


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("用法: -- <in.svg> <out.png> [scale]")
		quit(1)
		return
	var in_path: String = args[0]
	var out_path: String = args[1]
	var scale: float = 8.0
	if args.size() > 2:
		scale = float(args[2])
	var f := FileAccess.open(in_path, FileAccess.READ)
	if f == null:
		push_error("读不到 " + in_path)
		quit(1)
		return
	var svg_text := f.get_as_text()
	f.close()
	var img: Image = Image.new()
	img.load_svg_from_string(svg_text, scale)
	if img.is_empty():
		push_error("SVG 解析失败: " + in_path)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var err: Error = img.save_png(out_path)
	if err != OK:
		push_error("存 PNG 失败 %s (err=%d)" % [out_path, err])
		quit(1)
		return
	print("OK %s -> %s (%dx%d)" % [in_path.get_file(), out_path, img.get_width(), img.get_height()])
	quit(0)
