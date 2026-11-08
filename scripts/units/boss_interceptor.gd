class_name BossInterceptor
extends PursuitBoss
## 第五章 BOSS·高空截击机「断云」（破晓云廊守卫）：追击框架能力层——
## 「防空截击」。细长镖形截击机（无旋翼，尾部双发短舱推进焰脉动；锚点账见
## bake_dawn_units.py 头注/提案_v1 §3）：
##   啸雷齐射（技能A）：背部炮塔（Cannon，俯仰跟随真瞄）预警 → 逐发梯次
##     FlakShell 定距空爆弹（出膛瞬间按玩家**当时位置**定距：引信=炮口距/
##     弹速，爆点=发射时玩家所在点——**停=吃/动=免**，与 ch4 重弹 lead 惩罚
##     互为镜像；精英「响哨」已预教；3 发/p2+1 弹串追赶读法）；
##   俯冲突袭（技能B）：**首次机体冲撞**——机鼻（Nose）预警+尾焰增亮 0.6s
##     → 锁定出手点（玩家当时 x、当地地表−120）→ 2100px/s 直线通场扫地面
##     通道（过冲 500px 后拉起返锚）。通场带覆盖 [地表−210, 地表−30]：
##     站立=被撞、纯跳 apex −127=被撞（压"跳过一切"）、推进 ≥204px 或横移
##     出锁定线=免。俯冲线每帧按 surface_y_at 校平（滑过台阶上缘不穿模）。
##     分工账：啸雷 hunts 空中与驻停，俯冲 hunts 地面通道——玩家被迫两头
##     换层（提案 §2）。
##   机鼻曳光（普攻直射）：机鼻炮座真瞄玩家短点放——弹=dawn_bolt.tscn
##     （bullet.gd 纯换皮紫白曳光矢，速度/伤害复用 BOSS_SWEEP_*，直瞄无
##     预判语法不变），真瞄即预警。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架（俯冲态接管运动出口，
## 拉起后还给弹簧）。数值全在 BalanceWorld5.INTERCEPTOR_*/FLAK_SHELL_*。

const ST_FLAK_WARN := 3
const ST_FLAK_FIRE := 4
const ST_DIVE_WARN := 5
const ST_DIVE := 6
const ST_DIRECT := 7

const DAWN_BOLT := preload("res://scenes/weapons/dawn_bolt.tscn")

# 冲撞判定宽限（玩家碰撞半宽 26 / 半高 24，同 GroundBlast.PLAYER_RADIUS 惯例：
# 手感从宽，宁可"擦边也算撞到"）
const PLAYER_HALF_W := 26.0
const PLAYER_HALF_H := 24.0

var _flak_launched := 0
var _launch_t := 0.0
var _direct_shoot_t := 0.0
var _dive_dir := Vector2.LEFT
var _dive_travel := 0.0
var _dive_distance := 0.0
var _dive_hit := false

@onready var _cannon: Node2D = $Visuals/Cannon
@onready var _cannon_muzzle: Marker2D = $Visuals/Cannon/Muzzle
@onready var _flak_warn: ThreatFlash = $Visuals/Cannon/Muzzle/ThreatFlash
@onready var _nose_warn: ThreatFlash = $Visuals/Nose/ThreatFlash
@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash # 直射枪口（不预警，但池化复用要兜底重置）
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


## 血条上方显示的机体名。
func _display_name() -> String:
	return "断云"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld5.INTERCEPTOR_HOVER_Y # 绝对锚：机体 280..460，对最高台阶 536 净空 76px


func on_spawned() -> void:
	super()
	_flak_launched = 0
	_dive_hit = false


