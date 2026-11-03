class_name EliteShore
extends Enemy
## 第七章精英·海防炮车「岸炮」：ch1 导弹车/ch2 臼炮车/ch3 布雷车/ch4 海葵/
## ch5 响哨/ch6 锚桩的章节替位——预教 BOSS「沉锚」的「跳弹齐射」（精英=BOSS
## 最难读一手的预教学位：弹道有「落点→弹起→再落」三段节奏，读法=落点溅花+
## 弹跳弧）。海防炮臂**俯仰真瞄玩家**（臂枢随玩家俯仰，同响哨高炮惯例；
## 真实枪口律），周期性双连跳弹：炮口预警闪光（ThreatFlash）→ **逐发出膛
## 落点=玩家当时脚下**（SkipShell.launch 的落点解算在调用方，无 lead；
## 停=吃落点，顺着跑被下一跳追咬，跳过弹体=免）→ 连跳三次末跳球爆（无驻留区
## ——教学纯净版）。数值全在 BalanceWorld7.ELITE_SHORE_*/SKIP_SHELL_*；
## 重击公共规约见 BalanceCombat 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _launched := 0

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return BalanceWorld7.ELITE_SHORE_MAX_HP


func _species_score() -> int:
	return BalanceWorld7.ELITE_SHORE_SCORE


## 海防炮臂随玩家俯仰（真瞄读法：炮管指向即落点方向）。
func _arm_tracks_pitch() -> bool:
	return true


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
	super(delta) # 移动层 + 瞄准（海防炮俯仰跟踪）+ 朝向照旧；_tick_fire 已替换为空
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
					<= BalanceWorld7.ELITE_SHORE_ATTACK_RANGE
			if in_range and _roll_trigger(BalanceWorld7.ELITE_SHORE_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = BalanceCombat.HEAVY_GUN_WARN_TIME
				_launched = 0
				_warn.warn() # 预警统一入口：管口闪光 + 警告音
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
				if _launched >= BalanceWorld7.ELITE_SHORE_VOLLEY_COUNT:
					_volley_state = VolleyState.COOLDOWN
				else:
					_volley_t = BalanceWorld7.ELITE_SHORE_VOLLEY_STAGGER


## 跳弹：**平抛**出膛（v2 同 BOSS 对冲几何——水平初速朝玩家一侧，不瞄人；
## v1 解算落玩家脚下已判死：落点全在行进方向身后）。海防炮平射跳弹=海岸炮
## Ricochet 语汇；弹道/弹跳/溅花/末爆都在 SkipShell 内。
func _launch_one() -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var from := _muzzle.global_position
	var dir_x := signf(player.global_position.x - global_position.x)
	if dir_x == 0.0:
		dir_x = -1.0
	var shell := SkipShell.new()
	shell.damage = BalanceWorld7.ELITE_SHORE_SKIP_DAMAGE
	shell.blast_radius = BalanceWorld7.ELITE_SHORE_SKIP_BLAST_RADIUS
	container.add_child(shell)
	shell.launch(terrain, from, dir_x)
	_muzzle_flash.fire(Vector2(dir_x, 0.0).angle()) # 出膛焰=平射向，钉在管口
	Sfx.play(&"fire_enemy") # 占位：海防炮出膛暂用敌枪声，跳弹配方后配
