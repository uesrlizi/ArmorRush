class_name Player
extends CharacterBody2D
## 机甲玩家：左右移动、跳跃、AC6 式飞行（空中按住跳持续推进上升）、自动开火、近战连段斩。
## 索敌：以左右移动方向为优先方向，找该侧最近的敌人；该侧没有才锁另一侧。
## 视觉朝向：优先面朝锁定的敌人，没有目标时面朝移动方向。
## 镜头：横向跟随、高度锁死（飞行范围由天花板约束在画面内）。
## 数值一律取自 BalancePlayer（玩家域调参表），本文件不存副本。

signal hp_changed(current: int, max_hp: int)
signal boost_changed(current: float, max_value: float)
signal died

enum MeleePhase { IDLE, WINDUP, DASH, STRIKE, RECOVER }

const PLAYER_BULLET := preload("res://scenes/weapons/player_bullet.tscn")
const POD_MISSILE := preload("res://scenes/weapons/player_missile.tscn")
const RAIL_BOLT := preload("res://scenes/weapons/rail_bolt.tscn")
const SPARK_BURST := preload("res://scenes/fx/spark_burst.tscn")
const TIP_SPARKS := preload("res://scenes/fx/slash_tip_sparks.tscn")
const EXPLOSION := preload("res://scenes/fx/explosion_burst.tscn")

const POD_REST_ANGLE := -0.12 # 肩部武器待机姿态：炮身微微上抬（弧度，画布本地角）

## 连段斩各段的表现配置，段序固定：一段从上往下劈、二段从下往上挑、
## 三段=加宽压扁的大横扫收尾（只被刀槽成员 三连刃 的 melee_max_stage=3 唤出，默认两段）。
## 二段起只有上一段后摇走完时吃到预输入（短时间再按）才会触发，末段之后重新起一段。
## 角度为"挥砍平面"的平面角（度）：0=正前、+90=观众一侧、±180=正后、-90=头顶方向。
## 一二段都是从一侧侧后方绕过身前扫到另一侧侧后方的 240° 大回环，方向相反；
## SlashRoot 把整个平面按 MELEE_SQUASH 压扁投影成椭圆，即 2D 侧视的"贴地横扫"。
## 近/远深度分层由 sinθ 符号决定（见 slash_arc.gd）。
## 可选段配置：squash=本段椭圆压扁倍率（更小=更平）、strike_time=本段刀光时长
## （默认 MELEE_STRIKE_TIME；第三段略长=收尾要有存在感）。
const MELEE_SWINGS := [
	{
		"from_deg": -112.0, "to_deg": 128.0, # 一段：后上侧起手，从上往下劈收至后下侧
		"radius": 122.0, "thickness": 34.0,
		"pivot": Vector2(12, -2),
		"color_core": Color(0.88, 0.98, 1.0), "color_outer": Color(0.18, 0.62, 1.0),
		"lunge_scale": 1.0,
	},
	{
		"from_deg": 112.0, "to_deg": -128.0, # 二段：后下侧起手，从下往上挑收至后上侧
		"radius": 115.0, "thickness": 30.0,
		"pivot": Vector2(10, 2),
		"color_core": Color(1.0, 0.96, 0.85), "color_outer": Color(1.0, 0.58, 0.18),
		"lunge_scale": 1.35,
	},
	{
		"from_deg": -112.0, "to_deg": 128.0, # 三段：与前两刀同幅的下劈横扫（角度不放大——
		"radius": 130.0, "thickness": 48.0, #  整周回旋试过被否=丑；存在感走宽刃带+更扁）
		"pivot": Vector2(10, 0),
		"squash": 0.55, # 压更扁：刃带读作更平的贴地横浪（三连刃收尾专属读法）
		"strike_time": 0.17, # 刀光略长于前两刀（0.12）：第三刀要有存在感
		"color_core": Color(1.0, 0.97, 0.88), "color_outer": Color(0.95, 0.72, 0.16),
		"lunge_scale": 1.5,
	},
]

var hp := 0
var max_hp := 0
var boost := 0.0 # 剩余推进量（秒）
var shield := 0  # 护盾余量（§4，一次性吸收层）：先于 hp 扣，吸掉的部分不进倍率惩罚账
var shield_max := 0 # 护盾容量（0=没装护盾）：装备入账，普通关转场满血时回满
var search_direction := 1.0 # 索敌优先方向，由左右移动决定
var input_enabled := false # 启动页待机锁操作：Main 进战斗才开（小恐龙式站桩开局）
var auto_fire := true # 自动开火副开关（自测探针临时关掉保确定性；总开关在 BalancePlayer.PLAYER_AUTO_FIRE）

var _fire_timer := 0.0
var _pod_timer := 0.0 # 肩部武器独立冷却（与主枪各走各的节拍）
var _shield_charges := 1 # 护盾剩余充能次数（§4 复层盾：碎盾后再立一次；壁垒/无装备=1 档）
var _reform_t := 0.0     # 复层盾碎盾后再立倒计时（>0=碎盾进行中）
var _hurt_t := 0.0    # 受击无敌窗剩余（秒；>0=窗内只结算比 _hurt_peak 更大的那部分）
var _hurt_peak := 0   # 本窗已结算的最大单击（原始伤害，护盾之前）
var hurt_window_enabled := true # dev 闸：几何探针（probe_world_N 多段累计伤害账）置 false
var _dead := false
var _face_dir := 1.0
var _camera_y := 0.0 # 本局镜头锁死高度（桌面=BalanceGlobal.CAMERA_Y，移动端再下移两档）
var _gun_pitch := 0.0 # 枪臂俯仰角（度，正=朝上）
var _idle_puff_t := 0.0  # 待机小喷焰剩余时间
var _idle_puff_cd := 0.6 # 下一次待机小喷焰的倒计时

# ---- 近战状态 ----
var _melee_phase := MeleePhase.IDLE
var _melee_swing := 0        # 当前段数（1=下劈/2=上挑/3=宽平收尾），段序固定：只有上一段后的追击才进下一段
var _melee_t := 0.0          # 当前阶段剩余时间
var _melee_buffered := false # 连段预约：窗口内（后摇期间）再按才置位，后摇走完兑现
var _combo_window_t := 0.0   # 连段窗口倒计时（从斩击完成起算，独立于后摇时长）
var _melee_hits := {}        # 本段已命中的敌人，一段只结算一次
var _strike_judged := false  # 本次斩击是否已到判定瞬间（MELEE_HIT_MOMENT）
var _melee_pitch := 0.0      # 挥砍俯仰角（度，正=朝上），出刀瞬间朝目标锁定、限角
var _lunge_dir := Vector2.RIGHT # 突进方向（含俯仰的竖直分量）
var _slash_clock := 0.0      # 刃光动画时钟（ACTIVE 起跑，贯穿熄灭）
var _slash_head := 0.0       # 刃口平面角（弧长只增不减：弧尾恒为起手角）
var _slash_playing := false
var _slash_flash := 0.0      # 命中闪增：斩击命中瞬间整弧提亮，随时间衰减
var _tip_sparks: CPUParticles2D # 刃口碎光发射器（扫掠期跟随刃口，停喷后自灭）
var _control_scale := 1.0    # 水平操控系数（后摇期降为 MELEE_RECOVER_CONTROL）
var _shake_strength := 0.0
var _boost_regen_delay := 0.0 # 空中松开推进后到开始回充的倒计时（落地清零立即回）
var _slide_kick := 0.0       # 重落地踢火花的剩余喷射时长（秒）
var _crouch := 0.0           # 当前滑行下蹲量（px，向目标指数趋近；腿部 IK 由 LegRig 自解算）
var _land_crouching := false # 落地缓冲进行中：先蹲到底再交还常规目标（快蹲慢起）
var _slide_sparks_base_y := 0.0 # 滑行火花原位（Visuals 下蹲时火花要钉回地面）
var _phys_prev := Vector2.ZERO # 上一个物理步位置（镜头亚步补间用，见 _process）
var _phys_curr := Vector2.ZERO

