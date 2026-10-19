class_name Enemy
extends ScrollObject
## 敌人 AI 分两个互不干预的层，各自用「半衰期掷骰」独立驱动（泊松采样）：
##   移动层：待机 ⇄ 机动——短距离前后踱步；攻击层不依赖它，边扫边走照常瞄准。
##   攻击层：待机 ⇄ 扫射——玩家在射程内按概率开一梭随机发数的短点放。
## 触发概率 p = 1 - 2^(-Δt/t½)：帧率无关、无记忆（同波敌人天然错开，无需预置冷却）。
## 本体是 CharacterBody2D：踱步/击退都走 move_and_slide，台阶/障碍自然挡住，
## 走出平台边缘会掉落；被玩家攻击命中按冲量击退（apply_knockback，指数弹衰减）。
## 弹道继承/预判读 get_real_velocity()（move_and_slide 的实际速度，撞墙滑停时不虚标）。
## 数值一律取自 Balance（全局调参表）。

enum MoveState { IDLE, MANEUVER }
enum FireState { IDLE, BURST }

const ENEMY_BULLET := preload("res://scenes/enemy_bullet.tscn")
const EXPLOSION := preload("res://scenes/explosion_burst.tscn")

const IMPACT_TINT := Color(1.0, 0.5, 0.3) # 敌弹命中迸溅的染色（与弹体同族的暗红）

var _hp := 0
var _move_state := MoveState.IDLE
var _fire_state := FireState.IDLE
var _maneuver_target_x := 0.0 # 本次机动的目标世界 x
var _control_vx := 0.0        # 踱步控制速度（击退是叠加项，见 _knockback）
var _knockback := 0.0         # 击退水平速度（px/s，带符号），线性衰减
var _burst_shots_left := 0    # 本次扫射剩余发数
var _burst_timer := 0.0       # 距扫射内下一发的时间
var _impact := 0.0            # 当前冲击积累（AC6 式失衡：打满上限即硬直）
var _impact_decay_t := 0.0    # 衰减宽限倒计时：受击即重置，走完才开始掉冲击
var _impact_lock_t := 0.0     # 失衡免疫倒计时：恢复后这么久内攒不了冲击
var _staggered := false       # 失衡硬直中：AI/移动停摆、受伤加深
var _stagger_t := 0.0         # 失衡剩余时长
var _hover := 0.0        # >0 = 悬浮单位：出生抬升量（之后整机正弦浮动）
var _hover_base_y := 0.0 # 浮动基准高度（出生抬升后的原点高度）
var _bob_t := 0.0        # 浮动相位时钟
var _player: Node2D
var _hit_tween: Tween
var _punch_tween: Tween
var _tilt_t := -1.0 # >=0 = 失衡歪斜进行中（物理帧驱动，见 _tick_tilt）

## 受击缩放 punch（命中顿挫感）：临时关掉看失衡歪斜的独占效果，要恢复改 true。
const HIT_SCALE_PUNCH := false
const STAGGER_TILT_RAD := 0.2   # 失衡歪斜幅度（rad）：快速小幅旋转再回正
const STAGGER_TILT_UP := 0.1    # 歪到峰值时长（秒）
const STAGGER_TILT_HOLD := 0.2  # 歪顶保持时长（秒）：愣住的瘫劲
const STAGGER_TILT_DOWN := 0.7  # 回正时长（秒，带一点过冲晃动）

@onready var _visuals: Node2D = $Visuals
@onready var _sprite: Sprite2D = $Visuals/Sprite2D
@onready var _arm_pivot: Node2D = $Visuals/ArmPivot
@onready var _muzzle: Marker2D = $Visuals/ArmPivot/Muzzle
@onready var _muzzle_flash: MuzzleFlash = $Visuals/ArmPivot/Muzzle/Flash


func on_spawned() -> void:
	super()
	add_to_group("enemies")
	_hp = _species_max_hp()
	_move_state = MoveState.IDLE
	_fire_state = FireState.IDLE
	velocity = Vector2.ZERO # CharacterBody2D 内置速度
	_control_vx = 0.0
	_knockback = 0.0
	_impact = 0.0
	_impact_decay_t = 0.0
	_impact_lock_t = 0.0
	_staggered = false
	_stagger_t = 0.0
	_player = null
	if _hit_tween != null:
		_hit_tween.kill()
		_hit_tween = null
	if _punch_tween != null:
		_punch_tween.kill()
		_punch_tween = null
	_tilt_t = -1.0
	_visuals.modulate = Color.WHITE # 受击红闪目标（池化复用兜底）
	_visuals.rotation = 0.0 # 失衡歪斜目标（死亡打断歪斜的残角兜底）
	_sprite.scale = Vector2.ONE # 受击压扁 punch（HIT_SCALE_PUNCH）目标
	# 悬浮单位：刷怪落点仍是"贴地姿态"，在这里抬到巡航高度；浮动相位随机错开。
	_hover = _hover_height()
	if _hover > 0.0:
		global_position.y -= _hover
	_hover_base_y = global_position.y
	_bob_t = randf() * TAU


