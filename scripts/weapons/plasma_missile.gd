class_name PlasmaMissile
extends HeavyMissile
## 电浆导弹（第三章白鲸「电浆弹雨」）：HeavyMissile 的纯视觉换皮——追踪/伤害
## 语法一字不改（抛体滑行→按时长开机→比例导引→锁死扎地→球状爆），只换外观：
##   弹体=SVG 矢弹（missile_plasma.svg，+X 弹头随弹体轴转，同 MortarShell 惯例，
##   顶掉父类的 _draw 平涂占位）；尾迹=电光粒子（missile_plasma_trail.tscn：
##   白热芯光晕+电弧），出膛即亮——电浆没有"点火"概念，不复用父类拉烟的
##   开机时机（_coast 找不到 _smoke/_flame，开机分支安全跳过）；
##   爆=电浆爆闪（plasma_burst.tscn）+ GroundBlast（爆区闪染冰蓝，伤害判定同源）。
## 规约出处：提案_v2 §1「基本还是导弹，相当于换皮」（本项目无能量伤害模型）；
## fx 规约：全贴图+粒子，无程序化 _draw。数值全在 BalanceWorld3.SENTINEL_RAIN_*。

const BODY_TEXTURE := preload("res://assets/world_3/missile_plasma.svg")
const TRAIL := preload("res://scenes/fx/missile_plasma_trail.tscn")
const BURST := preload("res://scenes/fx/plasma_burst.tscn")

const FLASH_COLOR := Color(0.5, 0.8, 1.0, 0.55) # 电浆爆区冰蓝（对比现役橙红）

var _trail: Node2D


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = BODY_TEXTURE
	add_child(sprite)
	_trail = TRAIL.instantiate()
	_trail.position = Vector2(-14.0, 0.0) # 弹尾（随弹体转向，永远在速度反侧）
	add_child(_trail)


## 弹体交给 SVG 精灵；父类 _physics_process 的 queue_redraw() 照跑，空绘制无害。
func _draw() -> void:
	pass


func _detonate() -> void:
	var surface := _terrain.surface_y_at(global_position.x)
	var at := Vector2(global_position.x, surface) # 爆心贴地（弹体已略入地，拉回表面）
	var container := get_tree().get_first_node_in_group("projectile_container")
	if _trail != null:
		for p in _trail.get_children():
			if p is GPUParticles2D:
				(p as GPUParticles2D).emitting = false
		if container != null:
			_trail.reparent(container) # 过继弹容器让残余电光淡完再清（同拉烟收尾惯例）
			get_tree().create_timer(0.8).timeout.connect(_trail.queue_free)
	if container != null:
		var blast := GroundBlast.new()
		blast.damage = damage
		blast.radius = blast_radius
		blast.flash_color = FLASH_COLOR
		container.add_child(blast)
		blast.global_position = at
		blast.reset_physics_interpolation()
		var burst := BURST.instantiate() as Node2D
		burst.position = at + Vector2(0.0, -14.0) # 容器在原点，position 即全局位
		container.add_child(burst)
	Sfx.play(&"boom_enemy")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 1.5)
	queue_free()
