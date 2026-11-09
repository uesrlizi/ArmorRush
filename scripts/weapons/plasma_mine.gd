class_name PlasmaMine
extends Node2D
## 电浆浮雷（第三章精英/BOSS 共用危险件）：高抛入位→悬停警戒→近炸。
## 弹道：出膛初速按「落点+时长」解算（ballistic_velocity，g=MORTAR_GRAVITY，
## 同 MortarShell 账），落点是**空中点**（lead_x, 当地地表−HOVER_CLEAR）——
## 到点断发悬停（速度清零、姿态不转：雷是球，无朝向）。蓄能 WARMUP 渐亮
## （变危险的二段预警，期间不引信）后进入警戒：玩家进入 PROXIMITY → 引信
## FUSE 快闪 → 原地空中球状爆（GroundBlast，无火区——本项目无能量伤害模型，
## 电浆命中=爆炸）。寿命 LIFETIME 到点哑熄（无伤淡出）——雷是空间封锁不是
## 雷管，等待永远是合法反制。
## 惩罚账（提案_v2 §2）：站雷下=吃（雷人距 70 < 爆判定 106）；跑动穿越=免
## （引信 0.28s×跑速 600=168 位移 > 106）；跳跃穿越=吃（顶点距 4）。
## .new() 出生的类：纯代码自建视觉（fx_plasma_mine.svg 本体 + plasma_mine_arcs
## 电弧粒子），不池化（寿终自灭）。预警在发射器上（ThreatFlash，见调用方）。

enum State { FLY, HOVER, FUSED }

const BODY_TEXTURE := preload("res://assets/world_3/fx_plasma_mine.svg")
const ARCS := preload("res://scenes/fx/plasma_mine_arcs.tscn")
const BURST := preload("res://scenes/fx/plasma_burst.tscn")

const FLASH_COLOR := Color(0.5, 0.8, 1.0, 0.55) # 电浆爆区冰蓝（同 PlasmaMissile）

var damage := BalanceWorld3.PLASMA_MINE_DAMAGE
var blast_radius := BalanceWorld3.PLASMA_MINE_BLAST_RADIUS

var _terrain: Terrain
var _vel := Vector2.ZERO
var _state := State.FLY
var _flight := 0.0       # 解算飞行时长（launch 给入，到点断发悬停）
var _t := 0.0            # FLY 段计时
var _fuse_t := 0.0       # 引信剩余（FUSED 段）
var _hover := 0.0        # 悬停寿钟（寿命/淡出账）
var _bob_t := 0.0        # 悬停浮动+闪烁公用时钟
var _hover_base := Vector2.ZERO
var _visual: Sprite2D
var _arcs: GPUParticles2D


func _ready() -> void:
	add_to_group("plasma_mines") # 自测探针用
	_visual = Sprite2D.new()
	_visual.texture = BODY_TEXTURE
	_visual.modulate.a = 0.0
	add_child(_visual)
	_arcs = ARCS.instantiate() as GPUParticles2D
	_arcs.emitting = false # launch() 定位后开（先入树后定位：粒子别喷在原点）
	add_child(_arcs)


## 抛物线初速解算：v0 = Δ/T − ½gT（竖直项），全程只受 MORTAR_GRAVITY。
static func ballistic_velocity(from: Vector2, target: Vector2, flight_time: float) -> Vector2:
	var d := target - from
	var g := BalanceCombat.MORTAR_GRAVITY
	return Vector2(d.x / flight_time, d.y / flight_time - 0.5 * g * flight_time)


## 布雷带基点 x：按玩家速度外推（相对速度即机制：冲得越快雷铺得越远），
## clamp 到 [lead_min, lead_max]——停着不动雷也落在脚下前方（承诺带）。
static func fence_base_x(player: Player, flight_time: float, lead_min: float,
		lead_max: float) -> float:
	var vx := clampf(player.velocity.x,
			-BalancePlayer.PLAYER_MOVE_SPEED, BalancePlayer.PLAYER_MOVE_SPEED)
	return clampf(player.global_position.x + vx * flight_time,
			player.global_position.x + lead_min,
			player.global_position.x + lead_max)


## 先入树再调本方法。target 必须是空中点（调用方：地表−HOVER_CLEAR）。
func launch(terrain: Terrain, from: Vector2, target: Vector2, flight_time: float) -> void:
	_terrain = terrain
	_flight = flight_time
	global_position = from
	_vel = ballistic_velocity(from, target, flight_time)
	reset_physics_interpolation() # 先入树后定位：不拖补间残影
	_arcs.emitting = true