@onready var _visuals: Node2D = $Visuals
@onready var _sprite: Sprite2D = $Visuals/Sprite2D
@onready var _nozzle_pivot: Node2D = $Visuals/NozzlePivot
@onready var _arm_pivot: Node2D = $Visuals/ArmPivot
@onready var _muzzle: Marker2D = $Visuals/ArmPivot/Muzzle
@onready var _muzzle_flash: MuzzleFlash = $Visuals/ArmPivot/Muzzle/Flash
@onready var _thruster: ThrusterFlame = $Visuals/NozzlePivot/Thruster
@onready var _leg_thruster: ThrusterFlame = $Visuals/LegThruster     # 腿部姿控焰：向后喷=前进
@onready var _waist_thruster: ThrusterFlame = $Visuals/WaistThruster # 腰部姿控焰：向前喷=倒退
@onready var _slide_sparks: GroundSparks = $Visuals/SlideSparks
@onready var _camera: Camera2D = $Camera2D
@onready var _slash_root: Node2D = $Visuals/SlashRoot
@onready var _slash_far: SlashArc = $Visuals/SlashRoot/SlashFar
@onready var _slash_near: SlashArc = $Visuals/SlashRoot/SlashNear
@onready var _melee_hitbox: Area2D = $MeleeHitbox
@onready var _melee_hitbox_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var _overhead_bar: OverheadBar = $OverheadBar
@onready var _shield_ring: Sprite2D = $Visuals/ShieldRing           # 护盾环（§4 护盾槽通道）
@onready var _pod: Node2D = $Visuals/ShoulderPod                     # 肩部装备（§4 肩部武器槽）：固定支架
@onready var _pod_pivot: Node2D = $Visuals/ShoulderPod/PodPivot      # 瞄准轴：支架与炮身之间，炮身绕它转
@onready var _pod_missile_body: Sprite2D = $Visuals/ShoulderPod/PodPivot/MissilePod
@onready var _pod_rail_body: Sprite2D = $Visuals/ShoulderPod/PodPivot/RailGun
@onready var _pod_muzzle_missile: Marker2D = $Visuals/ShoulderPod/PodPivot/MuzzleMissile
@onready var _pod_muzzle_rail: Marker2D = $Visuals/ShoulderPod/PodPivot/MuzzleRail
@onready var _pod_flash_missile: MuzzleFlash = $Visuals/ShoulderPod/PodPivot/MuzzleMissile/Flash
@onready var _pod_flash_rail: MuzzleFlash = $Visuals/ShoulderPod/PodPivot/MuzzleRail/Flash


func _ready() -> void:
	add_to_group("player")
	# 装甲装备（§4）：上限加成跨关保持——新玩家实例按持有表算有效上限，满血开场。
	max_hp = BalancePlayer.PLAYER_MAX_HP + int(RunState.mod_stat(&"max_hp_bonus", 0.0))
	hp = max_hp
	boost = boost_capacity()
	# 移动端镜头额外下移两档（战斗区抬到屏幕上半躲手指），桌面为 0。
	_camera_y = BalanceGlobal.CAMERA_Y \
			+ (BalanceGlobal.MOBILE_CAMERA_Y_OFFSET if Platforms.is_mobile() else 0.0)
	_camera.global_position = Vector2(
		global_position.x + BalanceGlobal.CAMERA_X_OFFSET, _camera_y)
	# 开机即位：清掉平滑器残差，镜头第一帧就钉在目标点——
	# 启动页要的是静止画面（机甲站平地），不能看见镜头从旁边滑过来。
	_camera.reset_smoothing()
	# 镜头不吃物理插值（场景里 physics_interpolation_mode=OFF）：它由 _process
	# 每渲染帧驱动（亚步补间位，见 _process），被引擎按物理步补间反而会滞后。
	_phys_prev = global_position
	_phys_curr = global_position
	# 近战判定盒尺寸/位置从 BalancePlayer 取，避免场景存副本（调参没效果的老坑）。
	var hitbox_rect := RectangleShape2D.new()
	hitbox_rect.size = Vector2(BalancePlayer.MELEE_REACH, BalancePlayer.MELEE_HEIGHT)
	_melee_hitbox_shape.shape = hitbox_rect
	_melee_hitbox.position = Vector2(BalancePlayer.MELEE_HITBOX_OFFSET, 0)
	# 刃光平面：x 镜像交给 Visuals（朝向层），这里只按 MELEE_SQUASH 压扁 y
	# （挥砍平面投影成椭圆，即 2D 侧视的"贴地横扫"）。
	_slash_root.scale = Vector2(1.0, BalancePlayer.MELEE_SQUASH)
	# 滑行火花原生朝 +X 喷（滑行后方）：本地固定镜像一次，朝向换边由
	# Visuals 整体翻转承担（不再随 _face_dir 逐帧重写）。
	_slide_sparks.scale.x = -1.0
	_slide_sparks_base_y = _slide_sparks.position.y
	# 刃光前后分层：同一道弧画两遍，近段裁掉上半（观众半侧）、远段裁掉下半。
	_slash_near.clip = SlashArc.Clip.LOWER
	_slash_far.clip = SlashArc.Clip.UPPER
	_slash_near.depth_dim = BalancePlayer.MELEE_FAR_DIM
	_slash_far.depth_dim = BalancePlayer.MELEE_FAR_DIM
	# 启动页待机空场不挂牌（overhead_bar 侧也不画）；进战斗由 reveal_overhead_bar 淡入。
	_overhead_bar.modulate.a = 0.0
	# 装备恢复（§4）：持有表跨关保持——新玩家实例把盾量与通道表现全部装回
	# （盾满、肩部武器在位、焰转色；枪/刀通道在出弹/出刀时现读，无驻留件）。
	shield_max = int(RunState.mod_stat(&"shield_capacity", 0.0))
	shield = shield_max
	_shield_charges = int(RunState.mod_stat(&"shield_charges", 1.0))
	_refresh_mod_visuals()


