class_name BossConductor
extends PursuitBoss
## 第九章 BOSS·浮空巡线舰「引雷」（雷暴线场守卫）：追击框架能力层——「架线与引雷」。
## 门型横担机体（前臂绝缘子串俯仰真瞄=敌基类 ArmPivot 驱动，末端放电球=Muzzle；
## 腹舱双桩口 BayPort；背部三孔 RodPorts；锚点账=bake_storm_units.py 头注）：
##   跨缆网（技能A）：BayPort 预警（t=0 同帧采样 lead，R13）→ 跨缆 LiveSpan：p1 一套、
##     高/低每轮交替；p2 两段固定先高后低（第二段 x1′=第一段末端+360，带电晚 0.6）——
##     读法链「先钻，后飞」；
##   引雷针链（技能B）：RodPorts 逐孔 ThreatFlash → RodChain 出针一列（针1=px+clamp(
##     vx·1.95,−300,1170)，间距 300）→ 充能 → Muzzle→针1 主弧、针→针跳弧+底爆——
##     罚跳（弧带 h∈[112,128]）、罚贴针停（底爆 r90）、罚满速直冲（压针2 底爆）；
##     解=贴地刹进缝或停针列前；
##   断缆甩弧（普攻=单发点放）：arc_lash.tscn=bullet.gd 纯换皮，朝玩家**出手瞬间**
##     中心（无预判无逐发跟踪），p2 双发各自重瞄——「罚停留」：满速保持前跑在
##     ~x_p+615 处从弹线下钻过（R11），静止/刹停吃 12，纯跳可越。不挂 ThreatFlash。
## 分工账：A 管「读高度」（钻或飞），B 管「读缝」（贴地停进缝/停针列前），普攻把
## 停下的人捞出来——两技能把玩家按在贴地层、普攻逼他别停。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架。数值全在 BalanceWorld9。

const ST_SPAN_WARN := 3
const ST_SPAN_FIRE := 4
const ST_ROD := 5
const ST_DIRECT := 6

const ARC_LASH := preload("res://scenes/weapons/arc_lash.tscn")

var _span_high_first := true   # p1 高/低轮换旗标
var _span_plans: Array[Dictionary] = []
var _lash_fired := 0
var _direct_shoot_t := 0.0

@onready var _bay_warn: ThreatFlash = $Visuals/BayPort/ThreatFlash
@onready var _bay_flash: MuzzleFlash = $Visuals/BayPort/Flash
@onready var _rod_ports: Array[Node2D] = [
	$Visuals/RodPort1 as Node2D,
	$Visuals/RodPort2 as Node2D,
	$Visuals/RodPort3 as Node2D,
]
@onready var _rod_warns: Array[ThreatFlash] = [
	$Visuals/RodPort1/ThreatFlash as ThreatFlash,
	$Visuals/RodPort2/ThreatFlash as ThreatFlash,
	$Visuals/RodPort3/ThreatFlash as ThreatFlash,
]
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


func _display_name() -> String:
	return "引雷"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld9.CONDUCTOR_HOVER_Y # 机体 280..460，对最高台阶 536 净空 76


func on_spawned() -> void:
	super()
	_span_high_first = true
	_span_plans.clear()


## 双举升喷口装饰紫呼吸；前臂俯仰由基类瞄准层驱动。
func _tick_visual(_delta: float) -> void:
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = 0.4 + 0.22 * sin(_bob_t * 11.0 + i * 2.3)
		t.scale = Vector2.ONE * (0.95 + 0.15 * sin(_bob_t * 8.0 + i * 1.9))


## ---- 技能 A：跨缆网 ----

func _begin_skill_a() -> void:
	_bstate = ST_SPAN_WARN
	_bt = BalanceWorld9.LIVE_SPAN_WARN
	_plan_spans()
	_bay_warn.warn()


## t=0 采样 lead（R13）+ 规划落位（R6/R7/同台）。p2 第二段从第一段末端 +360 起规划，
## 放不进就只出第一段；第一段落空则整招只剩预警（照常收势）。
func _plan_spans() -> void:
	_span_plans.clear()
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if player == null:
		return
	var lead := clampf(player.velocity.x * BalanceWorld9.LIVE_SPAN_LEAD_TIME,
			BalanceWorld9.LIVE_SPAN_LEAD_MIN, BalanceWorld9.LIVE_SPAN_LEAD_MAX)
	var base := player.global_position.x - BalanceWorld9.LIVE_SPAN_LENGTH * 0.5 + lead
	var first := LiveSpan.plan_x1(get_tree(), terrain, base)
	if first.is_empty():
		return
	first["lead_x1"] = base
	first["delay"] = float(first["shift"]) / BalanceWorld9.LIVE_SPAN_SHIFT_SPEED
	if _phase2:
		first["h"] = BalanceWorld9.LIVE_SPAN_HIGH_H
	else:
		first["h"] = BalanceWorld9.LIVE_SPAN_HIGH_H if _span_high_first else BalanceWorld9.LIVE_SPAN_LOW_H
		_span_high_first = not _span_high_first
	_span_plans.append(first)
	if _phase2:
		var base2 := float(first["x1"]) + BalanceWorld9.LIVE_SPAN_LENGTH + BalanceWorld9.CONDUCTOR_SPAN_P2_GAP
		var second := LiveSpan.plan_x1(get_tree(), terrain, base2)
		if not second.is_empty():
			second["lead_x1"] = base2
			second["h"] = BalanceWorld9.LIVE_SPAN_LOW_H
			second["delay"] = BalanceWorld9.CONDUCTOR_SPAN_P2_LIVE_DELAY \
					+ float(first["shift"]) / BalanceWorld9.LIVE_SPAN_SHIFT_SPEED \
					+ float(second["shift"]) / BalanceWorld9.LIVE_SPAN_SHIFT_SPEED
			_span_plans.append(second)