func _physics_process(delta: float) -> void:
	match _state:
		State.FLY:
			_t += delta
			_vel.y += BalanceCombat.MORTAR_GRAVITY * delta
			global_position += _vel * delta
			if _t >= _flight:
				_state = State.HOVER # 到点断发：速度清零悬停（落点即解算值）
				_hover_base = global_position
				_bob_t = 0.0
				_hover = 0.0
		State.HOVER:
			_tick_hover(delta)
		State.FUSED:
			_bob_t += delta
			_hover += delta
			_tick_visual(delta)
			if _hover >= BalanceWorld3.PLASMA_MINE_LIFETIME:
				_release_arcs() # 雷体已淡完，残余电弧过继淡完（不随节点瞬灭）
				queue_free() # 引信期内没人靠近：照常哑熄（无伤）
				return
			_fuse_t -= delta
			if _fuse_t <= 0.0:
				_detonate()


## 悬停警戒：呼吸浮动 + 蓄能渐亮（二段预警）+ 侦测近炸 + 寿命哑熄。
func _tick_hover(delta: float) -> void:
	_bob_t += delta
	_hover += delta
	global_position = _hover_base + Vector2(
			sin(_bob_t * BalanceEnemy.DRONE_BOB_SPEED * 0.6) * 3.0,
			sin(_bob_t * BalanceEnemy.DRONE_BOB_SPEED) * 4.0)
	if _hover >= BalanceWorld3.PLASMA_MINE_LIFETIME:
		_release_arcs() # 雷体已淡完，残余电弧过继淡完（不随节点瞬灭）
		queue_free() # 哑熄：无伤淡出（等出来的是安全，不是圈套）
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.is_dead() \
			and _hover >= BalanceWorld3.PLASMA_MINE_WARMUP \
			and global_position.distance_to(player.global_position) \
					<= BalanceWorld3.PLASMA_MINE_PROXIMITY:
		_state = State.FUSED
		_fuse_t = BalanceWorld3.PLASMA_MINE_FUSE
	_tick_visual(delta)


## 状态灯：蓄能=渐显+慢呼吸（变危险的二段预警），警戒=常亮微脉，
## 引信=高频快闪（冲刺穿雷的时间窗读得出来）。寿命末段统一淡出。
func _tick_visual(_delta: float) -> void:
	var alpha := 0.9
	if _state == State.FLY:
		alpha = 0.9
	elif _hover < BalanceWorld3.PLASMA_MINE_WARMUP:
		var p := _hover / BalanceWorld3.PLASMA_MINE_WARMUP
		alpha = p * (0.6 + 0.3 * sin(_bob_t * 10.0))
	elif _state == State.FUSED:
		alpha = 0.95 if fmod(_bob_t * 14.0, 1.0) < 0.5 else 0.35 # 高频快闪（14Hz 方波）
	else:
		alpha = 0.85 + 0.1 * sin(_bob_t * 6.0)
	var fade_out := clampf((BalanceWorld3.PLASMA_MINE_LIFETIME - _hover) / 0.4, 0.0, 1.0)
	_visual.modulate.a = minf(alpha, fade_out)


## 残余电弧过继弹容器淡完再清（同导弹拉烟收尾惯例；引爆与哑熄两条收尾共用）。
func _release_arcs() -> void:
	if _arcs == null:
		return
	_arcs.emitting = false
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		_arcs.reparent(container)
		_arcs.reset_physics_interpolation() # 过继后清补间基点（否则电弧从原点补间一步=闪一帧）
		get_tree().create_timer(0.8).timeout.connect(_arcs.queue_free)
	_arcs = null


func _detonate() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	_release_arcs()
	if container != null:
		# 空中球状爆：GroundBlast 只做位置球判定（不依赖地面），雷下驻停必吃
		var blast := GroundBlast.new()
		blast.damage = damage
		blast.radius = blast_radius
		blast.flash_color = FLASH_COLOR
		container.add_child(blast)
		blast.global_position = global_position
		blast.reset_physics_interpolation()
		var burst := BURST.instantiate() as Node2D
		burst.position = global_position
		container.add_child(burst)
	Sfx.play(&"boom_enemy")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 1.2)
	queue_free()
