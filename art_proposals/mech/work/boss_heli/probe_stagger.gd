extends Node2D

## 失衡歪斜探针：验证 0.1s 到顶 / 0.2s 保持 / 0.7s 回正（共 1.0s）。
## 用法：godot --headless --path <项目> res://art_proposals/mech/work/boss_heli/probe_stagger.tscn

func _fail(msg: String) -> void:
	push_error(msg)
	get_tree().quit(1)

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/units/elite_1.tscn")
	if ps == null:
		return _fail("elite_mortar_ch1.tscn 载入失败")
	var enemy := ps.instantiate()
	add_child(enemy)
	enemy.on_spawned()
	await get_tree().physics_frame
	var sprite: Sprite2D = enemy.get_node("Sprite2D")
	enemy.add_impact(999.0)
	if not enemy.is_staggered():
		return _fail("add_impact 没触发失衡")
	var peak := 0.0
	var hold_rot := 0.0
	var rest_rot := 0.0
	for i in 64: # 全程 1.0s=60 物理帧 + 余量
		await get_tree().physics_frame
		peak = maxf(peak, absf(sprite.rotation))
		if i == 12: # 0.2s 处：位于歪顶保持段（0.1..0.3s）
			hold_rot = absf(sprite.rotation)
		if i == 62:
			rest_rot = absf(sprite.rotation)
	print("peak=%.4f hold@0.2s=%.4f rest=%.4f" % [peak, hold_rot, rest_rot])
	if peak < 0.18:
		return _fail("幅度不对 peak=%.4f" % peak)
	if absf(hold_rot - 0.2) > 0.02:
		return _fail("歪顶保持段没稳住 hold=%.4f" % hold_rot)
	if rest_rot > 0.01:
		return _fail("没回正 rest=%.4f" % rest_rot)
	print("PROBE OK")
	get_tree().quit(0)
