class_name BossRedwheel
extends PursuitBoss
## 第六章 BOSS·斗轮采集舰「赤轮」（赤沙矿区守卫）：追击框架能力层——
## 「矿区电网与输送」。低矮宽驳采集舰（斗轮独立旋转件+背甲双桩炮架+腹舱；
## 锚点账见 bake_red_units.py 头注/提案_v1 §3）：
##   电网闸（技能A）：背甲炮架（固定射角）预警 → 两枚锚桩落到玩家**当时
##     位置两侧**（ArcFence，无 lead——「桩钉住你现在的位置」就是机制）→
##     蓄能火花渐亮 → 竖直电幕立起（停=被围/跑=出带免/出笼交税或推进飞越；
##     精英「锚桩」已预教）；
##   凿岩齐射（技能B）：腹舱（BayPort）预警 → 抛 DrillCharge 凿岩装药——
##     lead 解算落到玩家前进路径上等距铺开，落地即钉住（**落点静止件零地形
##     跟随**，贴地跑行类已判死），定延时起爆封跑线路径（变速/变向=装药
##     落在身后；p2 走廊拉长）；
##   斗轮抛石（普攻）：**斗轮=武器**（2026-11-02 替掉毂心机枪短梭；11-03 改
##     外缘切向甩出）——斗轮提速吐料一拍 → 逐石从**斗轮外缘切向**甩出（发射点=
##     出手方向反退到轮缘的切点，世界逆时针轮的上缘切向=出手向，石头沿轮斗运动
##     离开；弹=red_lob.tscn，bullet.gd 抛体语法）：每枚按 solve_lob_velocity 解到
##     玩家**出手瞬间**位置（无 lead、无跟踪），按序号在固定扇里错开方向——石群
##     落点围着玩家当时位置散布：站桩/直线冲脸=吃，看弧线挪位=免，弧线从头顶盖
##     下来滞空不免费。抛体不贴地（贴地跟随类已判死）。提速本身是读法，出膛尘
##     一撮=甩石工序（普攻不挂 ThreatFlash）。斗轮恒转（signature 动画）。
## 分工账：站桩被电网罚+抛石落点罚、匀速跑被装药走廊罚、直线冲脸被石扇罚——
## 反制=变速变向（相对速度语言，ch2/ch4 同族）。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架。数值全在
## BalanceWorld6.REDWHEEL_*/REDWHEEL_CHARGE_*/REDWHEEL_LOB_*。

const ST_FENCE_WARN := 3
const ST_FENCE_FIRE := 4
const ST_CHARGE_WARN := 5
const ST_CHARGE_FIRE := 6
const ST_DIRECT := 7

const RED_LOB := preload("res://scenes/weapons/red_lob.tscn")
const DRILL_PLANT_DUST := preload("res://scenes/fx/drill_plant_dust.tscn")

var _charges_launched := 0
var _launch_t := 0.0
var _lobs_thrown := 0
var _direct_shoot_t := 0.0

@onready var _rack: Node2D = $Visuals/Rack
@onready var _rack_muzzle: Marker2D = $Visuals/Rack/Muzzle
@onready var _rack_flash: MuzzleFlash = $Visuals/Rack/Muzzle/Flash
@onready var _fence_warn: ThreatFlash = $Visuals/Rack/Muzzle/ThreatFlash
@onready var _bay_warn: ThreatFlash = $Visuals/BayPort/ThreatFlash
@onready var _bay_flash: MuzzleFlash = $Visuals/BayPort/Flash
@onready var _wheel: Sprite2D = $Visuals/ArmPivot/Wheel
@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash # 斗轮毂心（不预警，但池化复用要兜底重置）
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


## 血条上方显示的机体名。
func _display_name() -> String:
	return "赤轮"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld6.REDWHEEL_HOVER_Y # 绝对锚：机体 280..460，斗轮缘 454 对最高台阶净空 76


## 斗轮固定安装（不随玩家俯仰；直射由毂心真瞄承担）。
func _arm_tracks_pitch() -> bool:
	return false


func on_spawned() -> void:
	super()
	_charges_launched = 0


## 斗轮恒转（采掘读法；抛石/装药齐射期加速=「吐料」语言，抛石的提速一拍就是
## 它的出手读法）。方向账：×scale.x 抵消镜像=世界向恒定；取负=世界**逆时针**
## ——轮缘上缘永远朝玩家侧（左）运动，抛石才有「轮斗把石头甩出去」的连续读法
## （2026-11-03 抛石改外缘切向甩出配套；顺时针时缘上切向朝右=与出手向相反）。
## + 双举升风扇呼吸 + 背甲炮架/腹舱固定（无俯仰挂件）。
func _tick_visual(delta: float) -> void:
	var spin := 14.0 if (_bstate == ST_DIRECT or _bstate == ST_CHARGE_FIRE) else 5.0
	_wheel.rotation = fmod(_wheel.rotation - spin * delta * _visuals.scale.x, TAU)
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = 0.45 + 0.25 * sin(_bob_t * 11.0 + i * 2.3)
		t.scale = Vector2.ONE * (0.95 + 0.15 * sin(_bob_t * 8.0 + i * 1.9))


