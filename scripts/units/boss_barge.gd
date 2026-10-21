class_name BossBarge
extends PursuitBoss
## 第二章 BOSS·悬浮冶炼驳船「钢嵴」（精炼所工业带）：低空悬浮的重装驳船。
## 与 ch1 直升机的区分在威胁语法——不追人瞄准，而是改造场地 + 几何弹幕：
##   熔渣封路（技能）：背部 4 垂发孔逐孔高抛（预警闪在弹舱）→ 迫击炮弹
##     （MortarShell 真弹道，4×重力快弧），落点=按玩家速度推算的前方路面
##     （lead 机制，精英已预教），落地小溅射 + 驻留火区——惩罚匀速节奏；
##   排炮弹幕墙（技能）：船艏 3 真实炮位（真实枪口律：弹流=炮位×方向×时机）
##     梯次开火，基准俯角 + 每轮整体摆动扇（缝位轮轮换，驻停必被扫）；每发
##     出膛前沿射线采样地形——埋弹抬角校平（至多 2 次），仍埋该炮本轮哑火
##     （被地形挡住不打；敌弹蒙版含世界层，埋弹撞山即灭，视觉诚实）；
##   直瞄机炮（普攻）：甲板枪臂真瞄玩家短点放（同 ch1 惯例：瞄准即预警），
##     逼玩家持续前进；俯仰 ±60°，高空不是免费位。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架；数值全在 Balance.BARGE_*。

const ST_WALL_WARN := 3
const ST_WALL_FIRE := 4
const ST_SLAG_WARN := 5
const ST_SLAG_FIRE := 6
const ST_DIRECT := 7

var _wall_angles: Array[float] = []  # 本轮各炮位校平后俯角（NAN=哑火）
var _wall_times: Array[float] = []   # 逐发开火时刻（自 FIRE 起点）
var _wall_seq: Array[Vector2i] = []  # 与 _wall_times 对齐的 (炮位, 第几发)
var _wall_idx := 0
var _wall_t := 0.0
var _slag_launched := 0
var _slag_launch_t := 0.0
var _direct_shoot_t := 0.0

@onready var _wall_muzzles: Array[Node2D] = [
	$Visuals/WallPorts/Port1 as Node2D,
	$Visuals/WallPorts/Port2 as Node2D,
	$Visuals/WallPorts/Port3 as Node2D,
]
@onready var _wall_flashes: Array[MuzzleFlash] = [
	$Visuals/WallPorts/Port1/Flash as MuzzleFlash,
	$Visuals/WallPorts/Port2/Flash as MuzzleFlash,
	$Visuals/WallPorts/Port3/Flash as MuzzleFlash,
]
@onready var _wall_warns: Array[ThreatFlash] = [
	$Visuals/WallPorts/Port1/ThreatFlash as ThreatFlash,
	$Visuals/WallPorts/Port2/ThreatFlash as ThreatFlash,
	$Visuals/WallPorts/Port3/ThreatFlash as ThreatFlash,
]
@onready var _slag_ports: Array = $Visuals/SlagPorts.get_children()
@onready var _slag_warn: ThreatFlash = $Visuals/SlagWarn/ThreatFlash
@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash # 直瞄枪口（不预警，但池化复用要兜底重置）


func _species_max_hp() -> int:
	return Balance.BARGE_MAX_HP


func _hover_anchor_y() -> float:
	return Balance.BARGE_HOVER_Y # 绝对锚（不随地形成台阶跳变），船底永在最高台阶之上


func on_spawned() -> void:
	super()
	_wall_angles.clear()
	_wall_times.clear()
	_wall_seq.clear()
	_wall_idx = 0
	_slag_launched = 0


## ---- 技能 A：排炮弹幕墙 ----

func _begin_skill_a() -> void:
	_bstate = ST_WALL_WARN
	_bt = Balance.HEAVY_GUN_WARN_TIME
	# 一轮一声警告：首炮走统一入口（闪光+警告音），余炮只闪（同一波齐射
	# 不叠三声警告音；预警仍然只在发射器上）
	_wall_warns[0].warn()
	for i in range(1, _wall_warns.size()):
		_wall_warns[i].flash()


