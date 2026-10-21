extends Node2D

## BOSS 场景探针（场景启动版，autoload 齐全 → boss.gd/threat_flash.gd 真编译）：
## 实例化 boss_ch1.tscn，验证导弹仓口/预警/旋翼节点齐全，再直接调一次出弹节拍
## 看导弹是否真从仓口出。用法：
##   godot --headless --path <项目> res://art_proposals/mech/work/boss_heli/probe_boss.tscn

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/units/boss_1.tscn")
	assert(ps != null, "boss_ch1.tscn 载入失败")
	var boss := ps.instantiate()
	add_child(boss) # 触发 _ready/@onready：缺节点/脚本编译失败这里就炸
	var ok := true
	for p in ["MissilePorts", "MissilePorts/Port1", "MissilePorts/Port2",
			"MissilePorts/Port3", "MissilePorts/Port4", "MissileWarn/ThreatFlash",
			"Rotor", "TailRotor", "ArmPivot/Muzzle/ThreatFlash", "Sprite2D/EyeGlow"]:
		if boss.get_node_or_null(p) == null:
			push_error("缺节点 " + p)
			ok = false
	var ports: Node2D = boss.get_node_or_null("MissilePorts")
	if ports != null and ports.get_child_count() != 4:
		push_error("仓口数 != 4（应与 BOSS_RAIN_COUNT 1:1）")
		ok = false
	# 旋翼动画字段直读（Balance 常量挂进 boss.gd 才算接线完成）
	assert(Balance.BOSS_ROTOR_SPIN > 0.0 and Balance.BOSS_ROTOR_WOBBLE > 0.0)
	print("PROBE %s ports=%s" % ["OK" if ok else "FAIL",
			str(ports.get_child_count()) if ports != null else "?"])
	get_tree().quit(0 if ok else 1)