## 镜头横向跟随玩家，高度锁死（飞行范围由天花板约束在画面内）；命中时叠加震动。
## 物理开插值后 global_position 仍是 60Hz 跳变的物理位，直接读镜头会跟着逐格抖
##（高刷屏上渲染帧率不是 60 的整数倍时尤其明显）。渲染帧落在两物理步之间时
## 按引擎同款插值比例（get_physics_interpolation_fraction）在前后两步间补间，
## 手动等价于 3D 的 get_global_transform_interpolated()（4.7 的 Node2D 没有该接口）。
func _process(delta: float) -> void:
	# 震屏走 Camera2D.offset：offset 在平滑之后叠加，不会被 position_smoothing 滤掉。
	if _shake_strength > 0.1:
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, BalancePlayer.MELEE_SHAKE_DECAY * delta)
	else:
		_camera.offset = Vector2.ZERO
	var blended := _phys_prev.lerp(_phys_curr, Engine.get_physics_interpolation_fraction())
	_camera.global_position = Vector2(
		blended.x + BalanceGlobal.CAMERA_X_OFFSET, _camera_y)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_shield_reform(delta) # 复层盾：碎盾后再立倒计时（§4 复层盾）
	_tick_hurt_window(delta)

	# 启动页待机：不读任何输入，机体站桩（重力/镜头照常，脚下是平地）。
	var axis := 0.0
	var jump_just := false
	var jump_held := false
	if input_enabled:
		axis = Input.get_axis("move_left", "move_right")
		if axis != 0.0:
			axis = signf(axis) # 方向归一化（同触控语义）：手柄左摇杆只读方向，轻推=满速
		jump_just = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
	# 物理加速度：朝目标速度渐进，加/减速都走 BalancePlayer.PLAYER_ACCELERATION；
	# 近战后摇期间操控系数降低（硬直但可微调走位）。
	velocity.x = move_toward(
		velocity.x, axis * BalancePlayer.PLAYER_MOVE_SPEED,
		BalancePlayer.PLAYER_ACCELERATION * _control_scale * delta)

	# AC6 式飞行：地面按跳起跳；空中按住跳持续推进上升，耗 BOOST 槽，松开或耗尽即落。
	# 近战全程滞空（AC6 同款"不下坠"）：竖直速度由近战阶段自己管，重力跳过。
	var thrusting := false
	var melee_active := _melee_phase != MeleePhase.IDLE
	if melee_active:
		match _melee_phase:
			MeleePhase.WINDUP:
				# 前摇：悬停钉住（推进器撑住，速度快速归零）。
				velocity.y = lerpf(velocity.y, 0.0,
						1.0 - exp(-BalancePlayer.MELEE_HANG_DAMP * delta))
			MeleePhase.RECOVER:
				# 后摇：推进器撑着缓慢沉降。
				velocity.y = lerpf(velocity.y, BalancePlayer.MELEE_HANG_SINK,
						1.0 - exp(-BalancePlayer.MELEE_HANG_DAMP * delta))
			MeleePhase.DASH, MeleePhase.STRIKE:
				pass # 突进/斩击向量自带竖直分量
	elif is_on_floor():
		if jump_just:
			velocity.y = BalancePlayer.PLAYER_JUMP_VELOCITY
	elif jump_held and boost > 0.0:
		velocity.y = move_toward(
			velocity.y, -BalancePlayer.BOOST_MAX_ASCENT_SPEED, BalancePlayer.BOOST_THRUST_ACCEL * delta)
		boost = maxf(boost - BalancePlayer.BOOST_DRAIN_PER_SEC * delta, 0.0)
		# 推进即重置回充倒计时（腿推装备可缩短空中回气延迟，§4）
		_boost_regen_delay = RunState.mod_stat(&"boost_regen_delay_air", BalancePlayer.BOOST_REGEN_DELAY_AIR)
		thrusting = true
	else:
		# 上升/下降段重力分开：下降略小，体感为机体在下落时主动反推缓降。
		var g := BalancePlayer.PLAYER_GRAVITY_ASCENT if velocity.y < 0.0 else BalancePlayer.PLAYER_GRAVITY_DESCENT
		velocity.y += g * delta
	if not thrusting and not melee_active:
		# AC6 式回充：空中松开推进后只隔很短一拍就开始（没有"晾一段时间"的门槛），
		# 落地则立即回充且不受倒计时影响；速率本身调快。
		# 近战全程（后摇结束前）不回充不倒计时：固定耗气已在起手一次扣完，收势后恢复常规回充。
		if is_on_floor() or _boost_regen_delay <= 0.0:
			boost = minf(boost + RunState.mod_stat(&"boost_regen_per_sec", BalancePlayer.BOOST_REGEN_PER_SEC) * delta,
					boost_capacity())
		else:
			_boost_regen_delay -= delta
	boost_changed.emit(boost, boost_capacity())

	if axis != 0.0:
		search_direction = signf(axis)

	var was_on_floor := is_on_floor()
	var pre_vy := velocity.y # 落地瞬间会被地板清零，先留底用于重落地判定
	move_and_slide()
	# 记录前后两个物理步的位置，给 _process 的镜头亚步补间用。
	_phys_prev = _phys_curr
	_phys_curr = global_position

	# 滑行下蹲（腿部两骨 IK，解算在 Visuals/LegRig 自跑）：按移动输入驱动
	# （非实际速度——按下即蹲，无加速爬坡延迟），贴地滑行身体下沉屈膝、
	# 脚掌钉地（LegRig 读本值补账）；直立与浮空回手绘站姿（=最高位）。
	# 落地缓冲：任意 空中→地面 必先快速蹲到底、再慢起，无论有无移动指令；
	# 到底判据=贴近满深（指数逼近的工程截止），到底即交还常规目标（慢起接管）。
	# 快蹲慢起：下沉走 DOWN（贴地蹲+落地缓冲）；起立贴地走 UP（慢起从容），
	# 空中走伸腿速率（按跳跃初速反推：起跳越猛伸越快，空中不用慢起拖姿态）。
	# 近战贴地突进按住方向同享。
	if not is_on_floor():
		_land_crouching = false # 离地即撤（跳离缓冲不被钉在蹲姿）
	elif not was_on_floor:
		_land_crouching = true # 落地瞬间起蹲
	elif _land_crouching and _crouch >= BalancePlayer.SLIDE_CROUCH_HEIGHT - 0.1:
		_land_crouching = false
	var crouch_target := 0.0
	if _land_crouching:
		crouch_target = BalancePlayer.SLIDE_CROUCH_HEIGHT
	elif is_on_floor() and axis != 0.0:
		crouch_target = BalancePlayer.SLIDE_CROUCH_HEIGHT # 滑行下蹲：按输入即蹲
	var crouch_rate: float
	if crouch_target > _crouch:
		crouch_rate = BalancePlayer.SLIDE_CROUCH_DOWN_RATE # 蹲下
	elif is_on_floor():
		crouch_rate = BalancePlayer.SLIDE_CROUCH_UP_RATE # 贴地起身
	else:
		crouch_rate = -BalancePlayer.PLAYER_JUMP_VELOCITY \
				* BalancePlayer.SLIDE_CROUCH_EXTEND_GAIN # 空中伸腿
	_crouch = lerpf(_crouch, crouch_target, 1.0 - exp(-crouch_rate * delta))
	_visuals.position.y = _crouch
	# 滑行火花钉地面：不跟身体下沉。
	_slide_sparks.position.y = _slide_sparks_base_y - _crouch

	# 地面滑行火花：贴地高速刮地（跑动/近战突进/前摇预压都算），重落地再踢一脚。
	if is_on_floor() and not was_on_floor and pre_vy > BalancePlayer.SLIDE_SPARK_LAND_VY:
		_slide_kick = GroundSparks.LAND_KICK_TIME
	_slide_kick = maxf(_slide_kick - delta, 0.0)
	_slide_sparks.set_slide(
			is_on_floor() and (absf(velocity.x) > BalancePlayer.SLIDE_SPARK_MIN_SPEED
					or _slide_kick > 0.0),
			absf(velocity.x) / BalancePlayer.PLAYER_MOVE_SPEED)
	# 地面滑行摩擦声：与滑行火花同条件同源（音画同步）；脚步声已按音画同步砍掉
	# ——移动是滑动，没有步态动画。
	var slide_vx := absf(velocity.x)
	Sfx.set_slide(
			clampf(slide_vx / BalancePlayer.PLAYER_MOVE_SPEED, 0.0, 1.0)
			if is_on_floor() and slide_vx > BalancePlayer.SLIDE_SPARK_MIN_SPEED else 0.0)

	# 喷口状态判定（画布空间；朝向镜像由 Visuals 承担）：
	# 竖直支撑=推进上升/近战悬停/缓沉/下落反推；水平分量分前进/倒退两向。
	var nozzle_vertical := thrusting or _melee_phase == MeleePhase.WINDUP \
			or _melee_phase == MeleePhase.RECOVER \
			or (not is_on_floor() and velocity.y > 20.0)
	var nozzle_forward := axis != 0.0 and signf(axis) == _face_dir
	var nozzle_backward := axis != 0.0 and signf(axis) != _face_dir

	# 推进喷焰分档：推进上升全焰；下落=主动反推缓降半焰（下降段重力偏小就是它在反推）；
	# 近战悬停/缓沉由推进器撑住出焰，突进/斩击冲锋=主焰/腿焰同拉过烧档；
	# 纯前进=主焰巡航半档（倒退时主焰熄火，倒退排气由腰焰承担）；地面静止与惯性上升段熄火。
	var flame_level := 0.0
	var cruise_flame := false
	if thrusting:
		flame_level = 1.0
	elif _melee_phase == MeleePhase.WINDUP:
		flame_level = 0.75
	elif _melee_phase == MeleePhase.RECOVER:
		flame_level = 0.5
	elif _melee_phase == MeleePhase.DASH \
			or _melee_phase == MeleePhase.STRIKE:
		flame_level = BalancePlayer.NOZZLE_DASH_FLAME # 近战推进：突进/斩击冲锋过烧
	elif not is_on_floor() and velocity.y > 20.0:
		flame_level = 0.45
	elif nozzle_forward:
		flame_level = BalancePlayer.NOZZLE_CRUISE_FLAME
		cruise_flame = true
	# 待机小喷焰：启动页站桩时机体每隔几秒排一口汽（随包络起落）。
	if not input_enabled:
		_idle_puff_cd = maxf(_idle_puff_cd - delta, 0.0)
		if _idle_puff_cd == 0.0:
			_idle_puff_t = BalanceGlobal.IDLE_PUFF_TIME
			_idle_puff_cd = randf_range(BalanceGlobal.IDLE_PUFF_INTERVAL_MIN, BalanceGlobal.IDLE_PUFF_INTERVAL_MAX)
	if _idle_puff_t > 0.0:
		_idle_puff_t = maxf(_idle_puff_t - delta, 0.0)
		flame_level = maxf(flame_level,
				BalanceGlobal.IDLE_PUFF_LEVEL * sin(PI * (1.0 - _idle_puff_t / BalanceGlobal.IDLE_PUFF_TIME)))
	_thruster.set_target(flame_level)
	# 巡航焰只出视觉不出声（移动系音效宁缺毋滥，跑动已有滑行摩擦声）：
	# 推进声仍只跟真实推进/悬停/反推走。
	Sfx.set_thrust(0.0 if cruise_flame else flame_level)

	# 喷口可动摆动（BalancePlayer.NOZZLE_SWING_DEG）：默认朝左下（画布正形）；
	# 纯前进抬向正后(+)；倒退与竖直支撑（推进上升/近战悬停/下落反推缓降）压向正下(−)；
	# 前进+竖直同时回正中（对角=两者的合成排气向）。摆角写画布空间本地角，
	# 朝向镜像由 Visuals 承担——面朝哪边，同一个本地角都落到屏幕同一侧。
	# 近战冲刺按纯前进算：不看移动输入直接抬向正后（冲刺是向前突刺，与焰档同账）。
	var melee_dashing := _melee_phase == MeleePhase.DASH \
			or _melee_phase == MeleePhase.STRIKE
	var nozzle_target := 0.0
	if melee_dashing:
		nozzle_target = BalancePlayer.NOZZLE_SWING_DEG
	elif nozzle_backward:
		nozzle_target = -BalancePlayer.NOZZLE_SWING_DEG
	elif nozzle_forward:
		nozzle_target = 0.0 if nozzle_vertical else BalancePlayer.NOZZLE_SWING_DEG
	elif nozzle_vertical:
		nozzle_target = -BalancePlayer.NOZZLE_SWING_DEG
	_nozzle_pivot.rotation = move_toward(
			_nozzle_pivot.rotation, deg_to_rad(nozzle_target),
			BalancePlayer.NOZZLE_TURN_SPEED * delta)

	# 腰/腿姿控焰（固定喷口，不带可动）：腿焰向后喷=前进推力，腰焰向前喷=倒退推力。
	# 巡航全焰；近战突进/斩击冲锋没有后退，腰焰不跟冲刺只认倒退巡航，主焰+腿焰同拉过烧档。
	_leg_thruster.set_target(BalancePlayer.VERNIER_DASH_FLAME if melee_dashing
			else (BalancePlayer.VERNIER_CRUISE_FLAME if nozzle_forward else 0.0))
	_waist_thruster.set_target(
			BalancePlayer.VERNIER_CRUISE_FLAME if nozzle_backward else 0.0)

	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_pod_timer = maxf(_pod_timer - delta, 0.0)

	if input_enabled:
		_tick_auto_fire() # 开火全自动：手动开火键已移除（主枪冷却闸在内部，肩炮独立计时）

	if input_enabled:
		_tick_melee_input()
	_tick_melee(delta)

	# 挥刀全程锁定朝向（AC6 的出刀跟踪感来自起手瞬间锁定，而非全程转向）。
	if _melee_phase == MeleePhase.IDLE:
		_melee_pitch = move_toward(_melee_pitch, 0.0, 90.0 * delta) # 空闲俯仰回正
		_update_facing()


