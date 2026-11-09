class_name SlagPool
extends Node2D
## 熔渣火区：熔渣弹落地后驻留的地面危险。球状 tick 判定（圆心=落点，玩家碰撞
## 中心距圆心 ≤ 半径+宽限即结算），落地先蓄热 SLAG_POOL_WARMUP——火区亮起但
## 还不咬人（溅开→变危险的二段预警），驻留末段淡出。视觉=贴图平涂（fx 规约
## 禁程序化 _draw），本脚本只管判定与生命周期；由 HeavyMissile 落地战斗部以
## SlagPool.new() 生成（纯代码构建视觉，同 GroundBlast 的 FlashBurst 惯例——
## .new() 不带场景子节点），不池化（寿终自灭）。

const POOL_TEXTURE := preload("res://assets/world_2/slag_pool.svg")

var radius := BalanceWorld2.SLAG_POOL_RADIUS
var damage := BalanceWorld2.SLAG_POOL_DAMAGE
var tick_interval := BalanceWorld2.SLAG_POOL_TICK
var lifetime := 2.8

var _warmup := 0.0
var _tick_t := 0.0
var _life := 0.0
var _visual: Sprite2D


func _ready() -> void:
	add_to_group("slag_pools") # 自测探针用
	_visual = Sprite2D.new()
	_visual.texture = POOL_TEXTURE
	_visual.scale = Vector2.ONE * (radius / 90.0) # 画布按 r90 满幅，按判定半径缩放
	_visual.modulate.a = 0.0
	add_child(_visual)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= lifetime:
		queue_free()
		return
	# 淡入（蓄热期渐亮=变危险的前摇）与末段淡出，一段式 alpha 账
	var a_in := clampf(_life / BalanceWorld2.SLAG_POOL_WARMUP, 0.0, 1.0)
	var a_out := clampf((lifetime - _life) / 0.4, 0.0, 1.0)
	_visual.modulate.a = minf(a_in, a_out)
	if _warmup > 0.0:
		_warmup -= delta
		return
	_tick_t -= delta
	if _tick_t > 0.0:
		return
	_tick_t = tick_interval
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	if global_position.distance_to(player.global_position) \
			<= radius + GroundBlast.PLAYER_RADIUS:
		player.take_damage(damage, true) # 驻留 tick：不进受击无敌窗（站着就每拍疼）