## 头顶血条数据源（OverheadBar 轮询）：受损且存活才显示。
func is_damaged() -> bool:
	return _hp > 0 and _hp < _species_max_hp()


func hp_ratio() -> float:
	return clampf(float(_hp) / float(_species_max_hp()), 0.0, 1.0)


## 伤害结算：常规伤害先扣防御力（下限 1——盾"打不动"但不完全免疫）；
## ignore_defense 给近战用：盾板挡弹不挡刀。传参来源见 bullet.gd / player.gd。
## 失衡期受伤 ×STAGGER_DMG_MULT（AC6 式失衡乘区：打失衡就是为了这段爆发）。
func take_damage(amount: int, ignore_defense: bool = false) -> void:
	if _hp <= 0:
		return
	if _staggered:
		amount = ceili(amount * Balance.STAGGER_DMG_MULT)
	_hp -= amount if ignore_defense else maxi(amount - _defense(), 1)
	if _hp <= 0:
		_explode()
		killed.emit(_species_score())
		request_despawn()
		return
	# 受击声：伤害被防御力整档吃掉=盾板"铛"的弹开感；否则薄金属受击。
	if not ignore_defense and _defense() > 0 and amount <= _defense():
		Sfx.play(&"hit_deflect")
	else:
		Sfx.play(&"hit_enemy")
	if _hit_tween != null:
		_hit_tween.kill()
	_hit_tween = create_tween()
	# 受击红闪打 Visuals 整层（modulate 随树下传，臂/舱/旋翼一起红）：
	# 只红主精灵的话武器保持原色，受击读不出"整机挨打"。
	_hit_tween.tween_property(_visuals, "modulate", Color.WHITE, 0.15).from(Color(1.0, 0.35, 0.35))
	# 受击缩放 punch：近战/子弹命中的顿挫感。
	# （留在本体：squash 读在躯干质量上，臂不随压可接受；挂 Visuals 得给补间
	# 带朝向符号——scale.x 同时是镜像位，不值得，当前也处于关闭态。）
	if HIT_SCALE_PUNCH:
		if _punch_tween != null:
			_punch_tween.kill()
		_sprite.scale = Vector2(1.18, 0.88)
		_punch_tween = create_tween()
		_punch_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	super(delta)
	if _despawn_requested or _hp <= 0:
		return
	_tick_tilt(delta) # 失衡歪斜独立全程走完（1.0s 可能跨出失衡硬直），不留在失衡分支里
	# 失衡硬直：AI 两层与浮动全部停摆，只剩击退滑行+重力（挨打攒的硬直，白给近战）。
	if _staggered:
		_stagger_t -= delta
		_knockback = move_toward(_knockback, 0.0,
				Balance.ENEMY_KNOCKBACK_DECEL * delta)
		velocity.x = _knockback
		if _hover > 0.0:
			velocity.y = 0.0 # 悬浮失衡：僵在原高度（瘫而不坠）
			move_and_slide()
		else:
			velocity.y += _gravity() * delta
			move_and_slide()
		if _stagger_t <= 0.0:
			_staggered = false
			_impact = 0.0
			_impact_lock_t = _stagger_immunity() # 恢复后进入冲击免疫期（防连续失衡）
		return
	# 悬浮浮动相位（放在玩家索敌之前：浮动不依赖场上有没有玩家）。
	# y 在移动出口处直赋：舱体+枪臂+碰撞盒整机一起浮，不经物理积分。
	var bob_y := INF
	if _hover > 0.0:
		_bob_t += delta
		bob_y = _hover_base_y \
				+ sin(_bob_t * Balance.DRONE_BOB_SPEED) * Balance.DRONE_BOB_AMPLITUDE
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var player := _player as Player
	if player != null and player.is_dead():
		return # 玩家已毁：停火（死亡演出期间世界照跑，但不朝残骸开火）

	var dx := _player.global_position.x - global_position.x
	# 朝向只翻 Visuals 一层（敌方美术原生朝左）：贴图、枪臂、仓口等全部挂件
	# 随父级整体换边，挂点坐标按原生姿态摆一次即可——flip_h「只翻贴图不翻
	# 子节点」、逐挂件补镜像/补位移的老坑就此除名。
	_visuals.scale.x = -1.0 if dx > 0.0 else 1.0
	# 枪臂俯仰写在画布空间：镜像由 Visuals 承担，不乘朝向符号——面朝哪边，
	# 抬头都是同一个本地角；垂发架等固定射角武器不俯仰（恒回正）。
	if _arm_tracks_pitch():
		var to := _player.global_position - _arm_pivot.global_position
		var pitch := clampf(-rad_to_deg(atan2(to.y, maxf(absf(to.x), 40.0))),
				-Balance.GUN_PITCH_MAX_DEG, Balance.GUN_PITCH_MAX_DEG)
		_arm_pivot.rotation = deg_to_rad(pitch)
	else:
		_arm_pivot.rotation = 0.0

	# 两个分层各自独立推进：机动时不影响扫射节奏，扫射时也不打断踱步。
	_tick_move(delta)
	_tick_fire(delta)

	# 移动出口：踱步控制速度 + 击退合流进 move_and_slide（地形/台阶自然挡住）。
	velocity.x = _control_vx + _knockback
	if _hover > 0.0:
		velocity.y = 0.0 # 悬浮族只做水平碰撞滑动，高度由浮动自管
		move_and_slide()
		global_position.y = bob_y
	else:
		velocity.y += _gravity() * delta
		move_and_slide()
	_knockback = move_toward(_knockback, 0.0,
			Balance.ENEMY_KNOCKBACK_DECEL * delta)
	# 冲击衰减：受击会重置宽限倒计时——持续输出冲击只涨不掉；停手宽限走完才掉
	if _impact_decay_t > 0.0:
		_impact_decay_t -= delta
	else:
		_impact = move_toward(_impact, 0.0, Balance.IMPACT_DECAY * delta)
	# 失衡免疫倒计时：恢复后这段时间攒不了冲击（防连续失衡无限锁死）
	if _impact_lock_t > 0.0:
		_impact_lock_t -= delta


