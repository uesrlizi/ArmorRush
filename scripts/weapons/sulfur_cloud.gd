class_name SulfurCloud
extends Node2D
## 硫云爆燃（第十章 BOSS「井口」技能 B；全游戏首个横向推火锋）：VentPort 抛出硫气弹
## （无伤弹药读法）落进固定绝对高度带 y∈[428,512] 的右端（BOSS 侧），带内铺开硫褐烟墙
## （引火期，无伤）→ 点燃后火锋自右端向左以 2500px/s 推进，燃烧区 = [max(锋, xL), xR]，
## 燃烧窗结束即熄灭不驻留。带位零地形跟随（CoralTide/SeaSurge 同类合法件）。
## 判定：燃烧窗内玩家 AABB（40×60）与燃烧区 x 相交且身体 y 区间与带相交 → 伤 12，每片云
## 至多结算一次。只罚 tier2(g=536) 站立与 tier1(g=600) 起跳；tier1/tier0 贴地免。
## 时间口径（R3）：age=0 为硫气弹出膛，绝对时间 t_abs = age + SULFUR_CLOUD_WARN。
## group "sulfur_clouds" 供探针；视觉全代码自建；整件物理插值 OFF。

const TEX_CLOUD := preload("res://assets/world_10/fx_sulfur_cloud.svg")
const TEX_FRONT := preload("res://assets/world_10/fx_sulfur_cloud_front.svg")
const TEX_SHELL := preload("res://assets/world_10/fx_sulfur_gas_shell.svg")
const PLAYER_HALF := Vector2(20.0, 30.0)

var damage := 12
var x_left := 0.0      # 带左端世界 x（出手帧定死）
var age := 0.0
var hits := 0

var _from := Vector2.ZERO
var _shell: Sprite2D
var _tiles: Array[Sprite2D] = []
var _front: Sprite2D
var _hit := false


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	add_to_group("sulfur_clouds")


func x_right() -> float:
	return x_left + BalanceWorld10.SULFUR_CLOUD_SPAN


func t_abs() -> float:
	return age + BalanceWorld10.SULFUR_CLOUD_WARN


## 火锋世界 x（点燃前=右端；推到左端后停在左端）。
func front_x() -> float:
	var t := t_abs() - BalanceWorld10.SULFUR_CLOUD_IGNITE
	return maxf(x_right() - BalanceWorld10.SULFUR_CLOUD_FRONT_SPEED * maxf(t, 0.0), x_left)


func is_burning() -> bool:
	var t := t_abs()
	return t >= BalanceWorld10.SULFUR_CLOUD_IGNITE \
			and t <= BalanceWorld10.SULFUR_CLOUD_IGNITE + BalanceWorld10.SULFUR_CLOUD_BURN


## 先入树再调本方法。from=VentPort 世界位；xl=带左端。
func launch(from: Vector2, xl: float) -> void:
	global_position = Vector2.ZERO
	x_left = xl
	_from = from
	var top := BalanceWorld10.SULFUR_CLOUD_BAND_TOP
	var x := xl
	while x < x_right() - 0.5:
		var s := Sprite2D.new()
		s.texture = TEX_CLOUD
		s.centered = false
		s.position = Vector2(x, top)
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, minf(200.0, x_right() - x), 84)
		s.modulate.a = 0.0
		add_child(s)
		_tiles.append(s)
		x += 200.0
	_front = Sprite2D.new()
	_front.texture = TEX_FRONT
	_front.position = Vector2(x_right(), (top + BalanceWorld10.SULFUR_CLOUD_BAND_BOTTOM) * 0.5)
	_front.visible = false
	add_child(_front)
	_shell = Sprite2D.new()
	_shell.texture = TEX_SHELL
	_shell.position = from
	add_child(_shell)


func _physics_process(delta: float) -> void:
	age += delta
	var t := t_abs()
	var mid_y := (BalanceWorld10.SULFUR_CLOUD_BAND_TOP + BalanceWorld10.SULFUR_CLOUD_BAND_BOTTOM) * 0.5
	var feed_end := BalanceWorld10.SULFUR_CLOUD_WARN + BalanceWorld10.SULFUR_CLOUD_FEED_FLIGHT
	var ign := BalanceWorld10.SULFUR_CLOUD_IGNITE
	var end := ign + BalanceWorld10.SULFUR_CLOUD_BURN
	if _shell != null:
		var k := clampf(age / BalanceWorld10.SULFUR_CLOUD_FEED_FLIGHT, 0.0, 1.0)
		var dst := Vector2(x_right() - 40.0, mid_y)
		_shell.position = _from.lerp(dst, k) + Vector2(0, -80.0 * sin(PI * k))
		_shell.rotation += delta * 6.0
		if k >= 1.0:
			_shell.queue_free()
			_shell = null
	if t < feed_end:
		return
	var fx := front_x()
	for s in _tiles:
		var a := 0.0
		if t < ign:
			a = 0.55 * clampf((t - feed_end) / 0.3, 0.0, 1.0)   # 引火期烟墙（无伤）
		elif t <= end:
			a = 1.0 if s.position.x + 200.0 > fx else 0.55
		else:
			a = maxf(0.0, 1.0 - (t - end) / 0.2)
		s.modulate.a = a
	_front.visible = t >= ign and t <= end
	_front.position.x = fx
	if is_burning() and not _hit:
		_try_hit(fx)
	if t > end + 0.2:
		queue_free()


func _try_hit(fx: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	var c := player.global_position
	var top := BalanceWorld10.SULFUR_CLOUD_BAND_TOP
	var bot := BalanceWorld10.SULFUR_CLOUD_BAND_BOTTOM
	if c.x + PLAYER_HALF.x >= fx and c.x - PLAYER_HALF.x <= x_right() \
			and c.y - PLAYER_HALF.y < bot and c.y + PLAYER_HALF.y > top:
		_hit = true
		hits += 1
		player.take_damage(damage)
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 0.8)
