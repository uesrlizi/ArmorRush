class_name Bullet
extends Area2D
## 通用子弹：玩家弹和敌人弹共用脚本，速度/伤害由发射方从 Balance* 调参表取值后赋给本节点，
## 场景里不再保存副本（避免导出值遮蔽脚本改动）。
## 玩家弹蒙版 = 世界 + 敌人；敌人弹蒙版 = 世界 + 玩家。
## 方向是二维向量，整颗子弹（含碰撞形状）旋转到飞行方向；
## 飞行速度 = 自身速度 + 发射瞬间继承的载体速度。
## lob_gravity>0 时为抛体弹种（red_lob 斗轮抛石）：初速=方向×速度+继承，之后逐帧
## 吃重力，朝向/迸溅/击退全跟实时速度走——直线弹种（lob_gravity=0）语法零改动。
##（成员名带 lob_ 前缀：Area2D 原生就有 gravity 属性，裸名会撞成重定义解析错。）

const IMPACT_BURST := preload("res://scenes/fx/impact_burst.tscn")

@export var max_lifetime := 5.0

var speed := 700.0
var damage := 10
var impact_tint := Color(1.0, 0.92, 0.6) # 命中迸溅染色：玩家弹暖金，敌弹出膛时覆写为红
var impact := 0.0 # 冲击值（失衡积累，AC6 式）：发射方赋值——玩家弹 >0，敌弹默认 0 不积累
var lob_gravity := 0.0 # px/s²，>0=抛体弹种（发射方赋值；场景不存副本，同 speed/damage 惯例）

var _direction := Vector2.RIGHT
var _inherit := Vector2.ZERO
var _vel := Vector2.ZERO # 抛体弹的实时合速度（首个物理帧从 方向×速度+继承 起算）
var _lifetime := 0.0
var _spawn_pos := Vector2.ZERO # 出膛点（首个物理帧记录，用于迸溅最小飞行距离）
var _started := false

@onready var _sprite: Sprite2D = $Sprite2D


## 兼容先 setup 再进树、先进树再 setup 两种调用顺序；零向量兜底为向右。
## inherit_velocity：发射瞬间载体的速度（如玩家跑动速度）。
func setup(direction: Vector2, inherit_velocity: Vector2 = Vector2.ZERO) -> void:
	if direction.length_squared() > 0.0001:
		_direction = direction.normalized()
	_inherit = inherit_velocity
	if is_inside_tree():
		_refresh()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_refresh()


## 朝向按世界速度（自体速度 + 继承速度的合矢量），而非枪口指向；
## 移动则沿同一合速度，贴图所见即弹道所向。
func _refresh() -> void:
	var world_vel := _direction * speed + _inherit
	if world_vel.length_squared() > 0.0001:
		rotation = world_vel.angle()


func _physics_process(delta: float) -> void:
	if not _started:
		_started = true
		_spawn_pos = global_position
		_vel = _direction * speed + _inherit
	if lob_gravity > 0.0:
		# 抛体：速度积分重力，弹头/迸溅反向/击退方向都改读实时速度（贴图所见即弹道所向）
		_vel.y += lob_gravity * delta
		_direction = _vel.normalized()
		rotation = _vel.angle()
		position += _vel * delta
	else:
		position += (_direction * speed + _inherit) * delta
	_lifetime += delta
	if _lifetime > max_lifetime or _is_offscreen():
		queue_free()


## 预判瞄准：按目标当前速度外推其在子弹飞行时间后的位置。
## 目标需暴露 velocity 属性（CharacterBody2D 天生有——玩家与敌人都是）。
## （若之后同时存在速度继承与移动目标，实际合速度会偏离弹速，届时在此处用合速度迭代求精。）
static func aim_point(from: Vector2, target: Node2D, bullet_speed: float) -> Vector2:
	var target_vel := Vector2.ZERO
	var v: Variant = target.get("velocity")
	if v is Vector2:
		target_vel = v
	var to_target := target.global_position - from
	var t := to_target.length() / bullet_speed
	t = (to_target + target_vel * t).length() / bullet_speed # 再迭代一次，收敛提前量
	return target.global_position + target_vel * t


