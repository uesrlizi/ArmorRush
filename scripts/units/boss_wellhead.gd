class_name BossWellhead
extends PursuitBoss
## 第十章 BOSS·井场管线母舰「井口」（硫焰地热田守卫）：追击框架能力层——「井口与硫云」。
## 一座飞着的井场平台（锚点账=bake_sulfur_units.py 头注）：艏部井口喷嘴 NozzlePort
## (−146,54)=世界 y424、腹舱钻杆井口 DrillPort (0,78)、艉部排烟囱口 VentPort (96,−44)；
## 甲板井架吊杆=ArmPivot（敌基类俯仰层驱动，无发光口、不出弹）。
##   井压线（技能A）：DrillPort ThreatFlash 0.6（t=0 同帧采样 lead）→ 钻头出膛 → 纵队
##     SulfurVent 3 口（p2 4 口）xk = xv + k·360，xv = px + clamp(vx·2.4, 240, 1440)；
##     第 k 口首喷 2.3+0.6k、每口 3 喷；R10 每口独立避让，取消的口留空不重排——
##     读法链「刹第一口、读息喷节拍、绿波穿线」；
##   硫云爆燃（技能B）：VentPort ThreatFlash 0.6 → 硫气弹 → 固定带 y∈[428,512]、
##     [xL, xL+1000]（xL = px + clamp(vx·1.0, 0, 600)）1.8 自右端点燃、火锋 2500px/s 左推、
##     2.4 燃完——罚 tier2 站立与 tier1 起跳；派招闸 R7（带内 tier2 累计 ≥320）+ R16
##     （tier2 与受罚区间 I 交集 ≥40），不满足改派 A 且 B 冷却不消耗；
##   硫焰扫掠（普攻）：NozzlePort 出手锁定 7 团（p2 8 团）近水平分层火鞭，全部穿过出手瞬间
##     玩家中心 x、到靶高 h=210..0（down/up 交替），R9 逐发 16px 采样校平（抬 6°×≤2，仍埋哑火）——
##     读法：出手时人在跑就继续跑，停下/站在出手点=吃。不挂 ThreatFlash。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架。数值全在 BalanceWorld10。

const ST_VENT_WARN := 3
const ST_VENT_FIRE := 4
const ST_CLOUD_WARN := 5
const ST_CLOUD_FIRE := 6
const ST_SWEEP := 7

const FLARE_PUFF := preload("res://scenes/weapons/flare_puff.tscn")

## 探针开关（R16）：绕过 B 派招闸，只给 scenes/previews 探针用；常规运行恒为 false。
var force_cast_b := false
## 探针读数：B 实际派出 / 被闸改派 A 的次数。
var cloud_cast_count := 0
var cloud_gated_count := 0
var last_cloud_xl := NAN

var _vent_plans: Array[Dictionary] = []
var _cloud_xl := 0.0
var _sweep_plan: Array[Dictionary] = []   # {t, dir, h}；dir=Vector2.ZERO 表示哑火
var _sweep_from := Vector2.ZERO
var _sweep_t := 0.0
var _sweep_fired := 0
var _sweep_down := true
var sweep_duds := 0                      # 探针读数：最近一轮哑火数
var sweep_lifts: Array[int] = []         # 探针读数：最近一轮各发抬角次数（−1=哑火）

@onready var _nozzle: Node2D = $Visuals/NozzlePort
@onready var _nozzle_flash: MuzzleFlash = $Visuals/NozzlePort/Flash
@onready var _drill_port: Node2D = $Visuals/DrillPort
@onready var _drill_warn: ThreatFlash = $Visuals/DrillPort/ThreatFlash
@onready var _drill_flash: MuzzleFlash = $Visuals/DrillPort/Flash
@onready var _vent_port: Node2D = $Visuals/VentPort
@onready var _vent_warn: ThreatFlash = $Visuals/VentPort/ThreatFlash
@onready var _vent_flash: MuzzleFlash = $Visuals/VentPort/Flash
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


func _display_name() -> String:
	return "井口"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld10.WELLHEAD_HOVER_Y # 机体 280..460，对最高台阶 536 净空 76


