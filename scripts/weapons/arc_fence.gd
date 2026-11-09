class_name ArcFence
extends Node2D
## 电网闸（第六章精英「锚桩」/BOSS「赤轮」共用危险件）：两枚锚桩按解算弹道
## 落到玩家**当时位置**两侧（无 lead——「桩钉住你现在的位置」就是机制），
## 桩上火花蓄能（渐亮=二段预警）后竖直电幕立起。幕=各自桩位的竖直线段
## （贴各自当地地表，台阶两侧各贴各的），跨幕判定=点到线段距离。
## 惩罚账=提案 §2：**停=被围**（出笼触幕交税/推进飞越/等哑熄）、全速跑=
## 幕立起前出带免。触幕一次即整套溃散（同潮墙「灼烧即溃」）；寿命到点
## 哑熄（无伤）——等待永远合法。桩抛体重力=MORTAR_GRAVITY（真弹道解算，
## 落点精确，无地面校平需求：桩是抛体落点自身贴地）。
## 视觉全贴图+代码脉冲（fx 规约）：fx_red_stake.svg（桩，竖直定桩）/
## fx_red_fence.svg（幕光带纵向拉伸到幕高，亮度脉冲）/ fx_red_arcglow.svg
## （桩顶充能光斑=蓄能二段预警的主读出件——v1 整桩 alpha 脉冲在亮沙底上
## 读作「闪烁消失」已废）+ arc_curtain_fx.tscn（幕驻留电花，「电在流动」）
## + arc_spark_burst.tscn（落桩迸花/触电迸溅）。group "arc_fences"
## 供自测探针计数；预警在发射器上（ThreatFlash，见调用方）。
## 数值：伤害/半宽/幕高/蓄能/寿命/飞行=调用方按机体段注入（BalanceWorld6 的
## ELITE_PILER_FENCE_* / REDWHEEL_FENCE_*）。

const STAKE_TEXTURE := preload("res://assets/world_6/fx_red_stake.svg")
const FENCE_TEXTURE := preload("res://assets/world_6/fx_red_fence.svg")
const GLOW_TEXTURE := preload("res://assets/world_6/fx_red_arcglow.svg")
const CURTAIN_FX := preload("res://scenes/fx/arc_curtain_fx.tscn")
const HIT_BURST := preload("res://scenes/fx/arc_spark_burst.tscn")

# 真弹道同源（=MORTAR_GRAVITY：弧快不掉速）。var 非 const：autoload 值不能进
# const 表达式（解析期报错）。
var _stake_gravity: float = BalanceCombat.MORTAR_GRAVITY
const CURTAIN_RADIUS := 14.0   # 幕判定半厚（光带宽 8 的读法余量）
const MAX_LIFETIME := 8.0      # 兜底寿钟（正常按溃散/哑熄结算）

enum Phase { STAKES, WARMUP, LIVE, FADE }

var damage := 8
var half_width := 140.0
var top_height := 150.0
var warmup_time := 0.8
var lifetime := 1.6
var stake_flight := 0.5

var _phase := Phase.STAKES
var _t := 0.0
var _terrain: Terrain
var _stakes: Array[Sprite2D] = []
var _stake_vels: Array[Vector2] = []
var _glows: Array[Sprite2D] = []   # 桩顶充能光斑（WARMUP 脉冲主读出件）
var _addmat := CanvasItemMaterial.new()
var _curtains: Array[Sprite2D] = []
var _xs: Array[float] = []     # 两幕的世界 x（=桩落点）
var _tops: Array[float] = []   # 两幕的上端 y（世界）


## 先入树再调本方法。center_x=两桩的中点（玩家当时位置，调用方可带半 lead）。
func launch(terrain: Terrain, from: Vector2, center_x: float) -> void:
	_terrain = terrain
	global_position = Vector2.ZERO # 弹容器在原点：子精灵 position 即全局位
	reset_physics_interpolation() # 先入树后定位：不拖补间残影
	for side in [-1.0, 1.0]:
		var x: float = center_x + side * half_width
		var target_y := terrain.surface_y_at(x) if terrain != null else from.y
		var stake := Sprite2D.new()
		stake.texture = STAKE_TEXTURE
		add_child(stake)
		var glow := Sprite2D.new()
		glow.texture = GLOW_TEXTURE
		glow.material = _addmat
		glow.visible = false
		add_child(glow)
		var d := Vector2(x, target_y) - from
		var g := _stake_gravity
		var vel := Vector2(d.x / stake_flight, d.y / stake_flight - 0.5 * g * stake_flight)
		stake.position = from
		stake.rotation = vel.angle()
		stake.reset_physics_interpolation()
		_stakes.append(stake)
		_stake_vels.append(vel)
		_glows.append(glow)
		_xs.append(x)
		_tops.append(target_y - top_height)