## ---- 失衡（AC6 式冲击/STAGGER） ----

## 玩家攻击的冲击入口（bullet.gd 命中处 / player.gd 近战结算调用）。
## 打满 _impact_resistance() 即失衡；失衡中与免疫期不积累。
func add_impact(amount: float) -> void:
	if _hp <= 0 or _staggered or _impact_lock_t > 0.0:
		return
	_impact += amount
	_impact_decay_t = Balance.IMPACT_DECAY_DELAY # 受击即重置宽限：连打不掉
	if _impact >= _impact_resistance():
		_enter_stagger()


func _enter_stagger() -> void:
	_staggered = true
	_stagger_t = _stagger_time()
	_control_vx = 0.0
	_fire_state = FireState.IDLE # 若在扫射中途失衡，收枪
	# 失衡反馈：机体快速小幅歪一下再回正——被玩家打歪的后仰（方向=背离玩家一侧，
	# 顶被推向远处），回程带一点过冲晃动。不用 Tween：项目开着 2D 物理插值，
	# 变换写入必须走物理步（idle 帧写 rotation 读数会被插值搅掉），见 _tick_tilt。
	# 白热爆闪已删（flash_burst 留给爆区闪光）。
	_tilt_t = 0.0
	# 失衡音延迟播：命中的受击声先落地，钟鸣随后补位（读"垮下来"，不和主击挤一拍）。
	# 定时器连到本节点方法——节点先被砍掉时连接自动断开，无需判空。
	get_tree().create_timer(Balance.STAGGER_SFX_DELAY).timeout.connect(_play_stagger_sfx)


## 延迟失衡音（STAGGER_SFX_DELAY 后到点）：等主击声落地；期间被砍死/被重置就不播。
func _play_stagger_sfx() -> void:
	if _hp <= 0 or not _staggered:
		return
	Sfx.play(_stagger_key()) # 键随体量分档（钟振款，注册见 sfx.gd）


