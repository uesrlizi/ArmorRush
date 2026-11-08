class_name EliteFountain
extends Enemy
## 第十章精英·井口封堵车「窜井」：前九章精英的章节替位——预教 BOSS「井口」技能 A 的
## 单口节拍读法「看第一喷、息窗里穿，否则吃第二喷」。车尾钻机架**固定射角不俯仰**
## （锚桩/喷井/架线家族垂发账，_arm_tracks_pitch false），钻杆口=DrillPort=Muzzle。
## 周期性单口：DrillPort ThreatFlash（t=0，warn() 同拍警告音，同帧采样 px/vx 定 lead）
## → t=0.6 钻头出膛 → 1.3 落位 → 1.7 亮井 → 喷 [2.3,2.75] / 息 [2.75,3.5] / 喷 [3.5,3.95] → 熄。
## 落位：xv = px + clamp(vx·2.4, 240, 1440)，R10 档位边界避让（+96/−96）+ 脚手架 ±104，
## 仍不合格本次取消（回冷却）。冷却闸：本车上一口井未熄灭前不出新套。
## 与 ch8 喷井差异：间歇泉一次性汽柱（离开或等它喷完）；窜井是有节拍的闸（息窗是门）。
## 数值全在 BalanceWorld10.ELITE_FOUNTAIN_*/VENT_*。

enum VolleyState { COOLDOWN, TELEGRAPH }

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _plan_x := NAN
var _lead_x := 0.0

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return BalanceEnemy.ELITE_MAX_HP


func _species_score() -> int:
	return BalanceWorld10.ELITE_FOUNTAIN_SCORE


## 钻机架固定射角：臂不随玩家俯仰。
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


func _physics_process(delta: float) -> void:
	super(delta)
	if _despawn_requested or _hp <= 0:
		return
	_tick_volley(delta)


## 冷却闸：本车名下仍在场的井口数。
func vent_count() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("sulfur_vents"):
		var v := node as SulfurVent
		if v != null and v.owner_id == get_instance_id() and not v.is_done() \
				and not v.is_queued_for_deletion():
			n += 1
	return n


func is_telegraphing() -> bool:
	return _volley_state == VolleyState.TELEGRAPH


func _tick_volley(delta: float) -> void:
	var player := _player as Player
	if player == null or player.is_dead():
		return
	match _volley_state:
		VolleyState.COOLDOWN:
			if vent_count() > 0:
				return
			var in_range := absf(player.global_position.x - global_position.x) \
					<= BalanceWorld10.ELITE_FOUNTAIN_ATTACK_RANGE
			if in_range and _roll_trigger(BalanceWorld10.ELITE_FOUNTAIN_VOLLEY_HALF_LIFE, delta):
				begin_volley()
		VolleyState.TELEGRAPH:
			_volley_t -= delta
			if _volley_t <= 0.0:
				_volley_state = VolleyState.COOLDOWN
				_launch_vent()


## 出一套（探针也走这个入口）：闪光 t=0 同帧采样 lead 并规划落位。
## 返回是否进入预警（落位全不合格=本次取消，返回 false）。
func begin_volley() -> bool:
	var player := _player as Player
	if player == null:
		return false
	_lead_x = player.global_position.x + clampf(
			player.velocity.x * BalanceWorld10.VENT_LEAD_TIME,
			BalanceWorld10.VENT_LEAD_MIN, BalanceWorld10.VENT_LEAD_MAX)
	_plan_x = SulfurVent.plan_x(get_tree(), _lead_x)
	if is_nan(_plan_x):
		return false
	_volley_state = VolleyState.TELEGRAPH
	_volley_t = BalanceWorld10.VENT_WARN
	_warn.warn()
	return true


func _launch_vent() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null or is_nan(_plan_x):
		return
	var v := SulfurVent.new()
	v.damage = BalanceWorld10.VENT_DAMAGE
	v.pulses = BalanceWorld10.ELITE_FOUNTAIN_PULSES
	v.owner_id = get_instance_id()
	v.lead_x = _lead_x
	container.add_child(v)
	var g := terrain.surface_y_at(_plan_x) if terrain != null else global_position.y + 40.0
	v.launch(_muzzle.global_position, _plan_x, g)
	_muzzle_flash.fire(-PI * 0.5)
	Sfx.play(&"fire_enemy") # 占位：钻头出膛暂用敌枪声
