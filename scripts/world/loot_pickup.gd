class_name LootPickup
extends Node2D
## 装备掉落小件（design/run_loop.md §4）：BOSS 击杀后从爆点弹出的通用补给件，
## 通体成员色 tint=到手后通道的预告（颜色即预告：弹出青色件=青焰）。三段生命：
## ①出膛：从击杀点小幅上抛 → 重力落到正下方地表 → 弹一次 → 立稳（连续轨迹，
##   出膛全程可见=颜色预告窗；击杀点在 BOSS 悬浮高度，比地面高 200~400px）；
## ②立稳后玩家在磁吸半径内（≈全屏=实际必捡，禁「躲弹漏捡」双随机叠加）即加速
##   飞向玩家——跑过去捡=疾驰被奖励（越早贴近越早收包）；
## ③抵达授予：RunState.equip + Player.apply_mod（通道当场换色=公告）+ 物品音。
## 转场兜底：Main 在抽关/通关结算前调 collect_in_flight() 把在途件就地授予
## ——掉一次落都不许丢。由 Main._on_boss_defeated 以 .new() 生成（纯代码构建，
## 同 SlagPool/FlashBurst 惯例），不池化（授予即灭）。玩家死亡时不授予也不追人
## （本局已结束，mods 随 start_run 清空，掉落物无所谓了）。

const PART_TEXTURE := preload("res://assets/common/loot_part.svg")

var member := &"" # 装备成员 id（setup 赋值）

var _vel_y := 0.0        # 出膛段竖直速度（px/s，向下为正）
var _bounced := false    # 已触地弹过一次
var _landed := false     # 已立稳（之后才进磁吸段）
var _ground_y := 0.0     # 落点地表 y（出生时按地形吸附）
var _magnet := false     # 是否已进磁吸段
var _speed := 0.0        # 磁吸当前速度（加速到极速）
var _granted := false
var _visual: Sprite2D


## 纯代码构建：先 setup 再入树（同子弹 setup/launch 惯例）；视觉件在 _ready 自建
## （SlagPool 同款），tint=成员色即预告。
func setup(member_id: StringName, at: Vector2, ground_y: float) -> void:
	member = member_id
	position = at
	_ground_y = ground_y
	_vel_y = -BalanceGlobal.LOOT_POP_SPEED # 从爆点小幅上抛


func _ready() -> void:
	add_to_group("loot_pickups") # 转场兜底按组就地授予
	_visual = Sprite2D.new()
	_visual.texture = PART_TEXTURE
	_visual.self_modulate = BalanceMods.MEMBERS[member]["tint"]
	add_child(_visual)
	reset_physics_interpolation() # 先定位再入树/入树即定位都要清插值基点，出膛不拖残影


func _physics_process(delta: float) -> void:
	if _granted:
		return
	if not _landed:
		_tick_drop(delta)
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return # 本局已结束：不追人不授予，随场景卸载消失（mods 会清，无所谓）
	var to := player.global_position - global_position
	if not _magnet and to.length() > BalanceGlobal.LOOT_MAGNET_RADIUS:
		return
	# 磁吸段：从静止加速扑向玩家，极速封顶（1480px 站桩最坏账 ≈0.7s 收包）。
	_magnet = true
	_speed = minf(_speed + BalanceGlobal.LOOT_MAGNET_ACCEL * delta, BalanceGlobal.LOOT_MAGNET_SPEED)
	var step := to.normalized() * _speed * delta
	if step.length() >= to.length() or to.length() <= BalanceGlobal.LOOT_GRAB_RANGE:
		_grant(player)
		return
	position += step


## 出膛段：竖直抛体积分（上抛 → 下落 → 触地反弹一次 → 立稳），落点钉在出生时
## 吸附的地表 y。必须是连续轨迹：曾按「从地面起抛、定时回落」写成固定时长弧，
## 而起抛点其实在 BOSS 悬浮高度——定时到点还在半空，一帧瞬移到地面 ~360px，
## 读成「掉落物弹出两次」（2026-11-08 用户报）。翻滚只在首次触地前，之后转角
## 指数回正（弹跳 ~0.15s 内归零），立稳时置零无跳变。
func _tick_drop(delta: float) -> void:
	_vel_y += BalanceGlobal.LOOT_FALL_GRAVITY * delta
	position.y += _vel_y * delta
	if _bounced:
		rotation = lerp_angle(rotation, 0.0, 1.0 - exp(-BalanceGlobal.LOOT_SETTLE_RATE * delta))
	else:
		rotation += BalanceGlobal.LOOT_SPIN * delta
	if position.y < _ground_y:
		return
	position.y = _ground_y
	if not _bounced and _vel_y > BalanceGlobal.LOOT_BOUNCE_MIN_SPEED:
		_vel_y = -_vel_y * BalanceGlobal.LOOT_BOUNCE
		_bounced = true
		return
	_landed = true
	_vel_y = 0.0
	rotation = 0.0


## 生效瞬间：装备入表 + 玩家侧通道当场换色/换形（视觉即公告）+ 物品音 + 授予闪光。
func _grant(player: Player) -> void:
	if _granted:
		return
	_granted = true
	RunState.equip(member)
	player.apply_mod(member)
	Sfx.play(&"pickup")
	_spawn_grant_flash(player)
	queue_free()


## 授予闪光：玩家身上一记成员色爆闪（FlashBurst，颜色即公告的最后一拍）。
func _spawn_grant_flash(player: Player) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var flash := FlashBurst.new()
	flash.flash_color = BalanceMods.MEMBERS[member]["tint"]
	flash.size_scale = 1.4
	flash.position = player.global_position
	container.add_child(flash)


## 转场兜底（Main 在抽关/通关结算前调）：把场上所有在途件就地授予——
## 掉落不许因为转场时序而丢（禁「躲弹漏捡」之后的第二种丢失）。
static func collect_in_flight() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("loot_pickups"):
		var pickup := node as LootPickup
		if pickup != null and not pickup._granted:
			var player := tree.get_first_node_in_group("player") as Player
			if player != null and not player.is_dead():
				pickup._grant(player)
