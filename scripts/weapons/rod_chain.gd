class_name RodChain
extends Node2D
## 引雷针链（第九章 BOSS「引雷」技能 B 危险件）：背部 RodPorts 逐孔出针，针用解算
## 弹道（MORTAR_GRAVITY）落到玩家前路一列（间距 300），**落地即钉住竖立**（静止
## 落点零地形跟随，各针贴各自当地地表）；针尖充能环渐急=二段预警（无伤）；然后
## 「雷沿着针跳」：Muzzle→针1 主弧，随后针k−1 尖→针k 尖跳弧，每跳一次该针底爆
## （GroundBlast r90 贴地）。弧=静止线段（±8，存活 0.15s，伤 8，每段至多一次），
## 底爆伤 10；电走过的针熄灭。针高 120 → 弧带 h∈[112,128]：站立头顶 60 余量 52，
## 「站缝安全、跳到弧带挨弧、贴针停挨爆、满速直冲压针2 底爆」（R1/R12）。
## 时间原点（R13）：本节点 t=0 = RodPorts ThreatFlash 亮起（发射方同帧 add_child）；
## 针k 出膛 0.6+0.1k、落地 1.2+0.1k；放电 2.2+k·hop（hop 0.25 / p2 0.2）。
## 视觉全代码自建（贴图 fx_storm_rod.svg 36×140 锚点 (18,138)=接地点，针尖局部
## (0,−120)；充能环 Line2D 圆 Ø28=R9；弧=芯 #f0e6ff + 外辉 #c9a6ff 双层 Line2D）。
## 整件物理插值 OFF（弧端点读针尖/枪口实时世界位，逐物理帧写）。group "rod_chains"。

const ROD_TEX := preload("res://assets/world_9/fx_storm_rod.svg")
const HIT_BURST := preload("res://scenes/fx/arc_spark_burst.tscn")

var rod_xs: Array[float] = []        # 各针落点世界 x（探针读）
var rod_ground: Array[float] = []    # 各针落点地表 y
var land_t: Array[float] = []        # 各针实际落地的 age（探针读）
var discharge_t: Array[float] = []   # 各针实际放电的 age（探针读）
var hop := 0.25
var age := 0.0

var _ports: Array[Node2D] = []
var _muzzle: Node2D
var _terrain: Terrain
var _rods: Array[Sprite2D] = []
var _rings: Array[Line2D] = []
var _from: Array[Vector2] = []
var _vels: Array[Vector2] = []
var _fired: Array[bool] = []
var _arcs: Array[Dictionary] = []    # {a: Vector2, b: Vector2, t: float, hit: bool, glow, core}
var _next := 0                       # 下一根要放电的针序号
var _done_t := -1.0


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	add_to_group("rod_chains")


## 先入树再调。xs=已规划的针位（R7 避让已过）；ports=背部出针孔（按针序回绕复用）；
## muzzle=主弧源点（前臂放电球）。
func setup(terrain: Terrain, ports: Array[Node2D], muzzle: Node2D, xs: Array[float], hop_: float) -> void:
	_terrain = terrain
	_ports = ports
	_muzzle = muzzle
	hop = hop_
	global_position = Vector2.ZERO
	rod_xs = xs
	for i in xs.size():
		rod_ground.append(terrain.surface_y_at(xs[i]) if terrain != null else 664.0)
		land_t.append(-1.0)
		discharge_t.append(-1.0)
		_fired.append(false)
		_from.append(Vector2.ZERO)
		_vels.append(Vector2.ZERO)
		var r := Sprite2D.new()
		r.texture = ROD_TEX
		r.centered = false
		r.offset = Vector2(-18, -138)
		r.visible = false
		add_child(r)
		_rods.append(r)
		var ring := Line2D.new()
		ring.width = 2.5
		ring.default_color = RodChain.glow_color()
		var pts := PackedVector2Array()
		for k in 25:
			var ang := TAU * k / 24.0
			pts.append(Vector2(cos(ang), sin(ang)) * 14.0) # Ø28（R9）
		ring.points = pts
		ring.visible = false
		add_child(ring)
		_rings.append(ring)


static func core_color() -> Color:
	return Color(0.941, 0.902, 1.0) # #f0e6ff


static func glow_color() -> Color:
	return Color(0.788, 0.651, 1.0) # #c9a6ff


## 针 k 的针尖世界位（底部接地点 + (0,−120)）。
func tip(k: int) -> Vector2:
	return Vector2(rod_xs[k], rod_ground[k] - BalanceWorld9.ROD_HEIGHT)


func _launch_time(k: int) -> float:
	return BalanceWorld9.ROD_WARN + BalanceWorld9.ROD_STAGGER * k


func _discharge_time(k: int) -> float:
	return BalanceWorld9.ROD_WARN + BalanceWorld9.ROD_FLIGHT + BalanceWorld9.ROD_CHARGE + hop * k