## 双发尾焰：金琥珀错相呼吸（截击机无旋翼）；预警/俯冲期过烧增亮=俯冲的
## 第二重预警读法（机鼻闪光之外的引擎语言）。失衡/死亡演出期间也照烧。
func _tick_visual(delta: float) -> void:
	var burn := 1.0
	if _bstate == ST_DIVE_WARN:
		burn = 1.6
	elif _bstate == ST_DIVE:
		burn = 2.0
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = minf((0.5 + 0.25 * sin(_bob_t * 13.0 + i * 2.1)) * burn, 1.0)
		t.scale = Vector2.ONE * minf((0.9 + 0.15 * sin(_bob_t * 9.0 + i * 1.7)) * burn, 2.2)
	# 背部啸雷炮塔俯仰跟随（真瞄读法；塔身独件双管朝天画，转角补 90°）
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		_cannon.rotation = _cannon_muzzle.global_position \
				.direction_to(player.global_position).angle() + PI * 0.5


## ---- 技能 A：啸雷齐射 ----

func _begin_skill_a() -> void:
	_bstate = ST_FLAK_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_flak_launched = 0
	_flak_warn.warn() # 预警统一入口：背炮管口闪光 + 警告音


## 出膛节拍：蓄力结束首发即出，逐发梯次；**每发都按玩家当时位置定距**
##（无 lead：跑=身后开花，停=原地吃爆）——弹串沿跑线追赶（提案 §2 弹串账）。
func _launch_ticker(delta: float) -> void:
	if _flak_launched >= _flak_count():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var from := _cannon_muzzle.global_position
	var aim := player.global_position
	var shell := FlakShell.new()
	shell.damage = BalanceWorld5.INTERCEPTOR_FLAK_DAMAGE
	shell.blast_radius = BalanceWorld5.INTERCEPTOR_FLAK_BLAST_RADIUS
	container.add_child(shell)
	shell.launch(terrain, from, from.direction_to(aim),
			from.distance_to(aim) / BalanceWorld5.FLAK_SHELL_SPEED)
	_flak_launched += 1
	_launch_t = BalanceWorld5.INTERCEPTOR_FLAK_STAGGER
	Sfx.play(&"fire_enemy") # 占位：高炮出膛暂用敌枪声，啸雷配方后配


## ---- 技能 B：俯冲突袭 ----

func _begin_skill_b() -> void:
	_bstate = ST_DIVE_WARN
	_bt = BalanceWorld5.INTERCEPTOR_DIVE_WARN
	_dive_hit = false
	_nose_warn.warn() # 预警统一入口：机鼻闪光 + 警告音（尾焰增亮在 _tick_visual）


## 出手锁定：预警结束瞬间读定出手点（玩家当时 x、当地地表−CLEAR）——
## 机体本身是"炮口"，锁定一次后直线通场（后撤/横移出线=免）。
func _lock_dive() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if player == null or terrain == null:
		_enter_recover(BalanceWorld5.INTERCEPTOR_DIVE_RECOVER)
		return
	var target := Vector2(player.global_position.x,
			terrain.surface_y_at(player.global_position.x)
					- BalanceWorld5.INTERCEPTOR_DIVE_CLEAR)
	_dive_dir = global_position.direction_to(target)
	_dive_travel = 0.0
	_dive_distance = global_position.distance_to(target) \
			+ BalanceWorld5.INTERCEPTOR_DIVE_OVERSHOOT
	_bstate = ST_DIVE
	# 看门狗须重置（_bt 刚从预警减到 ≤0，不重置会在进入俯冲的首帧判超时
	# 立刻拉起=俯冲自灭）；正常退出走 _tick_screen_lock 的过冲判据，这只是兜底。
	_bt = _dive_distance / BalanceWorld5.INTERCEPTOR_DIVE_SPEED + 0.5


## 冲撞判定：body_size 半宽/半高 + 玩家半宽限，一次俯冲至多结算一次。
func _dive_contact() -> void:
	if _dive_hit:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	var d := player.global_position - global_position
	if absf(d.x) <= body_size.x * 0.5 + PLAYER_HALF_W \
			and absf(d.y) <= body_size.y * 0.5 + PLAYER_HALF_H:
		_dive_hit = true
		player.take_damage(BalanceWorld5.INTERCEPTOR_DIVE_DAMAGE)
		player.add_shake(BalancePlayer.PLAYER_DAMAGE_SHAKE_STRENGTH)


