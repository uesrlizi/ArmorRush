class_name ElitePiler
extends Enemy
## 第六章精英·打桩车「锚桩」：ch1 导弹车/ch2 臼炮车/ch3 布雷车/ch4 海葵/
## ch5 响哨的章节替位——预教 BOSS「赤轮」的「电网闸」（精英=BOSS 最难读
## 一手的预教学位：幕立在玩家带内的双重读法，读法=桩落点+充能火花渐亮）。
## 双桩炮架**固定射角**（垂发账：臂不俯仰，`_arm_tracks_pitch` false），周期性
## 单笼投放：炮架口预警闪光（ThreatFlash）→ 两枚锚桩按解算弹道落到玩家
## **当时位置**两侧（ArcFence，无 lead——桩钉住的就是你现在的位置）→ 蓄能
## 火花渐亮 → 竖直电幕立起（触幕一次即溃散；停=被围/动=免，与 ch5 啸雷
## 「停=吃」互补：那边罚不跑，这边罚跑晚了）。数值全在 BalanceWorld6.ELITE_PILER_*；
## 重击公共规约见 BalanceCombat 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return BalanceWorld6.ELITE_PILER_MAX_HP


func _species_score() -> int:
	return BalanceWorld6.ELITE_PILER_SCORE


## 双桩炮架固定射角（垂发账：臂只随朝向镜像，rotation 恒回正）。
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


## 攻击层整体替换：父类的机枪扫射层置空（移动层照旧，边踱步边按节奏打桩）。
func _tick_fire(_delta: float) -> void:
	pass


func on_spawned() -> void:
	super()
	_warn.reset() # 池化复用/预警中死亡的残光兜底


func _physics_process(delta: float) -> void:
	super(delta) # 移动层 + 朝向照旧；_tick_fire 已替换为空
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
					<= BalanceWorld6.ELITE_PILER_ATTACK_RANGE
			if in_range and _roll_trigger(BalanceWorld6.ELITE_PILER_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = BalanceCombat.HEAVY_GUN_WARN_TIME
				_warn.warn() # 预警统一入口：管口闪光 + 警告音
		VolleyState.TELEGRAPH:
			_volley_t -= delta
			if _volley_t <= 0.0:
				_volley_state = VolleyState.LAUNCH
				_drop_fence()


## 电网闸：两桩落到玩家**当时位置**两侧（无 lead，真实桩位律），围栏的
## 蓄能/立幕/触幕/哑熄都在 ArcFence 内。
func _drop_fence() -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		_volley_state = VolleyState.COOLDOWN
		return
	var fence := ArcFence.new()
	fence.damage = BalanceWorld6.ELITE_PILER_FENCE_DAMAGE
	fence.half_width = BalanceWorld6.ELITE_PILER_FENCE_HALF
	fence.top_height = BalanceWorld6.ELITE_PILER_FENCE_TOP
	fence.warmup_time = BalanceWorld6.ELITE_PILER_FENCE_WARMUP
	fence.lifetime = BalanceWorld6.ELITE_PILER_FENCE_LIFE
	fence.stake_flight = BalanceWorld6.ELITE_PILER_STAKE_FLIGHT
	container.add_child(fence)
	fence.launch(terrain, _muzzle.global_position, player.global_position.x)
	_muzzle_flash.fire(-PI * 0.5) # 出膛焰朝天（固定射角读法），钉在管口
	Sfx.play(&"fire_enemy") # 占位：打桩出膛暂用敌枪声
	_volley_state = VolleyState.COOLDOWN