## ---- 技能 A：电网闸 ----

func _begin_skill_a() -> void:
	_bstate = ST_FENCE_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_fence_warn.warn() # 预警统一入口：炮架管口闪光 + 警告音


## 落桩：落带中心=玩家当时位置 ±半 lead（速度×预警到立幕的时长，clamp
## LEAD_MAX——惩罚缓移与后撤，全速跑仍出带；提案 §2 惩罚账）。
func _drop_fence() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player != null and terrain != null and container != null:
		var delay := BalanceWorld6.REDWHEEL_STAKE_FLIGHT + _fence_warmup()
		var lead := clampf(player.velocity.x * delay,
				-BalanceWorld6.REDWHEEL_FENCE_LEAD_MAX, BalanceWorld6.REDWHEEL_FENCE_LEAD_MAX)
		var fence := ArcFence.new()
		fence.damage = BalanceWorld6.REDWHEEL_FENCE_DAMAGE
		fence.half_width = BalanceWorld6.REDWHEEL_FENCE_HALF
		fence.top_height = BalanceWorld6.REDWHEEL_FENCE_TOP
		fence.warmup_time = _fence_warmup()
		fence.lifetime = BalanceWorld6.REDWHEEL_FENCE_LIFE
		fence.stake_flight = BalanceWorld6.REDWHEEL_STAKE_FLIGHT
		container.add_child(fence)
		fence.launch(terrain, _rack_muzzle.global_position,
				player.global_position.x + lead)
		_rack_flash.fire(-PI * 0.5) # 出膛焰朝天（固定射角读法），钉在管口
		Sfx.play(&"fire_enemy") # 占位：打桩出膛暂用敌枪声
	_enter_recover(BalanceWorld6.REDWHEEL_FENCE_RECOVER)


func _fence_warmup() -> float:
	return BalanceWorld6.REDWHEEL_PHASE2_FENCE_WARMUP if _phase2 \
			else BalanceWorld6.REDWHEEL_FENCE_WARMUP


## ---- 技能 B：凿岩齐射 ----

func _begin_skill_b() -> void:
	_bstate = ST_CHARGE_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_charges_launched = 0
	_launch_t = 0.0
	_bay_warn.warn() # 预警统一入口：腹舱口闪光 + 警告音


## 装药走廊：落带中心=玩家位置 + 半 lead（速度×飞行+引信，clamp LEAD_MAX），
## 沿跑道路面等距铺开（间距 > 爆球直径：不连锁、缝可读）；每枚独立解算
## 抛体弹道落各自的贴地点（落点即静止，零地形跟随）。无预判弹道语法不变
## ——lead 只在开火时机算一次（真实枪口律）。
func _launch_ticker(delta: float) -> void:
	if _charges_launched >= _charge_count():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var total := BalanceWorld6.REDWHEEL_CHARGE_FLIGHT + BalanceWorld6.REDWHEEL_CHARGE_FUSE
	var lead := clampf(player.velocity.x * total,
			-BalanceWorld6.REDWHEEL_CHARGE_LEAD_MAX, BalanceWorld6.REDWHEEL_CHARGE_LEAD_MAX)
	var center := player.global_position.x + lead
	var from := ($Visuals/BayPort as Node2D).global_position
	var i := _charges_launched
	var x := center + (float(i) - float(_charge_count() - 1) * 0.5) \
			* BalanceWorld6.REDWHEEL_CHARGE_SPACING
	var charge := DrillCharge.new()
	charge.damage = BalanceWorld6.REDWHEEL_CHARGE_DAMAGE
	charge.blast_radius = BalanceWorld6.REDWHEEL_CHARGE_RADIUS
	charge.flight_time = BalanceWorld6.REDWHEEL_CHARGE_FLIGHT
	charge.fuse_time = BalanceWorld6.REDWHEEL_CHARGE_FUSE
	container.add_child(charge)
	charge.launch(terrain, from,
			Vector2(x, terrain.surface_y_at(x)), BalanceWorld6.REDWHEEL_CHARGE_FLIGHT)
	_bay_flash.fire(charge.initial_dir().angle()) # 出膛焰=装药初速向（真实枪口律）
	_charges_launched += 1
	_launch_t = BalanceWorld6.REDWHEEL_CHARGE_STAGGER
	Sfx.play(&"fire_enemy") # 占位：出膛暂用敌枪声，装药配方后配


func _charge_count() -> int:
	return BalanceWorld6.REDWHEEL_CHARGE_COUNT \
			+ (BalanceWorld6.REDWHEEL_PHASE2_CHARGE_BONUS if _phase2 else 0)