## 解开火方向：使「自体速度 × speed + 继承速度」的合速度恰好沿 from→target_point 连线飞行。
## 这样继承只影响弹速快慢，不影响命中——跳跃/下落开火也不会把弹道带偏。
## 数学：|dir|=1，dir*speed + I = k*d（d 为瞄准单位向量），解 k 取正根。
static func solve_fire_direction(
		from: Vector2, target_point: Vector2, bullet_speed: float, inherit: Vector2
) -> Vector2:
	var d := from.direction_to(target_point)
	if d == Vector2.ZERO:
		return Vector2.RIGHT
	var di := d.dot(inherit)
	var k := di + sqrt(maxf(di * di + bullet_speed * bullet_speed - inherit.length_squared(), 0.0))
	return (d * k - inherit).normalized()


## 抛体初速解算：给定重力与飞行时长，使弹道恰在 flight 秒后经过 target——落点
## 锁定在**出手时刻**（无 lead：目标此后移开就落空）。发射方把返回值拆成
## speed=length / setup(normalized) 并赋 lob_gravity。p(t)=from+v·t+½g·t²，解 v。
static func solve_lob_velocity(
		from: Vector2, target: Vector2, gravity_px: float, flight: float
) -> Vector2:
	var t := maxf(flight, 0.05)
	return (target - from - Vector2(0.0, 0.5 * gravity_px * t * t)) / t


func _is_offscreen() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var half_size := get_viewport_rect().size * 0.5
	var offset := global_position - cam.get_screen_center_position()
	return absf(offset.x) > half_size.x + 100.0 or absf(offset.y) > half_size.y + 100.0


func _on_body_entered(body: Node2D) -> void:
	# 命中声分账：敌人/玩家各自发自己的受击声，这里只管打在地形/障碍上。
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("add_impact"): # 冲击只进敌人（失衡积累），玩家没有该入口
			body.add_impact(impact)
		if body.has_method("apply_knockback"): # 只有敌人响应击退（玩家没有该入口）
			body.apply_knockback(_direction * BalanceEnemy.ENEMY_KNOCKBACK_GUN)
		_spawn_impact(global_position)
	else:
		_spawn_impact(global_position, true)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		if area.has_method("add_impact"):
			area.add_impact(impact)
		if area.has_method("apply_knockback"):
			area.apply_knockback(_direction * BalanceEnemy.ENEMY_KNOCKBACK_GUN)
	_spawn_impact(_impact_point(area))
	queue_free()


## 命中迸溅：火花沿弹道反向回溅，生成在弹容器里（不随子弹销毁）。
## 出膛后飞满 BULLET_IMPACT_MIN_TRAVEL 才喷：贴脸撞墙时不在枪口上开花——
## 枪口焰是挂在 Muzzle 下的子节点（跟着枪走），落世界空间的是迸溅。
## world=true 表示打在无生命地形上，补一记轻弹着声（节流在 Sfx 音库里管）。
func _spawn_impact(at: Vector2, world := false) -> void:
	if _started and global_position.distance_to(_spawn_pos) < BalancePlayer.BULLET_IMPACT_MIN_TRAVEL:
		return
	if world:
		Sfx.play(&"hit_world")
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var burst := IMPACT_BURST.instantiate() as ImpactBurst
	burst.setup(-_direction, impact_tint)
	# 必须先定位再入树：one_shot 粒子在 _ready（add_child 时）就整批出生，
	# 入树后再挪节点，粒子已经喷在容器原点（=出生点上空）留在那里了。
	burst.position = at # 容器在原点且无变换，position 即全局位
	container.add_child(burst)


## 命中点近似：弹速快、一帧可穿入命中体数十像素，把命中点拉回其迎弹面。
func _impact_point(on: Node2D) -> Vector2:
	var size: Variant = on.get("body_size")
	if size is Vector2 and (size as Vector2).x > 0.0:
		var half_x: float = (size as Vector2).x * 0.5
		var dx := global_position.x - on.global_position.x
		if absf(dx) > half_x:
			return Vector2(on.global_position.x + signf(dx) * half_x, global_position.y)
	return global_position