## 失衡歪斜的物理帧驱动：0→峰值（快）→歪顶保持（愣住）→过冲回正（晃一下稳住）。
## 在 _physics_process 里无条件走完整程：全程 1.0s 会超过最短失衡硬直 0.9s——
## 不挂在失衡分支里，杂兵提前缓过来歪斜也能收尾归零，不留残余倾角。
## 歪斜写 Visuals 整层：只歪主精灵会让枪臂/喷口/旋翼以原姿态悬空。
## 符号账：节点自身变换是先 scale 后 rotation（R∘S），镜像态下同一本地角的
## 世界方向反号——乘回 scale.x 把「顶推向背离玩家一侧」钉在世界侧，
## 两个朝向同一段代码不用分支。
func _tick_tilt(delta: float) -> void:
	if _tilt_t < 0.0:
		return
	_tilt_t += delta
	var r: float
	if _tilt_t < STAGGER_TILT_UP:
		var p := _tilt_t / STAGGER_TILT_UP
		r = STAGGER_TILT_RAD * (1.0 - (1.0 - p) * (1.0 - p)) # 快速歪到峰值
	elif _tilt_t < STAGGER_TILT_UP + STAGGER_TILT_HOLD:
		r = STAGGER_TILT_RAD # 歪顶保持：愣住的瘫劲
	else:
		var p := (_tilt_t - STAGGER_TILT_UP - STAGGER_TILT_HOLD) / STAGGER_TILT_DOWN
		if p >= 1.0:
			_tilt_t = -1.0
			_visuals.rotation = 0.0
			return
		r = STAGGER_TILT_RAD * (1.0 - p) * cos(p * 5.0) # 过冲回正
	_visuals.rotation = r * _visuals.scale.x


func is_staggered() -> bool:
	return _staggered


## 冲击积累比例 0..1（BOSS 顶部冲击条数据源；免疫期为 0）。
func impact_ratio() -> float:
	return clampf(_impact / _impact_resistance(), 0.0, 1.0)


## ---- 移动层：待机 ⇄ 机动（短距离前后踱步，只定控制速度，物理在出口合流） ----

func _tick_move(delta: float) -> void:
	match _move_state:
		MoveState.IDLE:
			_control_vx = 0.0
			if _roll_trigger(Balance.ENEMY_MANEUVER_HALF_LIFE, delta):
				var dir := 1.0 if randf() < 0.5 else -1.0 # 前后各半
				_maneuver_target_x = global_position.x + dir * randf_range(
						Balance.ENEMY_MANEUVER_DIST_MIN, Balance.ENEMY_MANEUVER_DIST_MAX)
				_move_state = MoveState.MANEUVER
		MoveState.MANEUVER:
			var remain := _maneuver_target_x - global_position.x
			# 被墙挡住=上一帧真实速度与控制速度反向/为零（撞台阶滑停）
			var blocked := absf(_control_vx) > 0.0 \
					and signf(get_real_velocity().x) != signf(_control_vx)
			# 到点 / 被挡 / 步行族脚下悬空（不主动走下台阶，被击退除外）：
			if absf(remain) <= Balance.ENEMY_MANEUVER_SPEED * delta \
					or blocked or (_hover <= 0.0 and not is_on_floor()):
				_control_vx = 0.0
				_move_state = MoveState.IDLE
			else:
				_control_vx = signf(remain) * Balance.ENEMY_MANEUVER_SPEED


## ---- 攻击层：待机 ⇄ 扫射（随机发数短点放；玩家出射程即中断） ----

func _tick_fire(delta: float) -> void:
	var in_range := absf(_player.global_position.x - global_position.x) \
			<= Balance.ENEMY_ATTACK_RANGE
	match _fire_state:
		FireState.IDLE:
			if in_range and _roll_trigger(Balance.ENEMY_FIRE_HALF_LIFE, delta):
				_fire_state = FireState.BURST
				_burst_shots_left = randi_range(
						Balance.ENEMY_BURST_MIN, Balance.ENEMY_BURST_MAX)
				_burst_timer = 0.0 # 进扫射第一发立即出膛
		FireState.BURST:
			if not in_range:
				_fire_state = FireState.IDLE # 目标脱离：中断扫射
				return
			_burst_timer -= delta
			if _burst_timer > 0.0:
				return
			_shoot()
			_burst_shots_left -= 1
			if _burst_shots_left <= 0:
				_fire_state = FireState.IDLE
			else: # 机枪射速固定，但节拍叠 ±20% 抖动：听着不机械
				_burst_timer = Balance.ENEMY_BURST_INTERVAL * randf_range(0.8, 1.2)


