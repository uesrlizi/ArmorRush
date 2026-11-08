class_name BossAnchor
extends PursuitBoss
## 第七章 BOSS·打捞巡防舰「沉锚」（溺海都会守卫）：追击框架能力层——
## 「海防与打捞」。低矮宽巡防舰（艏炮俯仰真瞄+艉舱深弹+艉部打捞吊臂；锚点账
## 见 bake_sea_units.py 头注/提案_v1 §3）：
##   跳弹齐射（技能A，v2 平抛鱼雷）：**压低到发射高度**（ANCHOR_SKIP_FIRE_Y，
##     同 ch1 扫射压高语言：本体压下来=预警的一半）→ 艏部下管（TorpedoPort）
##     预警 → 逐发梯次 SkipShell **平抛**出膛——水平初速向玩家一侧（不瞄人，
##     发射点=船体下部的鱼雷管；v1 解算落玩家脚下，落点全在行进方向身后=
##     「跳的没意义」已判死）→ 重力拉浅弧触甲板连跳三次末跳球爆——对冲几何：
##     玩家 +X 行进 vs 弹 −X 平抛/跳=迎面相遇，平射段在头部高度（停=被平射
##     命中），跳=反制；2 发/p2+1；
##   深弹涌浪（技能B）：艉舱（BayPort）预警 → 深弹向**艉侧**抛出（远离玩家，
##     弹体走地形后方容器=坠入桥后海面，不穿桥面）→ 落海水花 → 定延时闷爆
##     → SeaSurge 固定高度带漫桥（p1 淹最低档/p2 淹到二档——低处=吃/高处=免/
##     升空=免，浮空脚手架=掩体；BOSS 现场教：水花→闷爆→涨潮三重预警）；
##   舰炮曳光（普攻直射）：艏炮真瞄玩家短点放——弹=sea_bolt.tscn（bullet.gd
##     纯换皮暗壳曳光，速度/伤害复用 BOSS_SWEEP_*，直瞄无预判语法不变），
##     真瞄即预警。
## 分工账：跳弹 hunts 地面站位与顺向跑（跳=反制），涌浪 hunts 低处停留
## （上=反制）——两手都把玩家往"上"赶。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架。数值全在 BalanceWorld7.ANCHOR_*。

const ST_SKIP_WARN := 3
const ST_SKIP_FIRE := 4
const ST_SURGE_WARN := 5
const ST_SURGE_DROP := 6
const ST_DIRECT := 7

const SEA_BOLT := preload("res://scenes/weapons/sea_bolt.tscn")

var _skips_launched := 0
var _launch_t := 0.0
var _charges_launched := 0
var _direct_shoot_t := 0.0

# 艏炮=敌基类的 ArmPivot（俯仰瞄准层由 Enemy._physics_process 驱动，同响哨高炮账）：
# _muzzle/_muzzle_flash 直接沿用基类的 $Visuals/ArmPivot/Muzzle 句柄（直射用）。
@onready var _tube: Marker2D = $Visuals/TorpedoPort # 艏部下管=跳弹出膛位（鱼雷语汇）
@onready var _tube_warn: ThreatFlash = $Visuals/TorpedoPort/ThreatFlash
@onready var _tube_flash: MuzzleFlash = $Visuals/TorpedoPort/Flash
@onready var _bay_warn: ThreatFlash = $Visuals/BayPort/ThreatFlash
@onready var _bay_flash: MuzzleFlash = $Visuals/BayPort/Flash
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


## 血条上方显示的机体名。
func _display_name() -> String:
	return "沉锚"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	if _bstate == ST_SKIP_WARN or _bstate == ST_SKIP_FIRE:
		# 技能A 压低到发射高度（鱼雷管贴水线发射；同 ch1 扫射压高语言——
		# 本体压下来就是预警的一半）。对当地地表净空账：锚 ≤ 地表−CLEAR
		# （船底=锚+90 ≥ 地表上方 60），高台阶上自动抬高锚。
		var fire_y := BalanceWorld7.ANCHOR_SKIP_FIRE_Y
		var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
		if terrain != null:
			fire_y = minf(fire_y,
					terrain.surface_y_at(global_position.x) - BalanceWorld7.ANCHOR_SKIP_CLEAR)
		return fire_y
	return BalanceWorld7.ANCHOR_HOVER_Y # 绝对锚：机体 280..460，对最高台阶 536 净空 76


func on_spawned() -> void:
	super()
	_skips_launched = 0
	_charges_launched = 0


## 双举升喷口青白呼吸（打捞舰无旋翼）；艏炮俯仰由基类瞄准层驱动，这里不重复。
func _tick_visual(_delta: float) -> void:
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = 0.45 + 0.25 * sin(_bob_t * 11.0 + i * 2.3)
		t.scale = Vector2.ONE * (0.95 + 0.15 * sin(_bob_t * 8.0 + i * 1.9))


## ---- 技能 A：跳弹齐射 ----

func _begin_skill_a() -> void:
	_bstate = ST_SKIP_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_skips_launched = 0
	_tube_warn.warn() # 预警统一入口：艏部下管闪光 + 警告音（压高是预警的另一半）