func on_spawned() -> void:
	super()
	_vent_plans.clear()
	_sweep_plan.clear()
	_sweep_down = true


## 双举升喷口硫焰蓝呼吸；井架吊杆俯仰由基类瞄准层驱动。
func _tick_visual(_delta: float) -> void:
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = 0.4 + 0.22 * sin(_bob_t * 11.0 + i * 2.3)
		t.scale = Vector2.ONE * (0.95 + 0.15 * sin(_bob_t * 8.0 + i * 1.9))


func _player_node() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _terrain_node() -> Terrain:
	return get_tree().get_first_node_in_group("terrain") as Terrain


## ---- 技能 A：井压线 ----

func vent_count_for_phase() -> int:
	return BalanceWorld10.WELLHEAD_VENT_COUNT \
			+ (BalanceWorld10.WELLHEAD_VENT_P2_BONUS if _phase2 else 0)


func _begin_skill_a() -> void:
	_bstate = ST_VENT_WARN
	_bt = BalanceWorld10.VENT_WARN
	_plan_vents()
	_drill_warn.warn()


## t=0 采样 lead + 逐口 R10 避让（取消的口留空，其余口保持原 k）。
func _plan_vents() -> void:
	_vent_plans.clear()
	var player := _player_node()
	if player == null:
		return
	var xv := player.global_position.x + clampf(
			player.velocity.x * BalanceWorld10.VENT_LEAD_TIME,
			BalanceWorld10.VENT_LEAD_MIN, BalanceWorld10.VENT_LEAD_MAX)
	for k in vent_count_for_phase():
		var lead := xv + k * BalanceWorld10.VENT_PITCH
		var x := SulfurVent.plan_x(get_tree(), lead)
		if is_nan(x):
			continue
		_vent_plans.append({"k": k, "x": x, "lead": lead})


func _launch_vents() -> void:
	var terrain := _terrain_node()
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var from := _drill_port.global_position
	for plan in _vent_plans:
		var v := SulfurVent.new()
		v.damage = BalanceWorld10.VENT_DAMAGE
		v.pulses = BalanceWorld10.VENT_PULSES
		v.owner_id = get_instance_id()
		v.k_index = int(plan["k"])
		v.lead_x = float(plan["lead"])
		container.add_child(v)
		var x := float(plan["x"])
		var g := terrain.surface_y_at(x) if terrain != null else 600.0
		v.launch(from, x, g)
	if not _vent_plans.is_empty():
		_drill_flash.fire(PI * 0.5)
		Sfx.play(&"fire_enemy") # 占位：钻头出膛暂用敌枪声


## ---- 技能 B：硫云爆燃 ----

## 区间 [a,b] 内 tier2(g=536) 地块的累计宽度（按 320 宽地块逐块求交）。
func tier2_width(a: float, b: float) -> float:
	var terrain := _terrain_node()
	if terrain == null or b <= a:
		return 0.0
	var w := BalanceWorld10.VENT_CHUNK_W
	var total := 0.0
	var i := floori(a / w)
	while i * w < b:
		var lo := maxf(a, i * w)
		var hi := minf(b, (i + 1) * w)
		if hi > lo and is_equal_approx(terrain.surface_y_at(i * w + w * 0.5),
				BalanceWorld10.SULFUR_CLOUD_TIER2_Y):
			total += hi - lo
		i += 1
	return total