## 半衰期掷骰（恒定危险率的泊松采样）：p = 1 - 2^(-Δt/t½)，期望等待 = t½ / ln2。
func _roll_trigger(half_life: float, delta: float) -> bool:
	return randf() < 1.0 - pow(2.0, -delta / half_life)


## 击毁爆炸：生成在弹容器里（不随本体回池消失），并给镜头震动 + 轻顿帧。
## 近战击毁时 Player 已有更强的顿帧/震动，apply_hitstop 内部会防叠加。
func _explode() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var boom := EXPLOSION.instantiate() as Node2D
		# 先定位再入树：one_shot 粒子在 _ready（add_child 时）整批出生，晚定位会喷在原点。
		boom.position = global_position + Vector2(0.0, -body_size.y * 0.3) # 容器在原点，position 即全局位
		container.add_child(boom)
	Sfx.play(&"boom_enemy")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(Balance.KILL_SHAKE_STRENGTH)
		player.apply_hitstop(Balance.KILL_HITSTOP_TIME, Balance.KILL_HITSTOP_SCALE)


func _shoot() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var bullet := ENEMY_BULLET.instantiate()
	bullet.speed = Balance.ENEMY_BULLET_SPEED
	bullet.damage = Balance.ENEMY_BULLET_DAMAGE
	bullet.impact_tint = IMPACT_TINT
	# 直瞄：朝玩家当前位置打，不预判不修偏——跑起来弹自然落后，跑=有效规避。
	var fire_dir := _muzzle.global_position.direction_to(_player.global_position)
	bullet.setup(fire_dir, Vector2.ZERO)
	container.add_child(bullet)
	bullet.global_position = _muzzle.global_position
	bullet.reset_physics_interpolation() # 先入树后定位：重置插值基点，出膛不拖残影
	# 枪口焰是 Muzzle 的子节点，天然跟随枪臂俯仰/镜像，不落世界空间。
	_muzzle_flash.fire(fire_dir.angle())
	Sfx.play(&"fire_enemy")


## 玩家攻击的击退入口（bullet.gd 命中处 / player.gd 近战结算调用）。
## 只做水平：竖直交给重力/浮动自管。扫射连发逐发微推，幅值封顶不叠飞。
func apply_knockback(impulse: Vector2) -> void:
	if _hp <= 0:
		return
	_knockback = clampf(_knockback + impulse.x * _knockback_scale(),
			-Balance.ENEMY_KNOCKBACK_MAX, Balance.ENEMY_KNOCKBACK_MAX)


## ---- 机型档案钩子：子类覆写以换数值/姿态（数值出处仍是 Balance） ----

## 枪臂是否随玩家俯仰瞄准。垂发架发射角固定（仓口朝天），子类覆写关闭——
## 关闭后臂只随朝向镜像（镜像不动竖直轴，朝天仓口仍朝天），rotation 恒回正。
func _arm_tracks_pitch() -> bool:
	return true


func _species_max_hp() -> int:
	return Balance.ENEMY_MAX_HP


func _species_score() -> int:
	return Balance.ENEMY_SCORE


## 防御力：常规伤害（子弹）先减这一档、下限 1；近战绕盾（ignore_defense）。
func _defense() -> int:
	return 0


## 出生抬升高度，>0 视作悬浮单位（带浮动）；每次出生重掷，子类覆写。
func _hover_height() -> float:
	return 0.0


## 击退响应系数：轻浮单位飘得远，重甲近乎岿然不动；BOSS 覆写 apply_knockback 免疫。
func _knockback_scale() -> float:
	return 1.0


## 步行族下落重力（悬浮族不走物理竖直轴，不调用）；BOSS 覆写 0（高度自管）。
func _gravity() -> float:
	return Balance.ENEMY_GRAVITY


## 失衡上限（冲击抗性）：杂兵一刀近战踉跄；精英/BOSS 见 Balance。
func _impact_resistance() -> float:
	return Balance.IMPACT_RESIST_GRUNT


## 失衡硬直时长。
func _stagger_time() -> float:
	return Balance.STAGGER_TIME_GRUNT


## 失衡确立音键：按体量分档（杂兵/精英/BOSS 各配变调文件，注册见 sfx.gd）。
func _stagger_key() -> StringName:
	return &"stagger"


## 失衡恢复后的冲击免疫时长（这段时间攒不了冲击，防连续失衡锁死）。
func _stagger_immunity() -> float:
	return Balance.STAGGER_IMMUNITY_GRUNT
