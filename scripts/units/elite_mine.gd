class_name EliteMine
extends Enemy
## 第三章精英·电浆布雷车：ch1 导弹车/ch2 臼炮车的章节替位——预教 BOSS 白鲸的
## 「浮雷封锁」（精英=BOSS 最难读一手的预教学位；电浆弹雨是 ch1 已教语法，
## 白鲸现场教）。垂发双管朝天（臂枢只镜像不俯仰，同 EliteMortar 惯例），周期性
## 高抛电浆浮雷：枪口预警闪光（ThreatFlash）→ 弹道解算高抛（PlasmaMine，
## g=MORTAR_GRAVITY 同熔渣弹账，弧顶≈+370px 屏内）→ 悬停在「按玩家速度推算的
## 前方路面上方 HOVER_CLEAR」→ 蓄能渐亮（二段预警）→ 近炸。
## 落点带 lead（相对速度即机制：冲得快雷铺得远；蓄能窗 0.7s 内冲刺穿过=免费，
## 犹豫/回头/跳跃才吃雷）。教学纯净版：车体无直伤，雷才是威胁。
## 数值全在 Balance.ELITE_MINE_*/PLASMA_MINE_*；重击公共规约见 Balance 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

## 双仓口的 pivot 空间 x（左→右轮转出弹；与车体 SVG 仓口中心列画布 38.5/49.5
## - ArmPivot 44 对应，同 ch1/ch2 精英车的 1:1 账）
const CELL_MUZZLE_X := [-5.5, 5.5]

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _launch_seq := 0 # 仓口轮转序号（随机起步，连轮不总从同一仓开打）

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return Balance.ELITE_MINE_MAX_HP


func _species_score() -> int:
	return Balance.ELITE_MINE_SCORE


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


## 攻击层整体替换：父类的机枪扫射层置空（移动层照旧，边踱步边按节奏布雷）。
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
					<= Balance.ELITE_MINE_ATTACK_RANGE
			if in_range and _roll_trigger(Balance.ELITE_MINE_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = Balance.HEAVY_GUN_WARN_TIME
				_muzzle.position.x = 0.0 # 预警钉在双管正中（发射时再轮转到具体仓）
				_warn.warn() # 预警统一入口：枪口闪光 + 警告音（出弹节拍另行倒数）
		VolleyState.TELEGRAPH:
			_volley_t -= delta
			if _volley_t <= 0.0:
				_volley_state = VolleyState.LAUNCH
				_volley_t = 0.0
		VolleyState.LAUNCH:
			# 一次性齐布：双仓同帧出弹（空中读成"一把撒开的雷幕"，
			# 与臼炮逐孔梯次的读法分家），随后直接回冷却
			for i in Balance.ELITE_MINE_VOLLEY_COUNT:
				_launch_one(i)
			_volley_state = VolleyState.COOLDOWN


## 垂发高抛布雷：出膛初速由弹道解算给（PlasmaMine.launch，弧线朝天起手），
## 落点=承诺带基点（fence_base_x 按玩家速度外推，基点同一瞬间读定）+ 序位×布雷间距。
func _launch_one(volley_idx: int) -> void:
	var player := _player as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var cell_x: float = CELL_MUZZLE_X[(_launch_seq + volley_idx) % CELL_MUZZLE_X.size()]
	_muzzle.position.x = cell_x
	var x := PlasmaMine.fence_base_x(player, Balance.ELITE_MINE_FLIGHT,
			Balance.ELITE_MINE_LEAD_MIN, Balance.ELITE_MINE_LEAD_MAX) \
			+ volley_idx * Balance.PLASMA_MINE_FENCE_SPACING
	var target := Vector2(x, terrain.surface_y_at(x)
			- Balance.PLASMA_MINE_HOVER_CLEAR)
	var mine := PlasmaMine.new()
	container.add_child(mine)
	mine.launch(terrain, _muzzle.global_position, target, Balance.ELITE_MINE_FLIGHT)
	# 出膛焰跟解算出的朝天抛速方向，钉在发射仓口
	_muzzle_flash.fire(PlasmaMine.ballistic_velocity(
			_muzzle.global_position, target, Balance.ELITE_MINE_FLIGHT).angle())
	Sfx.play(&"fire_enemy") # 占位发射声（暂用敌枪声，布雷音效后续单独配方）
