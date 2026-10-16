extends Node2D
## 临时验收卡：EyeGlow 独眼拉丝对位检查——小机型四枚上下两行（上原生朝左、
## 下翻转朝右）+ BOSS 原生/翻转各一。摆拍体冻结 _physics_process（AI/浮动停，
## EyeGlow 自己的 _process 照跑：镜像与脉动活着），隔 0.6s 截两张验脉动后退出。
## 跑法：godot --path . res://tools/eye_check.tscn（须带窗口，截图依赖渲染帧）

const SCENES := [
	preload("res://scenes/enemy.tscn"),
	preload("res://scenes/enemy_drone.tscn"),
	preload("res://scenes/enemy_shield.tscn"),
	preload("res://scenes/elite_mortar.tscn"),
]
const BOSS := preload("res://scenes/boss.tscn")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2(-400, -600)
	bg.size = Vector2(2200, 900)
	bg.color = Color(0.09, 0.09, 0.11)
	add_child(bg)
	for i in SCENES.size():
		_place(SCENES[i].instantiate(), Vector2(62.0 * i, 0.0), false)
		_place(SCENES[i].instantiate(), Vector2(62.0 * i, -70.0), true)
	_place(BOSS.instantiate(), Vector2(390.0, -50.0), false)
	_place(BOSS.instantiate(), Vector2(790.0, -190.0), true)
	var cam := Camera2D.new()
	cam.position = Vector2(455.0, -120.0)
	cam.zoom = Vector2(1.4, 1.4)
	add_child(cam)
	cam.make_current()
	_run()


func _place(inst: Node2D, pos: Vector2, flipped: bool) -> void:
	add_child(inst) # on_spawned 已跑（无人机抬升等），随后覆写定位
	inst.global_position = pos
	inst.set_physics_process(false)
	var sprite := inst.get_node("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.flip_h = flipped


func _run() -> void:
	for i in 2:
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				ProjectSettings.globalize_path("res://autotest_shots/_eye_check%d.png" % i))
	get_tree().quit()
