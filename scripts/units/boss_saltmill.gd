class_name BossSaltmill
extends PursuitBoss
## 第八章 BOSS·悬浮采盐联合机「盐磨」（镜盐之原守卫）：追击框架能力层——
## 「采盐与地热」。低宽联合机（镜阵翼俯仰真瞄+腹裂地锚口+舷侧盐料斗；锚点账
## 见 bake_salt_units.py 头注/提案_v1 §3）：
##   间歇泉幕（技能A）：腹口（BayPort）预警 → 裂地镖 5 枚梯次远→近出膛，
##     落点锚玩家**当时**位置前后铺开（前方 900..身后 28，间距 232，无 lead）
##     → 各自 mark（0.7s 地裂环纹）→ 瞬时汽柱（0.55s，高 360）——「柱是墙
##     不是弹」：跳≠过，反制=离/穿缝/等（梯次远→近，身后先灭）；
##   定镜灼烤（技能B）：镜翼蓄光 0.5s（翼面泛粉=蓄能读法）→ 逐点 **干燥光束
##     线**（镜面→落点，无伤=反向预告：先看见烧哪）→ 灼点 tick 区——落点=
##     半 lead（玩家速度×1.1 clamp 400，ArcFence 同账）：罚匀速不罚变速，
##     梯次连点压挪位路线；
##   融盐重弹（普攻=单发点放，2026-11-06 用户换皮：别像普通机枪，要配得上
##     镜阵聚焦口——镜阵聚热熔出的盐弹）：salt_bolt.tscn=bullet.gd 纯换皮
##     （暗盐壳+熔芯裂缝+白热熔芯，照 slag_slug 账），单发朝玩家**出手瞬间**
##     位置（无预判无逐发跟踪=离散点放，可跳越/挪位），p2 双发各自重瞄；
##     开火戏=枪口焰+熔杏爆闪双叠+fire_heavy 专配出膛音（ch2 重弹同款份量）。
## 分工账：泉幕=罚站桩与罚直线穿行（离/穿缝/等），灼点=罚匀速与罚慢挪
## （变速变向）——全章语言=「变速变向，读线走位」。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架。数值全在 BalanceWorld8.SALTMILL_*。

const ST_GEYSER_WARN := 3
const ST_GEYSER_FIRE := 4
const ST_BURN_GLOW := 5
const ST_BURN_FIRE := 6
const ST_DIRECT := 7

const SALT_BOLT := preload("res://scenes/weapons/salt_bolt.tscn")

const WING_GLOW := Color(1.0, 0.62, 0.74) # 蓄光粉（盐田粉系，modulate 泛粉读法）

var _darts_launched := 0
var _launch_t := 0.0
var _geyser_anchor_x := 0.0 # 泉幕锚：出膛轮开始时玩家的位置（无 lead，当时位置）
var _burns_launched := 0
var _molten_fired := 0
var _direct_shoot_t := 0.0

# 镜阵翼=敌基类的 ArmPivot（俯仰瞄准层由 Enemy._physics_process 驱动，同沉锚
# 艏炮账）：_muzzle/_muzzle_flash 直接沿用基类的 $Visuals/ArmPivot/Muzzle 句柄
# （融盐重弹点放+灼烤光束源=翼尖聚焦口）。
@onready var _wing: Sprite2D = $Visuals/ArmPivot/Sprite2D
@onready var _muzzle_warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash
@onready var _bay_warn: ThreatFlash = $Visuals/BayPort/ThreatFlash
@onready var _bay_flash: MuzzleFlash = $Visuals/BayPort/Flash
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


## 血条上方显示的机体名。
func _display_name() -> String:
	return "盐磨"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld8.SALTMILL_HOVER_Y # 绝对锚：机体 280..460，对最高台阶 536 净空 76


func on_spawned() -> void:
	super()
	_darts_launched = 0
	_burns_launched = 0
	_wing.modulate = Color.WHITE


## 双举升喷口杏金呼吸（联合机无旋翼）；镜阵翼俯仰由基类瞄准层驱动，这里不重复。
func _tick_visual(_delta: float) -> void:
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = 0.45 + 0.25 * sin(_bob_t * 11.0 + i * 2.3)
		t.scale = Vector2.ONE * (0.95 + 0.15 * sin(_bob_t * 8.0 + i * 1.9))


## ---- 技能 A：间歇泉幕 ----

func _begin_skill_a() -> void:
	_bstate = ST_GEYSER_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_darts_launched = 0
	_bay_warn.warn() # 预警统一入口：腹口闪光 + 警告音