## 派招闸 R7+R16 的判定量（探针也读这个）：{xl, xr, t_star, i_lo, i_hi, band_w, pen_w, ok}。
func cloud_gate(px: float, vx: float) -> Dictionary:
	var v := clampf(vx, 0.0, BalanceWorld10.SULFUR_CLOUD_LEAD_MAX)
	var lead := clampf(vx * BalanceWorld10.SULFUR_CLOUD_LEAD_TIME, 0.0, BalanceWorld10.SULFUR_CLOUD_LEAD_MAX)
	var xl := px + lead
	var xr := xl + BalanceWorld10.SULFUR_CLOUD_SPAN
	var xr_rel := lead + BalanceWorld10.SULFUR_CLOUD_SPAN
	var t0 := BalanceWorld10.SULFUR_CLOUD_IGNITE
	var fs := BalanceWorld10.SULFUR_CLOUD_FRONT_SPEED
	var t_star := (xr_rel + fs * t0) / (v + fs)
	var pad := BalanceWorld10.SULFUR_CLOUD_PENALTY_PAD
	var i_lo := px + v * t_star - pad
	var i_hi := px + v * (t0 + BalanceWorld10.SULFUR_CLOUD_BURN) + pad
	var band_w := tier2_width(xl, xr)
	var pen_w := tier2_width(i_lo, i_hi)
	return {
		"xl": xl, "xr": xr, "t_star": t_star, "i_lo": i_lo, "i_hi": i_hi,
		"band_w": band_w, "pen_w": pen_w,
		"ok": band_w >= BalanceWorld10.SULFUR_CLOUD_TIER2_MIN_WIDTH
				and pen_w >= BalanceWorld10.SULFUR_CLOUD_PENALTY_MIN_WIDTH,
	}


func _begin_skill_b() -> void:
	var player := _player_node()
	if player == null:
		_enter_recover(BalanceWorld10.WELLHEAD_CLOUD_RECOVER)
		return
	var gate := cloud_gate(player.global_position.x, player.velocity.x)
	if not bool(gate["ok"]) and not force_cast_b:
		# 改派 A，B 冷却不消耗：把轮换旗标拨回，下一次技能仍轮到 B
		cloud_gated_count += 1
		_skill_flip = true
		_begin_skill_a()
		_skill_flip = true
		return
	_bstate = ST_CLOUD_WARN
	_bt = BalanceWorld10.SULFUR_CLOUD_WARN
	_cloud_xl = float(gate["xl"])
	_vent_warn.warn()


func _launch_cloud() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var c := SulfurCloud.new()
	c.damage = BalanceWorld10.SULFUR_CLOUD_DAMAGE
	container.add_child(c)
	c.launch(_vent_port.global_position, _cloud_xl)
	cloud_cast_count += 1
	last_cloud_xl = _cloud_xl
	_vent_flash.fire(-PI * 0.5)
	Sfx.play(&"fire_enemy") # 占位：硫气弹出膛暂用敌枪声


## ---- 普攻：硫焰扫掠 ----

func sweep_heights() -> Array[float]:
	var hs: Array[float] = []
	if _phase2 and BalanceWorld10.FLARE_SWEEP_P2_BONUS > 0:
		hs.append(BalanceWorld10.FLARE_SWEEP_H_TOP + BalanceWorld10.FLARE_SWEEP_H_STEP)
	for i in BalanceWorld10.FLARE_SWEEP_PUFFS:
		hs.append(BalanceWorld10.FLARE_SWEEP_H_TOP - i * BalanceWorld10.FLARE_SWEEP_H_STEP)
	return hs


## R9 逐发校平：从 from 沿 dir 每 16px 采样直到越过靶 x，任一点埋入地表 → 返回 false。
static func ray_clear(terrain: Terrain, from: Vector2, dir: Vector2, target_x: float) -> bool:
	if terrain == null:
		return true
	var step := BalanceWorld10.FLARE_SWEEP_SAMPLE
	var dist := 0.0
	while true:
		dist += step
		var p := from + dir * dist
		if (dir.x < 0.0 and p.x < target_x) or (dir.x >= 0.0 and p.x > target_x):
			break
		if p.y > terrain.surface_y_at(p.x) + 0.5:
			return false
		if dist > 6000.0:
			break
	return true


## 出手锁定（探针也走这个入口）：返回 [{t, dir, h, lifts}]（dir=ZERO 即哑火）。
func plan_sweep(from: Vector2, px: float, down: bool) -> Array[Dictionary]:
	var terrain := _terrain_node()
	var g := terrain.surface_y_at(px) if terrain != null else 600.0
	var hs := sweep_heights()
	if not down:
		hs.reverse()
	var out: Array[Dictionary] = []
	for i in hs.size():
		var tgt := Vector2(px, g - hs[i])
		var d := from.direction_to(tgt)
		var sx := signf(d.x) if d.x != 0.0 else -1.0
		var pitch := atan2(d.y, absf(d.x))
		var lifts := 0
		while not ray_clear(terrain, from, d, px):
			if lifts >= BalanceWorld10.FLARE_SWEEP_LIFT_MAX:
				d = Vector2.ZERO
				lifts = -1
				break
			lifts += 1
			pitch -= deg_to_rad(BalanceWorld10.FLARE_SWEEP_LIFT_DEG)
			d = Vector2(sx * cos(pitch), sin(pitch))
		out.append({"t": BalanceWorld10.FLARE_SWEEP_DELAY + i * BalanceWorld10.FLARE_SWEEP_GAP,
				"dir": d, "h": hs[i], "lifts": lifts})
	return out