func _begin_wall_fire() -> void:
	_bstate = ST_WALL_FIRE
	var player := get_tree().get_first_node_in_group("player") as Player
	# 射角在开火瞬间定案（预警期船还在漂）：基准 ± 本轮摆动 → 逐炮地形校平
	var offset := randf_range(-_sweep_deg(), _sweep_deg())
	_wall_angles.clear()
	for i in _wall_muzzles.size():
		_wall_angles.append(_legalize_angle(
				(_wall_muzzles[i] as Node2D).global_position,
				Balance.BARGE_WALL_BASE_DEG[i] + offset))
	_wall_times.clear()
	_wall_seq.clear()
	var burst := _burst()
	for p in _wall_muzzles.size():
		if is_nan(_wall_angles[p]):
			continue # 本轮哑火：被地形挡住，不开火
		for k in burst:
			_wall_times.append(p * Balance.BARGE_WALL_PORT_STAGGER
					+ k * Balance.BARGE_WALL_BURST_INTERVAL)
			_wall_seq.append(Vector2i(p, k))
	_wall_idx = 0
	_wall_t = 0.0
	if _wall_times.is_empty():
		_enter_recover(Balance.BARGE_WALL_RECOVER) # 全员哑火（极端地形）：直接收势
		return


## 单发校平：沿射线按步长采样地形，射线钻地=埋 → 抬角重算（至多 FLATTEN_MAX
## 次），仍埋返回 NAN（该炮本轮哑火）。
func _legalize_angle(from: Vector2, down_deg: float) -> float:
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if terrain == null:
		return down_deg
	var ang := down_deg
	for attempt in Balance.BARGE_WALL_FLATTEN_MAX + 1:
		if _ray_clear(terrain, from, ang):
			return ang
		ang -= Balance.BARGE_WALL_FLATTEN_DEG # 抬角（正=向下，减=朝平/朝上抬）
	return NAN


func _ray_clear(terrain: Terrain, from: Vector2, down_deg: float) -> bool:
	var dir := Vector2.LEFT.rotated(deg_to_rad(-down_deg))
	var x_min := -INF
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		x_min = player.global_position.x - 300.0 # 越过交战区后的弹不归它管
	var t := Balance.BARGE_WALL_SAMPLE_STEP
	while t <= Balance.BARGE_WALL_SAMPLE_RANGE:
		var p := from + dir * t
		if p.x <= x_min:
			return true
		if terrain.surface_y_at(p.x) < p.y:
			return false # 地表在射线上方：这条射角会埋进台阶
		if p.y < 520.0:
			return true # 已压到全场最高地形顶（536）之上：直线不会再下来
		t += Balance.BARGE_WALL_SAMPLE_STEP
	return true


func _fire_wall_shot(port: int) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var b := ENEMY_BULLET.instantiate() as Bullet
	b.speed = Balance.BOSS_SWEEP_SPEED
	b.damage = Balance.BOSS_SWEEP_DAMAGE
	b.impact_tint = Color(1.0, 0.32, 0.25)
	b.setup(Vector2.LEFT.rotated(deg_to_rad(-_wall_angles[port])), Vector2.ZERO)
	container.add_child(b)
	b.global_position = (_wall_muzzles[port] as Node2D).global_position
	b.reset_physics_interpolation()
	(_wall_flashes[port] as MuzzleFlash).fire(-deg_to_rad(_wall_angles[port]))
	Sfx.play(&"fire_enemy")


## ---- 技能 B：熔渣封路 ----

func _begin_skill_b() -> void:
	_bstate = ST_SLAG_WARN
	_bt = Balance.HEAVY_GUN_WARN_TIME
	_slag_warn.warn() # 预警统一入口：弹舱闪光 + 警告音（机枪口留给直瞄）


