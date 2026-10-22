extends Node2D
## 珊瑚特效预览（临时）：暗场夜里三档爆蕗（基准/精英/BOSS 爆径，GroundBlast
## 按珊瑚链路关平涂爆闪）+ 珊瑚潮横涌，分时截图自退。同 touch_icons_preview
## 守则：godot --path . res://scenes/previews/coral_fx_preview.tscn
## 跑前后 tasklist 清残留 godot 进程，编辑器在线别跑。

const SHOT_DIR := "res://autotest_shots"
const BURST := preload("res://scenes/fx/coral_burst.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_run()


func _run() -> void:
	var _warm := CoralOrb.new() # 编译自检：珊瑚链路上游脚本（不入树，即建即毁）
	_warm.free()
	var powers := [1.0, 1.78, 2.0]
	for i in powers.size():
		var at := Vector2(350 + i * 700, 695)
		var blast := GroundBlast.new() # 珊瑚链路同款：平涂爆闪关，只剩判定（无视觉）
		blast.show_flash = false
		blast.radius = 90.0 * powers[i]
		add_child(blast)
		blast.position = at
		var burst := BURST.instantiate() as CoralBurst
		burst.power = powers[i]
		add_child(burst)
		burst.position = at
	await _wait(0.12)
	await _shot("coral_fx_burst_early.png")
	await _wait(0.1)
	await _shot("coral_fx_burst_peak.png")
	await _wait(0.25)
	await _shot("coral_fx_burst_late.png")
	var tide := CoralTide.new()
	add_child(tide)
	tide.launch(null, Vector2(2200, 580), -1.0) # terrain 仅签名占位，预览用不上
	await _wait(0.35)
	await _shot("coral_fx_tide_early.png")
	await _wait(0.55)
	await _shot("coral_fx_tide_late.png")
	get_tree().quit(0)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + "/" + file)
	printerr("shot ", file)
