class_name BossAngler
extends PursuitBoss
## 第四章 BOSS·深海猎杀舰「鮟鱇」（珊瑚辐合夜）：追击框架能力层——「珊瑚
## 能量武器」。v2 舰体按能力重设计（背驮大口径珊瑚重炮 + 艏部钓灯臂 + 腹下
## 吊挂放电舱，锚点账见 bake_coral_units.py 头注/提案_v2 §4）：
##   珊瑚重炮（技能A）：炮位（Cannon）预警 → 逐发梯次 CoralOrb 慢速能量重弹
##     （出膛瞬间 lead 瞄准，弹体自读可躲；3 发/p2+1）——惩罚"看到预警后仍
##     匀速直线跑"（相对速度即机制，精英「海葵」已预教）；
##   珊瑚潮（技能B）：腹闸（BayPort）预警 → 出舱爆蕗小瓣 → CoralTide 贴地
##     涌浪爬向玩家（跳越=免，与浮雷「跳=吃」互为镜像）；二阶段双波；
##   钓灯爆闪（普攻）：**艏部钓灯=爆闪源**（拟饵钓鱼→灯一闪、能量矢四散；
##     2026-11-02 替掉机枪短梭）——径向 N 矢同帧齐放，一矢对准玩家当时位置、余矢
##     等分圆周，弹=coral_bolt.tscn（bullet.gd 纯换皮）慢矢 ANGLER_FLASH_SPEED，
##     弹体自读、拉开距离即躲；贴脸 700 压招保底无贴脸不公平。三招三种几何：
##     重炮=点、潮=线、爆闪=面。灯亮即预警（普攻不挂 ThreatFlash）。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架；_tick_visual=尾部涵道桨
## （Rotor/TailRotor 节点位沿用）。数值全在 BalanceWorld4.ANGLER_*/CORAL_ORB_SPEED
## /CORAL_TIDE_*。

const ST_VOLLEY_WARN := 3
const ST_VOLLEY_FIRE := 4
const ST_TIDE_WARN := 5
const ST_TIDE_FIRE := 6
const ST_DIRECT := 7

const CORAL_BOLT := preload("res://scenes/weapons/coral_bolt.tscn")
const CORAL_BURST := preload("res://scenes/fx/coral_burst.tscn")

var _orb_launched := 0
var _launch_t := 0.0
var _tide_dropped := 0
var _tide_drop_t := 0.0
var _flash_fired := false
var _direct_shoot_t := 0.0

@onready var _cannon_muzzle: Marker2D = $Visuals/Cannon/Muzzle
@onready var _volley_warn: ThreatFlash = $Visuals/Cannon/Muzzle/ThreatFlash
@onready var _bay_port: Marker2D = $Visuals/BayPort
@onready var _bay_warn: ThreatFlash = $Visuals/BayPort/ThreatFlash
@onready var _bay_flash: MuzzleFlash = $Visuals/BayPort/Flash
@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash # 钓灯炮口（直射不预警，但池化复用要兜底重置）
@onready var _rotor: Sprite2D = $Visuals/Rotor
@onready var _tail_rotor: Sprite2D = $Visuals/TailRotor


## 血条上方显示的机体名。
func _display_name() -> String:
	return "鮟鱇"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld4.ANGLER_HOVER_Y # 绝对锚：船体 280..460，对最高台阶 536 净空 76px


func on_spawned() -> void:
	super()
	_orb_launched = 0
	_tide_dropped = 0


## 钓灯臂不俯仰（2026-11-03 用户「钓灯怎么还跟炮管一样旋转」）：普攻已改径向
## 爆闪，灯没有"瞄准"语义——竿臂钉在艏部原姿态只随船体镜像，拟饵就该垂着。
## 瞄准基向由爆闪出手瞬间从灯口→玩家现算（_fire_flash），不靠臂转。
func _arm_tracks_pitch() -> bool:
	return false


## 涵道双风扇：主扇侧视刃边呼吸摆，尾扇盘整周转（舰没熄火，失衡/死亡
## 演出期间也照转）。
func _tick_visual(delta: float) -> void:
	_rotor.rotation = sin(_bob_t * BalanceCombat.BOSS_ROTOR_WOBBLE_SPEED) \
			* BalanceCombat.BOSS_ROTOR_WOBBLE
	_tail_rotor.rotation += BalanceCombat.BOSS_ROTOR_SPIN * delta


## ---- 技能 A：珊瑚重炮 ----

func _begin_skill_a() -> void:
	_bstate = ST_VOLLEY_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_orb_launched = 0
	_volley_warn.warn() # 预警统一入口：背炮炮口闪光 + 警告音


## 出膛节拍：蓄力结束首发即出，逐发梯次；**瞄准锁定在各自的开火时机**
##（lead_direction：玩家速度×飞行时长，真实枪口律）——连跑的玩家被逐发
## 压在路径上，预警瞬间变向则全部落空。
func _launch_ticker(delta: float) -> void:
	if _orb_launched >= _orb_count():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var dir := CoralOrb.lead_direction(terrain, _cannon_muzzle.global_position,
			player, BalanceWorld4.CORAL_ORB_SPEED,
			BalanceWorld4.ANGLER_ORB_LEAD_BACK, BalanceWorld4.ANGLER_ORB_LEAD_MAX)
	var orb := CoralOrb.new()
	orb.damage = BalanceWorld4.ANGLER_ORB_DAMAGE
	orb.blast_radius = BalanceWorld4.ANGLER_ORB_BLAST_RADIUS
	container.add_child(orb)
	orb.launch(terrain, _cannon_muzzle.global_position, dir)
	_orb_launched += 1
	_launch_t = BalanceWorld4.ANGLER_VOLLEY_STAGGER
	Sfx.play(&"fire_enemy") # 占位：能量出膛暂用敌枪声，珊瑚系配方后配


