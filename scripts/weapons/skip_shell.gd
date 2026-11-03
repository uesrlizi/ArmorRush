class_name SkipShell
extends Node2D
## 跳弹（第七章精英「岸炮」/BOSS「沉锚」共用重击弹）：**平抛发射→连跳弹道**
## ——出膛=水平初速向玩家一侧（**不瞄人**，炮位定平射向；v1 解算落玩家脚下，
## 正常行进下落点全在行进方向身后=「跳的没意义」，用户判死），发射点在船体
## 下部（鱼雷语汇：BOSS 技能A 压低到发射高度，见 ANCHOR_SKIP_FIRE_Y）。
## 重力把平抛拉出浅垂弧触到甲板，触地即反弹：弹道顶高固定 HOP_APEX、水平
## 速度按跳序衰减（跳距 509/432/367 可预判），第 4 次触地=球爆（GroundBlast
## 一次性判定）。触地喷白沫溅花=落点读出件；撞台阶立面（埋深超限）=撞墙
## 当场起爆，零穿模。
## 惩罚账（v2 对冲几何）：玩家 +X 行进 vs 弹 −X 平抛/跳=迎面对冲——平射段
## 在头部高度（发射净空 60），**停=被平射段命中**；首跳带与跳弧都在玩家
## **前方迎面**（v1 落点在身后），**跳过弹体=免**（纯跳脚底 +67 > 弹体接触带；
## 跳弧中段站立玩家擦顶不中）；顺弹向走=顺着弹尾走远离（免）。
## 弹体接触判定=弹心距玩家中心 ≤ CONTACT_RADIUS+26，命中即当场起爆。
## group "skip_shells" 供自测探针计数。数值：伤害/爆径=调用方按机体段注入。

const SHELL_TEXTURE := preload("res://assets/world_7/fx_sea_skip.svg")
const SPLASH_TEXTURE := preload("res://assets/world_7/fx_sea_splash.svg")
const EXPLOSION := preload("res://scenes/fx/explosion_burst.tscn")

const MAX_LIFETIME := 5.0 # 兜底寿钟（正常按跳数/接触/撞墙结算）

var damage := 10
var blast_radius := 100.0

var _vel := Vector2.ZERO
var _terrain: Terrain
var _hops := 0
var _t := 0.0
var _popped := false
var _visual: Sprite2D


## 先入树再调本方法。dir_x 带符号：平射水平方向（朝玩家一侧）。
func launch(terrain: Terrain, from: Vector2, dir_x: float) -> void:
	_terrain = terrain
	global_position = from
	var dir := signf(dir_x) if dir_x != 0.0 else -1.0
	_vel = Vector2(dir * BalanceWorld7.SKIP_SHELL_SPEED, 0.0) # 平抛：水平出膛，重力拉弧
	rotation = _vel.angle()
	reset_physics_interpolation() # 先入树后定位：不拖补间残影


func _ready() -> void:
	add_to_group("skip_shells")
	_visual = Sprite2D.new()
	_visual.texture = SHELL_TEXTURE
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if _popped:
		return
	_t += delta
	if _t >= MAX_LIFETIME:
		_detonate()
		return
	_vel.y += BalanceCombat.MORTAR_GRAVITY * delta
	global_position += _vel * delta
	rotation = _vel.angle()
	_touch_player()
	if _popped:
		return
	var surface := _terrain.surface_y_at(global_position.x) \
			if _terrain != null else global_position.y
	if global_position.y >= surface:
		_ground_contact(surface)


## 触地分诊：埋深超限=撞台阶立面（撞墙当场起爆）；否则反弹（apex 固定、
## 水平速度按跳序衰减），喷白沫溅花=「这里弹起」的落点读出件。
func _ground_contact(surface: float) -> void:
	if global_position.y - surface > BalanceWorld7.SKIP_SHELL_WALL_PENETRATION:
		_detonate() # 台阶立面：掩体合法，弹当场爆
		return
	_hops += 1
	if _hops > BalanceWorld7.SKIP_SHELL_HOPS:
		_detonate()
		return
	global_position.y = surface - 1.0
	var dir_x := signf(_vel.x) if absf(_vel.x) > 1.0 else -1.0
	var speed := BalanceWorld7.SKIP_SHELL_HOP_SPEED \
			* pow(BalanceWorld7.SKIP_SHELL_HOP_DECAY, float(_hops - 1))
	_vel = Vector2(dir_x * speed, -sqrt(2.0 * BalanceCombat.MORTAR_GRAVITY
			* BalanceWorld7.SKIP_SHELL_HOP_APEX))
	rotation = _vel.angle()
	reset_physics_interpolation()
	_spawn_splash(Vector2(global_position.x, surface), 1.0)
	Sfx.play(&"hit_deflect") # 占位：触地弹跳暂用弹开声


## 弹体接触：命中即当场起爆（爆区判定兜住贴身擦边）。
func _touch_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	if global_position.distance_to(player.global_position) \
			<= BalanceWorld7.SKIP_SHELL_CONTACT_RADIUS + 26.0:
		_detonate()


## 末爆：球状爆区（单次判定）+ 溅花放大 + 通用爆花，无驻留区。
func _detonate() -> void:
	_popped = true
	var at := global_position
	var surface := _terrain.surface_y_at(global_position.x) \
			if _terrain != null else global_position.y
	if at.y > surface:
		at = Vector2(at.x, surface - 10.0) # 爆心贴地读法
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var blast := GroundBlast.new()
		blast.damage = damage
		blast.radius = blast_radius
		container.add_child(blast)
		blast.global_position = at
		blast.reset_physics_interpolation()
		var boom := EXPLOSION.instantiate() as Node2D
		boom.scale = Vector2(1.1, 1.1)
		container.add_child(boom)
		boom.position = at
		boom.reset_physics_interpolation()
		_spawn_splash(at, blast_radius / 90.0)
	Sfx.play(&"boom_enemy") # 占位：末跳起爆暂用敌爆声
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 0.8)
	queue_free()


## 白沫溅花：贴图一次性件（scale 冲开+快速淡出），代码补间，无粒子依赖。
func _spawn_splash(at: Vector2, power: float) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var splash := Sprite2D.new()
	splash.texture = SPLASH_TEXTURE
	splash.scale = Vector2.ONE * (0.7 + 0.5 * power)
	container.add_child(splash)
	splash.global_position = at + Vector2(0.0, -8.0)
	splash.reset_physics_interpolation()
	var tw := splash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(splash, "scale", splash.scale * 1.6, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(splash, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(splash.queue_free)
