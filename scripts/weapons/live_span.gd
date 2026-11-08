class_name LiveSpan
extends Node2D
## 跨缆（第九章精英「架线」/BOSS「引雷」共用核心危险件）：两根跨缆桩按解算弹道
## （MORTAR_GRAVITY）落到 [x1, x1+320] 两端，**落地即钉住竖立**（静止落点，零地形
## 跟随——DrillCharge/ArcFence 同族），桩顶之间挂一根静止直缆。「电沿着线走」：
##   飞行（松弛灰缆垂弧，Line2D 两端绑两桩顶=连接是真实的）→ 紧绷灰缆 idle（无伤）
##   → 爬电（电花从 A 桩顶沿缆爬到 B 桩顶，无伤=二段预警）→ 带电（白紫芯+外辉，
##   唯一判定期：玩家 AABB 40×60 到缆线段距离 ≤ 半厚 8 即命中，结算一次整套溃散）
##   → 寿命到点熄灭（无伤，等待永远合法）。
## 读法只看桩高：高缆 H110=贴地钻过别跳；低缆 H40=按住推进飞越或刹停等熄。
## 时间原点（R13）：本节点 t=0 = 首桩出膛（发射方闪光 0.6 之后）；落地 0.7、
## 带电 [1.6+extra, 2.6+extra]（extra=平移补时 位移/600 + p2 第二段晚 0.6）。
## 落位规则（同台/向前平移 ≤160/脚手架避让）在静态 plan_x1 里，发射方先问再放。
## group "live_spans" 供冷却闸（R5，按 owner_id 计数）与探针计数；预警在发射器上。
## 视觉全代码自建（.new() 出生件惯例：无场景子节点）；整件物理插值 OFF（缆的点
## 数据逐物理帧写，桩若插值会与缆端错开半步）。

const STAKE_HIGH := preload("res://assets/world_9/fx_storm_stake_high.svg")
const STAKE_LOW := preload("res://assets/world_9/fx_storm_stake_low.svg")
const HIT_BURST := preload("res://scenes/fx/arc_spark_burst.tscn")

const LIVE_CORE := Color(0.941, 0.902, 1.0)       # #f0e6ff 带电芯（R10）
const LIVE_GLOW := Color(0.788, 0.651, 1.0)       # #c9a6ff 带电外辉
const CABLE_GREY := Color(0.149, 0.125, 0.196)    # #262032 BELLY 暗缆（未带电）
const PLAYER_HALF := Vector2(20.0, 30.0)          # 玩家碰撞盒半尺寸（player.tscn 40×60）

enum Phase { FLY, IDLE, CRAWL, LIVE, FADE }

var damage := 10
var height := 110.0
var extra_delay := 0.0      # idle 延长（平移补时 + p2 第二段延迟）
var owner_id := 0           # 发射方 instance id（R5 冷却闸按此计数）
var x1 := 0.0               # 缆左端世界 x（落地后的定值；探针读）
var shift := 0.0            # 本次向前平移量（探针读）
var lead_x1 := 0.0          # 平移前的 lead 落点（探针读）
var cable_y := 0.0          # 缆世界 y（=桩顶；同台约束下两端同高）
var age := 0.0              # 自首桩出膛起的秒数（探针读）
var live_t0 := -1.0         # 进入带电的 age（探针读：= 1.6 + extra_delay）

var _phase := Phase.FLY
var _t := 0.0
var _terrain: Terrain
var _stakes: Array[Sprite2D] = []
var _vels: Array[Vector2] = []
var _launch_at: Array[float] = []
var _flight: Array[float] = []
var _from := Vector2.ZERO
var _xs: Array[float] = []
var _ground: Array[float] = []
var _cable: Line2D
var _glow: Line2D
var _charged: Line2D
var _spark: Polygon2D


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	add_to_group("live_spans")