func _exit_tree() -> void:
	# 安全兜底：带顿帧离场（死亡重开）时把时间流速还原。
	Engine.time_scale = 1.0


## 索敌：按「距离 ÷ 朝向权重」打分，分数越低越优先。
## 面朝侧权重 1.0，背侧权重减半（等效距离翻倍），形成软性前后优先级而非硬性二选一。
## 屏幕外的敌人不锁。
func _acquire_target() -> Node2D:
	var cam := get_viewport().get_camera_2d()
	var half_w := get_viewport_rect().size.x * 0.5
	var cam_x := global_position.x
	if cam != null:
		cam_x = cam.get_screen_center_position().x
	var lo := cam_x - half_w
	var hi := cam_x + half_w

	var best: Node2D = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var ex := enemy.global_position.x
		if ex < lo or ex > hi:
			continue
		var dx := ex - global_position.x
		var weight := 1.0
		if signf(dx) != search_direction:
			weight = 0.5 # 背侧权重减半
		var score := absf(dx) / weight
		if score < best_score:
			best_score = score
			best = enemy
	return best


func _update_facing() -> void:
	var target := _acquire_target()
	var face_left := search_direction < 0.0
	if target != null:
		face_left = target.global_position.x < global_position.x
	_face_dir = -1.0 if face_left else 1.0
	# 朝向只翻 Visuals 一层：身体、枪臂、喷口、刃光、滑行火花全体换边。
	# 挂件位置按「原生朝右」在场景里手摆一次，不再逐节点补镜像/补位移
	# （手调多少位移都跟着走，flip_h「只翻贴图不翻子节点」的老坑就此除名）。
	# 子节点的旋转一律写画布空间本地角，先缩放后旋转的换算由镜像层统一吃掉。
	_visuals.scale.x = _face_dir
	_apply_melee_attitude()
	_update_arm(get_physics_process_delta_time())


## 枪臂可动瞄准：朝锁定目标做有限俯仰，无目标时缓慢回平。
## Muzzle 是 ArmPivot 子节点，枪口位置跟随俯仰与镜像。
## 俯仰写画布空间本地角：正俯仰(朝上)=负角，与朝向无关。
func _update_arm(delta: float) -> void:
	var target := _acquire_target()
	if target != null:
		var to := target.global_position - _arm_pivot.global_position
		_gun_pitch = clampf(-rad_to_deg(atan2(to.y, maxf(absf(to.x), 40.0))),
				-BalanceCombat.GUN_PITCH_MAX_DEG, BalanceCombat.GUN_PITCH_MAX_DEG)
	else:
		_gun_pitch = move_toward(_gun_pitch, 0.0, BalanceCombat.GUN_PITCH_RETURN_SPEED * delta)
	_arm_pivot.rotation = -deg_to_rad(_gun_pitch)


## 把俯仰角落到表现与判定上：刃光椭圆整体倾斜；判定盒挂 Visuals 外
## （Area2D 不吃负缩放），镜像/俯仰自己补。
##（y 向下为正，"朝上俯仰"= 负旋转；Visuals 内是画布角，判定盒在世界带朝向。）
func _apply_melee_attitude() -> void:
	_slash_root.rotation = -deg_to_rad(_melee_pitch)
	var rot := -deg_to_rad(_melee_pitch) * _face_dir
	_melee_hitbox.rotation = rot
	_melee_hitbox.position = Vector2(BalancePlayer.MELEE_HITBOX_OFFSET * _face_dir, 0).rotated(rot)


## 锁定本次挥砍的俯仰角与突进方向：朝锁定目标做有限俯仰（AC6 近战追踪），
## 没有目标就保持水平平斩。
func _lock_melee_attitude() -> void:
	if not _aim_at_target():
		_melee_pitch = 0.0
		_lunge_dir = Vector2(_face_dir, 0.0)
		_apply_melee_attitude()


## 朝锁定目标修正俯仰角与突进方向并落到表现/判定上。
## 返回是否找到了目标。
func _aim_at_target() -> bool:
	var target := _acquire_target()
	if target == null:
		return false
	var to := target.global_position - global_position
	_melee_pitch = clampf(-rad_to_deg(atan2(to.y, maxf(absf(to.x), 40.0))),
			-BalancePlayer.MELEE_PITCH_MAX_DEG, BalancePlayer.MELEE_PITCH_MAX_DEG)
	var pitch_rad := deg_to_rad(_melee_pitch)
	_lunge_dir = Vector2(cos(pitch_rad) * _face_dir, -sin(pitch_rad))
	_apply_melee_attitude()
	return true


## 开火：返回是否真的出弹。近战全程禁射（前摇→追击→斩击→后摇）是这里的底层硬闸
## ——不管谁调用都拦，挥刀滞空硬直里夹子弹会毁掉出招读法；调用方据此不空耗冷却。
## 枪槽装备（§4）：弹伤/冲击/击退走 mod_stat，曳光与迸溅转成员色（黄色族红线：
## 敌我共弹语言不重开）；双曳光=同一拍两发沿垂向错开（同道齐射读法，不散角）。
func _fire() -> bool:
	if _melee_phase != MeleePhase.IDLE:
		return false
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return false
	var fire_dir := Vector2(search_direction, 0.0)
	var target := _acquire_target()
	if target != null:
		# 预判瞄准（打提前量）+ 按继承速度反解方向，弹道精确穿过预判点。
		var aim_at := Bullet.aim_point(_muzzle.global_position, target, BalancePlayer.PLAYER_BULLET_SPEED)
		fire_dir = Bullet.solve_fire_direction(
			_muzzle.global_position, aim_at, BalancePlayer.PLAYER_BULLET_SPEED, velocity)
	var gun := RunState.mod_member(&"gun")
	var shots := 2 if gun == &"gun_twin" else 1
	for i in shots:
		var bullet := PLAYER_BULLET.instantiate()
		bullet.speed = BalancePlayer.PLAYER_BULLET_SPEED
		bullet.damage = int(RunState.mod_stat(&"bullet_damage", BalancePlayer.PLAYER_BULLET_DAMAGE))
		# 冲击值：失衡积累用（衰减>扫射注入，近战主积累）
		bullet.impact = RunState.mod_stat(&"bullet_impact", BalanceCombat.PLAYER_BULLET_IMPACT)
		if not gun.is_empty():
			var tint: Color = BalanceMods.MEMBERS[gun]["tint"]
			bullet.tracer_tint = tint
			bullet.impact_tint = tint
			bullet.knockback_scale = RunState.mod_stat(&"bullet_knockback_scale", 1.0)
		bullet.setup(fire_dir, velocity)
		container.add_child(bullet)
		var offset := (float(i) - float(shots - 1) * 0.5) * BalanceMods.TWIN_TRACER_GAP
		bullet.global_position = _muzzle.global_position + fire_dir.orthogonal() * offset
		bullet.reset_physics_interpolation() # 先入树后定位：重置插值基点，出膛不拖残影
	# 枪口焰是 Muzzle 的子节点，天然跟随枪臂的俯仰/镜像/移动，不落世界空间。
	_muzzle_flash.fire(fire_dir.angle())
	Sfx.play(&"fire_player")
	return true


