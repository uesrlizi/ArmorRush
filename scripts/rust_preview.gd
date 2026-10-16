extends Node2D
## 锈雨皮肤预览（临时）：加载主场景，手动摆三块断桥平台，单帧截图自退。
## godot --path . res://scenes/rust_preview.tscn
## 注意：Godot 窗口进程紧邻重启可能卡在首帧（驱动交换链），重跑前 taskkill 残留进程。

func _ready() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var spawner: Spawner = main.get_node("Spawner")
	for dx: float in [500.0, 1100.0, 1700.0]:
		spawner._spawn(spawner.scaffold_scene, false, 200.0 + dx)
	_shoot()


func _shoot() -> void:
	for i in 50:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://autotest_shots/rust_preview.png"))
	# 排查：枚举滚动层与桥墩层的对象
	for layer_name in ["ScrollObjects", "BridgePiers"]:
		var layer := get_tree().root.find_child(layer_name, true, false)
		if layer == null:
			continue
		for child in layer.get_children():
			print("[inv] %s | %s pos=%s scale=%s z=%d tex=%s" % [
				layer_name, child.get_class(), child.global_position, child.scale,
				child.z_index, child.get("texture") if child.get("texture") != null else "-"])
	print("[rust_preview] saved")
	get_tree().quit()