func _launch_spans() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var from := ($Visuals/BayPort as Node2D).global_position
	for plan in _span_plans:
		var span := LiveSpan.new()
		span.damage = BalanceWorld9.LIVE_SPAN_DAMAGE
		span.owner_id = get_instance_id()
		span.shift = plan["shift"]
		span.lead_x1 = plan["lead_x1"]
		span.extra_delay = plan["delay"]
		container.add_child(span)
		span.launch(terrain, from, float(plan["x1"]), float(plan["h"]))
	if not _span_plans.is_empty():
		_bay_flash.fire(PI * 0.5)
		Sfx.play(&"fire_enemy") # 占位：桩口出膛暂用敌枪声


## ---- 技能 B：引雷针链 ----

func _rod_count() -> int:
	return BalanceWorld9.ROD_COUNT + (BalanceWorld9.ROD_P2_BONUS if _phase2 else 0) \
			+ RunState.ladder_bullets_extra()


## 针位规划（R12 lead + R7 避让：重叠后移 +300 重试一次，仍重叠取消该针）。
func plan_rod_xs(px: float, vx: float) -> Array[float]:
	var xs: Array[float] = []
	var x := px + clampf(vx * BalanceWorld9.ROD_LEAD_TIME,
			BalanceWorld9.ROD_LEAD_MIN, BalanceWorld9.ROD_LEAD_MAX)
	for k in _rod_count():
		var pad := BalanceWorld9.ROD_SCAFFOLD_PAD
		if LiveSpan.scaffold_overlaps(get_tree(), x - pad, x + pad):
			x += BalanceWorld9.ROD_SPACING
			if LiveSpan.scaffold_overlaps(get_tree(), x - pad, x + pad):
				x += BalanceWorld9.ROD_SPACING
				continue
		xs.append(x)
		x += BalanceWorld9.ROD_SPACING
	return xs


func _begin_skill_b() -> void:
	_bstate = ST_ROD
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	var hop := BalanceWorld9.ROD_P2_HOP if _phase2 else BalanceWorld9.ROD_HOP
	var n := _rod_count()
	_bt = BalanceWorld9.ROD_WARN + BalanceWorld9.ROD_FLIGHT + BalanceWorld9.ROD_CHARGE \
			+ hop * (n - 1) + BalanceWorld9.ROD_ARC_LIFE + 0.2 # 全事件链窗口
	for w in _rod_warns:
		w.warn() # 逐孔出针前的真实口位预警（R2）
	if player == null or container == null:
		return
	var xs := plan_rod_xs(player.global_position.x, player.velocity.x)
	if xs.is_empty():
		return
	var chain := RodChain.new()
	container.add_child(chain)
	chain.setup(terrain, _rod_ports, _muzzle, xs, hop)


## ---- 普攻：断缆甩弧 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_lash_fired = 0
	_direct_shoot_t = BalanceWorld9.ARC_LASH_DELAY
	_bt = BalanceWorld9.ARC_LASH_DELAY \
			+ (_lash_count() - 1) * BalanceWorld9.ARC_LASH_TWIN_GAP + 0.2


func _lash_count() -> int:
	return 1 + (BalanceWorld9.ARC_LASH_P2_BONUS if _phase2 else 0)


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_SPAN_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_launch_spans()
				_bstate = ST_SPAN_FIRE
				var tail := 0.0
				for plan in _span_plans:
					tail = maxf(tail, float(plan["delay"]))
				# 出膛后全事件链：飞 0.7 + idle 0.3 + 爬电 0.6 + 带电 1.0 + 补时
				_bt = BalanceWorld9.LIVE_SPAN_FLIGHT + BalanceWorld9.LIVE_SPAN_IDLE \
						+ BalanceWorld9.LIVE_SPAN_CRAWL + BalanceWorld9.LIVE_SPAN_LIVE + tail
		ST_SPAN_FIRE:
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld9.CONDUCTOR_SPAN_RECOVER)
		ST_ROD:
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld9.CONDUCTOR_ROD_RECOVER)
		ST_DIRECT:
			_bt -= delta
			_direct_shoot_t -= delta
			if _lash_fired < _lash_count() and _direct_shoot_t <= 0.0:
				var player := get_tree().get_first_node_in_group("player") as Player
				if player != null:
					fire_lash(_muzzle.global_position.direction_to(player.global_position))
				_lash_fired += 1
				_direct_shoot_t = BalanceWorld9.ARC_LASH_TWIN_GAP
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)


## 断缆甩弧单发：放电球真实源点出膛、方向锁定出手瞬间（探针也走这个入口）。
func fire_lash(dir: Vector2) -> Bullet:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return null
	var from := _muzzle.global_position
	var b := ARC_LASH.instantiate() as Bullet
	b.speed = BalanceWorld9.ARC_LASH_SPEED
	b.damage = BalanceWorld9.ARC_LASH_DAMAGE
	b.impact_tint = Color(0.86, 0.78, 1.0)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = from
	b.reset_physics_interpolation()
	var bloom := FlashBurst.new()
	bloom.flash_color = Color(0.79, 0.65, 1.0)
	bloom.size_scale = 0.6
	bloom.position = from
	container.add_child(bloom)
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_heavy") # 占位：出膛音先用 fire_heavy
	return b


## 压招期间断掉的预警，回距重走完整程（预警只认发射器，压掉的半截不算数）。
## 跨缆预警重走时 lead 一并重采（t=0 原点随预警重开，R13）。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_SPAN_WARN:
			_bt = BalanceWorld9.LIVE_SPAN_WARN
			_plan_spans()
			_bay_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_bay_warn.reset()
	for w in _rod_warns:
		w.reset()
