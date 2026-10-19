class_name HeavyMissile
extends Node2D
## 重击导弹：两段式——无动力抛体滑行 + 末段比例导引。
## 出膛动量 = 出膛方向（initial_dir=发射器"炮口"的实际朝向，散布由调用方
## 并入）×THROW_SPEED×随机 + 载机速度继承（carrier_vel）。**滑行段弹体姿态
## 钉在炮口朝向、不随速度偏转**——继承只加平动动量（看得到被机体带动），
## 载机后退不会把弹头姿态拽得"朝后飞"。滑行段纯抛体拉弧（无动力不喷烟），
## **滑行 COAST_TIME 秒按时长开机**（不等过顶——上升段就压弯进入拦截，
## 更果断）——点火喷烟，弹体轴由比例导引从炮口朝向起转：转向率 = N×视线
## 角速度（限幅到转向半径），自动打提前量——玩家横穿弹道时迎头截住，不尾
## 追；**开机后恒速沿弹体轴巡航（速度模型别动：推力/阻力版实测"飞一半停
## 天上"已回退）**；到时锁死直线飞完撞地（不判"飞过即锁直"——早锁会把弹
## 甩到玩家身后老远）。
## 开机后的追踪瞄准玩家脚底（瞄脚底让弹道自然往地面收束），只与地面耦合：
## 穿过机体不引爆，撞地即爆，球状伤害检测（GroundBlast）。
## 规约：预警在发射器上（枪口闪红，见调用方），弹道无区域标记。
## 占位美术：_draw 平涂弹体（弹身+弹头），后续换 SVG；
## 拉烟/尾焰=missile_smoke/flame.tscn 粒子挂弹尾（开机才发射，爆时烟过继弹容器淡完）。

enum Phase { COAST, HOME, LOCK }

const EXPLOSION := preload("res://scenes/explosion_burst.tscn")
const SMOKE := preload("res://scenes/missile_smoke.tscn")
const FLAME := preload("res://scenes/missile_flame.tscn")

const BODY_COLOR := Color(0.2, 0.18, 0.16)
const HEAD_COLOR := Color(0.35, 0.3, 0.26)

var speed := 1000.0 # 开机后巡航速度（沿弹体轴恒速）
var damage := 20
var blast_radius := 110.0

const BODY_SCALE := 0.7 # 弹体绘制缩放（占位平涂弹体比爆炸球显大，整体收一档）

var _dir := Vector2.LEFT
var _phase := Phase.HOME  # 默认直瞄（旧行为）；lofted 出膛时进 COAST
var _vel := Vector2.ZERO  # COAST 段弹道速度（含重力积分），开机时归化为巡航速度
var _prev_los := 0.0      # PN 用的上一帧视线角
var _t := 0.0             # 当前段计时：HOME 段超时锁死防缠斗
var _turn_rate := 3.0     # 转向角速度（rad/s）=速度/转向半径，_init 里从 Balance 导出
var _terrain: Terrain
var _smoke: GPUParticles2D # 拉烟（missile_smoke.tscn，浓度/寿命/色带在场景里调）
var _flame: GPUParticles2D # 尾焰（missile_flame.tscn）：开机才点火，与拉烟同拍


func _ready() -> void:
	# 拉烟/尾焰挂弹尾：粒子全局坐标（local_coords=false），弹飞过去效果留在
	# 弹道线上。direction 取发射器局部 -X（朝弹尾），随弹体转向——开机后
	# 永远向后拖。滑行段无动力不喷烟不点火，emitting 在开机（进 HOME）才打开。
	_smoke = SMOKE.instantiate() as GPUParticles2D
	_smoke.position = Vector2(-16.0, 0.0) * BODY_SCALE
	_smoke.emitting = false
	add_child(_smoke)
	_flame = FLAME.instantiate() as GPUParticles2D
	_flame.position = Vector2(-16.0, 0.0) * BODY_SCALE
	_flame.emitting = false
	add_child(_flame)


func _init() -> void:
	speed = Balance.HEAVY_MISSILE_SPEED
	_turn_rate = speed / Balance.HEAVY_MISSILE_TURN_RADIUS


