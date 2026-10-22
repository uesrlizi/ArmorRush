class_name EliteSiren
extends Enemy
## 第五章精英·防空炮车「响哨」：ch1 导弹车/ch2 臼炮车/ch3 布雷车/ch4 海葵的
## 章节替位——预教 BOSS「断云」的「啸雷」（精英=BOSS 最难读一手的预教学位：
## 爆点在半空、出膛时不可见，读法=炮口预警+引信芯快闪）。双管高炮**俯仰
## 真瞄玩家**（臂枢随玩家俯仰，同杂兵枪臂惯例；真实枪口律），周期性双连
## 啸雷弹：炮口预警闪光（ThreatFlash）→ **逐发出膛瞬间按玩家当时位置定距**
## （FlakShell.launch 的引信=炮口距/弹速——爆点=发射时玩家所在点，无 lead；
## 停=吃/动=免，与 ch4 重弹的 lead 惩罚互为镜像）→ 定距空爆（无驻留区
## ——教学纯净版）。数值全在 Balance.ELITE_SIREN_*/FLAK_SHELL_*；
## 重击公共规约见 Balance 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _launched := 0

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return Balance.ELITE_SIREN_MAX_HP


func _species_score() -> int:
	return Balance.ELITE_SIREN_SCORE


## 高炮臂随玩家俯仰（真瞄读法：炮塔指向即瞄准方向）。
func _arm_tracks_pitch() -> bool:
	return true


## 重装车体：枪弹几乎推不动，近战也只微微滑半步。
func _knockback_scale() -> float:
	return 0.25


func _impact_resistance() -> float:
	return Balance.IMPACT_RESIST_ELITE


func _stagger_time() -> float:
	return Balance.STAGGER_TIME_ELITE


func _stagger_key() -> StringName:
	return &"stagger_elite"


func _stagger_immunity() -> float:
	return Balance.STAGGER_IMMUNITY_ELITE


## 攻击层整体替换：父类的机枪扫射层置空（移动层照旧，边踱步边按节奏开炮）。
func _tick_fire(_delta: float) -> void:
	pass


func on_spawned() -> void:
	super()
	_warn.reset() # 池化复用/预警中死亡的残光兜底


func _physics_process(delta: float) -> void:
	super(delta) # 移动层 + 瞄准（高炮俯仰跟踪）+ 朝向照旧；_tick_fire 已替换为空
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
					<= Balance.ELITE_SIREN_ATTACK_RANGE
			if in_range and _roll_trigger(Balance.ELITE_SIREN_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = Balance.HEAVY_GUN_WARN_TIME
				_launched = 0
				_warn.warn() # 预警统一入口：双管口闪光 + 警告音
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
				if _launched >= Balance.ELITE_SIREN_VOLLEY_COUNT:
					_volley_state = VolleyState.COOLDOWN
				else:
					_volley_t = Balance.ELITE_SIREN_VOLLEY_STAGGER


## 啸雷弹：出膛瞬间按玩家**当时位置**定距（引信=炮口距/弹速，真实枪口律，
## 无预判——停=吃/动=免）；弹道、空爆、音效、震屏都在 FlakShell 内。
func _launch_one() -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var from := _muzzle.global_position
	var aim := player.global_position
	var dir := from.direction_to(aim)
	var shell := FlakShell.new()
	shell.damage = Balance.ELITE_SIREN_FLAK_DAMAGE
	shell.blast_radius = Balance.ELITE_SIREN_FLAK_BLAST_RADIUS
	container.add_child(shell)
	shell.launch(terrain, from, dir, from.distance_to(aim) / Balance.FLAK_SHELL_SPEED)
	_muzzle_flash.fire(dir.angle()) # 出膛焰跟弹道方向，钉在双管口
	Sfx.play(&"fire_enemy") # 占位：高炮出膛暂用敌枪声，啸雷配方后配
