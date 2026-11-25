extends Node2D
## 探针：八台 BOSS 火箭焰终案实机检查（窗口自退，2026-11-11 八/九轮验收）。
## 断言：①八场景可实例化；②Thruster centered=false+offset(-20,-6)（原点=焰根）
## +脚本贴图在挂+enabled/visible（boss_5 平时熄火）；③boss_5 冲撞前摇点火/拉起
## 熄火；④随速拉长（甩开锚点让 spring 给速度后 scale.y 涨）；⑤逐台截图目检
## 焰根咬合。跑法：godot --log-file probe_thrust.log
## res://scenes/previews/probe_boss_thrust.tscn （带窗，无头=没渲染帧）

const BOSSES := {
	2: "res://scenes/units/boss_2.tscn",
	3: "res://scenes/units/boss_3.tscn",
	5: "res://scenes/units/boss_5.tscn",
	6: "res://scenes/units/boss_6.tscn",
	7: "res://scenes/units/boss_7.tscn",
	8: "res://scenes/units/boss_8.tscn",
	9: "res://scenes/units/boss_9.tscn",
	10: "res://scenes/units/boss_10.tscn",
}
const SHOT_DIR := "res://art_proposals/boss_forms/raster_check"

var _fails := 0


func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(_timeout)
	_run()


func _timeout() -> void:
	printerr("[probe_thrust] TIMEOUT 30s 强制退出")
	get_tree().quit(1)


func _chk(cond: bool, tag: String) -> void:
	if cond:
		printerr("[probe_thrust] OK   " + tag)
	else:
		_fails += 1
		printerr("[probe_thrust] FAIL " + tag)


func _run() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	add_child(cam)
	cam.make_current()
	for ch in BOSSES:
		await _one(ch, BOSSES[ch], cam)
	printerr("[probe_thrust] SUMMARY fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _one(ch: int, path: String, cam: Camera2D) -> void:
	var packed = load(path)
	_chk(packed != null, "ch%d 场景加载" % ch)
	if packed == null:
		return
	var boss = packed.instantiate()
	_chk(boss != null, "ch%d 实例化" % ch)
	if boss == null:
		return
	add_child(boss)
	boss.position = Vector2(400, 170)
	cam.position = boss.position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var visuals = boss.get_node_or_null("Visuals")
	var thrusters: Array = []
	if visuals != null:
		thrusters = visuals.find_children("Thruster*", "Sprite2D", false, false)
	_chk(thrusters.size() == 2, "ch%d 双推进焰节点 (实际 %d)" % [ch, thrusters.size()])
	var flame0: Sprite2D = null
	if thrusters.size() >= 1:
		flame0 = thrusters[0]
	for t in thrusters:
		var s := t as Sprite2D
		_chk(s != null and s.centered == false and s.offset == Vector2(-20, -6),
				"ch%d %s 原点=焰根 (centered/offset)" % [ch, s.name if s else "?"])
		_chk(s != null and s.texture != null and s.get_script() != null,
				"ch%d %s 脚本+贴图在挂" % [ch, s.name if s else "?"])
	if flame0 == null:
		boss.queue_free()
		await get_tree().process_frame
		return
	if ch == 5:
		# 截击机：平时熄火 → 冲撞前摇点火 → 拉起熄火
		_chk(flame0.enabled == false and flame0.visible == false,
				"ch5 平时熄火 enabled=false/visible=false")
		await _shot(ch, "cold")
		boss._begin_skill_b()
		await get_tree().physics_frame
		await get_tree().physics_frame
		_chk(flame0.visible == true, "ch5 前摇点火 visible=true")
		await _shot(ch, "dash")
		boss._end_dive()
		await get_tree().physics_frame
		_chk(flame0.visible == false, "ch5 拉起熄火 visible=false")
	else:
		_chk(flame0.enabled == true and flame0.visible == true,
				"ch%d 常燃 enabled/visible" % ch)
		# 随速拉长：甩开锚点让 spring 给速度。判据按当时实际速度条件化——
		# 慢速 strafe 的 BOSS（驳船/斗轮机等）甩不开 260px/s，不该硬 FAIL
		var base_y: float = flame0.scale.y
		boss.position.x -= 280.0
		cam.position = boss.position
		for i in range(8):
			await get_tree().physics_frame
		var sy: float = flame0.scale.y
		var v: float = (boss.velocity as Vector2).length()
		if v > 260.0:
			_chk(sy > base_y * 1.2,
					"ch%d 随速拉长 (v=%.0f) scale.y %.2f→%.2f" % [ch, v, base_y, sy])
		else:
			printerr("[probe_thrust] INFO ch%d 慢速 strafe v=%.0f scale.y %.2f（拉长不触发，语义正确）"
					% [ch, v, sy])
		await _shot(ch, "")
	boss.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _shot(ch: int, tag: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var shot := "ingame_boss_%d" % ch
	if tag != "":
		shot += "_%s" % tag
	var err := img.save_png(SHOT_DIR + "/" + shot + ".png")
	printerr("[probe_thrust] shot %s err=%d" % [shot, err])