## ---- 技能 B：珊瑚潮 ----

func _begin_skill_b() -> void:
	_bstate = ST_TIDE_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_tide_dropped = 0
	_tide_drop_t = 0.0
	_bay_warn.warn() # 预警统一入口：腹闸闪光 + 警告音


## 投放节拍：预警结束首发即涌，二阶段第二波错后一拍（舰在漂，第二波落点=
## 彼时腹舱正下方——投放口永远真实）。
func _drop_ticker(delta: float) -> void:
	if _tide_dropped >= _tide_count():
		return
	_tide_drop_t -= delta
	if _tide_drop_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var from := _bay_port.global_position
	var ground := Vector2(from.x, terrain.surface_y_at(from.x))
	var puff := CORAL_BURST.instantiate() as Node2D # 出舱爆蕗小瓣（投放口的能量吐出读法）
	puff.scale = Vector2(0.6, 0.6)
	puff.position = ground
	container.add_child(puff)
	var tide := CoralTide.new()
	container.add_child(tide)
	tide.launch(terrain, ground, signf(player.global_position.x - ground.x))
	_bay_flash.fire(deg_to_rad(90.0)) # 出舱焰朝下（放电舱往下吐潮）
	Sfx.play(&"fire_enemy") # 占位：能量出舱暂用敌枪声，珊瑚系配方后配
	_tide_dropped += 1
	_tide_drop_t = BalanceWorld4.ANGLER_TIDE_DROP_STAGGER


## ---- 普攻：钓灯爆闪 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_bt = BalanceWorld4.ANGLER_FLASH_WINDOW # 出手窗：爆闪后留一拍让矢散开再收势
	_flash_fired = false
	_direct_shoot_t = BalanceWorld4.ANGLER_FLASH_DELAY # 钓灯亮起到爆闪的一拍


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_VOLLEY_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_VOLLEY_FIRE
				_launch_t = 0.0
				_bt = (_orb_count() - 1) * BalanceWorld4.ANGLER_VOLLEY_STAGGER \
						+ 1.6 # 全数出膛+慢弹飞抵窗口
		ST_VOLLEY_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld4.ANGLER_VOLLEY_RECOVER)
		ST_TIDE_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_TIDE_FIRE
				_bt = (_tide_count() - 1) * BalanceWorld4.ANGLER_TIDE_DROP_STAGGER + 0.5 # 出舱+涌出窗
		ST_TIDE_FIRE:
			_drop_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld4.ANGLER_TIDE_RECOVER)
		ST_DIRECT:
			_bt -= delta
			_direct_shoot_t -= delta
			if not _flash_fired and _direct_shoot_t <= 0.0:
				_flash_fired = true
				_fire_flash()
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)


## 钓灯爆闪：径向 N 矢同帧从钓灯口齐放——基准矢对准玩家**出手瞬间**位置（无预判、
## 无跟踪），其余按 TAU/N 等分圆周；弹是 bullet.gd 纯换皮慢矢（贴图=电浆镖几何换
## 珊瑚配色），命中迸溅染珊瑚红。爆闪本体=珊瑚爆蕗粒群在灯头绽放（本章现役件
## 压 power）+ 枪口焰朝基准矢；一轮一声出膛音（N 矢不叠音）。
func _fire_flash() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var from := _muzzle.global_position
	var base := Vector2.LEFT
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		base = from.direction_to(player.global_position)
	var count := _flash_count()
	for i in count:
		var dir := base.rotated(TAU * float(i) / float(count))
		var b := CORAL_BOLT.instantiate() as Bullet
		b.speed = BalanceWorld4.ANGLER_FLASH_SPEED
		b.damage = BalanceWorld4.ANGLER_FLASH_DAMAGE
		b.impact_tint = Color(1.0, 0.45, 0.25) # 珊瑚家橙红（压蓝防粉）
		b.setup(dir, Vector2.ZERO)
		container.add_child(b)
		b.global_position = from
		b.reset_physics_interpolation()
	var bloom := CORAL_BURST.instantiate() as CoralBurst
	bloom.power = 0.6 # 灯头量级：比重弹爆蕗（≈2.0）小一档，读「闪」不读「爆」
	bloom.position = from # 容器在原点且无变换：先定位再入树（one_shot 粒子入树即出生）
	container.add_child(bloom)
	_muzzle_flash.fire(base.angle())
	Sfx.play(&"fire_enemy")


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_VOLLEY_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_volley_warn.warn()
		ST_TIDE_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_bay_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_volley_warn.reset()
	_bay_warn.reset()
	_warn.reset()


## ---- 二阶段数值 ----

func _orb_count() -> int:
	return BalanceWorld4.ANGLER_VOLLEY_COUNT \
			+ (BalanceWorld4.ANGLER_PHASE2_VOLLEY_BONUS if _phase2 else 0)


func _tide_count() -> int:
	return BalanceWorld4.ANGLER_TIDE_COUNT \
			+ (BalanceWorld4.ANGLER_PHASE2_TIDE_BONUS if _phase2 else 0)


func _flash_count() -> int:
	return BalanceWorld4.ANGLER_FLASH_COUNT \
			+ (BalanceWorld4.ANGLER_PHASE2_FLASH_BONUS if _phase2 else 0)
