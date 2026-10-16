extends Node2D
## P1 雾层实装验证(临时):加载主场景(AerialFog 已接线),摆断桥+敌人,截图自退。
## godot --path . res://scenes/fog_check_preview.tscn
## 窗口进程可能卡首帧:卡住就 taskkill + sleep 后重跑。

func _ready() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	(main.get_node("HUD") as CanvasLayer).visible = false
	var spawner: Spawner = main.get_node("Spawner")
	for dx in [500.0, 1100.0, 1700.0]:
		spawner._spawn(spawner.scaffold_scene, false, 200.0 + dx)
	spawner.debug_spawn_enemy(1180.0)
	spawner.debug_spawn_enemy(1900.0)
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://autotest_shots/fog_check.png"))
	print("[fog_check] saved")
	get_tree().quit()
