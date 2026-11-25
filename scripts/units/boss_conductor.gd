class_name BossConductor
extends PursuitBoss
## 第九章 BOSS·浮空电塔「引雷」（雷暴线场守卫）：追击框架能力层——「布珠与引雷」。
## 横担桁架机体（前部**固定天线桅**=出弹源：天线不俯仰（覆写 _arm_tracks_pitch=false），
## 桅顶电珠=Muzzle；腹舱双桩口 BayPort；背部三孔 RodPorts；锚点账=gen_boss_forms.py
## 头注；座裙双电紫火箭焰，2026-11-11 八轮换装）——攻击全走球状闪电语汇，机体上无电线/绝缘子读法：
##   跨缆网（技能A）：BayPort 预警（t=0 同帧采样 lead，R13）→ 跨缆 LiveSpan：p1 一套、
##     高/低每轮交替；p2 两段固定先高后低（第二段 x1′=第一段末端+360，带电晚 0.6）——
##     读法链「先钻，后飞」；落点全放不下先回退采样（玩家当前 x 一组），仍空=整招
##     取消不亮预警（先检空再预警：空计划亮预警=「看起来没发出来」的根因）；
##   引雷针链（技能B）：先规划后预警——RodPorts 逐孔 ThreatFlash → RodChain 出珠列
##     （珠1=px+clamp(vx·1.95,−300,1170)，间距 300）→ 充能 → 天线顶→珠1 主弧、
##     珠→珠跳弧+底爆——罚跳（弧带 h∈[112,128]）、罚贴珠停（底爆 r90）、罚满速直冲
##     （压珠2 底爆）；解=贴地刹进缝或停珠列前；规划空同样回退采样、仍空=取消不预警；
##   断缆甩弧（普攻=单发点放）：arc_lash.tscn=bullet.gd 纯换皮（闪电球贴图），
##     朝玩家**出手瞬间**中心（无预判无逐发跟踪），出手前天线顶放电一闪（FlashBurst
##     预备拍，时长=ARC_LASH_DELAY），p2 双发各自重瞄——「罚停留」：满速保持前跑
##     从弹线下钻过（R11），静止/刹停吃 12，纯跳可越。不挂 ThreatFlash。
## 分工账：A 管「读高度」（钻或飞），B 管「读缝」（贴地停进缝/停珠列前），普攻把
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


func _display_name() -> String:
	return "引雷"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld9.CONDUCTOR_HOVER_Y # 机体 280..460，对最高台阶 536 净空 76


## 固定天线桅：出弹源=桅顶电珠，不做可动瞄准（垂发架先例）——基类瞄准层每帧把
## ArmPivot 回正，甩弧/针链主弧方向由出手瞬间的 direction_to 现算。
func _arm_tracks_pitch() -> bool:
	return false


func on_spawned() -> void:
	super()
	_span_high_first = true
	_span_plans.clear()


## ---- 技能 A：跨缆网 ----

## 先规划后预警：plans 空（lead+回退两档都放不下）=整招取消直接回后摇，一个预警
## 都不亮——「亮了预警却什么都不来」会被读成「这招没发出来」，宁不出手。
func _begin_skill_a() -> void:
	_plan_spans()
	if _span_plans.is_empty():
		_enter_recover(BalanceWorld9.CONDUCTOR_SPAN_RECOVER)
		return
	_bstate = ST_SPAN_WARN
	_bt = BalanceWorld9.LIVE_SPAN_WARN
	_bay_warn.warn()


## t=0 采样 lead（R13）+ 规划落位（R6/R7/同台）。p2 第二段从第一段末端 +360 起规划，
## 放不进就只出第一段；第一段 lead 位放不下时回退采样（玩家当前 x 居中一组，节奏/
## 跨度参数不变，只是落点多一档），仍空=返回空 plans 由调用方取消整招。
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
	var used_base := base
	if first.is_empty():
		used_base = player.global_position.x - BalanceWorld9.LIVE_SPAN_LENGTH * 0.5
		first = LiveSpan.plan_x1(get_tree(), terrain, used_base)
		if first.is_empty():
			return
	first["lead_x1"] = used_base # 实际采用的规划原点（回退档时=玩家当前 x 居中）
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
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or container == null:
		return
	# 先规划后预警（顺序是读法命案）：预警亮在前而 xs 空=亮着预警却不来珠列，
	# 玩家读作「这招没发出来」。xs 空先回退采样（lead 位不行就试玩家当前 x 直落
	# 一组，节奏/间距参数不变）；仍空=本招取消回 RECOVER，一个预警都不亮。
	var xs := plan_rod_xs(player.global_position.x, player.velocity.x)
	if xs.is_empty():
		xs = plan_rod_xs(player.global_position.x, 0.0)
	if xs.is_empty():
		_enter_recover(BalanceWorld9.CONDUCTOR_ROD_RECOVER)
		return
	_bstate = ST_ROD
	var hop := BalanceWorld9.ROD_P2_HOP if _phase2 else BalanceWorld9.ROD_HOP
	var n := _rod_count()
	_bt = BalanceWorld9.ROD_WARN + BalanceWorld9.ROD_FLIGHT + BalanceWorld9.ROD_CHARGE \
			+ hop * (n - 1) + BalanceWorld9.ROD_ARC_LIFE + 0.2 # 全事件链窗口
	for w in _rod_warns:
		w.warn() # 逐孔出珠前的真实口位预警（R2）
	var chain := RodChain.new()
	container.add_child(chain)
	chain.setup(terrain, _rod_ports, _muzzle, xs, hop)


## ---- 普攻：断缆甩弧 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_lash_fired = 0
	_direct_shoot_t = BalanceWorld9.ARC_LASH_DELAY
	# 预备拍（ARC_LASH_DELAY 注释的「放电球一闪」）：出手前天线顶电珠先闪一下
	# （FlashBurst 紫放电语汇，纯视觉零判定；普攻不挂红色 ThreatFlash=换形四家惯例），
	# 方向仍锁定出手瞬间。
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var spark := FlashBurst.new()
		spark.flash_color = Color(0.79, 0.65, 1.0)
		spark.size_scale = 0.45
		spark.position = _muzzle.global_position
		container.add_child(spark)
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


## 断缆甩弧单发：天线顶电珠真实源点出膛、方向锁定出手瞬间（探针也走这个入口）。
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
## 跨缆预警重走时 lead 一并重采（t=0 原点随预警重开，R13）；重采后落点全放不下
## 则同 _begin_skill_a 取消整招，不亮空预警。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_SPAN_WARN:
			_plan_spans()
			if _span_plans.is_empty():
				_enter_recover(BalanceWorld9.CONDUCTOR_SPAN_RECOVER)
			else:
				_bt = BalanceWorld9.LIVE_SPAN_WARN
				_bay_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_bay_warn.reset()
	for w in _rod_warns:
		w.reset()
