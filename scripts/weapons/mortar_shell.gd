class_name MortarShell
extends Node2D
## 迫击炮·熔渣弹：真弹道抛体，与导弹彻底分家（不用 HeavyMissile，无制导无锁死）。
## 出膛初速按「落点 + 飞行时长」解算：v0 = Δ/T − ½gT（竖直项），全程只受
## MORTAR_GRAVITY（≈4×玩家重力——弧快、不掉速，0.7s 级全程、弧顶 ≈+120px），
## 所见弧线即全部真相，砸到哪算哪（贴地引爆）。
## 战斗部：溅射（可选，splash）+ 驻留熔渣火区（SlagPool）。
## 弹体/尾迹独立资产：mortar_shell.svg（熔渣鼻帽铁壳弹）+ mortar_trail.tscn
## （双层尾迹：烟=fx_smoke 走暖灰带对标导弹烟量级、寿命砍短 0.4s；火星=
## fx_flame 走熔橙带 0.35s 垫上层；爆时过继弹容器淡完再清，同导弹拉烟收尾惯例）。
## 落点推算 compute_lead_target：落点=按玩家当前速度外推的前方路面
## （相对速度即机制：匀速直线跑会一头扎进火区）；时长已知 → 无需迭代。

const BODY_TEXTURE := preload("res://assets/world_2/mortar_shell.svg")
const TRAIL := preload("res://scenes/weapons/mortar_trail.tscn")
const EXPLOSION := preload("res://scenes/fx/explosion_burst.tscn")

var damage := 0
var blast_radius := 0.0
var splash := true
var pool_radius := 0.0
var pool_lifetime := 2.8

var _vel := Vector2.ZERO
var _terrain: Terrain
var _trail: Node2D
var _body: Sprite2D


func _ready() -> void:
	_body = Sprite2D.new()
	_body.texture = BODY_TEXTURE
	add_child(_body)
	_trail = TRAIL.instantiate()
	_trail.position = Vector2(-10.0, 0.0) # 弹尾（随弹体旋转，永远在速度反侧）
	add_child(_trail)


## 先入树再调。target 必须贴地（调用方走 compute_lead_target）。
func launch(terrain: Terrain, from: Vector2, target: Vector2, flight_time: float) -> void:
	_terrain = terrain
	global_position = from
	var d := target - from
	var g := BalanceCombat.MORTAR_GRAVITY
	_vel = Vector2(d.x / flight_time, d.y / flight_time - 0.5 * g * flight_time)
	rotation = _vel.angle()
	reset_physics_interpolation() # 先入树后定位：不拖补间残影


func _physics_process(delta: float) -> void:
	_vel.y += BalanceCombat.MORTAR_GRAVITY * delta
	global_position += _vel * delta
	rotation = _vel.angle()
	if _terrain != null and global_position.y >= _terrain.surface_y_at(global_position.x):
		_detonate()
		return


## 定点落点推算：飞行时长已知（弹道由解算保证精确命中），提前量一次算完。
static func compute_lead_target(from: Vector2, player: Player, terrain: Terrain,
		lead_max: float, flight_time: float) -> Vector2:
	var vx := clampf(player.velocity.x,
			-BalancePlayer.PLAYER_MOVE_SPEED, BalancePlayer.PLAYER_MOVE_SPEED)
	var x := clampf(player.global_position.x + vx * flight_time,
			player.global_position.x - 150.0,
			player.global_position.x + lead_max)
	return Vector2(x, terrain.surface_y_at(x))


func _detonate() -> void:
	var surface := _terrain.surface_y_at(global_position.x) \
			if _terrain != null else global_position.y
	var at := Vector2(global_position.x, surface) # 爆心贴地
	var container := get_tree().get_first_node_in_group("projectile_container")
	if _trail != null:
		for p in _trail.get_children():
			if p is GPUParticles2D:
				(p as GPUParticles2D).emitting = false
		if container != null:
			_trail.reparent(container)
			_trail.reset_physics_interpolation() # 过继后清补间基点（否则整条尾从原点补间一步=闪一帧）
			get_tree().create_timer(0.8).timeout.connect(_trail.queue_free)
	if container != null:
		if splash and damage > 0:
			var blast := GroundBlast.new()
			blast.damage = damage
			blast.radius = blast_radius
			container.add_child(blast)
			blast.global_position = at
			blast.reset_physics_interpolation()
		if pool_radius > 0.0:
			var pool := SlagPool.new()
			pool.radius = pool_radius
			pool.lifetime = pool_lifetime
			pool.position = at
			container.add_child(pool)
		var boom := EXPLOSION.instantiate() as ExplosionBurst
		boom.scale = Vector2(1.5, 1.5) if splash else Vector2(0.9, 0.9)
		boom.position = at + Vector2(0.0, -14.0) # 容器在原点，position 即全局位
		# 白闪起跳半径=弹体面积折算（无溅射精英弹 ×0.9 的原版白闪首帧只有 ~8px，接不住
		# 32x16 弹体；面积承接，design/worlds.md §4c）
		boom.cover_radius = ExplosionBurst.area_cover_radius(
				ExplosionBurst.sprite_area(_body)) / boom.scale.x
		container.add_child(boom)
	Sfx.play(&"boom_enemy")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 1.5)
	queue_free()
