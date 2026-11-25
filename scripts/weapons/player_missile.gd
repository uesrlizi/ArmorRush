class_name PlayerMissile
extends Area2D
## 蜂巢小导弹（§4 肩部武器槽）：沿炮口直瞄出膛 → 出膛即制导（无助推段）。
## 线速渐增：起步滑行、匀加速爬到 2 倍终速（不是高速射出）；转向率按初始速账
## （直瞄基本不用转弯，速度上来后转弯半径自然放大）。目标没了（被打死/离场）
## 果断换场上最近的敌人（不限距）；场上没敌人=不再制导直飞（BOSS 导弹同款
## 抛体滑行读法，原地转圈丑）。
## 命中敌人=伤+冲击（借 bullet.gd 同款 has_method 路径）；撞地形/寿命到头=自爆不伤。
## 拉烟复用敌方导弹的 missile_smoke（全程点燃，弹体小一号浓度）；爆时烟过继弹容器
## 淡完再清（消失承接规范 design/worlds.md §4c：小爆当帧盖住弹体）。

const BURST := preload("res://scenes/fx/explosion_burst.tscn")
const SMOKE := preload("res://scenes/fx/missile_smoke.tscn")

const SPEED := 780.0      # 初始线速（滑行起步，不快射）
const SPEED_MAX := 1560.0 # 终速=2 倍初始（BOSS 战对跑追速账，2026-11-09）
const ACCEL := 650.0      # 线速爬升（px/s²）：匀加 ~1.2s 到终速
const TURN_RATE := 5.0    # 制导转向角速度（rad/s）：按初始速算（转弯半径 156px）
const LIFETIME := 3.0     # 寿命上限：到头自爆（屏外静默销毁）

var damage := 6
var impact := 3.0
var tracer_tint := Color(0, 0, 0, 0) # 尾焰染色（成员色；弹体本体不受 tint）

var _dir := Vector2.UP
var _speed := SPEED
var _target: Node2D
var _t := 0.0
var _exploded := false
var _smoke: GPUParticles2D


## 兼容先 setup 再进树、先进树再 setup 两种调用顺序；target 可空（直飞）。
func setup(launch_dir: Vector2, target: Node2D) -> void:
	if launch_dir.length_squared() > 0.0001:
		_dir = launch_dir.normalized()
	_target = target


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	rotation = _dir.angle()
	_smoke = SMOKE.instantiate() as GPUParticles2D
	_smoke.position = Vector2(-8.0, 0.0) # 弹尾（弹体小，喷口即弹体后端）
	_smoke.scale = Vector2.ONE * 0.6
	_smoke.modulate = Color(1.0, 1.0, 1.0, 0.5) # 拖烟压淡（蜂巢是小弹，烟柱抢戏）
	if tracer_tint.a > 0.0:
		_smoke.self_modulate = tracer_tint # 拉烟染成员色（颜色即预告的延伸读法）
	add_child(_smoke)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		_explode()
		return
	_speed = minf(_speed + ACCEL * delta, SPEED_MAX) # 线速匀加爬终速（无目标也照爬）
	# 目标没了、或钻进地里够不着了（Enemy.is_targetable，如冰钻全埋地下）→ 换场上最近的
	if not is_instance_valid(_target) or (_target is Enemy and not _target.is_targetable()):
		_target = _nearest_enemy()
	if _target != null:
		var desired := (Enemy.aim_of(_target) - global_position).angle()
		_dir = _dir.rotated(clampf(wrapf(desired - _dir.angle(), -PI, PI),
				-TURN_RATE * delta, TURN_RATE * delta))
	# 没目标不转向：沿当前方向直飞（BOSS 导弹同款），转圈丑。
	rotation = _dir.angle() # 弹体轴跟实时速度（转弯可见）
	position += _dir * _speed * delta
	if _is_offscreen():
		queue_free() # 屏外静默销毁（消失承接豁免同 bullet.gd）


## 场上最近的敌人（不限距，果断换目标；enemies 组含 BOSS；此刻不可索敌的不选）。
## 返回 null=场上没有够得着的敌人。
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_queued_for_deletion() or not enemy.is_targetable():
			continue
		var d := global_position.distance_squared_to(enemy.aim_point())
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("add_impact"):
			body.add_impact(impact)
	_explode()


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		if area.has_method("add_impact"):
			area.add_impact(impact)
	_explode()


## 自爆：小爆当帧盖住弹体（消失承接），拉烟过继弹容器按粒子寿命淡完再清。
func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var burst := BURST.instantiate() as Node2D
		burst.position = global_position # 先定位再入树（一发粒子在 _ready 整批出生）
		container.add_child(burst)
		burst.scale = Vector2.ONE * 0.45
	_release_trail()
	queue_free()
	Sfx.play(&"boom_enemy", 0.4)


## 拉烟过继（同 bullet.gd _release_trail：留在弹体下会随 queue_free 整条瞬灭）。
func _release_trail() -> void:
	if _smoke == null:
		return
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	_smoke.emitting = false
	_smoke.reparent(container)
	# reparent=先入新父再改回全局变换后必须重置插值基点（物理插值惯例）
	_smoke.reset_physics_interpolation()
	get_tree().create_timer(_smoke.lifetime + 0.1, false, false, true).timeout.connect(
		_smoke.queue_free)


func _is_offscreen() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var half_size := get_viewport_rect().size * 0.5
	var offset := global_position - cam.get_screen_center_position()
	return absf(offset.x) > half_size.x + 100.0 or absf(offset.y) > half_size.y + 100.0