## 出膛节拍：蓄力结束首发即出，逐发梯次；**平抛**——水平初速向玩家一侧
##（不瞄人：发射点=艏部下管，鱼雷语汇；v1 解算落玩家脚下已判死——落点
## 全在行进方向身后），弹道/弹跳/溅花/末爆都在 SkipShell 内。
func _launch_ticker(delta: float) -> void:
	if _skips_launched >= _skip_count():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var dir_x := signf(player.global_position.x - global_position.x)
	if dir_x == 0.0:
		dir_x = -1.0
	var shell := SkipShell.new()
	shell.damage = BalanceWorld7.ANCHOR_SKIP_DAMAGE
	shell.blast_radius = BalanceWorld7.ANCHOR_SKIP_BLAST_RADIUS
	container.add_child(shell)
	shell.launch(terrain, _tube.global_position, dir_x)
	_skips_launched += 1
	_launch_t = _skip_stagger()
	_tube_flash.fire(Vector2(dir_x, 0.0).angle()) # 出膛焰=平射向（真实枪口律）
	Sfx.play(&"fire_enemy") # 占位：鱼雷管出膛暂用敌枪声，跳弹配方后配


func _skip_count() -> int:
	return BalanceWorld7.ANCHOR_SKIP_COUNT \
			+ (BalanceWorld7.ANCHOR_PHASE2_SKIP_BONUS if _phase2 else 0) \
			+ RunState.ladder_bullets_extra()


func _skip_stagger() -> float:
	return BalanceWorld7.ANCHOR_PHASE2_SKIP_STAGGER if _phase2 \
			else BalanceWorld7.ANCHOR_SKIP_STAGGER


## ---- 技能 B：深弹涌浪 ----

func _begin_skill_b() -> void:
	_bstate = ST_SURGE_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_charges_launched = 0
	_bay_warn.warn() # 预警统一入口：艉舱口闪光 + 警告音


## 深弹出舱：向**艉侧**抛出（远离玩家——弹落海点在 BOSS 身后，读法=打捞舰
## 在往海里丢东西）；弹体走地形后方容器（"sea_props_container"=坠入桥后海面，
## 不穿桥面）；首枚出舱时启动涌浪（lead=落海+引信：闷爆之后开始涨潮）。
func _launch_charges(delta: float) -> void:
	if _charges_launched >= BalanceWorld7.ANCHOR_CHARGE_COUNT + RunState.ladder_bullets_extra():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var container := get_tree().get_first_node_in_group("sea_props_container") as Node2D
	if container == null:
		container = get_tree().get_first_node_in_group("projectile_container") as Node2D
	if player == null or container == null:
		return
	var from := ($Visuals/BayPort as Node2D).global_position
	var toss_dir_x := signf(global_position.x - player.global_position.x)
	if toss_dir_x == 0.0:
		toss_dir_x = 1.0
	var charge := DepthCharge.new()
	container.add_child(charge)
	charge.launch(from, toss_dir_x)
	if _charges_launched == 0:
		var surge := SeaSurge.new()
		surge.flood_y = BalanceWorld7.SEA_SURGE_PHASE2_FLOOD_Y if _phase2 \
				else BalanceWorld7.SEA_SURGE_FLOOD_Y
		surge.lead = _charge_fall() + BalanceWorld7.DEPTH_CHARGE_FUSE
		var front := get_tree().get_first_node_in_group("projectile_container")
		if front != null:
			front.add_child(surge)
			surge.launch()
	_charges_launched += 1
	_launch_t = BalanceWorld7.ANCHOR_CHARGE_STAGGER
	Sfx.play(&"fire_enemy") # 占位：出舱暂用敌枪声，深弹配方后配


## 深弹坠海时长：舱口 ~430 → 海面 860 的竖直解算（抛速 260/初速 −60 微仰）。
func _charge_fall() -> float:
	return 0.45


## ---- 普攻：舰炮曳光 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_bt = BalanceCombat.BOSS_DIRECT_DURATION
	_direct_shoot_t = 0.0 # 首发即出


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_SKIP_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_SKIP_FIRE
				_skips_launched = 0
				_launch_t = 0.0
				_bt = (_skip_count() - 1) * _skip_stagger() \
						+ 2.4 # 全数出膛+平抛触甲板+三跳+末爆窗口
		ST_SKIP_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld7.ANCHOR_SKIP_RECOVER)
		ST_SURGE_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_SURGE_DROP
				_charges_launched = 0
				_launch_t = 0.0
				_bt = (BalanceWorld7.ANCHOR_CHARGE_COUNT + RunState.ladder_bullets_extra() - 1) \
						* BalanceWorld7.ANCHOR_CHARGE_STAGGER \
						+ _charge_fall() + BalanceWorld7.DEPTH_CHARGE_FUSE \
						+ BalanceWorld7.SEA_SURGE_SWELL + BalanceWorld7.SEA_SURGE_RISE \
						+ BalanceWorld7.SEA_SURGE_HOLD + 0.4 # 全事件链窗口
		ST_SURGE_DROP:
			_launch_charges(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld7.ANCHOR_SURGE_RECOVER)
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


## 直瞄单发：弹真从艏炮管口出膛、朝玩家当前位置（无预判）；弹=sea_bolt.tscn
## （v2=共享机炮弹画法，同 enemy_bullet；v1 暗壳曳光矢配白色迸溅读成
## 「黑色块瞬间消失」判死），速度/伤害复用 BOSS_SWEEP_*。
func _fire_direct_shot(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var b := SEA_BOLT.instantiate() as Bullet
	b.speed = BalanceCombat.BOSS_SWEEP_SPEED
	b.damage = BalanceCombat.BOSS_SWEEP_DAMAGE
	b.impact_tint = Color(1.0, 0.62, 0.35)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = _muzzle.global_position
	b.reset_physics_interpolation()
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_enemy")


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_SKIP_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_tube_warn.warn()
		ST_SURGE_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_bay_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_tube_warn.reset()
	_bay_warn.reset()