## ---- 普攻：斗轮抛石 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_lobs_thrown = 0
	_direct_shoot_t = BalanceWorld6.REDWHEEL_LOB_WINDUP # 斗轮提速吐料的一拍，再逐石抛出
	# 出手窗=提速拍+逐石节拍+尾拍（5 石 ≈0.8s，后摇不变）
	_bt = BalanceWorld6.REDWHEEL_LOB_WINDUP \
			+ (_lob_count() - 1) * BalanceWorld6.REDWHEEL_LOB_STAGGER + 0.15


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_FENCE_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_drop_fence()
		ST_CHARGE_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_CHARGE_FIRE
				_charges_launched = 0
				_launch_t = 0.0
				_bt = (_charge_count() - 1) * BalanceWorld6.REDWHEEL_CHARGE_STAGGER \
						+ BalanceWorld6.REDWHEEL_CHARGE_FLIGHT \
						+ BalanceWorld6.REDWHEEL_CHARGE_FUSE + 0.4 # 全数出膛+落地起爆窗口
		ST_CHARGE_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld6.REDWHEEL_CHARGE_RECOVER)
		ST_DIRECT:
			_bt -= delta
			_direct_shoot_t -= delta
			if _lobs_thrown < _lob_count() and _direct_shoot_t <= 0.0:
				_throw_lob(_lobs_thrown)
				_lobs_thrown += 1
				_direct_shoot_t = BalanceWorld6.REDWHEEL_LOB_STAGGER
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)


## 抛一枚弹石（2026-11-03 用户「要从轮斗甩出，不是毂心射出」；同日二轮修正
## 「扇面角度被弹道解算吃掉」）：**发射点=斗轮外缘切点**（出手方向逆旋 90° 取
## 法向——世界逆时针轮的上缘切向恰=出手向，石头沿轮斗运动方向离开）；扇面=
## **先解基准弹道（中心石恰落玩家出手瞬间位置），再按序号旋开初速**——弹道
## 解算每石只做一次，切点跟各自出手向走，两翼落点各偏 ≈±100/±200（若每石
## 各自解算回同一落点，扇面就被吃成一条线，首轮即踩）。无 lead、无跟踪：
## 石群锁的是出手时玩家站的地方。弹是 bullet.gd 抛体换皮（lob_gravity>0），
## 落地/命中迸溅染暖砂；出膛枪火不合适已移除，换=切点一撮凿尘
## （drill_plant_dust 压量级，「轮斗刨出一块石头」的工序读法，普攻不挂预警闪）。
func _throw_lob(index: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or container == null:
		return
	var to := player.global_position
	var wheel_center := _wheel.global_position
	var radius := _wheel.texture.get_size().x * 0.5 * absf(_wheel.global_scale.x)
	# 基准弹道：中心石从基准切点出发恰中玩家出手瞬间位置（一次解算，全扇共用）
	var base_dir := wheel_center.direction_to(to)
	var base_from := wheel_center + base_dir.rotated(PI * 0.5) * radius
	var flight := clampf(absf(to.x - base_from.x) / BalanceWorld6.REDWHEEL_LOB_RANGE_SPEED,
			BalanceWorld6.REDWHEEL_LOB_FLIGHT_MIN, BalanceWorld6.REDWHEEL_LOB_FLIGHT_MAX)
	var v := Bullet.solve_lob_velocity(base_from, to,
			BalanceWorld6.REDWHEEL_LOB_GRAVITY, flight)
	# 本石扇开：初速按序号旋开（落点随之散布），切点跟本石出手向重取
	v = v.rotated((float(index) - float(_lob_count() - 1) * 0.5) \
			* deg_to_rad(BalanceWorld6.REDWHEEL_LOB_SPREAD_STEP_DEG))
	var d := v.normalized()
	var from := wheel_center + d.rotated(PI * 0.5) * radius
	var b := RED_LOB.instantiate() as Bullet
	b.speed = v.length()
	b.damage = BalanceWorld6.REDWHEEL_LOB_DAMAGE
	b.lob_gravity = BalanceWorld6.REDWHEEL_LOB_GRAVITY
	b.impact_tint = Color(1.0, 0.62, 0.42)
	b.setup(d, Vector2.ZERO)
	container.add_child(b)
	b.global_position = from
	b.reset_physics_interpolation()
	var puff := DRILL_PLANT_DUST.instantiate() as Node2D
	puff.scale = Vector2(0.6, 0.6)
	puff.position = from # 先定位再入树（one_shot 粒子入树即出生）
	container.add_child(puff)
	Sfx.play(&"fire_enemy") # 占位：甩石出膛暂用敌枪声


func _lob_count() -> int:
	return BalanceWorld6.REDWHEEL_LOB_COUNT \
			+ (BalanceWorld6.REDWHEEL_PHASE2_LOB_BONUS if _phase2 else 0)


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_FENCE_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_fence_warn.warn()
		ST_CHARGE_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_bay_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_fence_warn.reset()
	_bay_warn.reset()
	_warn.reset()
