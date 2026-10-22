extends SceneTree
## 触控图标接线探针：实例化 touch_controls.tscn，断言三个按钮的 icon 已挂上且纹理非空。
## 不入树，_ready/UIFont 不参与；只验资源加载与属性接线。
## 用法：godot --headless --path <项目> --script res://scripts/dev/touch_icon_probe.gd

func _init() -> void:
	var ps: PackedScene = load("res://scenes/ui/touch_controls.tscn")
	if ps == null:
		printerr("FAIL: touch_controls.tscn 加载失败")
		quit(1)
		return
	var root := ps.instantiate()
	var found := 0
	for child in root.get_children():
		if child is TouchButton and child.icon != null:
			found += 1
			printerr("OK: %s action=%s icon=%dx%d" % [child.name, child.action,
					child.icon.get_width(), child.icon.get_height()])
	root.free()
	if found == 3:
		printerr("PASS: 3/3 图标就位")
		quit(0)
	else:
		printerr("FAIL: 仅 %d/3 图标就位" % found)
		quit(1)