func _begin_direct() -> void:
	_bstate = ST_SWEEP
	var player := _player_node()
	_sweep_from = _nozzle.global_position
	_sweep_plan.clear()
	sweep_lifts.clear()
	sweep_duds = 0
	if player != null:
		_sweep_plan = plan_sweep(_sweep_from, player.global_position.x, _sweep_down)
		for p in _sweep_plan:
			sweep_lifts.append(int(p["lifts"]))
			if int(p["lifts"]) < 0:
				sweep_duds += 1
	_sweep_down = not _sweep_down
	_sweep_t = 0.0
	_sweep_fired = 0
	_bt = BalanceWorld10.FLARE_SWEEP_DELAY \
			+ maxi(_sweep_plan.size() - 1, 0) * BalanceWorld10.FLARE_SWEEP_GAP + 0.2


func _fire_puff(dir: Vector2) -> Bullet:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return null
	var b := FLARE_PUFF.instantiate() as Bullet
	b.speed = BalanceWorld10.FLARE_SWEEP_SPEED
	b.damage = BalanceWorld10.FLARE_SWEEP_DAMAGE
	b.impact_tint = Color(0.78, 0.92, 1.0)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = _sweep_from
	b.reset_physics_interpolation()
	_nozzle_flash.fire(dir.angle())
	return b


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_VENT_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_launch_vents()
				_bstate = ST_VENT_FIRE
				var last_k := 0
				for plan in _vent_plans:
					last_k = maxi(last_k, int(plan["k"]))
				# 出膛后全事件链：到末口熄灭（首喷 2.3+0.6k，+2.85）减去已过的 0.6 预警
				_bt = BalanceWorld10.VENT_FLIGHT + BalanceWorld10.VENT_BURROW \
						+ BalanceWorld10.VENT_FIRST_LIT + BalanceWorld10.VENT_STAGGER * last_k \
						+ 2.0 * (BalanceWorld10.VENT_FLARE_ON + BalanceWorld10.VENT_FLARE_OFF) \
						+ BalanceWorld10.VENT_FLARE_ON
		ST_VENT_FIRE:
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld10.WELLHEAD_RECOVER)
		ST_CLOUD_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_launch_cloud()
				_bstate = ST_CLOUD_FIRE
				_bt = BalanceWorld10.SULFUR_CLOUD_IGNITE + BalanceWorld10.SULFUR_CLOUD_BURN \
						- BalanceWorld10.SULFUR_CLOUD_WARN + 0.2
		ST_CLOUD_FIRE:
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld10.WELLHEAD_CLOUD_RECOVER)
		ST_SWEEP:
			_bt -= delta
			_sweep_t += delta
			while _sweep_fired < _sweep_plan.size() \
					and _sweep_t >= float(_sweep_plan[_sweep_fired]["t"]):
				var d: Vector2 = _sweep_plan[_sweep_fired]["dir"]
				if d != Vector2.ZERO:
					_fire_puff(d)
				_sweep_fired += 1
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)


## 压招期间断掉的预警，回距重走完整程（预警只认发射器）；lead 随 t=0 原点一并重采。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_VENT_WARN:
			_bt = BalanceWorld10.VENT_WARN
			_plan_vents()
			_drill_warn.warn()
		ST_CLOUD_WARN:
			var player := _player_node()
			if player != null:
				_cloud_xl = float(cloud_gate(player.global_position.x, player.velocity.x)["xl"])
			_bt = BalanceWorld10.SULFUR_CLOUD_WARN
			_vent_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_drill_warn.reset()
	_vent_warn.reset()