## 泉幕镖数（难度阶梯第 4 关档起 +1）：几何铺开与时序窗口全走这里取数=同一把尺。
func _geyser_count() -> int:
	return BalanceWorld8.SALTMILL_GEYSER_COUNT + RunState.ladder_bullets_extra()


## 出膛节拍：蓄力结束首镖即出，逐发梯次远→近；落点锚**出膛轮开始时**玩家的
## 位置（无 lead——当时位置；mark 各自 0.7s 预警，跑离/穿缝/等=免）。
func _launch_ticker(delta: float) -> void:
	if _darts_launched >= _geyser_count():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if terrain == null or container == null:
		return
	# 玩家前方 SPAN .. 身后 REAR 等距铺开（梯次远→近：身后先灭，跑过空场=免）
	var i := _darts_launched
	var spread := BalanceWorld8.SALTMILL_GEYSER_SPAN + BalanceWorld8.SALTMILL_GEYSER_REAR
	var tx := _geyser_anchor_x + BalanceWorld8.SALTMILL_GEYSER_SPAN \
			- spread * i / float(_geyser_count() - 1)
	var from := ($Visuals/BayPort as Node2D).global_position
	var target := Vector2(tx, terrain.surface_y_at(tx))
	var dart := SaltDart.new()
	container.add_child(dart)
	dart.launch(terrain, from, target)
	_bay_flash.fire(dart.initial_dir().angle()) # 出膛焰=弹向（真实枪口律）
	_darts_launched += 1
	_launch_t = BalanceWorld8.SALTMILL_GEYSER_STAGGER
	Sfx.play(&"fire_enemy") # 占位：腹口出膛暂用敌枪声，裂地镖配方后配


## ---- 技能 B：定镜灼烤 ----

func _begin_skill_b() -> void:
	_bstate = ST_BURN_GLOW
	_bt = BalanceWorld8.MIRROR_BURN_GLOW
	_burns_launched = 0
	# 预警统一入口：翼尖聚焦口 ThreatFlash（红闪+警告音）——光束线之前的
	# 「炮口预警」段；翼面粉光（GLOW 分支 modulate）只作次级蓄能读法，
	# 单靠它读不出预警（小挂件色相偏移太弱，2026-11-06 用户报修）。
	_muzzle_warn.warn()


## 逐点出线：**半 lead** 落点（玩家速度×1.1 clamp LEAD_MAX 400——罚匀速不罚
## 变速；停=lead≈0 落脚下）；干燥光束线（镜面→落点，无伤）由 MirrorBurn
## 自带（beam_source=翼尖聚焦口，真实源点），蓄热窗=线驻留窗，随后灼点咬人。
func _launch_burns(delta: float) -> void:
	var count := BalanceWorld8.SALTMILL_BURN_COUNT \
			+ (BalanceWorld8.SALTMILL_PHASE2_BURN_BONUS if _phase2 else 0) \
			+ RunState.ladder_bullets_extra()
	if _burns_launched >= count:
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var lead := player.velocity * BalanceWorld8.MIRROR_BURN_LEAD_TIME
	if lead.length() > BalanceWorld8.MIRROR_BURN_LEAD_MAX:
		lead = lead.normalized() * BalanceWorld8.MIRROR_BURN_LEAD_MAX
	var tx := player.global_position.x + lead.x
	var burn := MirrorBurn.new()
	burn.radius = BalanceWorld8.MIRROR_BURN_RADIUS
	burn.damage = BalanceWorld8.MIRROR_BURN_DAMAGE
	burn.tick_interval = BalanceWorld8.MIRROR_BURN_TICK
	burn.beam_source = _muzzle.global_position
	container.add_child(burn)
	burn.global_position = Vector2(tx, terrain.surface_y_at(tx) - 4.0)
	burn.reset_physics_interpolation()
	_burns_launched += 1
	var stagger := BalanceWorld8.SALTMILL_PHASE2_BURN_STAGGER if _phase2 \
			else BalanceWorld8.SALTMILL_BURN_STAGGER
	_launch_t = stagger
	Sfx.play(&"fire_enemy") # 占位：干燥光束暂用敌枪声，灼烤配方后配


## ---- 普攻：融盐重弹（镜阵聚热点放） ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_molten_fired = 0
	_direct_shoot_t = BalanceWorld8.SALTMILL_MOLTEN_DELAY # 枪臂真瞄到位的一拍再点放
	# 出手窗=点放拍+双发间隔+尾拍（总 ≈0.32s/p2 0.47s，短于旧短梭 0.5，后摇不变）
	_bt = BalanceWorld8.SALTMILL_MOLTEN_DELAY \
			+ (_molten_count() - 1) * BalanceWorld8.SALTMILL_MOLTEN_TWIN_GAP + 0.2


