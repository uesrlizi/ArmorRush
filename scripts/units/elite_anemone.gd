class_name EliteAnemone
extends Enemy
## 第四章精英·炮台车「海葵」：ch1 导弹车/ch2 臼炮车/ch3 布雷车的章节替位——
## 预教 BOSS「鮟鱇」的「珊瑚重炮」（精英=BOSS 最难读一手的预教学位）。背驮
## 海葵发射器（固定射角，臂枢不随玩家俯仰，同垂发惯例；发射器=美术本体，
## Muzzle=海葵口），周期性双连珊瑚重弹：发射器预警闪光（ThreatFlash）→
## **逐发在出膛瞬间 lead 瞄准**（CoralOrb.lead_direction：玩家速度×飞行时长，
## clamp 承诺带——弹体自读：慢弹看得见、侧移即躲；匀速直线跑被压在路径上，
## 变向/急停=免）→ 慢速能量重球直线飞抵落点爆蕗（无残留区——教学纯净版）。
## 数值全在 BalanceWorld4.ELITE_ANEMONE_*/CORAL_ORB_*；重击公共规约见 Balance 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _launched := 0

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return BalanceWorld4.ELITE_ANEMONE_MAX_HP


func _species_score() -> int:
	return BalanceWorld4.ELITE_ANEMONE_SCORE


## 海葵发射器：射角固定（出膛方向由 lead 解算给），臂枢不随玩家俯仰。
func _arm_tracks_pitch() -> bool:
	return false


## 重装车体：枪弹几乎推不动，近战也只微微滑半步。
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


## 攻击层整体替换：父类的机枪扫射层置空（移动层照旧，边踱步边按节奏开炮）。
func _tick_fire(_delta: float) -> void:
	pass


func on_spawned() -> void:
	super()
	_warn.reset() # 池化复用/预警中死亡的残光兜底


func _physics_process(delta: float) -> void:
	super(delta) # 移动层 + 瞄准 + 朝向照旧；_tick_fire 已替换为空
	if _despawn_requested or _hp <= 0:
		return
	_tick_volley(delta)


func _tick_volley(delta: float) -> void:
	var player := _player as Player
	if player == null or player.is_dead():
		return
	match _volley_state:
		VolleyState.COOLDOWN:
			var in_range := absf(player.global_position.x - global_position.x) \
					<= BalanceWorld4.ELITE_ANEMONE_ATTACK_RANGE
			if in_range and _roll_trigger(BalanceWorld4.ELITE_ANEMONE_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = BalanceCombat.HEAVY_GUN_WARN_TIME
				_launched = 0
				_warn.warn() # 预警统一入口：海葵口闪光 + 警告音
		VolleyState.TELEGRAPH:
			_volley_t -= delta
			if _volley_t <= 0.0:
				_volley_state = VolleyState.LAUNCH
				_volley_t = 0.0
		VolleyState.LAUNCH:
			_volley_t -= delta
			if _volley_t <= 0.0:
				_launch_one()
				_launched += 1
				if _launched >= BalanceWorld4.ELITE_ANEMONE_VOLLEY_COUNT:
					_volley_state = VolleyState.COOLDOWN
				else:
					_volley_t = BalanceWorld4.ELITE_ANEMONE_VOLLEY_STAGGER


## 珊瑚重弹：出膛瞬间 lead 解算方向（瞄准锁定在开火时机，真实枪口律），
## 弹道、爆蕗、音效、震屏都在 CoralOrb 内。
func _launch_one() -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var dir := CoralOrb.lead_direction(terrain, _muzzle.global_position, player,
			BalanceWorld4.CORAL_ORB_SPEED,
			BalanceWorld4.ELITE_ANEMONE_LEAD_BACK, BalanceWorld4.ELITE_ANEMONE_LEAD_MAX)
	var orb := CoralOrb.new()
	orb.damage = BalanceWorld4.ELITE_ANEMONE_ORB_DAMAGE
	orb.blast_radius = BalanceWorld4.ELITE_ANEMONE_BLAST_RADIUS
	container.add_child(orb)
	orb.launch(terrain, _muzzle.global_position, dir)
	_muzzle_flash.fire(dir.angle()) # 出膛焰跟弹道方向，钉在海葵口
	Sfx.play(&"fire_enemy") # 占位：能量出膛暂用敌枪声，珊瑚系配方后配