## 先入树再调本方法。initial_dir 为出膛方向（=发射器炮口的实际朝向，弹体
## 姿态与出膛动量主轴都沿它）；lofted=true 走两段式；carrier_vel 为发射瞬间
## 载机速度（只进步进动量，弹体姿态不吃它）。
func launch(terrain: Terrain, from: Vector2, initial_dir: Vector2,
		lofted := false, carrier_vel := Vector2.ZERO) -> void:
	_terrain = terrain
	_dir = initial_dir.normalized() if initial_dir.length_squared() > 0.0001 else Vector2.LEFT
	global_position = from
	rotation = _dir.angle()
	reset_physics_interpolation() # 先入树后定位：不拖补间残影
	if not lofted:
		return
	# 出膛动量 = 炮口朝向×上抛初速×随机 + 载机速度（姿态仍钉炮口）
	_vel = _dir * Balance.HEAVY_MISSILE_THROW_SPEED * randf_range(0.85, 1.1) + carrier_vel
	_phase = Phase.COAST


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.COAST:
			_coast(delta)
		Phase.HOME:
			_home(delta)
		Phase.LOCK:
			pass
	if _phase == Phase.COAST:
		global_position += _vel * delta
	else:
		global_position += _dir * speed * delta
	rotation = _dir.angle()
	if _terrain != null and global_position.y >= _terrain.surface_y_at(global_position.x):
		_detonate()
		return
	queue_redraw()


## 滑行段：纯抛体（只受重力拉弧），弹体姿态钉在炮口朝向、不随速度偏转；
## 滑行 COAST_TIME 秒到点开机（不等过顶——上升段就点火压弯，拦截更果断）
## ——点火喷烟，PN 从炮口朝向起转。
func _coast(delta: float) -> void:
	_vel.y += Balance.HEAVY_MISSILE_COAST_GRAVITY * delta
	if _t >= Balance.HEAVY_MISSILE_COAST_TIME:
		_phase = Phase.HOME
		_t = 0.0
		_prev_los = _los_angle()
		if _smoke != null:
			_smoke.emitting = true # 开机点火：拉烟从这里才开始
		if _flame != null:
			_flame.emitting = true


## 末段：比例导引——航向转速 = N×视线角速度（限幅到转向半径）。
## 视线不转=已在拦截航线上，自然走直；玩家横穿时视线角速度变大，
## 自动压坡度迎头截。到时锁死直线扎地。
func _home(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		_phase = Phase.LOCK
		return
	var los := _los_angle()
	var los_rate := wrapf(los - _prev_los, -PI, PI) / delta
	_prev_los = los
	var step := clampf(Balance.HEAVY_MISSILE_PN_N * los_rate * delta,
			-_turn_rate * delta, _turn_rate * delta)
	_dir = _dir.rotated(step)
	if _t >= Balance.HEAVY_MISSILE_TRACK_MAX:
		_phase = Phase.LOCK


func _los_angle() -> float:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return _dir.angle()
	return (player.global_position \
			+ Vector2(0.0, Balance.HEAVY_MISSILE_FOOT_OFFSET) - global_position).angle()


func _detonate() -> void:
	var surface := _terrain.surface_y_at(global_position.x)
	var at := Vector2(global_position.x, surface) # 爆心贴地（弹体已略入地，拉回表面）
	var container := get_tree().get_first_node_in_group("projectile_container")
	if _smoke != null:
		_smoke.emitting = false # 断烟，过继给弹容器让残余烟团淡完再清（不随弹体瞬灭）
		if container != null:
			_smoke.reparent(container)
			get_tree().create_timer(1.2).timeout.connect(_smoke.queue_free)
	if container != null:
		# 爆区闪光（GroundBlast 的橙闪）先入树垫底：爆炸火球/冲击环/烟压在它
		# 上面，橙光只从边缘露出当爆区光晕——后入树会画在最顶，把特效全罩住
		var blast := GroundBlast.new()
		blast.damage = damage
		blast.radius = blast_radius
		container.add_child(blast)
		blast.global_position = at
		blast.reset_physics_interpolation()
		var boom := EXPLOSION.instantiate() as Node2D
		boom.scale = Vector2(1.5, 1.5)
		boom.position = at + Vector2(0.0, -14.0) # 容器在原点，position 即全局位
		container.add_child(boom)
	Sfx.play(&"boom_enemy")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(Balance.KILL_SHAKE_STRENGTH * 1.5)
	queue_free()


## 弹体指向 +X：弹身矩形 + 弹头三角（占位）；尾焰/拉烟是粒子，不在 _draw。
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * BODY_SCALE)
	draw_rect(Rect2(-16.0, -4.0, 24.0, 8.0), BODY_COLOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8.0, -4.0), Vector2(8.0, 4.0), Vector2(18.0, 0.0),
	]), HEAD_COLOR)