## 自动开火（唯一的开火方式，手动开火已移除）：索敌目标在射程内、枪口→目标连线
## 不被地形挡住才出弹；冷却与近战禁射闸都在 _fire 这一层。肩部武器（§4）共用
## 索敌/射程/LOS 闸，独立冷却（_tick_pod）；瞄准轴每帧跟目标转（在射程闸之外——
## 没进射程也先把炮身转过去，转到位才够得着开火时机）。
## LOS 只查世界地形层（层 1）：障碍层对子弹透明（obstacle.gd 头注——掩体不挡弹），
## 也就不该挡开火判定。
func _tick_auto_fire() -> void:
	var target := _acquire_target()
	_tick_pod_aim(target, get_physics_process_delta_time())
	if not BalancePlayer.PLAYER_AUTO_FIRE or not auto_fire:
		return
	if target == null:
		return
	var from := _muzzle.global_position
	var to := target.global_position
	if from.distance_to(to) > BalancePlayer.PLAYER_AUTO_FIRE_RANGE:
		return
	if _terrain_blocks(from, to):
		return
	if _fire_timer == 0.0 and _fire():
		_fire_timer = RunState.mod_stat(&"fire_cooldown", BalancePlayer.PLAYER_FIRE_COOLDOWN)
	_tick_pod(target)


## 肩部武器（§4 肩部武器槽）：越肩大件自己的枪口出弹，独立冷却；近战禁射硬闸同
## 主枪（挥刀滞空硬直里不夹子弹）。
## 磁轨炮=细长杆弹沿炮身指向直线出膛（转进容差角才发，所见即所射）；
## 蜂巢=三枚归航小导弹向上扇形出筒、错拍齐射（弹体自转弯，概略指向即可）。
func _tick_pod(target: Node2D) -> void:
	if not _pod.visible or _pod_timer > 0.0 or _melee_phase != MeleePhase.IDLE:
		return
	var member := RunState.mod_member(&"shoulder")
	var rail := member == &"shoulder_rail"
	var muzzle := _pod_muzzle_rail if rail else _pod_muzzle_missile
	if _terrain_blocks(muzzle.global_position, target.global_position):
		return
	if rail:
		# 瞄准闸：炮身没转到位不出膛（避免"炮口还指着天、弹已经横飞"的穿帮）。
		if absf(wrapf(_pod_pivot.rotation - _pod_aim_angle(target), -PI, PI)) \
				> BalanceMods.RAIL_AIM_TOLERANCE:
			return
		_fire_rail(member)
	else:
		_fire_missiles(member, target)


## 越肩瞄准轴：炮身朝目标方向转（磁轨炮=按弹速打提前量的直线弹道；导弹=概略指向，
## 归航弹自己转弯）；没目标缓回待机姿态。镜像朝向由 Visuals 承担，to_local 换算。
func _tick_pod_aim(target: Node2D, delta: float) -> void:
	if not _pod.visible:
		return
	var desired := POD_REST_ANGLE
	if target != null:
		desired = _pod_aim_angle(target)
	_pod_pivot.rotation = lerp_angle(_pod_pivot.rotation, desired, 1.0 - exp(-10.0 * delta))


## 目标在炮身（PodPivot）本地空间的瞄准角：磁轨炮打直线弹，按弹速预判提前点。
func _pod_aim_angle(target: Node2D) -> float:
	var aim_at := target.global_position
	if RunState.mod_member(&"shoulder") == &"shoulder_rail":
		aim_at = Bullet.aim_point(_pod_pivot.global_position, target, BalanceMods.RAIL_BOLT_SPEED)
	return (_pod.to_local(aim_at) - _pod_pivot.position).angle()


## 磁轨炮：细长杆弹直线出膛，高伤高冲击低射速（越肩大件的重击位）。
func _fire_rail(member: StringName) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var tint: Color = BalanceMods.MEMBERS[member]["tint"]
	var bolt := RAIL_BOLT.instantiate() as Bullet
	bolt.speed = BalanceMods.RAIL_BOLT_SPEED
	bolt.damage = int(RunState.mod_stat(&"rail_damage", 8.0))
	bolt.impact = RunState.mod_stat(&"rail_impact", 16.0)
	bolt.tracer_tint = tint
	bolt.impact_tint = tint
	var dir := _pod_pivot.global_transform.x.normalized() # 炮身 +X=弹道（镜像下自动换边）
	bolt.setup(dir, velocity)
	container.add_child(bolt)
	bolt.global_position = _pod_muzzle_rail.global_position
	bolt.reset_physics_interpolation() # 先入树后定位：重置插值基点，出膛不拖残影
	_pod_flash_rail.fire(dir.angle())
	_pod_timer = RunState.mod_stat(&"rail_cooldown", 1.3)
	Sfx.play(&"fire_player", 1.0)


## 蜂巢导弹舱：三枚归航小导弹向上扇形出筒、错拍齐射（一窝蜂读法）。
## 错拍计时器挂树（process_always=false：世界冻结时不出筒）。
func _fire_missiles(member: StringName, target: Node2D) -> void:
	var shots := int(RunState.mod_stat(&"missile_shots", 3.0))
	var tint: Color = BalanceMods.MEMBERS[member]["tint"]
	Sfx.play(&"fire_player", 0.5)
	for i in shots:
		var delay := float(i) * BalanceMods.MISSILE_STAGGER
		if delay <= 0.0:
			_launch_pod_missile(tint, target, i, shots)
		else:
			get_tree().create_timer(delay, false, false, true).timeout.connect(
				_launch_pod_missile.bind(tint, target, i, shots))
	_pod_flash_missile.fire(-PI / 2.0) # 出筒向上，枪口焰朝上开
	_pod_timer = RunState.mod_stat(&"missile_cooldown", 2.4)


## 单发导弹出筒：从导弹舱枪口出生，向上扇形张开出筒角（归航交给弹体自己）。
func _launch_pod_missile(tint: Color, target: Node2D, index: int, shots: int) -> void:
	if not _pod.visible or _dead:
		return
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var missile := POD_MISSILE.instantiate() as PlayerMissile
	missile.damage = int(RunState.mod_stat(&"missile_damage", 6.0))
	missile.impact = RunState.mod_stat(&"missile_impact", 3.0)
	missile.tracer_tint = tint
	# 出筒角绕竖直方向扇开；向上发射不受朝向镜像影响。
	var fan := (float(index) - float(shots - 1) * 0.5) * BalanceMods.MISSILE_LAUNCH_FAN
	missile.setup(Vector2.UP.rotated(fan), target if is_instance_valid(target) else null)
	container.add_child(missile)
	missile.global_position = _pod_muzzle_missile.global_position
	missile.reset_physics_interpolation() # 先入树后定位：重置插值基点