## RAIN 式出膛节拍：蓄力结束首发即出，逐孔轮发（4 孔=一轮 1:1，二阶段 +2 回绕）。
func _launch_ticker(delta: float) -> void:
	if _slag_launched >= _slag_count():
		return
	_slag_launch_t -= delta
	if _slag_launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var from := (_slag_ports[_slag_launched % _slag_ports.size()] as Node2D).global_position
	var target := MortarShell.compute_lead_target(from, player, terrain,
			Balance.BARGE_SLAG_LEAD_MAX, Balance.BARGE_SLAG_FLIGHT)
	var shell := MortarShell.new()
	shell.damage = Balance.BARGE_SLAG_DAMAGE
	shell.blast_radius = Balance.BARGE_SLAG_BLAST_RADIUS
	shell.pool_radius = Balance.SLAG_POOL_RADIUS
	shell.pool_lifetime = Balance.BARGE_SLAG_POOL_TIME
	container.add_child(shell)
	shell.launch(terrain, from, target, Balance.BARGE_SLAG_FLIGHT)
	_slag_launched += 1
	_slag_launch_t = Balance.BARGE_SLAG_STAGGER
	Sfx.play(&"fire_enemy") # 占位发射声（暂用敌枪声，熔渣炮音效后续单独配方）


## ---- 普攻：直瞄机炮 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_bt = Balance.BOSS_DIRECT_DURATION
	_direct_shoot_t = 0.0 # 首发即出


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_WALL_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_begin_wall_fire()
		ST_WALL_FIRE:
			_wall_t += delta
			while _wall_idx < _wall_times.size() and _wall_times[_wall_idx] <= _wall_t:
				_fire_wall_shot(_wall_seq[_wall_idx].x)
				_wall_idx += 1
			if _wall_t >= _wall_times[_wall_times.size() - 1] + 0.15:
				_enter_recover(Balance.BARGE_WALL_RECOVER)
		ST_SLAG_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_SLAG_FIRE
				_slag_launched = 0
				_slag_launch_t = 0.0
				_bt = Balance.HEAVY_MISSILE_TRACK_MAX + 0.8 # 全部出膛+追踪窗口
		ST_SLAG_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(Balance.BARGE_SLAG_RECOVER)
		ST_DIRECT:
			_bt -= delta
			_direct_shoot_t -= delta
			if _direct_shoot_t <= 0.0:
				var player := get_tree().get_first_node_in_group("player") as Player
				if player != null:
					_fire_direct_shot(_muzzle.global_position.direction_to(
							player.global_position))
				_direct_shoot_t = Balance.BOSS_SWEEP_FIRE_INTERVAL
			if _bt <= 0.0:
				_enter_recover(Balance.BOSS_DIRECT_RECOVER)


## 直瞄单发：子弹真从枪口出膛、朝玩家当前位置（无预判），同 ch1 普攻惯例。
func _fire_direct_shot(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var b := ENEMY_BULLET.instantiate() as Bullet
	b.speed = Balance.BOSS_SWEEP_SPEED
	b.damage = Balance.BOSS_SWEEP_DAMAGE
	b.impact_tint = Color(1.0, 0.32, 0.25)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = _muzzle.global_position
	b.reset_physics_interpolation()
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_enemy")


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_WALL_WARN:
			_bt = Balance.HEAVY_GUN_WARN_TIME
			_wall_warns[0].warn()
			for i in range(1, _wall_warns.size()):
				_wall_warns[i].flash()
		ST_SLAG_WARN:
			_bt = Balance.HEAVY_GUN_WARN_TIME
			_slag_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	for w in _wall_warns:
		(w as ThreatFlash).reset()
	_slag_warn.reset()
	_warn.reset()


## ---- 二阶段数值 ----

func _slag_count() -> int:
	return Balance.BARGE_SLAG_COUNT + (Balance.BARGE_PHASE2_SLAG_BONUS if _phase2 else 0)


func _burst() -> int:
	return Balance.BARGE_WALL_BURST + (Balance.BARGE_PHASE2_BURST_BONUS if _phase2 else 0)


func _sweep_deg() -> float:
	return Balance.BARGE_PHASE2_SWEEP_DEG if _phase2 else Balance.BARGE_WALL_SWEEP_DEG