func _ready() -> void:
	add_to_group("arc_fences")
	_addmat.blend_mode = 1 # 光斑走加色（energy 叠亮，平涂规约）


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.STAKES:
			for i in _stakes.size():
				var s := _stakes[i] as Sprite2D
				var v: Vector2 = _stake_vels[i]
				v.y += _stake_gravity * delta
				_stake_vels[i] = v
				s.position += v * delta
				s.rotation = v.angle()
			if _t >= stake_flight:
				_plant()
		Phase.WARMUP:
			# 桩顶充能光斑渐急脉冲（二段预警主读出件）：越接近立幕越亮越快
			# 越大；桩本体保持实心（v1 整桩 alpha 脉冲在亮沙底上=闪烁消失，废）
			var urgency := clampf(_t / warmup_time, 0.0, 1.0)
			for g in _glows:
				var glow := g as Sprite2D
				glow.modulate.a = urgency * (0.55 + 0.45 * sin(_t * (10.0 + 30.0 * urgency)))
				glow.scale = Vector2.ONE * (0.55 + 0.75 * urgency)
			if _t >= warmup_time:
				_live()
		Phase.LIVE:
			# 幕光带脉冲（频率随存活时间爬升=「还活着」的持续读法）+
			# 幕顶帽光轻脉冲呼应
			for c in _curtains:
				(c as Sprite2D).modulate.a = 0.62 + 0.38 * sin(_t * (14.0 + 10.0 * _t))
			for g in _glows:
				var glow := g as Sprite2D
				glow.modulate.a = 0.5 + 0.3 * sin(_t * 12.0)
			_tick_damage()
			if _t >= lifetime:
				_start_fade()
		Phase.FADE:
			var a := clampf(1.0 - _t * 4.0, 0.0, 1.0)
			modulate.a = a
			if a <= 0.0:
				queue_free()
	if _t >= MAX_LIFETIME:
		queue_free()


## 双桩落地：定桩（桩尖插地）→ 落点迸电花（「这桩带电」的前置教学）→
## 桩顶亮出充能光斑 → 进蓄能。
func _plant() -> void:
	_phase = Phase.WARMUP
	_t = 0.0
	for i in _stakes.size():
		var s := _stakes[i] as Sprite2D
		var ground_y := _terrain.surface_y_at(_xs[i]) if _terrain != null else s.position.y
		s.position = Vector2(_xs[i], ground_y - 4.0) # 桩尖入土 4px
		s.rotation = PI * 0.5 # 竖直定桩（贴图 +X=桩尖，转 90° 尖朝下）
		s.reset_physics_interpolation()
		var glow := _glows[i] as Sprite2D
		glow.visible = true
		glow.position = Vector2(_xs[i], ground_y - 17.0) # 桩顶（尾翼端朝上）
		glow.modulate.a = 0.0
		glow.scale = Vector2.ONE * 0.55
		var container := get_tree().get_first_node_in_group("projectile_container")
		if container != null:
			var spark := HIT_BURST.instantiate() as Node2D
			spark.position = Vector2(_xs[i], ground_y - 6.0) # 先定位再入树（OneShotFx 规矩）
			spark.scale = Vector2(0.55, 0.55)
			container.add_child(spark)
	Sfx.play(&"fire_enemy") # 占位：落桩暂用敌枪声，打桩配方后配


## 蓄能到点：双幕立起（光带从桩位拉到幕高+幕驻留电花；充能光斑转幕顶帽光）。
func _live() -> void:
	_phase = Phase.LIVE
	_t = 0.0
	for i in _stakes.size():
		var c := Sprite2D.new()
		c.texture = FENCE_TEXTURE
		var h := top_height
		c.scale = Vector2(1.0, h / 200.0) # 光带 200 高原生，纵向拉伸到幕高
		c.position = Vector2(_xs[i], _tops[i] + h * 0.5)
		c.modulate.a = 0.0
		add_child(c)
		c.reset_physics_interpolation()
		_curtains.append(c)
		# 驻留电花：全幕高矩形发射、上飘（作幕的子节点=随幕 modulate 淡出）；
		# process_material duplicate——实例化不复制子资源，直写会串到场景正本
		# （同幕高互覆无害，精英 150/BOSS 200 同屏时会串）
		var fx := CURTAIN_FX.instantiate() as GPUParticles2D
		var pm := (fx.process_material as ParticleProcessMaterial).duplicate() \
				as ParticleProcessMaterial
		pm.emission_box_extents.y = h * 0.5
		fx.process_material = pm
		c.add_child(fx)
		# 充能光斑收编为幕顶帽光（幕的能量顶点读法）
		var glow := _glows[i] as Sprite2D
		glow.position = Vector2(_xs[i], _tops[i] + 6.0)
		glow.scale = Vector2.ONE * 0.8
	Sfx.play(&"boom_enemy") # 占位：电幕立起暂用敌爆声，电弧配方后配


## 跨幕判定：点到幕线段（x, top..ground）距离 ≤ 半厚+玩家宽限 → 结算一次
## 并整套溃散（电放完了）。
func _tick_damage() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	for i in _curtains.size():
		var ground_y := _terrain.surface_y_at(_xs[i]) if _terrain != null else _tops[i] + top_height
		var a := Vector2(_xs[i], _tops[i])
		var b := Vector2(_xs[i], ground_y)
		var dist := Geometry2D.get_closest_point_to_segment(
				player.global_position, a, b).distance_to(player.global_position)
		if dist <= CURTAIN_RADIUS + 26.0:
			player.take_damage(damage)
			player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 0.8)
			var container := get_tree().get_first_node_in_group("projectile_container")
			if container != null:
				var spark := HIT_BURST.instantiate() as Node2D
				spark.position = player.global_position # 触电点迸花（结算读法；先定位再入树）
				container.add_child(spark)
			Sfx.play(&"boom_enemy") # 占位：触电暂用敌爆声
			_start_fade()
			return


func _start_fade() -> void:
	_phase = Phase.FADE
	_t = 0.0
