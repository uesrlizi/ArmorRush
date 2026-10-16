class_name EliteMortar
extends Enemy
## 精英·导弹车：步行炮台的车体，肩部垂发发射舱与车体一体构图（AC 式方箱两仓）。
## 继承 Enemy 的移动/受击/死亡/头顶血条全套；攻击层整体替换——不打机枪，
## 周期性导弹齐射：枪口预警闪光（ThreatFlash，不动精灵本体）→ 垂发固定角度
## 出膛（仓口朝天，臂枢只镜像不俯仰）→ 真追踪导弹（HeavyMissile）→ 落地
## 球状爆伤。玩家必须离地+甩角规避。数值全在 Balance.ELITE_*；重击公共规约
## 见 Balance 重击段。

enum VolleyState { COOLDOWN, TELEGRAPH, LAUNCH }

## 两列仓口的 pivot 空间 x（左→右轮转出弹；一轮 ELITE_VOLLEY_COUNT=2 发
## 与两仓口 1:1，对应车体 SVG 仓口中心列 canvas 38.5/49.5 - 44）
const CELL_MUZZLE_X := [-5.5, 5.5]

var _volley_state := VolleyState.COOLDOWN
var _volley_t := 0.0
var _launched := 0
var _launch_seq := 0 # 仓口轮转序号（随机起步，连轮不总从同一仓开打）

@onready var _warn: ThreatFlash = $ArmPivot/Muzzle/ThreatFlash


func _species_max_hp() -> int:
	return Balance.ELITE_MAX_HP


func _species_score() -> int:
	return Balance.ELITE_SCORE


## 垂发架：发射角固定朝天，臂枢不随玩家俯仰（见 Enemy._arm_tracks_pitch）。
func _arm_tracks_pitch() -> bool:
	return false


## 重装车体：枪弹几乎推不动，近战也只微微滑半步。
func _knockback_scale() -> float:
	return 0.25


## 失衡（AC6 式）：枪弹 ≈12 发命中打满上限，踉跄硬直给玩家补刀窗。
func _impact_resistance() -> float:
	return Balance.IMPACT_RESIST_ELITE


func _stagger_time() -> float:
	return Balance.STAGGER_TIME_ELITE


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
					<= Balance.ELITE_ATTACK_RANGE
			if in_range and _roll_trigger(Balance.ELITE_VOLLEY_HALF_LIFE, delta):
				_volley_state = VolleyState.TELEGRAPH
				_volley_t = Balance.HEAVY_GUN_WARN_TIME
				_launched = 0
				_muzzle.position.x = 0.0 # 预警钉在舱口正中（发射时再轮转到具体仓）
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
				if _launched >= Balance.ELITE_VOLLEY_COUNT:
					_volley_state = VolleyState.COOLDOWN
				else:
					_volley_t = Balance.ELITE_VOLLEY_STAGGER


## 垂发固定角度：出膛方向 = 枪口实际朝向——读 Muzzle 的全局 -Y（仓口朝天；
## 臂枢只镜像不俯仰，镜像翻的是横轴，竖直轴不动），发射架以后改摆角导弹
## 自动跟。三仓轮转出弹，散布并入方向；弹头沿炮口朝向出膛（不吃载机速度）。
func _launch_one() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if terrain == null or container == null:
		return
	var cell_x: float = CELL_MUZZLE_X[_launch_seq % CELL_MUZZLE_X.size()]
	_launch_seq += 1
	_muzzle.position.x = cell_x
	var dir := (-_muzzle.global_transform.y).normalized()
	dir = dir.rotated(deg_to_rad(randf_range(-Balance.HEAVY_MISSILE_SPREAD_DEG,
			Balance.HEAVY_MISSILE_SPREAD_DEG)))
	var missile := HeavyMissile.new()
	missile.damage = Balance.ELITE_MISSILE_DAMAGE
	missile.blast_radius = Balance.ELITE_BLAST_RADIUS
	container.add_child(missile)
	missile.launch(terrain, _muzzle.global_position, dir, true)
	_muzzle_flash.fire(dir.angle()) # 出膛焰跟枪口实际方向（朝天），钉在发射仓口
	Sfx.play(&"fire_enemy") # 占位发射声（暂用敌枪声，导弹音效后续单独配方）
