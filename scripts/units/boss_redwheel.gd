class_name BossRedwheel
extends PursuitBoss
## 第六章 BOSS·斗轮采集舰「赤轮」（赤沙矿区守卫）：追击框架能力层——
## 「矿区输送与电网」。低矮宽驳采集舰（斗轮独立旋转件+背甲双桩炮架+腹舱；
## 锚点账见 bake_red_units.py 头注/提案_v1 §3）：
##   电网闸（技能A）：背甲炮架（固定射角）预警 → 两枚锚桩落到玩家**当时
##     位置两侧**（ArcFence，无 lead——「桩钉住你现在的位置」就是机制）→
##     蓄能火花渐亮 → 竖直电幕立起（停=被围/跑=出带免/出笼交税或推进飞越；
##     精英「锚桩」已预教）；
##   溜矿车（技能B）：腹舱（BayPort）预警 → 倾泻 OreCart——出舱坠落贴地
##     恒速滚向玩家（纯跳可过、站桩=吃；p2 双车节拍减半）——地面驻留节奏
##     的拍子手（提案 §2 分工账：电网闸 hunts 滞留者、矿车 hunts 地面拍子，
##     玩家被迫在跑/跳/飞三态间换挡）；
##   斗轮弹石（普攻直射）：斗轮毂心真瞄玩家短点放——弹=red_chip.tscn
##     （bullet.gd 纯换皮红砂弹石，速度/伤害复用 BOSS_SWEEP_*，直瞄无预判
##     语法不变），真瞄即预警。斗轮恒转（signature 动画），直射期加速。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架。数值全在
## Balance.REDWHEEL_*/ORE_CART_*。

const ST_FENCE_WARN := 3
const ST_FENCE_FIRE := 4
const ST_CART_WARN := 5
const ST_CART_DROP := 6
const ST_DIRECT := 7

const RED_CHIP := preload("res://scenes/weapons/red_chip.tscn")

var _carts_dropped := 0
var _drop_t := 0.0
var _direct_shoot_t := 0.0

@onready var _rack: Node2D = $Visuals/Rack
@onready var _rack_muzzle: Marker2D = $Visuals/Rack/Muzzle
@onready var _fence_warn: ThreatFlash = $Visuals/Rack/Muzzle/ThreatFlash
@onready var _bay_warn: ThreatFlash = $Visuals/BayPort/ThreatFlash
@onready var _wheel: Sprite2D = $Visuals/ArmPivot/Wheel
@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash # 斗轮毂心（不预警，但池化复用要兜底重置）
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


func _species_max_hp() -> int:
	return Balance.REDWHEEL_MAX_HP


func _hover_anchor_y() -> float:
	return Balance.REDWHEEL_HOVER_Y # 绝对锚：机体 280..460，斗轮缘 454 对最高台阶净空 76


## 斗轮固定安装（不随玩家俯仰；直射由毂心真瞄承担）。
func _arm_tracks_pitch() -> bool:
	return false


func on_spawned() -> void:
	super()
	_carts_dropped = 0


## 斗轮恒转（采掘读法；直射期加速=「吐料」语言）+ 双举升风扇呼吸 +
## 背甲炮架/腹舱固定（无俯仰挂件）。
func _tick_visual(delta: float) -> void:
	var spin := 14.0 if _bstate == ST_DIRECT else 5.0
	_wheel.rotation = fmod(_wheel.rotation + spin * delta * _visuals.scale.x, TAU)
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = 0.45 + 0.25 * sin(_bob_t * 11.0 + i * 2.3)
		t.scale = Vector2.ONE * (0.95 + 0.15 * sin(_bob_t * 8.0 + i * 1.9))


## ---- 技能 A：电网闸 ----

func _begin_skill_a() -> void:
	_bstate = ST_FENCE_WARN
	_bt = Balance.HEAVY_GUN_WARN_TIME
	_fence_warn.warn() # 预警统一入口：炮架管口闪光 + 警告音


