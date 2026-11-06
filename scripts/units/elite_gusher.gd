class_name EliteGusher
extends Enemy
## 第八章精英·钻机车「喷井」：ch1 导弹车/ch2 臼炮车/ch3 布雷车/ch4 海葵/
## ch5 响哨/ch6 锚桩/ch7 岸炮的章节替位——预教 BOSS「盐磨」的「间歇泉」
## （精英=BOSS 最难读一手的预教学位：「柱是墙不是弹」——跳≠过、只有离，
## 必须由精英单发纯净教）。钻塔**固定射角不俯仰**（垂发账=ch6 锚桩家族，
## _arm_tracks_pitch false），周期性单发裂地镖：管口预警闪光（ThreatFlash）
## → **裂地镖落点=玩家当时脚下**（无 lead；mark 落地即计入威胁）→ 0.7s 地裂
## 环纹预警窗内跑离=免，停桩=吃一枚汽柱（无驻留区——教学纯净版）。
## 数值全在 BalanceWorld8.ELITE_GUSHER_*/SALT_DART_*/SALT_GEYSER_*；
## 重击公共规约见 BalanceCombat 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return BalanceEnemy.ELITE_MAX_HP


func _species_score() -> int:
	return BalanceWorld8.ELITE_GUSHER_SCORE


## 钻塔固定射角（垂发账=锚桩家族）：臂不随玩家俯仰。
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


## 攻击层整体替换：父类的机枪扫射层置空（移动层照旧，边踱步边按节奏打镖）。
func _tick_fire(_delta: float) -> void:
	pass


func on_spawned() -> void:
	super()
	_warn.reset() # 池化复用/预警中死亡的残光兜底


func _physics_process(delta: float) -> void:
	super(delta) # 移动层 + 朝向照旧；瞄准层（俯仰）已关
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
					<= BalanceWorld8.ELITE_GUSHER_ATTACK_RANGE
			if in_range and _roll_trigger(BalanceWorld8.ELITE_GUSHER_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = BalanceCombat.HEAVY_GUN_WARN_TIME
				_warn.warn() # 预警统一入口：钻尖闪光 + 警告音
		VolleyState.TELEGRAPH:
			_volley_t -= delta
			if _volley_t <= 0.0:
				_launch_one()
				_volley_state = VolleyState.COOLDOWN


## 裂地镖：落点=玩家**当时**脚下（无 lead——看到管口闪光后，mark 落地前
## 跑离原位即免，教学读法最纯净）。镖道/落定/间歇泉生命周期都在弹系件内。
func _launch_one() -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var from := _muzzle.global_position
	var target := Vector2(player.global_position.x,
			terrain.surface_y_at(player.global_position.x))
	var dart := SaltDart.new()
	container.add_child(dart)
	dart.launch(terrain, from, target)
	_muzzle_flash.fire(Vector2(-1.0, -0.6).normalized().angle()) # 出膛焰=钻尖上抛向
	Sfx.play(&"fire_enemy") # 占位：钻尖出膛暂用敌枪声，裂地镖配方后配
