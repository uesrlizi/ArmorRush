class_name SulfurVent
extends Node2D
## 硫焰井口（第十章精英「窜井」/BOSS「井口」技能 A 共用核心危险件）：钻头从发射口
## 按解算弹道（MORTAR_GRAVITY）落到井位，**落地即钉住**（静止落点、零地形跟随——
## DrillCharge/SaltGeyser 同族），钻入后井口亮井层渐急，按节拍喷竖直焰柱：
##   飞行 0.7 → 钻入 0.4 → 亮井（读出期，无伤；闪烁 f=min(1/剩余到下一喷, 4)Hz，R11）
##   → 首喷 → 喷 0.45 / 息 0.75 …（BOSS 3 喷、精英 2 喷）→ 末喷收即熄灭自清。
## 判定：喷发期玩家中心距井心 ≤ 52（井半宽 32+玩家半宽 20）且脚底高度 h < 220，
## 每次喷发至多结算一次（伤 10）。焰是墙不是弹：跳≠过，钻息窗/等=过。
## 时间口径（R3）：age=0 为钻头出膛，绝对时间 t_abs = age + VENT_WARN（发射方闪光起算）。
## 落位规划（R10 档位边界避让 + 脚手架 ±104）在静态 plan_x 里，发射方先问再放。
## group "sulfur_vents" 供冷却闸（按 owner_id 计数）与探针；视觉全代码自建（.new() 件惯例）；
## 整件物理插值 OFF（钻头位置逐物理帧写）。

const TEX_BASE := preload("res://assets/world_10/fx_sulfur_vent.svg")
const TEX_GLOW := preload("res://assets/world_10/fx_sulfur_vent_glow.svg")
const TEX_FLAME := preload("res://assets/world_10/fx_sulfur_vent_flame.svg")
const TEX_DRILL := preload("res://assets/world_10/fx_sulfur_drill.svg")
const PLAYER_HALF_W := 20.0

enum Phase { FLY, BURROW, LIT, DONE }

var damage := 10
var pulses := 3
var owner_id := 0
var k_index := 0              # 纵队序号：首喷 = 2.3 + 0.6k（亮井期按 k 延长）
var lead_x := 0.0             # 避让前 lead 落点（探针读）
var age := 0.0                # 自钻头出膛起的秒数
var ground_y := 0.0           # 井位地表 g（=origin.y，落定后）
var hits := 0                 # 已结算喷发次数（探针读）

var _phase := Phase.FLY
var _from := Vector2.ZERO
var _target := Vector2.ZERO
var _vel0 := Vector2.ZERO
var _hit_pulse := -1
var _blink_phase := 0.0
var _drill: Sprite2D
var _base: Sprite2D
var _glow: Sprite2D
var _flame: Sprite2D


func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	add_to_group("sulfur_vents")


## R10：lead 落点 x → 合格井位（依次试 x、x+96、x−96）；全不合格返回 NAN=取消该口。
static func plan_x(tree: SceneTree, x: float) -> float:
	for cand in [x, x + BalanceWorld10.VENT_EDGE_RETRY, x - BalanceWorld10.VENT_EDGE_RETRY]:
		if edge_ok(cand) and not LiveSpan.scaffold_overlaps(tree,
				cand - BalanceWorld10.VENT_SCAFFOLD_PAD, cand + BalanceWorld10.VENT_SCAFFOLD_PAD):
			return cand
	return NAN


## 距最近地块边界 320·n ≥ 52。
static func edge_ok(x: float) -> bool:
	var w := BalanceWorld10.VENT_CHUNK_W
	var r := fposmod(x, w)
	return minf(r, w - r) >= BalanceWorld10.VENT_EDGE_MIN


## 首喷绝对时刻（闪光 t=0 起算）。
func first_pulse_t() -> float:
	return BalanceWorld10.VENT_WARN + BalanceWorld10.VENT_FLIGHT + BalanceWorld10.VENT_BURROW \
			+ BalanceWorld10.VENT_FIRST_LIT + BalanceWorld10.VENT_STAGGER * k_index


func pulse_start(i: int) -> float:
	return first_pulse_t() + i * (BalanceWorld10.VENT_FLARE_ON + BalanceWorld10.VENT_FLARE_OFF)


func extinguish_t() -> float:
	return pulse_start(pulses - 1) + BalanceWorld10.VENT_FLARE_ON