## 落桩：落带中心=玩家当时位置 ±半 lead（速度×预警到立幕的时长，clamp
## LEAD_MAX——惩罚缓移与后撤，全速跑仍出带；提案 §2 惩罚账）。
func _drop_fence() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player != null and terrain != null and container != null:
		var delay := Balance.REDWHEEL_STAKE_FLIGHT + _fence_warmup()
		var lead := clampf(player.velocity.x * delay,
				-Balance.REDWHEEL_FENCE_LEAD_MAX, Balance.REDWHEEL_FENCE_LEAD_MAX)
		var fence := ArcFence.new()
		fence.damage = Balance.REDWHEEL_FENCE_DAMAGE
		fence.half_width = Balance.REDWHEEL_FENCE_HALF
		fence.top_height = Balance.REDWHEEL_FENCE_TOP
		fence.warmup_time = _fence_warmup()
		fence.lifetime = Balance.REDWHEEL_FENCE_LIFE
		fence.stake_flight = Balance.REDWHEEL_STAKE_FLIGHT
		container.add_child(fence)
		fence.launch(terrain, _rack_muzzle.global_position,
				player.global_position.x + lead)
		Sfx.play(&"fire_enemy") # 占位：打桩出膛暂用敌枪声
	_enter_recover(Balance.REDWHEEL_FENCE_RECOVER)


func _fence_warmup() -> float:
	return Balance.REDWHEEL_PHASE2_FENCE_WARMUP if _phase2 \
			else Balance.REDWHEEL_FENCE_WARMUP


## ---- 技能 B：溜矿车 ----

func _begin_skill_b() -> void:
	_bstate = ST_CART_WARN
	_bt = Balance.HEAVY_GUN_WARN_TIME
	_carts_dropped = 0
	_drop_t = 0.0
	_bay_warn.warn() # 预警统一入口：腹舱口闪光 + 警告音


## 倾泻节拍：预警结束首车即出，逐车间隔梯次（p2 双车：跳窗减半的拍子账）。
func _drop_ticker(delta: float) -> void:
	if _carts_dropped >= _cart_count():
		return
	_drop_t -= delta
	if _drop_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var from := ($Visuals/BayPort as Node2D).global_position
	var cart := OreCart.new()
	container.add_child(cart)
	cart.launch(terrain, from, signf(player.global_position.x - global_position.x))
	_carts_dropped += 1
	_drop_t = Balance.REDWHEEL_CART_STAGGER
	Sfx.play(&"fire_enemy") # 占位：出舱暂用敌枪声，矿车配方后配


func _cart_count() -> int:
	return Balance.REDWHEEL_CART_COUNT \
			+ (Balance.REDWHEEL_PHASE2_CART_BONUS if _phase2 else 0)


## ---- 普攻：斗轮弹石 ----

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
		ST_FENCE_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_drop_fence()
		ST_CART_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_CART_DROP
				_carts_dropped = 0
				_drop_t = 0.0
				_bt = (_cart_count() - 1) * Balance.REDWHEEL_CART_STAGGER \
						+ 1.0 # 全数出舱+落地滚行窗口
		ST_CART_DROP:
			_drop_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(Balance.REDWHEEL_CART_RECOVER)
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


## 直瞄单发：弹石真从斗轮毂心出膛、朝玩家当前位置（无预判）；弹是
## bullet.gd 纯换皮（速度/伤害复用 BOSS_SWEEP_*），命中迸溅染暖砂。
func _fire_direct_shot(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var b := RED_CHIP.instantiate() as Bullet
	b.speed = Balance.BOSS_SWEEP_SPEED
	b.damage = Balance.BOSS_SWEEP_DAMAGE
	b.impact_tint = Color(1.0, 0.62, 0.42)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = _muzzle.global_position
	b.reset_physics_interpolation()
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_enemy")


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_FENCE_WARN:
			_bt = Balance.HEAVY_GUN_WARN_TIME
			_fence_warn.warn()
		ST_CART_WARN:
			_bt = Balance.HEAVY_GUN_WARN_TIME
			_bay_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_fence_warn.reset()
	_bay_warn.reset()
	_warn.reset()