## 落位规划（R6/R7 + 同台）：从 lead 落点 base_x1 起只向前 32px 步进试到 +160，
## 第一个同时满足「跨度内同台」与「[x1−40, x1+360] 不碰 floating 脚手架」的位置
## 胜出；返回 {"x1", "shift"}，全落空返回空字典=取消本次。
static func plan_x1(tree: SceneTree, terrain: Terrain, base_x1: float) -> Dictionary:
	var step := BalanceWorld9.LIVE_SPAN_SHIFT_STEP
	var n := int(floor(BalanceWorld9.LIVE_SPAN_SHIFT_MAX / step + 0.001))
	for i in n + 1:
		var s := i * step
		if i == n:
			s = BalanceWorld9.LIVE_SPAN_SHIFT_MAX
		var cand := base_x1 + s
		if _same_tier(terrain, cand) and not scaffold_overlaps(tree,
				cand - BalanceWorld9.LIVE_SPAN_SCAFFOLD_PAD_L,
				cand + BalanceWorld9.LIVE_SPAN_LENGTH + BalanceWorld9.LIVE_SPAN_SCAFFOLD_PAD_R):
			return {"x1": cand, "shift": s}
	return {}


static func _same_tier(terrain: Terrain, cand: float) -> bool:
	if terrain == null:
		return true
	var g := terrain.surface_y_at(cand)
	var x := cand
	var end := cand + BalanceWorld9.LIVE_SPAN_LENGTH
	while x < end:
		x = minf(x + BalanceWorld9.LIVE_SPAN_TIER_SAMPLE, end)
		if not is_equal_approx(terrain.surface_y_at(x), g):
			return false
	return true


## 浮空脚手架（"obstacles" 组 floating 件）x 区间与 [a, b] 是否重叠（R7 共用尺）。
static func scaffold_overlaps(tree: SceneTree, a: float, b: float) -> bool:
	for node in tree.get_nodes_in_group("obstacles"):
		var ob := node as Obstacle
		if ob == null or not ob.floating:
			continue
		var hw := ob.body_size.x * 0.5
		var ox := ob.global_position.x
		if ox + hw > a and ox - hw < b:
			return true
	return false


