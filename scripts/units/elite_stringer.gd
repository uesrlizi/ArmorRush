class_name EliteStringer
extends Enemy
## 第九章精英·放线车「架线」：前八章精英的章节替位——预教 BOSS「引雷」技能 A
## 「跨缆」（同一件两种相反解法：高缆钻、低缆飞/刹，全章最难读的一手，必须由
## 精英单件纯净教）。车背双管桩炮架**固定射角不俯仰**（锚桩/喷井家族垂发账，
## _arm_tracks_pitch false）。周期性单套跨缆：炮架口 ThreatFlash（t=0，同帧采样
## 玩家 px/vx 定 lead）→ t=0.6 双桩出膛 → 1.3 落地 → 灰缆/爬电 → 带电 [2.2,3.2]。
## 高/低轮流：第一套固定高缆（先教「别跳」），第二套低缆（再教「飞或刹」）。
## 冷却闸（R5）：自己上一套未熄灭/溃散前不出新套。落位规则（同台/向前 ≤160/
## 脚手架避让）=LiveSpan.plan_x1，规划落空=本次取消（回冷却）。
## 数值全在 BalanceWorld9.ELITE_STRINGER_*/LIVE_SPAN_*。

enum VolleyState { COOLDOWN, TELEGRAPH }

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _next_high := true
var _plan := {}          # TELEGRAPH 期定好的落位 {x1, shift, lead_x1}

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return BalanceEnemy.ELITE_MAX_HP


func _species_score() -> int:
	return BalanceWorld9.ELITE_STRINGER_SCORE


## 桩炮架固定射角：臂不随玩家俯仰。
func _arm_tracks_pitch() -> bool:
	return false


func _knockback_scale() -> float:
	return 0.25


func _impact_resistance() -> float:
	return BalanceCombat.IMPACT_RESIST_ELITE


func _stagger_time() -> float:
	return BalanceCombat.STAGGER_TIME_ELITE


func _stagger_key() -> StringName:
	return &"stagger_elite"


func _stagger_immunity() -> float:
	return BalanceCombat.STAGGER_IMMUNITY_ELITE


## 攻击层整体替换：父类机枪层置空。
func _tick_fire(_delta: float) -> void:
	pass


func on_spawned() -> void:
	super()
	_warn.reset()
	_volley_state = VolleyState.COOLDOWN
	_next_high = true


func _physics_process(delta: float) -> void:
	super(delta)
	if _despawn_requested or _hp <= 0:
		return
	_tick_volley(delta)


## 冷却闸（R5）：本车名下仍在场（未进熄灭段）的跨缆套数。
func live_span_count() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("live_spans"):
		var sp := node as LiveSpan
		if sp != null and sp.owner_id == get_instance_id() and not sp.is_done():
			n += 1
	return n


func _tick_volley(delta: float) -> void:
	var player := _player as Player
	if player == null or player.is_dead():
		return
	match _volley_state:
		VolleyState.COOLDOWN:
			if live_span_count() > 0:
				return
			var in_range := absf(player.global_position.x - global_position.x) \
					<= BalanceWorld9.ELITE_STRINGER_ATTACK_RANGE
			if in_range and _roll_trigger(BalanceWorld9.ELITE_STRINGER_VOLLEY_HALF_LIFE, delta):
				begin_volley()
		VolleyState.TELEGRAPH:
			_volley_t -= delta
			if _volley_t <= 0.0:
				_volley_state = VolleyState.COOLDOWN
				_launch_span()


## 出一套（探针也走这个入口）：闪光 t=0 同帧采样 lead 并规划落位（R13）。
func begin_volley() -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if player == null:
		return
	var lead := clampf(player.velocity.x * BalanceWorld9.LIVE_SPAN_LEAD_TIME,
			BalanceWorld9.LIVE_SPAN_LEAD_MIN, BalanceWorld9.LIVE_SPAN_LEAD_MAX)
	var base := player.global_position.x - BalanceWorld9.LIVE_SPAN_LENGTH * 0.5 + lead
	_plan = LiveSpan.plan_x1(get_tree(), terrain, base)
	if _plan.is_empty():
		return # 放不下（跨档/脚手架）=本次取消
	_plan["lead_x1"] = base
	_volley_state = VolleyState.TELEGRAPH
	_volley_t = BalanceWorld9.LIVE_SPAN_WARN
	_warn.warn()


func _launch_span() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null or _plan.is_empty():
		return
	var span := LiveSpan.new()
	span.damage = BalanceWorld9.LIVE_SPAN_DAMAGE
	span.owner_id = get_instance_id()
	span.shift = _plan["shift"]
	span.lead_x1 = _plan["lead_x1"]
	span.extra_delay = float(_plan["shift"]) / BalanceWorld9.LIVE_SPAN_SHIFT_SPEED
	container.add_child(span)
	var h := BalanceWorld9.LIVE_SPAN_HIGH_H if _next_high else BalanceWorld9.LIVE_SPAN_LOW_H
	span.launch(terrain, _muzzle.global_position, float(_plan["x1"]), h)
	_next_high = not _next_high
	_muzzle_flash.fire(Vector2(-1.0, -0.8).normalized().angle())
	Sfx.play(&"fire_enemy") # 占位：桩炮出膛暂用敌枪声
