extends Node2D

## 爆炸层级探针：按 heavy_missile 引爆顺序生成 GroundBlast+ExplosionBurst，
## 验证脚本编译与入树序（闪光垫底）。用法：
##   godot --headless --path <项目> res://art_proposals/mech/work/boss_heli/probe_blast.tscn

func _fail(msg: String) -> void:
	push_error(msg)
	get_tree().quit(1)

func _ready() -> void:
	for p in ["res://scripts/heavy_missile.gd", "res://scripts/ground_blast.gd",
			"res://scripts/flash_burst.gd"]:
		var s: Script = load(p)
		if s == null or not s.can_instantiate():
			return _fail("脚本编译失败 " + p)
	# 按 _detonate 同序生成一次，跑几帧看有没有运行时报错
	var container := Node2D.new()
	container.add_to_group("projectile_container")
	add_child(container)
	var blast := GroundBlast.new()
	blast.damage = 10
	blast.radius = 70.0
	container.add_child(blast)
	blast.global_position = Vector2(0, 0)
	blast.reset_physics_interpolation()
	var boom: Node2D = (load("res://scenes/explosion_burst.tscn") as PackedScene).instantiate()
	boom.scale = Vector2(1.5, 1.5)
	container.add_child(boom)
	if container.get_children().find(blast) > container.get_children().find(boom):
		return _fail("爆区闪光没垫底")
	for i in 30:
		await get_tree().process_frame
	print("PROBE OK order=blast<boom")
	get_tree().quit(0)