func t_abs() -> float:
	return age + BalanceWorld10.VENT_WARN


## 当前正在喷的脉冲序号；不在喷发期返回 −1。
func active_pulse() -> int:
	if _phase != Phase.LIT:
		return -1
	var t := t_abs()
	for i in pulses:
		var s := pulse_start(i)
		if t >= s and t < s + BalanceWorld10.VENT_FLARE_ON:
			return i
	return -1


func is_lit() -> bool:
	return _phase == Phase.LIT


func is_done() -> bool:
	return _phase == Phase.DONE


## R11 亮井闪烁频率（喷发期返回 0）。
func blink_hz() -> float:
	if _phase != Phase.LIT or active_pulse() >= 0:
		return 0.0
	var t := t_abs()
	for i in pulses:
		var s := pulse_start(i)
		if s > t:
			return minf(1.0 / maxf(s - t, 0.0001), BalanceWorld10.VENT_BLINK_MAX_HZ)
	return 0.0


## 先入树再调本方法。from=出膛口世界位；x=已规划好的井位；g=井位地表。
func launch(from: Vector2, x: float, g: float) -> void:
	global_position = Vector2(x, g)
	reset_physics_interpolation()
	ground_y = g
	_from = from
	_target = Vector2(x, g)
	var tf := BalanceWorld10.VENT_FLIGHT
	var grav := BalanceCombat.MORTAR_GRAVITY
	_vel0 = Vector2((_target.x - from.x) / tf, (_target.y - from.y - 0.5 * grav * tf * tf) / tf)
	_base = _sprite(TEX_BASE, Vector2(40, 26))
	_base.visible = false
	_glow = _sprite(TEX_GLOW, Vector2(32, 18))
	_glow.visible = false
	_flame = _sprite(TEX_FLAME, Vector2(36, 222))
	_flame.visible = false
	_drill = Sprite2D.new()
	_drill.texture = TEX_DRILL
	_drill.top_level = true
	_drill.global_position = from
	add_child(_drill)


func _sprite(tex: Texture2D, anchor: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = -anchor # origin=底部接地点（SVG 锚点账）
	add_child(s)
	return s


func _physics_process(delta: float) -> void:
	age += delta
	match _phase:
		Phase.FLY:
			var t := minf(age, BalanceWorld10.VENT_FLIGHT)
			var grav := BalanceCombat.MORTAR_GRAVITY
			var p := _from + _vel0 * t + Vector2(0, 0.5 * grav * t * t)
			var v := _vel0 + Vector2(0, grav * t)
			_drill.global_position = p
			_drill.rotation = v.angle()
			if age >= BalanceWorld10.VENT_FLIGHT:
				_phase = Phase.BURROW
				_drill.global_position = _target
				_drill.rotation = PI * 0.5
				_base.visible = true
		Phase.BURROW:
			var k := clampf((age - BalanceWorld10.VENT_FLIGHT) / BalanceWorld10.VENT_BURROW, 0.0, 1.0)
			_drill.global_position = _target + Vector2(0, -8.0 + 16.0 * k)
			_drill.modulate.a = 1.0 - k
			if k >= 1.0:
				_phase = Phase.LIT
				_drill.visible = false
				_glow.visible = true
		Phase.LIT:
			_tick_lit(delta)


func _tick_lit(delta: float) -> void:
	var t := t_abs()
	if t >= extinguish_t():
		_phase = Phase.DONE
		queue_free()
		return
	var pi_ := active_pulse()
	_flame.visible = pi_ >= 0
	if pi_ >= 0:
		_glow.modulate.a = 1.0
		var into := t - pulse_start(pi_)
		_flame.scale = Vector2(1.0 + 0.04 * sin(age * 40.0), clampf(into / 0.06, 0.2, 1.0))
		if pi_ != _hit_pulse:
			_try_hit(pi_)
	else:
		_blink_phase += TAU * blink_hz() * delta
		_glow.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_blink_phase))


func _try_hit(pi_: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	var c := player.global_position
	var feet_h := ground_y - (c.y + 30.0)
	if absf(c.x - global_position.x) <= BalanceWorld10.VENT_WIDTH * 0.5 + PLAYER_HALF_W \
			and feet_h < BalanceWorld10.VENT_HEIGHT:
		_hit_pulse = pi_
		hits += 1
		player.take_damage(damage)
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 0.6)