## 线段与玩家 AABB 的最近距离 ≤ half_thick（逐 4px 采样线段，点到矩形距离）。
## 跨缆/针链弧共用判定尺（缆可水平、弧可斜）。
static func segment_hits_player(a: Vector2, b: Vector2, center: Vector2, half_thick: float) -> bool:
	var n := maxi(int(a.distance_to(b) / 4.0), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var dx := maxf(absf(p.x - center.x) - PLAYER_HALF.x, 0.0)
		var dy := maxf(absf(p.y - center.y) - PLAYER_HALF.y, 0.0)
		if dx * dx + dy * dy <= half_thick * half_thick:
			return true
	return false


## 先入树再调本方法。from=出膛口世界位；x1_=已规划好的缆左端；h=桩高（110/40）。
func launch(terrain: Terrain, from: Vector2, x1_: float, h: float) -> void:
	_terrain = terrain
	global_position = Vector2.ZERO # 弹容器在原点：子件 position 即全局位
	x1 = x1_
	height = h
	_from = from
	_xs = [x1, x1 + BalanceWorld9.LIVE_SPAN_LENGTH]
	var tex := STAKE_HIGH if h > 70.0 else STAKE_LOW
	var anchor := Vector2(14, 116) if h > 70.0 else Vector2(16, 46)
	for i in 2:
		var gy := terrain.surface_y_at(_xs[i]) if terrain != null else from.y + 300.0
		_ground.append(gy)
		var st := Sprite2D.new()
		st.texture = tex
		st.centered = false
		st.offset = -anchor # origin=底部接地点（SVG 锚点账）
		st.position = from
		st.visible = i == 0
		add_child(st)
		_stakes.append(st)
		var fl := BalanceWorld9.LIVE_SPAN_FLIGHT - BalanceWorld9.LIVE_SPAN_STAGGER * i
		_flight.append(fl)
		_launch_at.append(BalanceWorld9.LIVE_SPAN_STAGGER * i)
		var d := Vector2(_xs[i], gy) - from
		var g := BalanceCombat.MORTAR_GRAVITY
		_vels.append(Vector2(d.x / fl, d.y / fl - 0.5 * g * fl))
	cable_y = _ground[0] - height
	_glow = _make_line(12.0, LIVE_GLOW)
	_glow.visible = false
	_cable = _make_line(3.0, CABLE_GREY)
	_charged = _make_line(3.0, LIVE_CORE)
	_charged.visible = false
	_spark = Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 10:
		var ang := TAU * k / 10.0
		var r := 9.0 if k % 2 == 0 else 4.0
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	_spark.polygon = pts
	_spark.color = LIVE_CORE
	_spark.visible = false
	add_child(_spark)
	_update_cable(true)


func _make_line(w: float, c: Color) -> Line2D:
	var l := Line2D.new()
	l.width = w
	l.default_color = c
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(l)
	return l


func _tops() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s in _stakes:
		out.append(s.position + Vector2(0.0, -height))
	return out


## 缆：飞行中=两桩顶间松弛垂弧（二次贝塞尔 12 段）；落地后=紧绷直线。
func _update_cable(slack: bool) -> void:
	var t := _tops()
	var a: Vector2 = t[0] if _stakes[0].visible else _from
	var b: Vector2 = t[1] if _stakes[1].visible else _from
	var pts := PackedVector2Array()
	if slack:
		var c := (a + b) * 0.5 + Vector2(0.0, 60.0)
		for k in 13:
			var u := k / 12.0
			pts.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
	else:
		pts.append(a)
		pts.append(b)
	_cable.points = pts
	_glow.points = pts
	_charged.points = pts


func _physics_process(delta: float) -> void:
	age += delta
	_t += delta
	match _phase:
		Phase.FLY:
			var landed := 0
			for i in 2:
				var st := _stakes[i]
				var lt := age - _launch_at[i]
				if lt < 0.0:
					continue
				st.visible = true
				if lt >= _flight[i]:
					st.position = Vector2(_xs[i], _ground[i])
					landed += 1
					continue
				var v0: Vector2 = _vels[i]
				st.position = _from + v0 * lt + Vector2(0.0, 0.5 * BalanceCombat.MORTAR_GRAVITY * lt * lt)
			_update_cable(landed < 2)
			if landed == 2:
				_phase = Phase.IDLE
				_t = 0.0
				_plant_fx()
		Phase.IDLE:
			if _t >= BalanceWorld9.LIVE_SPAN_IDLE + extra_delay:
				_phase = Phase.CRAWL
				_t = 0.0
				_spark.visible = true
				_charged.visible = true
		Phase.CRAWL:
			var k := clampf(_t / BalanceWorld9.LIVE_SPAN_CRAWL, 0.0, 1.0)
			var tops := _tops()
			var p: Vector2 = tops[0].lerp(tops[1], k)
			_spark.position = p
			_spark.rotation += delta * 18.0
			_charged.points = PackedVector2Array([tops[0], p])
			if _t >= BalanceWorld9.LIVE_SPAN_CRAWL:
				_phase = Phase.LIVE
				_t = 0.0
				live_t0 = age
				_spark.visible = false
				_glow.visible = true
				_cable.default_color = LIVE_CORE
				_charged.visible = false
				Sfx.play(&"boom_enemy") # 占位：缆带电暂用敌爆声，电弧配方后配
		Phase.LIVE:
			_glow.modulate.a = 0.35 + 0.25 * sin(_t * 40.0)
			_cable.width = 3.0 + 1.2 * sin(_t * 55.0)
			_tick_damage()
			if _phase == Phase.LIVE and _t >= BalanceWorld9.LIVE_SPAN_LIVE:
				_start_fade()
		Phase.FADE:
			modulate.a = clampf(1.0 - _t * 4.0, 0.0, 1.0)
			if modulate.a <= 0.0:
				queue_free()


func _plant_fx() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		for i in 2:
			var spark := HIT_BURST.instantiate() as Node2D
			container.add_child(spark)
			spark.position = Vector2(_xs[i], _ground[i] - 6.0)
			spark.scale = Vector2(0.45, 0.45)
	Sfx.play(&"fire_enemy") # 占位：落桩暂用敌枪声


func is_live() -> bool:
	return _phase == Phase.LIVE


func is_done() -> bool:
	return _phase == Phase.FADE


func _tick_damage() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	var tops := _tops()
	if segment_hits_player(tops[0], tops[1], player.global_position,
			BalanceWorld9.LIVE_SPAN_HALF_THICK):
		player.take_damage(damage)
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 0.8)
		var container := get_tree().get_first_node_in_group("projectile_container")
		if container != null:
			var spark := HIT_BURST.instantiate() as Node2D
			container.add_child(spark)
			spark.position = player.global_position
		Sfx.play(&"boom_enemy")
		_start_fade()


func _start_fade() -> void:
	_phase = Phase.FADE
	_t = 0.0