## 拉起：过冲到点交还框架（RECOVER 到点直接出下一手，弹簧弹回构图位）。
func _end_dive() -> void:
	_vel = Vector2.ZERO
	_control_vx = 0.0
	velocity = Vector2.ZERO
	_enter_recover(BalanceWorld5.INTERCEPTOR_DIVE_RECOVER)


## ---- 普攻：机鼻曳光 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_bt = BalanceCombat.BOSS_DIRECT_DURATION
	_direct_shoot_t = 0.0 # 首发即出


## ---- 运动出口接管：俯冲态跳过悬浮锚/构图位弹簧，速度整体喂给 dive 向量 ----

func _tick_vertical(delta: float) -> void:
	if _bstate != ST_DIVE:
		super(delta)
		return
	_vel = _dive_dir * BalanceWorld5.INTERCEPTOR_DIVE_SPEED
	velocity.y = _vel.y
	_control_vx = _vel.x
	# 台阶校平：中心不得压进当地地表 −CLEAR 以深（滑过台阶上缘，不穿模）
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	if terrain != null:
		var ceil_y := terrain.surface_y_at(global_position.x) \
				- BalanceWorld5.INTERCEPTOR_DIVE_CLEAR
		if global_position.y > ceil_y:
			global_position.y = ceil_y
			velocity.y = minf(velocity.y, 0.0)


func _tick_screen_lock(delta: float) -> void:
	if _bstate != ST_DIVE:
		super(delta)
		return
	var step := BalanceWorld5.INTERCEPTOR_DIVE_SPEED * delta
	_dive_travel += step
	_dive_contact()
	if _dive_travel >= _dive_distance:
		_end_dive()


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_FLAK_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_FLAK_FIRE
				_flak_launched = 0
				_launch_t = 0.0
				_bt = (_flak_count() - 1) * BalanceWorld5.INTERCEPTOR_FLAK_STAGGER \
						+ 1.0 # 全数出膛+飞行空爆窗口
		ST_FLAK_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld5.INTERCEPTOR_FLAK_RECOVER)
		ST_DIVE_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_lock_dive()
		ST_DIVE:
			_bt -= delta
			if _bt <= 0.0: # 兜底：异常卡俯冲（无地形等）强制拉起
				_end_dive()
		ST_DIRECT:
			_bt -= delta
			_direct_shoot_t -= delta
			if _direct_shoot_t <= 0.0:
				var player := get_tree().get_first_node_in_group("player") as Player
				if player != null:
					_fire_direct_shot(_muzzle.global_position.direction_to(
							player.global_position))
				_direct_shoot_t = BalanceCombat.BOSS_SWEEP_FIRE_INTERVAL
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)


## 直瞄单发：曳光矢弹真从机鼻炮口出膛、朝玩家当前位置（无预判）；弹是
## bullet.gd 纯换皮（速度/伤害复用 BOSS_SWEEP_*），命中迸溅染紫白。
func _fire_direct_shot(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var b := DAWN_BOLT.instantiate() as Bullet
	b.speed = BalanceCombat.BOSS_SWEEP_SPEED
	b.damage = BalanceCombat.BOSS_SWEEP_DAMAGE
	b.impact_tint = Color(0.72, 0.62, 1.0)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = _muzzle.global_position
	b.reset_physics_interpolation()
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_enemy")


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数
##（俯冲断在预警=重走；已出手进入通场的俯冲不回头，冲完自己拉起）。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_FLAK_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_flak_warn.warn()
		ST_DIVE_WARN:
			_bt = BalanceWorld5.INTERCEPTOR_DIVE_WARN
			_nose_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_flak_warn.reset()
	_nose_warn.reset()
	_warn.reset()


## ---- 二阶段数值 ----

func _flak_count() -> int:
	return BalanceWorld5.INTERCEPTOR_FLAK_COUNT \
			+ (BalanceWorld5.INTERCEPTOR_PHASE2_FLAK_BONUS if _phase2 else 0) \
			+ RunState.ladder_bullets_extra()