## 枪口→目标连线是否被地形（碰撞层 1，见 terrain.gd）截断。
func _terrain_blocks(from: Vector2, to: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## ---- 近战（AC6 式连段斩） ----

func _tick_melee_input() -> void:
	if not Input.is_action_just_pressed("melee"):
		return
	if _melee_phase == MeleePhase.IDLE:
		# 连段窗口（从斩击完成起算、独立于后摇计时）未关且还没打满段数：
		# 这按直接起下一段；末段打完后窗口再开也重新起一段（完整前摇）。
		_start_swing(_combo_window_t > 0.0 and _melee_swing < _melee_max_stage())
	elif _melee_phase == MeleePhase.RECOVER:
		# 后摇期间按键登记连段预约（须在 MELEE_COMBO_WINDOW 内），走完才接。
		# 前摇/追击/斩击期间的按键不预约——那时这一刀还没完成。
		if _combo_window_t > 0.0:
			_melee_buffered = true


func _tick_melee(delta: float) -> void:
	_combo_window_t = maxf(_combo_window_t - delta, 0.0) # 连段窗口全程独立倒计时
	match _melee_phase:
		MeleePhase.WINDUP:
			# 反向预压一小步，蓄势感；竖直方向已在滞空分支里钉住。
			velocity.x = move_toward(velocity.x,
					-_face_dir * BalancePlayer.MELEE_ANTIC_SPEED,
					BalancePlayer.PLAYER_ACCELERATION * 2.0 * delta)
			_melee_t -= delta
			if _melee_t <= 0.0:
				_enter_dash()
		MeleePhase.DASH:
			# 追击突进：持续跟踪目标，直到进入斩击距离或到达时长上限才出刀。
			_dash_home()
			_melee_t -= delta
			if _melee_t <= 0.0 or _target_in_strike_range():
				_enter_strike()
		MeleePhase.STRIKE:
			_melee_t -= delta
			var cfg: Dictionary = MELEE_SWINGS[_melee_swing - 1]
			var lunge_scale: float = cfg.lunge_scale
			var strike_time: float = cfg.get("strike_time", BalancePlayer.MELEE_STRIKE_TIME)
			# 斩击：继承突进动量沿带俯仰方向冲（后段衰减交还操控）。
			var strike_t := clampf(_melee_t / strike_time, 0.0, 1.0)
			velocity = _lunge_dir * BalancePlayer.MELEE_DASH_SPEED * lunge_scale \
					* lerpf(0.25, 1.0, strike_t)
			# 伤害判定时机：斩击进度（归一化 0..1）到达 MELEE_HIT_MOMENT 的瞬间结算一次。
			if not _strike_judged \
					and 1.0 - _melee_t / strike_time >= BalancePlayer.MELEE_HIT_MOMENT:
				_strike_judged = true
				_scan_melee_hits()
			if _melee_t <= 0.0:
				_enter_recover() # 缓冲只预约下一段，后摇照常播完
		MeleePhase.RECOVER:
			_melee_t -= delta
			if _melee_t <= 0.0:
				if _melee_buffered:
					# 一段后摇走完吃到预输入 → 衔接前摇 → 二段（上挑）；
					# 上一段后摇走完吃到预输入 → 衔接前摇 → 下一段；末段之后再按
					# 则重新起手一段（完整前摇，连段不自动循环）。
					_start_swing(_melee_swing < _melee_max_stage())
				else:
					_end_swing()
		MeleePhase.IDLE:
			pass
	_update_slash_visual(delta)


func _start_swing(linked: bool) -> void:
	# 段序固定：空闲/重新起手永远是一段（下劈）；上一段后摇走完时吃到预输入
	# （linked）才进下一段。末段之后下一刀重新从一段开始。
	_melee_swing = mini(_melee_swing + 1, _melee_max_stage()) if linked else 1
	# 固定耗气：每刀起手一口价（不管突进/悬停拖多久），扣到 0 不打断出招。
	boost = maxf(boost - BalancePlayer.MELEE_BOOST_COST, 0.0)
	_melee_phase = MeleePhase.WINDUP
	# 闲置起手有明显停顿前摇（架势），连段衔接的停顿短一点（AC6 同款）；刀槽装备可缩（§4）。
	_melee_t = RunState.mod_stat(&"melee_windup_combo_time", BalancePlayer.MELEE_WINDUP_COMBO_TIME) \
			if linked else RunState.mod_stat(&"melee_windup_time", BalancePlayer.MELEE_WINDUP_TIME)
	_melee_buffered = false
	_combo_window_t = 0.0
	_melee_hits.clear()
	_control_scale = 0.0
	if not linked:
		Sfx.play(&"melee_windup") # 闲置起手给轻伺服"蓄"；连段衔接太快不配音
	_update_facing()      # 出刀瞬间锁定朝向
	_lock_melee_attitude() # 俯仰与突进方向：朝锁定目标，有限角度


## 本局连段段数上限（刀槽成员 三连刃 可开三段，§4；默认两段）。
func _melee_max_stage() -> int:
	return maxi(1, int(RunState.mod_stat(&"melee_max_stage", 2.0)))


func _enter_dash() -> void:
	_melee_phase = MeleePhase.DASH
	_melee_t = BalancePlayer.MELEE_DASH_TIME_MAX


## 追击跟踪：突进中每帧朝锁定目标修正俯仰与突进方向（AC6 近战追踪）；
## 目标丢失就沿最后方向直冲，到时长上限强制出刀。
func _dash_home() -> void:
	if not _aim_at_target():
		velocity = _lunge_dir * BalancePlayer.MELEE_DASH_SPEED
		return
	velocity = _lunge_dir * BalancePlayer.MELEE_DASH_SPEED


## 目标是否已进入斩击距离（水平为主，竖向按比例放宽）。
func _target_in_strike_range() -> bool:
	var target := _acquire_target()
	if target == null:
		return false
	var to := target.global_position - global_position
	return absf(to.x) <= BalancePlayer.MELEE_STRIKE_RANGE \
			and absf(to.y) <= BalancePlayer.MELEE_STRIKE_RANGE * 0.7


func _enter_strike() -> void:
	_melee_phase = MeleePhase.STRIKE
	var cfg: Dictionary = MELEE_SWINGS[_melee_swing - 1]
	# 本段刀光时长（三段略长=收尾存在感，§4 三连刃）；本段椭圆压扁倍率随段生效。
	_melee_t = cfg.get("strike_time", BalancePlayer.MELEE_STRIKE_TIME)
	_slash_root.scale.y = BalancePlayer.MELEE_SQUASH * float(cfg.get("squash", 1.0))
	_strike_judged = false
	_slash_clock = 0.0
	_slash_playing = true
	Sfx.play(&"melee_slash1" if _melee_swing == 1 else &"melee_slash2")
	var pivot: Vector2 = cfg.pivot
	var radius: float = cfg.radius
	var thickness: float = cfg.thickness
	var color_core: Color = cfg.color_core
	var color_outer: Color = cfg.color_outer
	# 刀槽装备（§4）：刃光整套转成员色——各段各有配色，相邻段色差保留（读法不动）；
	# 第三段只被 三连刃 唤出（其 blade 账带 core3/outer3，其余成员走不到这段）。
	var blade := RunState.mod_member(&"blade")
	if not blade.is_empty():
		var tones: Dictionary = BalanceMods.MEMBERS[blade]["blade"]
		var pair := "1" if _melee_swing == 1 else ("2" if _melee_swing == 2 else "3")
		color_core = tones.get("core" + pair, tones["core2"])
		color_outer = tones.get("outer" + pair, tones["outer2"])
	for arc: SlashArc in [_slash_far, _slash_near]:
		arc.pivot_offset = pivot
		arc.radius = radius
		arc.thickness = thickness
		arc.color_core = color_core
		arc.color_outer = color_outer
	# 刃口碎光：挂在弹容器里，扫掠期每帧挪到刃口世界位连续喷洒。
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		_tip_sparks = TIP_SPARKS.instantiate() as CPUParticles2D
		_tip_sparks.color = color_outer # 碎光与本段刃光同色系
		container.add_child(_tip_sparks)
		_tip_sparks.global_position = _slash_root.to_global(pivot) # 先就位再开喷
		_tip_sparks.reset_physics_interpolation() # 同上：入树后再定位，补间基点归位
		_tip_sparks.emitting = true


func _enter_recover() -> void:
	_melee_phase = MeleePhase.RECOVER
	_melee_t = RunState.mod_stat(&"melee_recover_1", BalancePlayer.MELEE_RECOVER_1) if _melee_swing == 1 \
			else RunState.mod_stat(&"melee_recover_2", BalancePlayer.MELEE_RECOVER_2)
	# 连段窗口从斩击完成这刻起算（刀槽装备可延长，§4）
	_combo_window_t = RunState.mod_stat(&"melee_combo_window", BalancePlayer.MELEE_COMBO_WINDOW)
	_control_scale = BalancePlayer.MELEE_RECOVER_CONTROL


func _end_swing() -> void:
	_melee_phase = MeleePhase.IDLE
	_control_scale = 1.0
	_slash_root.scale.y = BalancePlayer.MELEE_SQUASH # 段专属压扁倍率还原默认（三段更扁→收势归位）


func _scan_melee_hits() -> void:
	var default_damage := BalancePlayer.MELEE_DAMAGE_1 if _melee_swing == 1 \
			else (BalancePlayer.MELEE_DAMAGE_2 if _melee_swing == 2 else BalancePlayer.MELEE_DAMAGE_3)
	var damage_key: StringName = &"melee_damage_1" if _melee_swing == 1 \
			else (&"melee_damage_2" if _melee_swing == 2 else &"melee_damage_3")
	var damage := int(RunState.mod_stat(damage_key, default_damage))
	# 敌人本体是 CharacterBody2D（body），跨屏弹等旧 Area 命中路径已不存在；
	# 两边都扫一遍 + as Enemy 过滤，兼容一切挂敌层 4 的碰撞体。
	var hits: Array[Node2D] = []
	hits.append_array(_melee_hitbox.get_overlapping_bodies())
	hits.append_array(_melee_hitbox.get_overlapping_areas())
	for node in hits:
		var enemy := node as Enemy
		if enemy == null or _melee_hits.has(enemy):
			continue
		_melee_hits[enemy] = true
		enemy.take_damage(damage, true) # 近战绕盾：刀刃不吃防御力减免
		enemy.add_impact(BalanceCombat.MELEE_IMPACT_1 if _melee_swing == 1
				else BalanceCombat.MELEE_IMPACT_2) # 近战主冲击：打失衡的正式手段（三段随二段档）
		enemy.apply_knockback(Vector2(BalanceEnemy.ENEMY_KNOCKBACK_MELEE * _face_dir, 0.0))
		_spawn_sparks(enemy.global_position)
		_slash_flash = 1.0 # 刃光命中闪增
		if _melee_hits.size() == 1:
			Sfx.play(&"melee_hit") # 命中确认=全库最高档之一，与顿帧同拍
			apply_hitstop(BalancePlayer.MELEE_HITSTOP_TIME, BalancePlayer.MELEE_HITSTOP_SCALE)
			add_shake(BalancePlayer.MELEE_SHAKE_STRENGTH)
			# 斩击=脆：弱电机（高频）主导的短脉冲，与 0.05s 顿帧同量级；
			# 强电机低频"钝"留给受击/爆炸。
			_rumble(0.55, 0.25, 0.07)


## 刃光动画：弧从起手角长到收势角，**弧长全程只增不减**（弧尾恒为起手角，
## 刃口单调推进）；亮度起手 0.05s 快攻到满、沿弧向尾部逐渐减弱；
## 收势后几何不动，整弧不透明度渐减熄灭（radius 略微外扩）。
## 命中瞬间整弧提亮一下（_slash_flash，衰减 ~0.17s），刃口碎光扫掠期跟随刃口。
## 近/远两遍同参数喂入，裁剪由节点自己的 clip 做，两层亮度天然一致。
func _update_slash_visual(delta: float) -> void:
	if not _slash_playing:
		return
	_slash_clock += delta
	_slash_flash = maxf(_slash_flash - delta * 6.0, 0.0)
	var cfg: Dictionary = MELEE_SWINGS[_melee_swing - 1]
	var strike_time: float = cfg.get("strike_time", BalancePlayer.MELEE_STRIKE_TIME)
	var from_deg: float = cfg.from_deg
	var to_deg: float = cfg.to_deg
	var base_radius: float = cfg.radius
	var alpha := 1.0
	var brightness := 1.0
	var radius_grow := 0.0
	if _slash_clock <= strike_time:
		var p := _slash_clock / strike_time
		var eased := 1.0 - pow(1.0 - p, 3.0)
		_slash_head = lerpf(from_deg, to_deg, eased)
		brightness = clampf(_slash_clock / 0.05, 0.0, 1.0) # 亮度快攻
		# 碎光挪到刃口世界位（SlashRoot 的镜像/压扁/俯仰都含在 to_global 里）。
		if _tip_sparks != null:
			var head_dir := Vector2.from_angle(deg_to_rad(_slash_head))
			_tip_sparks.global_position = _slash_root.to_global(
					cfg.pivot + head_dir * base_radius)
	else:
		if _tip_sparks != null and _tip_sparks.emitting:
			_tip_sparks.emitting = false # 扫掠结束停喷，余量粒子由脚本自灭
		_slash_head = to_deg
		var fade_p := clampf(
			(_slash_clock - strike_time) / BalancePlayer.MELEE_FADE_TIME, 0.0, 1.0)
		alpha = 1.0 - fade_p # 不透明度只在末尾渐减
		radius_grow = 14.0 * fade_p
	if _slash_clock >= strike_time + BalancePlayer.MELEE_FADE_TIME:
		_slash_playing = false
		_slash_far.clear()
		_slash_near.clear()
		return
	brightness *= 1.0 + 0.7 * _slash_flash # 命中闪增
	_slash_far.radius = base_radius + radius_grow
	_slash_near.radius = base_radius + radius_grow
	_slash_near.show_arc(from_deg, _slash_head, alpha, brightness)
	_slash_far.show_arc(from_deg, _slash_head, alpha, brightness)


func _spawn_sparks(at: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var burst := SPARK_BURST.instantiate() as Node2D
	# 先定位再入树：one_shot 粒子在 _ready（add_child 时）整批出生，晚定位会喷在原点。
	burst.position = at # 容器在原点且无变换，position 即全局位
	container.add_child(burst)
	burst.scale.x = _face_dir
	burst.rotation = -0.18 * _face_dir # 火花沿挥刀方向略偏上喷


## 命中顿帧：整树时间流速短暂压低（AC6 命中的"卡肉"手感），按真实时间恢复。
## 近战命中的强顿帧与击毁的轻顿帧共用本入口；顿帧进行中不叠加。
func apply_hitstop(duration: float, time_scale: float) -> void:
	if Engine.time_scale != 1.0:
		return
	Engine.time_scale = time_scale
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


## 叠加镜头震动（近战命中与击毁爆炸等外部反馈共用），幅度取最大值。
func add_shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)


## 进战斗切换（Main 调）：掐掉待机汽（不能跨过切换点继续喷，读起来像
## "一开始就喷火"）、头顶血条/气槽渐亮、操作延迟解锁。
## handoff=true（章末黑场交接进新关）：操作立即解锁，落地即战——按住的
## 移动键跨关不松手就该接着走；延迟闸只服务启动页那一下（开始按键不许
## 直接变成跳跃/攻击），交接路径没有那一按。
## （开场推进器点火已删——全焰+推进音与"上升推进"同款，读起来像误触发。）
func enter_combat(handoff := false) -> void:
	_idle_puff_t = 0.0
	_thruster.set_target(0.0)
	var tw := create_tween()
	tw.tween_property(_overhead_bar, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if handoff:
		input_enabled = true
	else:
		enable_input_delayed(BalanceGlobal.COMBAT_INPUT_DELAY)


## 延迟解锁操作：开始那一下的按键（空格/J…）不许直接变成跳跃/攻击——
## 启动演出期间机体不应答，过半再交出操控。
## just_pressed 类动作只要解锁晚于输入处理帧就不会被残留按键误触。
func enable_input_delayed(delay: float) -> void:
	get_tree().create_timer(delay, true, false, true).timeout.connect(
		func() -> void:
			if is_instance_valid(self):
				input_enabled = true
	)


## periodic=true：驻留区的 tick 伤（熔渣火区/灼点）——不受无敌窗拦、也不开窗：
## 「站在里面每拍都疼」是这类件的设计本身，被窗吞掉=伤害砍半。
func take_damage(amount: int, periodic := false) -> void:
	if _dead:
		return
	# 受击无敌窗：一窗只结算最大的一下——机枪一串=吃一枚；窗内来了更重的一击
	# （技能弹）只补差价，不让擦一颗机枪弹就把紧随的技能整发免掉。
	if not periodic and hurt_window_enabled:
		if _hurt_t > 0.0:
			if amount <= _hurt_peak:
				return
			var raw := amount
			amount -= _hurt_peak
			_hurt_peak = raw
		else:
			_hurt_t = BalancePlayer.PLAYER_HURT_INVULN_TIME
			_hurt_peak = amount
	# 护盾（§4）：先于 hp 吸收；全吸=没掉血=没挨打（不进倍率惩罚账、不记受击、
	# 不震屏），格挡音+环闪白当公告；吸穿=碎盾，余量照常扣血。复层盾碎后过
	# SHIELD_REFORM_TIME 满盾再立（次数账尽才真碎）。
	if shield > 0:
		var absorbed := mini(shield, amount)
		shield -= absorbed
		amount -= absorbed
		Sfx.play(&"hit_deflect")
		if shield == 0:
			_break_shield()
		else:
			_flash_shield_ring()
		if amount <= 0:
			return
	# 反应装甲（§4 装甲槽）：护盾外的余伤按比例折减（装甲在盾里层，吃漏进来的那部分；
	# 最低保 1 点：伤害永远成立，免伤=免惩罚账会和护盾的「全吸=没挨打」账打架）。
	var taken_scale := RunState.mod_stat(&"damage_taken_scale", 1.0)
	if taken_scale < 1.0 and amount > 0:
		amount = maxi(1, roundi(amount * taken_scale))
	RunState.mult_take_hit(amount) # 受击按伤害量扣倍率进度+计数（run_loop.md §2；倍率关/冻结内部空转）
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	# 受击=钝：多感官同步（哈迪斯/死亡细胞同款），震屏+强电机低频一起上。
	add_shake(BalancePlayer.PLAYER_DAMAGE_SHAKE_STRENGTH)
	Sfx.play(&"hit_player")
	_rumble(0.25, 0.6, 0.15)
	if hp == 0:
		_die()


## RUSH 击破间不回血（run_loop.md §1）：黑场交接落地时接上一台打完的血量。
## ≤0 = 不携带（照旧满血开场）；头顶条经 hp_changed 当场刷新。
func carry_over_hp(value: int) -> void:
	if value <= 0:
		return
	hp = clampi(value, 1, max_hp)
	hp_changed.emit(hp, max_hp)


## 受击无敌窗倒计时 + 窗内机体轻闪（读法=「这会儿打不疼」；窗尽回实）。
func _tick_hurt_window(delta: float) -> void:
	if _hurt_t <= 0.0:
		return
	_hurt_t -= delta
	if _hurt_t <= 0.0:
		_hurt_peak = 0
		_visuals.modulate.a = 1.0
	elif BalancePlayer.PLAYER_HURT_FLICKER:
		var on := fmod(_hurt_t, BalancePlayer.PLAYER_HURT_FLICKER_PERIOD) \
				< BalancePlayer.PLAYER_HURT_FLICKER_PERIOD * 0.5
		_visuals.modulate.a = 1.0 if on else BalancePlayer.PLAYER_HURT_FLICKER_ALPHA


## 清掉受击无敌窗（探针用：逐招量伤前清场，别让上一下的窗吞掉/折扣这一下）。
func clear_hurt_window() -> void:
	_hurt_t = 0.0
	_hurt_peak = 0
	_visuals.modulate.a = 1.0


## 复层盾：碎盾后倒计时走完满盾再立一次（§4 复层盾，次数账 _shield_charges）。
## 再立给格挡音+环闪白当公告（半档响度：是「又立起来了」不是「又挡了一下」）。
func _tick_shield_reform(delta: float) -> void:
	if _reform_t <= 0.0:
		return
	_reform_t -= delta
	if _reform_t <= 0.0:
		shield = shield_max
		Sfx.play(&"hit_deflect", 0.6)
		_flash_shield_ring()


## RUSH 击破间盾不回充（§4，同不回血账）：黑场交接落地接上一台打完的盾量。
## <0 = 不携带（满盾照旧）；没装护盾时无事可做。
func carry_over_shield(value: int) -> void:
	if value < 0 or shield_max <= 0:
		return
	shield = clampi(value, 0, shield_max)
	_update_shield_ring()


## ---- 轻肉鸽装备（design/run_loop.md §4；数值/颜色正本在 BalanceMods） ----

## 生效瞬间（掉落芯片授予时调，RunState.equip 已先入表）：数值当场入账 +
## 通道当场换色/换形=公告（战斗内零文字）。装甲=上限加成并回补同量；护盾=
## 容量与充能次数入账、满盾亮环；肩部武器亮相；焰转色。枪/刀通道在出弹/出刀时现读。
func apply_mod(member: StringName) -> void:
	match BalanceMods.MEMBERS[member]["slot"]:
		&"armor":
			var bonus := int(RunState.mod_stat(&"max_hp_bonus", 0.0))
			max_hp += bonus
			hp = mini(hp + bonus, max_hp)
			hp_changed.emit(hp, max_hp)
		&"shield":
			shield_max = int(RunState.mod_stat(&"shield_capacity", 0.0))
			shield = shield_max
			_shield_charges = int(RunState.mod_stat(&"shield_charges", 1.0))
			_reform_t = 0.0
	_refresh_mod_visuals()


## 有效推进容量（背推装备可 +0.3s，黄线内）：回充钳制与头顶气槽比例统一走它。
func boost_capacity() -> float:
	return RunState.mod_stat(&"boost_capacity", BalancePlayer.BOOST_CAPACITY)


## 头顶血条宽（装甲装备=条加宽，§4 装甲槽通道）：OverheadBar 取宽走它。
func bar_width() -> float:
	return RunState.mod_stat(&"hp_bar_width", BalanceGlobal.HP_BAR_PLAYER_WIDTH)


## 装备→驻留表现（拾取瞬间与跨关恢复共用）：主焰+腰/腿姿控焰整套换色（推进合并槽
## 一套成员色染全部焰件）、肩部武器在位（按成员亮对应炮身）、护盾环上色。
## 没装的槽保持出厂表现（焰件默认色板不动）。
func _refresh_mod_visuals() -> void:
	var thrust := RunState.mod_member(&"boost")
	if not thrust.is_empty():
		var flame: Array = BalanceMods.MEMBERS[thrust]["flame"]
		_thruster.set_palette(flame[0], flame[1], flame[2])
		_leg_thruster.set_palette(flame[0], flame[1], flame[2])
		_waist_thruster.set_palette(flame[0], flame[1], flame[2])
	var pod_member := RunState.mod_member(&"shoulder")
	_pod.visible = not pod_member.is_empty()
	if _pod.visible:
		var rail := pod_member == &"shoulder_rail"
		_pod_missile_body.visible = not rail
		_pod_rail_body.visible = rail
		_pod_pivot.rotation = POD_REST_ANGLE # 换装归位，不保留上一件的瞄准角
	var guard := RunState.mod_member(&"shield")
	if not guard.is_empty():
		_shield_ring.self_modulate = BalanceMods.MEMBERS[guard]["ring"]
	_update_shield_ring()


## 护盾环=盾量读法：有盾才显示，残盾更淡（满盾全亮）。
func _update_shield_ring() -> void:
	_shield_ring.visible = shield > 0
	if shield > 0:
		_shield_ring.modulate.a = lerpf(BalanceMods.SHIELD_RING_ALPHA_MIN, 1.0,
				float(shield) / float(maxi(shield_max, 1)))


## 格挡公告：环闪白回落到成员色（吸收成立的那一下）。
func _flash_shield_ring() -> void:
	_update_shield_ring()
	var ring: Color = BalanceMods.MEMBERS[RunState.mod_member(&"shield")]["ring"]
	var tw := create_tween()
	tw.tween_property(_shield_ring, "self_modulate", ring, 0.18).from(Color.WHITE)


## 破盾：环扩散淡出 + 碎散火花；复层盾还有剩余充能时排再立倒计时（§4 复层盾）。
func _break_shield() -> void:
	_shield_charges -= 1
	if _shield_charges > 0:
		_reform_t = BalanceMods.SHIELD_REFORM_TIME
	# 环不一帧隐掉：残影原地放大淡出（消失承接规范 design/worlds.md §4c；火花环
	# 0.075s 才扩到环半径，接不住 104px 的环）
	VanishGhost.spawn(_shield_ring, 0.15, 1.35)
	_update_shield_ring()
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var burst := SPARK_BURST.instantiate() as Node2D
	burst.position = global_position # 先定位再入树：one_shot 粒子入树即整批出生
	container.add_child(burst)
	burst.scale = Vector2.ONE * 1.6


## 手柄震动；没接手柄时静默跳过。
func _rumble(weak: float, strong: float, duration: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	Input.start_joy_vibration(pads[0], weak, strong, duration)


## 死亡状态查询（敌人据此时火，避免死亡演出期间继续朝残骸开火）。
func is_dead() -> bool:
	return _dead


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	# 阵亡撤碰撞层（2）：结算后世界不冻结，在飞的敌弹不再把隐形的碰撞盒当靶子
	# ——穿过空位飞走，不在尸体原来的空气里开花。层一撤全体敌弹自动失的。
	collision_layer = 0
	# 机体在爆炸里炸没：Visuals 整层隐藏（本体/枪臂/喷口/刃光/火花），不留残骸立全场。
	# 隐藏前先量机体面积：爆炸白闪起跳半径按面积折算接住整机（§4c）。
	var cover := ExplosionBurst.area_cover_radius(ExplosionBurst.tree_sprite_area(_visuals))
	_visuals.visible = false
	_thruster.set_target(0.0) # 推进器熄火
	_leg_thruster.set_target(0.0)
	_waist_thruster.set_target(0.0)
	_slide_sparks.emitting = false # 滑行火花熄火
	Sfx.set_thrust(0.0)
	Sfx.set_slide(0.0)
	_slash_playing = false
	_slash_far.clear()
	_slash_near.clear()
	if _tip_sparks != null:
		_tip_sparks.emitting = false # 余量粒子由其脚本自灭
		_tip_sparks = null
	_spawn_death_explosion(cover)
	Sfx.play(&"boom_player")
	add_shake(BalancePlayer.PLAYER_DEATH_SHAKE_STRENGTH)
	_rumble(1.0, 1.0, 0.4) # 机体被毁：全强长震
	# 不顿帧：死亡结算由 Main 延迟到爆炸播完（GAME_OVER_DELAY），时停会冻住特效。
	set_physics_process(false)
	died.emit()


## 玩家被毁爆炸：与敌人同款，机体更大所以放大一档。机体当帧隐藏，白闪起跳半径
## =机体面积折算（cover 为世界 px，换算到爆炸局部单位；面积承接 design/worlds.md §4c）。
func _spawn_death_explosion(cover: float) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var boom := EXPLOSION.instantiate() as ExplosionBurst
	boom.scale = Vector2(1.3, 1.3)
	boom.cover_radius = cover / boom.scale.x
	# 先定位再入树：one_shot 粒子在 _ready（add_child 时）整批出生，晚定位会喷在原点。
	boom.position = global_position # 容器在原点且无变换，position 即全局位
	container.add_child(boom)