func _physics_process(delta: float) -> void:
	age += delta
	for k in _rods.size():
		var lt := age - _launch_time(k)
		if lt < 0.0:
			continue
		var rod := _rods[k]
		if not _fired[k]:
			_fired[k] = true
			var port := _ports[k % _ports.size()] if not _ports.is_empty() else null
			var from := port.global_position if is_instance_valid(port) else Vector2(rod_xs[k], 300.0)
			_from[k] = from
			var d := Vector2(rod_xs[k], rod_ground[k]) - from
			var fl := BalanceWorld9.ROD_FLIGHT
			_vels[k] = Vector2(d.x / fl, d.y / fl - 0.5 * BalanceCombat.MORTAR_GRAVITY * fl)
			rod.visible = true
			Sfx.play(&"fire_enemy") # 占位：出针暂用敌枪声
		if land_t[k] < 0.0:
			if lt >= BalanceWorld9.ROD_FLIGHT:
				rod.position = Vector2(rod_xs[k], rod_ground[k])
				land_t[k] = age
				_rings[k].visible = true
				_rings[k].position = tip(k)
				var container := get_tree().get_first_node_in_group("projectile_container")
				if container != null:
					var spark := HIT_BURST.instantiate() as Node2D
					container.add_child(spark)
					spark.position = Vector2(rod_xs[k], rod_ground[k] - 4.0)
					spark.scale = Vector2(0.4, 0.4)
			else:
				rod.position = _from[k] + _vels[k] * lt \
						+ Vector2(0.0, 0.5 * BalanceCombat.MORTAR_GRAVITY * lt * lt)
		elif discharge_t[k] < 0.0:
			# 充能环渐急（二段预警）：越近放电越亮越快
			var dt := _discharge_time(k)
			var u := clampf((age - land_t[k]) / maxf(dt - land_t[k], 0.01), 0.0, 1.0)
			_rings[k].modulate.a = 0.25 + 0.75 * u * (0.6 + 0.4 * sin(age * (8.0 + 40.0 * u)))
			_rings[k].scale = Vector2.ONE * (1.0 + 0.25 * u)
	# 放电：按序跳
	if _next < _rods.size() and age >= _discharge_time(_next) and land_t[_next] >= 0.0:
		_discharge(_next)
		_next += 1
	_tick_arcs(delta)
	if _next >= _rods.size() and _arcs.is_empty():
		if _done_t < 0.0:
			_done_t = age
		modulate.a = clampf(1.0 - (age - _done_t) * 4.0, 0.0, 1.0)
		if modulate.a <= 0.0:
			queue_free()


func _discharge(k: int) -> void:
	discharge_t[k] = age
	var a: Vector2
	if k == 0:
		a = _muzzle.global_position if is_instance_valid(_muzzle) else tip(0) + Vector2(400, -200)
	else:
		a = tip(k - 1)
		_rods[k - 1].modulate = Color(0.55, 0.52, 0.6, 0.85) # 电走过=熄灭
		_rings[k - 1].visible = false
	var b := tip(k)
	var glow := Line2D.new()
	glow.width = 12.0
	glow.default_color = Color(RodChain.glow_color(), 0.5)
	glow.points = _jag(a, b)
	add_child(glow)
	var core := Line2D.new()
	core.width = 3.0
	core.default_color = RodChain.core_color()
	core.points = glow.points
	add_child(core)
	_arcs.append({"a": a, "b": b, "t": 0.0, "hit": false, "glow": glow, "core": core})
	# 底爆：贴地 GroundBlast r90（判定一次）
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var blast := GroundBlast.new()
		blast.damage = BalanceWorld9.ROD_BURST_DAMAGE
		blast.radius = BalanceWorld9.ROD_BURST_RADIUS
		blast.flash_color = Color(0.86, 0.78, 1.0, 0.6)
		blast.position = Vector2(rod_xs[k], rod_ground[k])
		container.add_child(blast)
		blast.reset_physics_interpolation()
	Sfx.play(&"boom_enemy") # 占位：放电暂用敌爆声
	if k == _rods.size() - 1:
		_rods[k].modulate = Color(0.55, 0.52, 0.6, 0.85)
		_rings[k].visible = false


## 弧的视觉折线（判定仍按 a→b 直线段；折点偏移 ≤5px 落在判定半厚内）。
func _jag(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 8
	var nrm := (b - a).orthogonal().normalized()
	for i in n + 1:
		var u := float(i) / n
		var off := 0.0 if i == 0 or i == n else randf_range(-5.0, 5.0)
		pts.append(a.lerp(b, u) + nrm * off)
	return pts


func _tick_arcs(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	for i in range(_arcs.size() - 1, -1, -1):
		var arc: Dictionary = _arcs[i]
		if not arc["hit"] and player != null and not player.is_dead() \
				and LiveSpan.segment_hits_player(arc["a"], arc["b"], player.global_position,
						BalanceWorld9.ROD_ARC_HALF_THICK):
			arc["hit"] = true
			player.take_damage(BalanceWorld9.ROD_ARC_DAMAGE)
			player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 0.6)
		arc["t"] = float(arc["t"]) + delta
		var a := clampf(1.0 - float(arc["t"]) / BalanceWorld9.ROD_ARC_LIFE, 0.0, 1.0)
		(arc["glow"] as Line2D).modulate.a = 0.4 + 0.6 * a
		(arc["core"] as Line2D).modulate.a = 0.5 + 0.5 * a
		if float(arc["t"]) >= BalanceWorld9.ROD_ARC_LIFE:
			(arc["glow"] as Line2D).queue_free()
			(arc["core"] as Line2D).queue_free()
			_arcs.remove_at(i)