func _molten_count() -> int:
	return 1 + (BalanceWorld8.SALTMILL_PHASE2_MOLTEN_BONUS if _phase2 else 0)


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_GEYSER_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_GEYSER_FIRE
				var player := get_tree().get_first_node_in_group("player") as Player
				_geyser_anchor_x = player.global_position.x if player != null \
						else global_position.x
				_darts_launched = 0
				_launch_t = 0.0
				_bt = (_geyser_count() - 1) \
						* BalanceWorld8.SALTMILL_GEYSER_STAGGER \
						+ BalanceWorld8.SALT_DART_FLIGHT_MAX \
						+ BalanceWorld8.SALT_GEYSER_WARN \
						+ BalanceWorld8.SALT_GEYSER_ERUPT + 0.3 # 全事件链窗口
		ST_GEYSER_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld8.SALTMILL_GEYSER_RECOVER)
		ST_BURN_GLOW:
			# 镜翼蓄光：翼面泛粉渐亮（呼吸推进），光束线在 FIRE 段接棒
			var k := clampf(1.0 - _bt / BalanceWorld8.MIRROR_BURN_GLOW, 0.0, 1.0)
			_wing.modulate = Color.WHITE.lerp(WING_GLOW,
					k * (0.7 + 0.3 * sin(_bob_t * 24.0)))
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_BURN_FIRE
				_burns_launched = 0
				_launch_t = 0.0
				var count := BalanceWorld8.SALTMILL_BURN_COUNT \
						+ (BalanceWorld8.SALTMILL_PHASE2_BURN_BONUS if _phase2 else 0) \
						+ RunState.ladder_bullets_extra()
				var stagger := BalanceWorld8.SALTMILL_PHASE2_BURN_STAGGER if _phase2 \
						else BalanceWorld8.SALTMILL_BURN_STAGGER
				_bt = (count - 1) * stagger + BalanceWorld8.MIRROR_BURN_BEAM \
						+ BalanceWorld8.MIRROR_BURN_TICK_TIME + 0.3 # 全事件链窗口
		ST_BURN_FIRE:
			_launch_burns(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld8.SALTMILL_BURN_RECOVER)
		ST_DIRECT:
			_bt -= delta
			_direct_shoot_t -= delta
			if _molten_fired < _molten_count() and _direct_shoot_t <= 0.0:
				var player := get_tree().get_first_node_in_group("player") as Player
				if player != null:
					_fire_molten(_muzzle.global_position.direction_to(
							player.global_position))
				_molten_fired += 1
				_direct_shoot_t = BalanceWorld8.SALTMILL_MOLTEN_TWIN_GAP
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)


## 融盐重弹单发：镜阵聚热熔盐真从翼尖聚焦口出膛、朝玩家**出手瞬间**位置
## （无预判无逐发跟踪=离散点放，可跳越）；弹=salt_bolt.tscn（bullet.gd 纯换
## 皮，暗盐壳+熔芯裂缝读法照 slag_slug 账）。开火戏=枪口焰+熔杏爆闪双叠=
## 「重炮点放」的份量；出膛音=fire_heavy 专配（占位 fire_enemy 已退役）。
func _fire_molten(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var from := _muzzle.global_position
	var b := SALT_BOLT.instantiate() as Bullet
	b.speed = BalanceWorld8.SALTMILL_MOLTEN_SPEED
	b.damage = BalanceWorld8.SALTMILL_MOLTEN_DAMAGE
	b.impact_tint = Color(1.0, 0.58, 0.3) # 熔杏（#ff944d 档）：重弹命中迸的是熔盐不是火花
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = from
	b.reset_physics_interpolation()
	var bloom := FlashBurst.new()
	bloom.flash_color = Color(1.0, 0.64, 0.42) # 熔杏爆闪（衰减到白）
	bloom.size_scale = 0.8
	bloom.position = from # 先定位再入树（补间在 _ready 起跑）
	container.add_child(bloom)
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_heavy")


## 动作收势：翼面粉光退净（灼烤的蓄光只属于那一手）。
func _enter_recover(base: float) -> void:
	_wing.modulate = Color.WHITE
	super(base)


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_GEYSER_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_bay_warn.warn()
		ST_BURN_GLOW:
			_bt = BalanceWorld8.MIRROR_BURN_GLOW
			_muzzle_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_muzzle_warn.reset()
	_bay_warn.reset()
