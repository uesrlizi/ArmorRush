class_name EliteSlag
extends Enemy
## 第二章精英·熔渣臼炮车：ch1 导弹车的章节替位——把 BOSS「悬浮冶炼驳船」的
## 熔渣封路提前教给玩家（精英=BOSS 最难读一手的预教学位，见 ch1 导弹车之于弹雨）。
## 垂发双管朝天（臂枢只镜像不俯仰，同 EliteMortar 惯例），周期性高抛熔渣弹：
## 枪口预警闪光（ThreatFlash）→ 迫击炮弹（MortarShell 真弹道：初速按落点+时长
## 解算、4×重力快弧，与导弹彻底分家）→ 落点=**按玩家速度推算的前方路面**
## （lead=玩家x+vx×飞行时间，clamp 到 ELITE_SLAG_LEAD_MAX——相对速度就是机制：
## 匀速直线跑会一头扎进火区，躲=变速/绕行/跳越）→ 落地无溅射伤害（教学纯净版），
## 只留驻留熔渣火区（SlagPool，tick 伤害，蓄热后才咬人）。
## 数值全在 Balance.ELITE_SLAG_*/SLAG_POOL_*/MORTAR_*；重击公共规约见 Balance 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

## 双仓口的 pivot 空间 x（左→右轮转出弹；与车体 SVG 仓口中心列画布 38.5/49.5
## - ArmPivot 44 对应，同 ch1 精英车的 1:1 账）
const CELL_MUZZLE_X := [-5.5, 5.5]

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _launched := 0
var _launch_seq := 0 # 仓口轮转序号（随机起步，连轮不总从同一仓开打）

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return Balance.ELITE_SLAG_MAX_HP


func _species_score() -> int:
	return Balance.ELITE_SLAG_SCORE


## 垂发架：发射角固定朝天，臂枢不随玩家俯仰（见 Enemy._arm_tracks_pitch）。
func _arm_tracks_pitch() -> bool:
	return false


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


## 攻击层整体替换：父类的机枪扫射层置空（移动层照旧，边踱步边按节奏齐射）。
func _tick_fire(_delta: float) -> void:
	pass


func on_spawned() -> void:
	super()
	_warn.reset() # 池化复用/预警中死亡的残光兜底
	_launch_seq = randi() % CELL_MUZZLE_X.size()


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
					<= Balance.ELITE_SLAG_ATTACK_RANGE
			if in_range and _roll_trigger(Balance.ELITE_SLAG_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = Balance.HEAVY_GUN_WARN_TIME
				_launched = 0
				_muzzle.position.x = 0.0 # 预警钉在双管正中（发射时再轮转到具体仓）
				_warn.warn() # 预警统一入口：枪口闪光 + 警告音（出弹节拍另行倒数）
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
				if _launched >= Balance.ELITE_SLAG_VOLLEY_COUNT:
					_volley_state = VolleyState.COOLDOWN
				else:
					_volley_t = Balance.ELITE_SLAG_VOLLEY_STAGGER


## 垂发发射：出膛初速由弹道解算给（MortarShell.launch，弧线仍朝天起手），
## 落点由 compute_lead_target 按玩家速度推算（时长已知，一次算完）。
func _launch_one() -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var cell_x: float = CELL_MUZZLE_X[_launch_seq % CELL_MUZZLE_X.size()]
	_launch_seq += 1
	_muzzle.position.x = cell_x
	var target := MortarShell.compute_lead_target(_muzzle.global_position,
			player, terrain, Balance.ELITE_SLAG_LEAD_MAX, Balance.ELITE_SLAG_FLIGHT)
	var shell := MortarShell.new()
	shell.damage = Balance.ELITE_SLAG_SHELL_DAMAGE # 0=落地无溅射判定
	shell.blast_radius = 0.0
	shell.splash = false
	shell.pool_radius = Balance.SLAG_POOL_RADIUS
	shell.pool_lifetime = Balance.ELITE_SLAG_POOL_TIME
	container.add_child(shell)
	shell.launch(terrain, _muzzle.global_position, target, Balance.ELITE_SLAG_FLIGHT)
	_muzzle_flash.fire(shell.rotation) # 出膛焰跟初速方向（解算出的朝天弧），钉在发射仓口
	Sfx.play(&"fire_enemy") # 占位发射声（暂用敌枪声，熔渣炮音效后续单独配方）
