class_name BossWorm
extends PursuitBoss
## 第三章 BOSS·机械冰蠕「冰钻」（雪原警戒点守卫）：**全表首台钻地体**——不悬浮，占不了追击
## 框架的构图位弹簧/悬浮锚，本类整体接管运动出口（_physics_process 不走父类 AI、不用
## Visuals 镜像层），只沿用框架的 BOSS 公共账：血量/防御/RUSH 折扣/阶梯/后摇缩放/
## 技能⇄普攻轮换（_dispatch_next）/死亡终爆时刻。正本=design/worlds.md §4b ch3 行，
## 数值全在 BalanceWorld3.WORM_*。
##
## 形体=头 + 10 体节 + 尾节的**链**：头是节点本体（位置=路径上的点），体节沿「头走过的路」
## 按固定弧长回溯落位（路径史折线采样）——任意航向下身体都连续，节短（100px）三成套叠
## 才弯得顺。头的航向=路径切线；露头时颈关节让头转去盯人（体节不动）。
##
## 层级：本机入组 "burrowers"，Spawner 把它挂进场景的 burrow_container（Terrain 之后画）
## ——**地下部分被地块盖住**（不做透視），潜行位置全靠地表航迹报：冰下黑影+雪脊+喷雪
## 随头走、沿途留雪痕；潜得越深航迹越淡（WORM_WAKE_*）。
##
## 索敌/受击：只认露出地面的体节——体心高出地表「体高×WORM_EXPOSE_INSET」才算露出，
## 埋着的碰撞形状逐帧关掉（子弹/近战打不进地里）；全埋=不可索敌（Enemy.is_targetable），
## 索敌点=头（露出时）否则露出的最高体节（Enemy.aim_point）。
##
## 伤害律：**只有冲撞态有接触伤**（WORM_RAM_DAMAGE，一次招式至多结算一下）——破土上升、
## 跃袭贯空、横冲通场、啄击。露头/失衡瘫地/潜行碰到无伤：近战爆发窗不许被接触伤封死。
##
## 招式（潜行=框架后摇期 ST_RECOVER，阶梯后摇缩短=潜行更短出招更密）：
##   普攻·露头吐锥：右前方破土（地面隆起+ThreatFlash 预警 0.6s）→竖身高拱→头回钩压低
##     盯人（离地 195：地面近战一刀够得着）→口部三连冰锥×2 轮（p2 3 轮；真瞄无预判，
##     跑动即躲）→回缩+口部预警→啄击（朝人直扎，冲撞伤）→入地；
##   技能A·跃袭：左**后方**破土（航迹从脚下穿过）→过顶贯空（拱高 380；p2 压到 260=纯跳
##     也挨撞）→右前方砸落——砸落点按跑速预测：**匀速跑=被砸、收步=让它砸在前面**；
##   技能B·横冲：右前方破出→贴地通场（带心离地 78：站立/纯跳=撞、推进升空=免）→左前方
##     扎入；p2 扎入后高位（离地 185）回冲一趟——先升后降；
##   失衡=击出地面：打满冲击→全身被轰出地表、头朝人瘫在地上（4s 硬直，受伤×1.5）→入地。
## 玩家已毁（结算后世界不冻结）：不出新招，在放的招走完回潜行。

const ST_WINDUP := 3      # 破土前摇：贴着破土点上顶 + 地面隆起预警
const ST_REAR_RISE := 4   # 露头：破土→竖身→回钩
const ST_REAR_HOLD := 5   # 露头吐锥
const ST_REAR_TELL := 6   # 啄击回缩预告
const ST_REAR_PECK := 7   # 啄击→入地
const ST_LEAP := 8        # 跃袭：贯空→砸落→地下收势
const ST_SWEEP := 9       # 横冲：通场→扎入（p2 +回冲）
const ST_KO_OUT := 10     # 失衡击出：腾空→瘫落
const ST_KO_REST := 11    # 失衡瘫地
const ST_BURROW := 12     # 失衡结束后的入地段
const ST_APPROACH := 13   # 地下接近：游向破土点

const MOVE_LEAP := 0
const MOVE_REAR := 1
const MOVE_SWEEP := 2

## 有接触伤的状态：破土上升 / 啄击 / 跃袭贯空 / 横冲通场（其余状态碰到无伤）。
const RAM_STATES := [ST_REAR_RISE, ST_REAR_PECK, ST_LEAP, ST_SWEEP]

const ICE_SHARD := preload("res://scenes/weapons/ice_shard.tscn")
const WAKE := preload("res://scenes/fx/worm_wake.tscn")
const WAKE_MARK := preload("res://scenes/fx/worm_wake_mark.tscn")
const MOUND := preload("res://scenes/fx/worm_mound.tscn")
const BREACH := preload("res://scenes/fx/worm_breach.tscn")
const STUN_SPARKS := preload("res://scenes/fx/worm_stun_sparks.tscn")

## 冲撞判定宽限（玩家碰撞半宽 26 / 半高 24，同 GroundBlast.PLAYER_RADIUS 惯例）
const PLAYER_HALF_W := 26.0
const PLAYER_HALF_H := 24.0
const TRAIL_MIN_STEP := 2.0   # 路径史落点间距下限（px）：头静止/慢爬时不堆点
const MARK_GAP := 90.0        # 航迹雪痕间距（px）

var _heading := PI           # 运动航向（rad；0=朝 +X）=路径切线
var _head_angle := PI        # 头的实际朝向（颈关节可偏离航向）
var _speed := 0.0
var _cruise_t := 0.0
var _cruise_prev := Vector2.ZERO
var _cruise_valid := false
var _slam_point := Vector2.ZERO  # 跃袭砸落点（探针读数：离墙余量断言用）
var _peck_target := Vector2.ZERO # 啄击锁点（口部闪光那一拍读定）
var _peck_reach := false         # 锁点时够不着（玩家已跑远）=原地入地不啄
var _move := MOVE_LEAP       # 当前招式
var _plan_point := Vector2.ZERO  # 破土点（地表）
var _plan_dir := Vector2.UP      # 破土出向
var _windup_top := Vector2.ZERO  # 预警期上顶终点
var _ram_hit := false
var _pose_tangent := PI       # 露头位体节切线（颈关节偏转的基准）
var _hold_t := 0.0
var _burst := 0
var _shots_left := 0
var _shot_t := 0.0
var _tell_from := Vector2.ZERO
var _sweep_pass := 0          # 横冲第几趟（0=去程 1=回程）
var _sweep_lane := 0.0        # 当前趟带心离地高度
var _head_above := false      # 头此刻是否在地上（穿地瞬间出特效）
var _rest_t := 0.0
var _mark_dist := 0.0
var _cut_cycle := 0           # 犁雪线轮转游标
var _return_s := INF         # 横冲回程起始弧长（超过它=走回程带位）

# 路径段：折线 + 逐点累计弧长 + 逐点目标速度
var _path := PackedVector2Array()
var _path_len := PackedFloat32Array()
var _path_speed := PackedFloat32Array()
var _path_s := 0.0
var _path_i := 1

# 链：[头, 节1..节10, 尾]
var _seg_sprites: Array[Sprite2D] = []
var _seg_shapes: Array[CollisionShape2D] = []
var _seg_offset := PackedFloat32Array()   # 链位：距头心的弧长
var _seg_half_len := PackedFloat32Array()
var _seg_half_h := PackedFloat32Array()
var _seg_pos := PackedVector2Array()      # 本体局部坐标
var _seg_angle := PackedFloat32Array()
var _seg_exposed: Array[bool] = []
var _seg_shape_on: Array[bool] = []
var _target_index := -1                   # 索敌体节（-1=全埋/不可索敌）
var _trail := PackedVector2Array()        # 头走过的路（旧→新）
var _trail_need := 0.0                    # 需要保留的路径史长度

var _wake: Node2D
var _cut: Node2D                          # 体线切地喷雪（破土口/砸落点/犁雪线）
var _mound: Node2D
var _stun: Node2D

@onready var _head_sprite: Sprite2D = $Visuals/Sprite2D
@onready var _eye: Node2D = $Visuals/Sprite2D/EyeGlow
@onready var _mouth_warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash


func _display_name() -> String:
	return "冰钻"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


## 索敌点=头（露出时），否则露出的最高体节；钳到地表上方 36px（半露的头也够得着视线）。
func aim_point() -> Vector2:
	if _target_index < 0:
		return global_position
	var wp := global_position + _seg_pos[_target_index]
	return Vector2(wp.x, minf(wp.y, _surface(wp.x) - 36.0))


## 全埋地下=不可索敌（枪不朝它转、肩炮不锁、近战不追、蜂巢不归航）。
func is_targetable() -> bool:
	return _target_index >= 0 and _hp > 0 and not _despawn_requested


func _impact_resistance() -> float:
	return super() * BalanceWorld3.WORM_IMPACT_SCALE


func _ready() -> void:
	super()
	_build_chain()
	_reset_trail()
	_tick_chain(0.0) # 入树当帧就把链铺开（否则首渲染帧体节全叠在头上）
	_spawn_fx_nodes()


func on_spawned() -> void:
	super()
	_bstate = ST_ENTER
	_bt = BalanceWorld3.WORM_ENTER_TIME
	_heading = PI
	_head_angle = PI
	_speed = 900.0
	_cruise_valid = false
	velocity = Vector2.ZERO
	_move = MOVE_LEAP
	_ram_hit = true
	_shots_left = 0
	_path = PackedVector2Array()
	_trail = PackedVector2Array()
	_cruise_t = randf() * TAU
	_mark_dist = 0.0
	_mouth_warn.reset()
	# 出生=画面右缘外的地下，朝左潜入（Spawner 摆的悬浮锚位不用）
	var x := _player_node().global_position.x if _player_node() != null else global_position.x
	x = maxf(x + 2100.0, global_position.x)
	global_position = Vector2(x, _surface(x) + BalanceWorld3.WORM_CRUISE_DEPTH)


## ---- 链的构建：体节精灵按 tscn 的尾→头顺序登记，碰撞形状纯代码自建 ----

func _build_chain() -> void:
	_seg_sprites.clear()
	_seg_shapes.clear()
	_seg_offset.resize(0)
	_seg_half_len.resize(0)
	_seg_half_h.resize(0)
	for node in _visuals.get_children():
		var sp := node as Sprite2D
		if sp != null:
			_seg_sprites.append(sp)
	# _visuals 子序=尾…节1、头（Sprite2D）——登记序翻成头→尾
	_seg_sprites.reverse()
	var scales: Array = BalanceWorld3.WORM_SEG_SCALES
	var front := 100.0 - BalanceWorld3.WORM_HEAD_TUCK
	for k in _seg_sprites.size():
		var s: float = 1.0 if k == 0 else float(scales[mini(k, scales.size() - 1)])
		if k == 0:
			_seg_offset.append(0.0)
			_seg_half_len.append(88.0)
			_seg_half_h.append(66.0)
		else:
			_seg_offset.append(front + 50.0 * s)
			_seg_half_len.append(44.0 * s)
			_seg_half_h.append(56.0 * s)
			if k < _seg_sprites.size() - 1:
				front += BalanceWorld3.WORM_SEG_LEN * s - BalanceWorld3.WORM_SEG_TUCK * s
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(_seg_half_len[k] * 2.0, _seg_half_h[k] * 2.0)
		cs.shape = rect
		cs.disabled = true
		add_child(cs)
		_seg_shapes.append(cs)
	var n := _seg_sprites.size()
	_seg_pos.resize(n)
	_seg_angle.resize(n)
	_seg_angle.fill(PI)
	_seg_exposed.resize(n)
	_seg_exposed.fill(false)
	_seg_shape_on.resize(n)
	_seg_shape_on.fill(false)
	_trail_need = _seg_offset[_seg_offset.size() - 1] + 300.0


func _reset_trail() -> void:
	_trail = PackedVector2Array()
	var back := -Vector2.from_angle(_heading)
	var steps := int(ceil(_trail_need / 30.0))
	for i in range(steps, -1, -1):
		_trail.append(global_position + back * 30.0 * float(i))


## ---- 特效常驻件：潜行航迹（随头）+ 体线切地喷雪，都走弹容器（前景） ----

func _spawn_fx_nodes() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	_wake = WAKE.instantiate()
	container.add_child(_wake)
	# 体线喷雪件：只留喷雪层（雪脊/黑影是「潜行在地下」的读法，身体露在外面时不该有）
	_cut = WAKE.instantiate()
	_cut.set_show_mound(false)
	container.add_child(_cut)
	_cut.visible = false


func _exit_tree() -> void:
	# 航迹件不随本体走：本体没了就地快淡（可见物不许瞬灭），残影不留场
	for node in [_wake, _cut, _mound]:
		var ci := node as CanvasItem
		if ci != null and is_instance_valid(ci) and ci.is_inside_tree():
			var tw := ci.create_tween()
			tw.tween_property(ci, "modulate:a", 0.0, 0.2)
			tw.tween_callback(ci.queue_free)


func _player_node() -> Player:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player as Player


func _terrain_node() -> Terrain:
	return get_tree().get_first_node_in_group("terrain") as Terrain


## 当地地表（没地形节点的预览场退回中位档 600）。
func _surface(x: float) -> float:
	var terrain := _terrain_node()
	return terrain.surface_y_at(x) if terrain != null else 600.0


## ±200px 汉宁窗平滑地表（横冲通场带贴它走：台阶处 64px 落差摊成缓坡，不瞬跳）。
func _smooth_surface(x: float) -> float:
	var acc := 0.0
	var wsum := 0.0
	for i in range(-4, 5):
		var dx := 50.0 * float(i)
		var w := 0.5 + 0.5 * cos(PI * dx / 200.0)
		acc += _surface(x + dx) * w
		wsum += w
	return acc / wsum


## 玩家 seconds 秒后的预测 x（按当前水平速度线性外推，钳到跑速）。
func _predict_x(seconds: float) -> float:
	var player := _player_node()
	if player == null:
		return global_position.x
	return player.global_position.x + clampf(player.velocity.x,
			-BalancePlayer.PLAYER_MOVE_SPEED, BalancePlayer.PLAYER_MOVE_SPEED) * seconds


## ---- 路径段：三次贝塞尔按弧长采成折线，_follow_path 按逐点速度等速走完 ----

func _begin_path() -> void:
	_path = PackedVector2Array([global_position])
	_path_len = PackedFloat32Array([0.0])
	_path_speed = PackedFloat32Array([_speed])
	_path_s = 0.0
	_path_i = 1


func _push(p: Vector2, speed: float) -> void:
	var last := _path[_path.size() - 1]
	var d := last.distance_to(p)
	if d < 0.75:
		return
	_path.append(p)
	_path_len.append(_path_len[_path_len.size() - 1] + d)
	_path_speed.append(speed)


func _add_bezier(p1: Vector2, p2: Vector2, p3: Vector2, speed: float, n := 30) -> void:
	var p0 := _path[_path.size() - 1]
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var u := 1.0 - t
		_push(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t), speed)


## 地下段贴地安全：从 mark 号采样点起不得浅于 WORM_BURROW_MIN_DEPTH（防控制点把弧拉出地表）。
func _bury_from(mark: int) -> void:
	var deep := BalanceWorld3.WORM_BURROW_MIN_DEPTH
	for i in range(mark, _path.size()):
		var p := _path[i]
		var floor_y := _surface(p.x) + deep
		if p.y < floor_y:
			var prev := _path[i - 1]
			p.y = floor_y
			_path[i] = p
			_path_len[i] = _path_len[i - 1] + prev.distance_to(p)


## 返回是否走完。
func _follow_path(delta: float) -> bool:
	if _path.size() < 2:
		return true
	var total := _path_len[_path_len.size() - 1]
	var target := _path_speed[mini(_path_i, _path_speed.size() - 1)]
	_speed = move_toward(_speed, target, BalanceWorld3.WORM_PATH_ACCEL * delta)
	_path_s = minf(_path_s + _speed * delta, total)
	while _path_i < _path_len.size() - 1 and _path_len[_path_i] < _path_s:
		_path_i += 1
	var i := _path_i
	var seg := _path_len[i] - _path_len[i - 1]
	var t := 0.0 if seg <= 0.0 else clampf((_path_s - _path_len[i - 1]) / seg, 0.0, 1.0)
	global_position = _path[i - 1].lerp(_path[i], t)
	var far := mini(i + 3, _path.size() - 1)
	var tangent := _path[far] - _path[maxi(i - 4, 0)]
	if tangent.length_squared() > 0.01:
		_heading = lerp_angle(_heading, tangent.angle(), 0.55)
	velocity = Vector2.from_angle(_heading) * _speed
	return _path_s >= total


## 地下接近段：从当前位姿（航向=出向切线）拐到破土点正下方 out_dir×(rise+44) 处、以 out_dir 为
## 到达切线。point_of(到破土的秒数)=破土点——落点要按玩家跑速预测到**破土那一刻**，而破土
## 时刻取决于接近段要走多久：先按 1s 估值摆点量出接近弧长，再按量出的真实时长重摆一次
## （蠕虫常已在破土点附近，估值偏长=落点被甩到玩家前头）。
func _start_windup(point_of: Callable, out_dir: Vector2, rise: float) -> void:
	var est := 1.0
	var point := _off_walls(point_of.call(est))
	for attempt in 2:
		var start := point - out_dir * (rise + 44.0)
		_begin_path()
		var l := clampf(global_position.distance_to(start) * 0.45, 120.0, 520.0)
		var mark := _path.size()
		_add_bezier(global_position + Vector2.from_angle(_heading) * l,
				start - out_dir * l, start, BalanceWorld3.WORM_APPROACH_SPEED)
		_bury_from(mark)
		var real := _path_len[_path_len.size() - 1] / BalanceWorld3.WORM_APPROACH_SPEED \
				+ BalanceWorld3.WORM_WINDUP
		if absf(real - est) < 0.12:
			break
		est = real
		point = _off_walls(point_of.call(est))
	_plan_point = point
	_plan_dir = out_dir
	_windup_top = point - out_dir * 44.0
	_bstate = ST_APPROACH
	_ram_hit = true # 接近段全程在地下：冲撞到破土才开闸


## 离墙余量：落点若贴着「更高的邻块」（离块边不足 WORM_WALL_MARGIN 且邻块更高）就往开阔
## 一侧挪开——贴着台阶侧壁破土/砸落，160 宽的身子会嵌进墙里（台阶地形实机抓回）。
## 挪完 y 取挪后位置的地表。
func _off_walls(point: Vector2) -> Vector2:
	var w := BalanceGlobal.TERRAIN_CHUNK_WIDTH
	var margin := BalanceWorld3.WORM_WALL_MARGIN
	var x := point.x
	var i := floori(x / w)
	var g := _surface(x)
	if x - i * w < margin and _surface(x - w) < g - 1.0:
		x = i * w + margin
	elif (i + 1) * w - x < margin and _surface(x + w) < g - 1.0:
		x = (i + 1) * w - margin
	return Vector2(x, _surface(x))


func _spawn_mound(point: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	_mound = MOUND.instantiate()
	_mound.position = Vector2(point.x, _surface(point.x))
	container.add_child(_mound)
	Sfx.play(&"hit_world", 1.3) # 隆起闷响（占位：暂用弹着地声）


func _release_mound() -> void:
	if _mound != null and is_instance_valid(_mound):
		_mound.release()
	_mound = null


## ---- 主循环 ----

func _physics_process(delta: float) -> void:
	if _despawn_requested or _hp <= 0:
		return
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud != null:
		hud.set_boss_hp(hp_ratio())
		# 失衡期冲击条改读硬直剩余（同框架：匀速排空=硬直计时器）
		hud.set_boss_impact(_stagger_t / _stagger_time() if is_staggered()
				else impact_ratio())
	if is_staggered():
		_stagger_t -= delta
		if _stagger_t <= 0.0:
			_end_stagger()
			_begin_burrow()
		elif _bstate != ST_KO_OUT and _bstate != ST_KO_REST:
			_begin_knockout() # 失衡=击出地面（任何时刻挨满都成立）
	_tick_state(delta)
	# 冰锥错拍出膛（跨状态计时）
	if _shots_left > 0:
		_shot_t -= delta
		if _shot_t <= 0.0:
			_fire_shard()
			_shots_left -= 1
			_shot_t = BalanceWorld3.WORM_SHARD_GAP
	_tick_chain(delta)
	_tick_exposure()
	_tick_ram()
	_tick_fx(delta)
	_tick_impact_decay(delta)


func _tick_state(delta: float) -> void:
	match _bstate:
		ST_ENTER, ST_RECOVER:
			_tick_cruise(delta)
			if not _player_down():
				_bt -= delta
				if _bt <= 0.0:
					_dispatch_next()
		ST_APPROACH:
			# 地下接近：游到破土点正下方才进前摇——隆起此刻才起（预警只管破土前那 0.6s，
			# 接近这段全靠航迹读「它来了」）
			if _follow_path(delta):
				_bstate = ST_WINDUP
				_bt = BalanceWorld3.WORM_WINDUP
				_speed = 0.0
				_spawn_mound(_plan_point)
		ST_WINDUP:
			# 贴着破土点缓缓上顶（航向锁死出向）：地面隆起同步长到满
			var step := BalanceWorld3.WORM_WINDUP_RISE / BalanceWorld3.WORM_WINDUP * delta
			global_position = global_position.move_toward(_windup_top, step)
			_heading = _plan_dir.angle()
			velocity = _plan_dir * step / delta
			_bt -= delta
			if _bt <= 0.0:
				_release_mound()
				_begin_path()
				_speed = 500.0 # 破土预蓄：0 起步太肉，半速起冲 0.2s 内到全速
				match _move:
					MOVE_LEAP:
						_build_leap()
					MOVE_REAR:
						_build_rear()
					MOVE_SWEEP:
						_build_sweep_out()
					_:
						_enter_recover(1.0)
		ST_REAR_RISE:
			if _follow_path(delta):
				_begin_rear_hold()
		ST_REAR_HOLD:
			_tick_rear_hold(delta)
		ST_REAR_TELL:
			velocity = Vector2.ZERO
			var p := 1.0 - _bt / BalanceWorld3.WORM_REAR_TELL
			p = 1.0 - (1.0 - p) * (1.0 - p)
			global_position = _tell_from - Vector2.from_angle(_head_angle) \
					* BalanceWorld3.WORM_REAR_TELL_PULL * p
			_bt -= delta
			if _bt <= 0.0:
				_build_peck()
		ST_REAR_PECK, ST_BURROW:
			if _follow_path(delta):
				_enter_recover(BalanceWorld3.WORM_REAR_RECOVER)
		ST_LEAP:
			if _follow_path(delta):
				_enter_recover(BalanceWorld3.WORM_LEAP_RECOVER)
		ST_SWEEP:
			if _follow_path(delta):
				_enter_recover(BalanceWorld3.WORM_SWEEP_RECOVER)
			else:
				_sweep_lane = (BalanceWorld3.WORM_SWEEP_RETURN_LANE if _path_s >= _return_s
						else BalanceWorld3.WORM_SWEEP_LANE)
		ST_KO_OUT:
			if _follow_path(delta):
				_land_knockout()
		ST_KO_REST:
			velocity = Vector2.ZERO
			_rest_t += delta
		_:
			pass


## 潜行=贴轨巡游：轨道点=「玩家右侧 + 前后涌动」的地下锚，期望速度=锚点速度+偏差×增益
## （追上就跟着锚点起伏，不会绕锚转圈——纯追踪追上后必绕圈，圈的上缘会穿出地表）；
## 离得远饱和到 WORM_CRUISE_SPEED_MAX 追赶，速度有下限不许原地停死。
## 末尾硬闸：潜行段头不得浅于 WORM_BURROW_MIN_DEPTH。
func _tick_cruise(delta: float) -> void:
	_cruise_t += delta
	var player := _player_node()
	var px := player.global_position.x if player != null else global_position.x
	var ax := px + BalanceWorld3.WORM_CRUISE_X \
			+ BalanceWorld3.WORM_CRUISE_SURGE * sin(_cruise_t * BalanceWorld3.WORM_CRUISE_SURGE_SPEED)
	var ay := _surface(ax) + BalanceWorld3.WORM_CRUISE_DEPTH \
			+ BalanceWorld3.WORM_CRUISE_WEAVE * sin(_cruise_t * BalanceWorld3.WORM_CRUISE_WEAVE_SPEED)
	var tgt := Vector2(ax, ay)
	var tgt_vel := Vector2.ZERO
	if _cruise_valid and delta > 0.0:
		tgt_vel = (tgt - _cruise_prev) / delta
	_cruise_prev = tgt
	_cruise_valid = true
	var want := tgt_vel + (tgt - global_position) * BalanceWorld3.WORM_CRUISE_TRACK
	want = want.limit_length(BalanceWorld3.WORM_CRUISE_SPEED_MAX)
	var speed := maxf(want.length(), BalanceWorld3.WORM_CRUISE_IDLE_SPEED)
	if want.length() < 1.0:
		want = Vector2.from_angle(_heading)
	var rate := BalanceWorld3.WORM_TURN_RATE * clampf(speed / 600.0, 0.35, 1.0)
	_heading += clampf(wrapf(want.angle() - _heading, -PI, PI), -rate * delta, rate * delta)
	_speed = move_toward(_speed, speed, BalanceWorld3.WORM_ACCEL * delta)
	velocity = Vector2.from_angle(_heading) * _speed
	global_position += velocity * delta
	var floor_y := _surface(global_position.x) + BalanceWorld3.WORM_BURROW_MIN_DEPTH
	if global_position.y < floor_y:
		global_position.y = floor_y
		_heading = lerp_angle(_heading, PI if cos(_heading) < 0.0 else 0.0, 0.5)


## ---- 技能A·跃袭 ----

func _begin_skill_a() -> void:
	_move = MOVE_LEAP
	var behind := func(t: float) -> Vector2:
		var ex := _predict_x(t) - BalanceWorld3.WORM_LEAP_BEHIND
		return Vector2(ex, _surface(ex))
	_start_windup(behind, Vector2.UP, BalanceWorld3.WORM_WINDUP_RISE)


func _build_leap() -> void:
	_ram_hit = false # 冲撞开闸：破土上升即有伤害
	var s := global_position
	var h: float = BalanceWorld3.WORM_LEAP_HEIGHT_P2 if _phase2 else BalanceWorld3.WORM_LEAP_HEIGHT
	var lx := _predict_x(BalanceWorld3.WORM_LEAP_FLIGHT) + BalanceWorld3.WORM_LEAP_SLAM_AHEAD
	lx = _off_walls(Vector2(maxf(lx, _plan_point.x + BalanceWorld3.WORM_LEAP_MIN_SPAN), 0.0)).x
	_slam_point = Vector2(lx, _surface(lx))
	var top := minf(_surface(_plan_point.x), _surface(lx))
	var a := Vector2(_plan_point.x + 0.45 * (lx - _plan_point.x), top - h)
	_add_bezier(s + Vector2(0.0, -0.6 * (s.y - a.y)),
			a + Vector2(-0.55 * (a.x - s.x), 0.0), a, BalanceWorld3.WORM_LEAP_RISE_SPEED)
	var d := Vector2(lx, _surface(lx) + 50.0)
	_add_bezier(a + Vector2(0.5 * (d.x - a.x), 0.0),
			d + Vector2(0.0, -0.55 * (d.y - a.y)), d, BalanceWorld3.WORM_LEAP_FALL_SPEED)
	var r := Vector2(d.x + 210.0, _surface(d.x + 210.0) + 250.0)
	_add_bezier(d + Vector2(0.0, 200.0), r + Vector2(-220.0, 0.0), r,
			BalanceWorld3.WORM_APPROACH_SPEED)
	_bstate = ST_LEAP


## ---- 普攻·露头吐锥 ----

func _begin_direct() -> void:
	_move = MOVE_REAR
	# 破土点锚在玩家（按跑速外推到露头时刻）前方 REAR_AHEAD：跑动中的人追到露头位时还有 ~670 余量
	var ahead := func(t: float) -> Vector2:
		var ex := _predict_x(t + 0.3) + BalanceWorld3.WORM_REAR_AHEAD
		return Vector2(ex, _surface(ex))
	_start_windup(ahead, Vector2.UP, BalanceWorld3.WORM_WINDUP_RISE)


func _build_rear() -> void:
	_ram_hit = false # 冲撞开闸：破土上升有伤害；到露头位即关（_begin_rear_hold）
	var s := global_position
	var e := _plan_point
	var apex := Vector2(e.x - 50.0, _surface(e.x) - BalanceWorld3.WORM_REAR_HEIGHT)
	_add_bezier(s + Vector2(0.0, -0.58 * (s.y - apex.y)), apex + Vector2(60.0, 0.0), apex, 1500.0)
	var pose := Vector2(e.x - BalanceWorld3.WORM_REAR_HEAD_BACK,
			_surface(e.x - BalanceWorld3.WORM_REAR_HEAD_BACK) - BalanceWorld3.WORM_REAR_HEAD_HEIGHT)
	var dpose := Vector2(-cos(deg_to_rad(38.0)), sin(deg_to_rad(38.0)))
	_add_bezier(apex + Vector2(-0.5 * (apex.x - pose.x), 0.0), pose - dpose * 110.0, pose, 1400.0)
	_bstate = ST_REAR_RISE


func _begin_rear_hold() -> void:
	_ram_hit = true # 露头/吐锥期碰到无伤（近战窗口）
	_pose_tangent = _heading
	_hold_t = 0.0
	_burst = 0
	_bstate = ST_REAR_HOLD
	_bt = BalanceWorld3.WORM_REAR_HOLD \
			+ (BalanceWorld3.WORM_REAR_HOLD_P2 if _phase2 else 0.0)


func _tick_rear_hold(delta: float) -> void:
	velocity = Vector2.ZERO
	_hold_t += delta
	var bursts := BalanceWorld3.WORM_REAR_BURSTS + (1 if _phase2 else 0)
	if _burst < bursts and _hold_t >= 0.12 + _burst * BalanceWorld3.WORM_REAR_BURST_GAP:
		if _shots_left == 0:
			_shot_t = 0.0
		_shots_left += BalanceWorld3.WORM_SHARD_COUNT
		_burst += 1
	_bt -= delta
	if _bt <= 0.0:
		_begin_rear_tell()


## 啄击预告：口部闪光 + 警告音同拍，**这一拍就锁点**（玩家当时位置）——预告 0.42s + 直扎
## ~0.2s 是完整的闪避窗，站原地=吃，看见闪光就跑=免。
func _begin_rear_tell() -> void:
	_bstate = ST_REAR_TELL
	_bt = BalanceWorld3.WORM_REAR_TELL
	_tell_from = global_position
	var player := _player_node()
	_peck_reach = false
	if player != null and not player.is_dead():
		var dx := player.global_position.x - global_position.x
		_peck_reach = dx >= -BalanceWorld3.WORM_REAR_REACH and dx <= 80.0
		_peck_target = Vector2(player.global_position.x, _surface(player.global_position.x) - 24.0)
	_mouth_warn.warn() # 预警统一入口：口部闪光 + 警告音


## 啄击=先仰头再从高处直扎锁点：走廊只盖锁点左右 ~110px，落地前半段在头顶上方掠过——
## 往哪边跑、跳、推进都躲得开，站原地才吃（首版沿视线斜扫过去，往右跑=迎面撞进来的头）。
func _build_peck() -> void:
	_begin_path()
	var lunge := Vector2.from_angle(_head_angle)
	if _peck_reach:
		var t := _peck_target
		_add_bezier(global_position + Vector2(-40.0, -170.0), t + Vector2(150.0, -260.0), t,
				BalanceWorld3.WORM_REAR_PECK_SPEED, 22)
		lunge = Vector2(0.45, 0.89) # 末段扎地方向（右下陡）
		var w := Vector2(t.x + 150.0, _surface(t.x + 150.0) + 230.0)
		_add_bezier(t + lunge * 150.0, w + Vector2(-140.0, -60.0), w, 1400.0)
	else:
		var w := Vector2(global_position.x - 40.0, _surface(global_position.x - 40.0) + 230.0)
		_add_bezier(global_position + lunge * 160.0, w + Vector2(-120.0, -40.0), w, 1400.0)
	_ram_hit = false # 冲撞开闸：啄击有伤害
	_bstate = ST_REAR_PECK


## 口部单发冰锥：枪口→玩家当前位置（无预判，跑动即躲），普通混合弹体自带描边。
func _fire_shard() -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	var player := _player_node()
	if container == null or player == null or _player_down() or _hp <= 0:
		_shots_left = 0
		return
	var dir := _muzzle.global_position.direction_to(player.global_position + Vector2(0.0, -6.0))
	dir = dir.rotated(deg_to_rad(randf_range(-1.5, 1.5)))
	var b := ICE_SHARD.instantiate() as Bullet
	b.speed = BalanceWorld3.WORM_SHARD_SPEED
	b.damage = BalanceWorld3.WORM_SHARD_DAMAGE
	b.impact_tint = Color(0.7, 0.88, 1.0)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = _muzzle.global_position
	b.reset_physics_interpolation()
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_enemy")


## ---- 技能B·横冲 ----

func _begin_skill_b() -> void:
	_move = MOVE_SWEEP
	var out := Vector2(-cos(deg_to_rad(20.0)), -sin(deg_to_rad(20.0)))
	var breakout := func(t: float) -> Vector2:
		var bx := _predict_x(t) + BalanceWorld3.WORM_SWEEP_AHEAD
		return Vector2(bx, _surface(bx))
	_start_windup(breakout, out, 40.0)


## 破出→贴地通场→扎入。去程向左（朝玩家身后），回程（p2）向右、带位更高。
## 全程「一次规划、分段接龙」：每段起点一律取路径末点，不许读 global_position——规划这一帧
## 头还停在破出点，拿它当回程起点=回程带整段错位（铺成一条埋在地里的弧，实机探针抓回）。
func _build_sweep_out() -> void:
	_ram_hit = false # 冲撞开闸：通场全程有伤害
	_sweep_pass = 0
	_sweep_lane = BalanceWorld3.WORM_SWEEP_LANE
	_return_s = INF
	var z := _add_sweep_lane(-1.0, _sweep_lane, _predict_x(0.8) - BalanceWorld3.WORM_SWEEP_PAST)
	if _phase2:
		_sweep_pass = 1
		# 回程：从扎入点地下甩回地表带位再破出（U 形甩头），向右回冲更高一趟后扎入
		var turn_x := z.x - BalanceWorld3.WORM_SWEEP_TURN_BACK
		var back := Vector2(turn_x,
				_smooth_surface(turn_x) - BalanceWorld3.WORM_SWEEP_RETURN_LANE)
		_return_s = _path_len[_path_len.size() - 1]
		_add_bezier(z + Vector2(-160.0, 60.0), back + Vector2(-200.0, 0.0), back,
				BalanceWorld3.WORM_SWEEP_SPEED, 22)
		_add_sweep_lane(1.0, BalanceWorld3.WORM_SWEEP_RETURN_LANE,
				_predict_x(BalanceWorld3.WORM_SWEEP_RETURN_LEAD) + 620.0, Vector2.RIGHT)
	_bstate = ST_SWEEP


## 追加一趟通场：从路径末点拐到带位（sign_x 方向），沿平滑地表走带到 end_x，末尾斜扎入地。
## in_dir=这段的入段方向（省略=头当前航向）；返回扎入点（地下 220 深）。
func _add_sweep_lane(sign_x: float, lane: float, end_x: float,
		in_dir := Vector2.INF) -> Vector2:
	var s := _path[_path.size() - 1]
	if in_dir == Vector2.INF:
		in_dir = Vector2.from_angle(_heading)
	var first := Vector2(s.x + sign_x * 36.0, _smooth_surface(s.x + sign_x * 36.0) - lane)
	_add_bezier(s + in_dir * 70.0, first - Vector2(sign_x * 40.0, 0.0), first,
			BalanceWorld3.WORM_SWEEP_SPEED, 8)
	var x := first.x
	while (sign_x < 0.0 and x > end_x) or (sign_x > 0.0 and x < end_x):
		x += sign_x * 36.0
		_push(Vector2(x, _smooth_surface(x) - lane), BalanceWorld3.WORM_SWEEP_SPEED)
	var z := Vector2(x + sign_x * 250.0, _surface(x + sign_x * 250.0) + 220.0)
	_add_bezier(Vector2(x, _smooth_surface(x) - lane) + Vector2(sign_x * 200.0, 0.0),
			z + Vector2(-sign_x * 120.0, -90.0), z, 1600.0)
	return z


## ---- 失衡=击出地面 ----

## 击出=全身摔出地面、贴地滑到玩家脚下：先摔到触地点，再朝左滑行 WORM_KNOCKOUT_SKID——
## 滑行段比露在外面的前身还长，身体跟着路径史整条摊到地上（滑短了后半截还拱在半空）；
## 头滑过玩家身边停下（最多越过 WORM_KNOCKOUT_PAST），玩家就站在摊开的身体上=近战
## 爆发窗。头在玩家左侧时（身后破土上升中）先冲过头再折回，一样以向左滑行收势。
## 已在地面（横冲途中）直接滑行减速。
func _begin_knockout() -> void:
	_release_mound()
	_shots_left = 0
	_ram_hit = true # 瘫倒全程无接触伤
	_remove_stun()
	var px := global_position.x
	var player := _player_node()
	if player != null:
		px = player.global_position.x
	var head := global_position
	# 触地滑行起点：头在玩家右侧=原位左移 60；在左侧=冲过头的落点。高度取它自己脚下的地表
	var td := _rest_point(head.x - 60.0 if head.x >= px + 60.0 \
			else px + BalanceWorld3.WORM_KNOCKOUT_TOUCHDOWN)
	_begin_path()
	if head.x >= px + 60.0:
		if head.y < td.y - 30.0:
			var drop := td.y - head.y
			_add_bezier(head + Vector2(-40.0, minf(100.0, 0.5 * drop + 40.0)),
					td + Vector2(50.0, -minf(80.0, 0.4 * drop)), td,
					BalanceWorld3.WORM_KNOCKOUT_SPEED, 20)
		else:
			_push(td, BalanceWorld3.WORM_KNOCKOUT_SPEED) # 已在地面（横冲途中）：顺着惯性直接滑
	else:
		_add_bezier(Vector2(head.x, maxf(head.y - 400.0, -20.0)), td + Vector2(300.0, -240.0), td,
				BalanceWorld3.WORM_KNOCKOUT_SPEED, 26)
	var rx := clampf(td.x - BalanceWorld3.WORM_KNOCKOUT_SKID,
			px - BalanceWorld3.WORM_KNOCKOUT_PAST, px + BalanceWorld3.WORM_KNOCKOUT_FAR)
	var rest := _rest_point(rx)
	# 贴地滑行：逐段贴当地地表（滑上台阶跟着抬，不然头先埋进台阶侧壁再冒出来），线性减速
	# （到点急停=撞地闷响，见 _land_knockout）；末速留 350——收到太低会在地上爬两秒，
	# 4s 硬直被滑行吃掉大半
	var steps := maxi(3, ceili(absf(rest.x - td.x) / 24.0))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var sx := lerpf(td.x, rest.x, t)
		_push(Vector2(sx, _surface(sx) - BalanceWorld3.WORM_REST_HEIGHT), lerpf(1200.0, 350.0, t))
	_bstate = ST_KO_OUT


## 贴地点：x 处当地地表上方 WORM_REST_HEIGHT（瘫倒/滑行时头心的离地高度）。
func _rest_point(x: float) -> Vector2:
	return Vector2(x, _surface(x) - BalanceWorld3.WORM_REST_HEIGHT)


func _land_knockout() -> void:
	_bstate = ST_KO_REST
	_rest_t = 0.0
	_spawn_burst(global_position.x, true, 0.6)
	var player := _player_node()
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 1.4)
	if _stun == null and _hp > 0:
		_stun = STUN_SPARKS.instantiate()
		_visuals.add_child(_stun)


func _remove_stun() -> void:
	if _stun != null and is_instance_valid(_stun):
		_stun.queue_free()
	_stun = null


## 失衡结束：从瘫倒位顺头朝向扎回地下，之后交还潜行。
func _begin_burrow() -> void:
	_remove_stun()
	_begin_path()
	var p := global_position
	var w := Vector2(p.x - 170.0, _surface(p.x - 170.0) + 220.0)
	_add_bezier(p + Vector2.from_angle(_head_angle) * 120.0, w + Vector2(0.0, -100.0), w, 1300.0)
	_ram_hit = true
	_bstate = ST_BURROW


## ---- 链：路径史落点 + 体节回溯 ----

func _tick_chain(delta: float) -> void:
	var head := global_position
	if _trail.is_empty() or head.distance_squared_to(_trail[_trail.size() - 1]) >= TRAIL_MIN_STEP * TRAIL_MIN_STEP:
		_trail.append(head)
		_trim_trail()
	# 头朝向：默认跟航向；露头期颈关节转头盯人（钳在体节切线 ±WORM_NECK_YAW_DEG）
	var want := _heading
	if _bstate == ST_REAR_HOLD:
		var player := _player_node()
		if player != null:
			var yaw := deg_to_rad(BalanceWorld3.WORM_NECK_YAW_DEG)
			want = _pose_tangent + clampf(wrapf(head.angle_to_point(player.global_position) - _pose_tangent, -PI, PI), -yaw, yaw)
	_head_angle = lerp_angle(_head_angle, want, 0.35)
	# 体节沿路径史回溯（尾→头方向走一次，链位递增）
	var n := _trail.size()
	var i := n - 1
	var acc := 0.0
	for k in range(1, _seg_sprites.size()):
		var d := _seg_offset[k]
		while i > 0 and acc + _trail[i].distance_to(_trail[i - 1]) < d:
			acc += _trail[i].distance_to(_trail[i - 1])
			i -= 1
		var pos: Vector2
		var older: Vector2
		if i > 0:
			var seg := _trail[i].distance_to(_trail[i - 1])
			var t := clampf((d - acc) / maxf(seg, 0.0001), 0.0, 1.0)
			pos = _trail[i].lerp(_trail[i - 1], t)
			older = _trail[maxi(i - 5, 0)]
		else:
			var d0 := (_trail[1] - _trail[0]).normalized() if n > 1 else Vector2.RIGHT
			pos = _trail[0] - d0 * (d - acc)
			older = _trail[0] - d0 * 40.0
		_seg_pos[k] = pos - head
		_seg_angle[k] = older.angle_to_point(pos)
	# 首节前缘对到头的颈环（颈关节偏转时链条仍连续）
	if _seg_sprites.size() > 2:
		var collar := Vector2.from_angle(_head_angle) * -80.0
		var to2 := _seg_pos[2] - collar
		if to2.length_squared() > 1.0:
			_seg_pos[1] = collar + to2.normalized() * (50.0 * float(BalanceWorld3.WORM_SEG_SCALES[1]) - 6.0)
			_seg_angle[1] = collar.angle_to_point(_seg_pos[2])
	_seg_pos[0] = Vector2.ZERO
	_seg_angle[0] = _head_angle
	_sync_visuals()


func _trim_trail() -> void:
	if _trail.size() < 160:
		return
	var acc := 0.0
	var i := _trail.size() - 1
	while i > 0 and acc < _trail_need + 100.0:
		acc += _trail[i].distance_to(_trail[i - 1])
		i -= 1
	if i > 40:
		_trail = _trail.slice(i)


func _sync_visuals() -> void:
	# 瘫地抽搐：体节横向抖（幅度随硬直剩余衰减），头不抖
	var wiggle := 0.0
	if _bstate == ST_KO_REST:
		wiggle = 6.0 * clampf(_stagger_t / _stagger_time(), 0.0, 1.0)
	for k in _seg_sprites.size():
		var sp := _seg_sprites[k]
		var pos := _seg_pos[k]
		if wiggle > 0.0 and k > 0:
			pos += Vector2.from_angle(_seg_angle[k] + PI * 0.5) * wiggle * sin(_rest_t * 19.0 + float(k) * 1.3)
		sp.position = pos
		sp.rotation = _seg_angle[k]
		var cs := _seg_shapes[k]
		cs.position = _seg_pos[k]
		cs.rotation = _seg_angle[k]
	_arm_pivot.rotation = _head_angle
	_eye.rotation = -_head_angle # 独眼横向拉丝永远水平（头怎么转都不竖过来）


## 露出判定：体心高出地表「体高×WORM_EXPOSE_INSET」；埋着的碰撞形状关、露出的开。
func _tick_exposure() -> void:
	var best_k := -1
	var best := -INF
	for k in _seg_sprites.size():
		var wp := global_position + _seg_pos[k]
		var ground := _surface(wp.x)
		var above := wp.y < ground - _seg_half_h[k] * BalanceWorld3.WORM_EXPOSE_INSET
		_seg_exposed[k] = above
		var on := above and _hp > 0 and not _despawn_requested
		if on != _seg_shape_on[k]:
			_seg_shape_on[k] = on
			_seg_shapes[k].disabled = not on
		if above and k > 0 and ground - wp.y > best:
			best = ground - wp.y
			best_k = k
	# 索敌优先头：头露出就只认头，否则认露出的最高体节
	_target_index = 0 if _seg_exposed[0] else best_k


## 冲撞：只有冲撞态结算（且 _ram_hit 为假=开闸），一次招式至多一下。
func _tick_ram() -> void:
	if _ram_hit or not RAM_STATES.has(_bstate):
		return
	var player := _player_node()
	if player == null or player.is_dead():
		return
	var hit := false
	var pp := player.global_position
	for k in _seg_sprites.size():
		if not _seg_exposed[k]:
			continue
		var part := global_position + _seg_pos[k]
		if _bstate == ST_SWEEP:
			# 通场带：相对玩家脚下当地地表的高度带（见 _sweep_in_band）
			if absf(part.x - pp.x) <= _seg_half_len[k] + PLAYER_HALF_W and _sweep_in_band(pp):
				hit = true
				break
		else:
			var local := (pp - part).rotated(-_seg_angle[k])
			if absf(local.x) <= _seg_half_len[k] + PLAYER_HALF_W \
					and absf(local.y) <= _seg_half_h[k] + PLAYER_HALF_H:
				hit = true
				break
	if hit:
		_ram_hit = true
		player.take_damage(BalanceWorld3.WORM_RAM_DAMAGE)
		player.add_shake(BalancePlayer.PLAYER_DAMAGE_SHAKE_STRENGTH * 1.4)


## 横冲通场带：玩家碰撞中心落在「带心 ±（裸筒半高 60 + 玩家半高 24 + 余量 6）」内。
func _sweep_in_band(pp: Vector2) -> bool:
	return absf(pp.y - (_surface(pp.x) - _sweep_lane)) <= BalanceWorld3.WORM_SWEEP_BAND_HALF


## ---- 特效：潜行航迹 / 体线切地喷雪 / 穿地爆雪 ----

func _tick_fx(delta: float) -> void:
	if _wake == null:
		return
	var ground := _surface(global_position.x)
	var depth := global_position.y - ground
	var level := 0.0
	if depth >= 0.0:
		level = clampf(1.0 - (depth - BalanceWorld3.WORM_WAKE_DEPTH) / BalanceWorld3.WORM_WAKE_FADE, 0.0, 1.0)
		if _bstate == ST_WINDUP:
			level = maxf(level, 0.85)
	_wake.set_wake(level, velocity.x)
	_wake.global_position = Vector2(global_position.x, ground)
	# 沿途雪痕
	_mark_dist += absf(velocity.x) * delta
	if level > 0.35 and _mark_dist >= MARK_GAP:
		_mark_dist = 0.0
		_spawn_fx(WAKE_MARK, _wake.global_position, 0.0, 1.0)
	# 头穿地瞬间：破土/入地各一记爆雪
	var above := depth < 0.0
	if above != _head_above:
		_head_above = above
		_spawn_burst(global_position.x, above)
	# 体线切地喷雪：身体与地表的交点（任一相邻体节跨越地表）持续喷
	var cut_at := Vector2.INF
	if _bstate == ST_SWEEP:
		# 犁雪线：通场时沿露出的体节底缘轮转喷雪
		_cut_cycle = (_cut_cycle + 1) % maxi(_seg_sprites.size(), 1)
		for j in _seg_sprites.size():
			var k := (_cut_cycle + j) % _seg_sprites.size()
			if _seg_exposed[k]:
				var wx := (global_position + _seg_pos[k]).x
				cut_at = Vector2(wx, _surface(wx))
				break
	else:
		for k in range(1, _seg_sprites.size()):
			if _seg_exposed[k] != _seg_exposed[k - 1]:
				var a := global_position + _seg_pos[k - 1]
				var b := global_position + _seg_pos[k]
				var t := 0.5
				if absf(b.y - a.y) > 1.0:
					t = clampf((_surface(a.x) - a.y) / (b.y - a.y), 0.0, 1.0)
				cut_at = a.lerp(b, t)
				break
	if cut_at != Vector2.INF:
		_cut.set_wake(1.0, velocity.x)
		_cut.global_position = Vector2(cut_at.x, _surface(cut_at.x))
	else:
		_cut.set_wake(0.0, 0.0)


func _spawn_fx(scene: PackedScene, pos: Vector2, rot: float, scl: float) -> Node2D:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return null
	var fx := scene.instantiate() as Node2D
	fx.position = pos # 先定位再入树（一发粒子入树即整批出生）
	fx.rotation = rot
	fx.scale = Vector2.ONE * scl
	container.add_child(fx)
	return fx


## 破土（up=true）/入地（up=false）爆雪：喷向顺着运动（破土=沿航向喷，入地=反弹向上）。
func _spawn_burst(x: float, up: bool, scl := 1.0) -> void:
	var h := Vector2.from_angle(_heading)
	var lean := h if up else Vector2(h.x, -h.y)
	_spawn_fx(BREACH, Vector2(x, _surface(x)), lean.angle() + PI * 0.5, scl)
	Sfx.play(&"boom_enemy", 0.9 if up else 0.75)
	var player := _player_node()
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * (1.1 if up else 0.8) * scl)


## ---- 失衡钩子：父类入口原样，本类的击出在 _physics_process 里接 ----

## 失衡歪斜（Visuals 整层旋转）对链形体不成立：抽搐改在 _sync_visuals 的体节横向抖。
func _tick_tilt(_delta: float) -> void:
	pass


func _reset_warnings() -> void:
	_mouth_warn.reset()


## ---- 死亡：尾→头连锁爆，终爆接头部 ----

## 击毁演出：不调父类单体爆炸——尾→头逐节连锁爆（0.09s 一节）：露出地面的节原地爆
## （白闪起跳半径=该节墨迹面积折算，接住消失），埋着的节在地表炸开一记小喷雪；
## BOSS_DEATH_FINALE_TIME 终爆接头部、本体同帧清（Main 同一时刻爆装备）。
func _explode() -> void:
	if _death_played:
		return
	_death_played = true
	_shots_left = 0
	_release_mound()
	_remove_stun()
	if _wake != null:
		_wake.set_wake(0.0, 0.0)
	if _cut != null:
		_cut.set_wake(0.0, 0.0)
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud != null:
		hud.hide_boss()
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		get_tree().create_timer(BalanceCombat.BOSS_DEATH_FINALE_TIME).timeout.connect(queue_free)
		return
	var last := _seg_sprites.size() - 1
	for k in range(last, 0, -1):
		get_tree().create_timer(0.08 * float(last - k)).timeout.connect(_blow_segment.bind(k))
	var player := _player_node()
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH)
		player.apply_hitstop(BalanceCombat.KILL_HITSTOP_TIME, BalanceCombat.KILL_HITSTOP_SCALE)
	get_tree().create_timer(BalanceCombat.BOSS_DEATH_FINALE_TIME).timeout.connect(func() -> void:
		if is_instance_valid(container):
			_spawn_death_finale(container)
		queue_free())


func _blow_segment(k: int) -> void:
	var sp := _seg_sprites[k]
	var pos := global_position + _seg_pos[k]
	var exposed := _seg_exposed[k]
	sp.visible = false
	_seg_shapes[k].disabled = true
	if exposed:
		var boom := EXPLOSION.instantiate() as ExplosionBurst
		boom.scale = Vector2(1.2, 1.2)
		boom.cover_radius = ExplosionBurst.area_cover_radius(
				ExplosionBurst.sprite_area(sp)) / boom.scale.x
		boom.position = pos
		get_tree().get_first_node_in_group("projectile_container").add_child(boom)
	else:
		_spawn_fx(BREACH, Vector2(pos.x, _surface(pos.x)), 0.0, 0.55) # 埋着的节：地表炸开一记（向上喷）
	Sfx.play(&"boom_enemy", 0.8)


## 终爆只接头部（身体已被连锁爆逐节接走）：白闪起跳半径=头部墨迹面积折算。
func _spawn_death_finale(container: Node) -> void:
	var fin := EXPLOSION.instantiate() as ExplosionBurst
	fin.scale = Vector2.ONE * BalanceCombat.BOSS_DEATH_FINALE_SCALE
	fin.cover_radius = ExplosionBurst.area_cover_radius(
			ExplosionBurst.sprite_area(_head_sprite)) / fin.scale.x
	fin.position = global_position
	container.add_child(fin)
	Sfx.play(&"boom_enemy")
	var player := _player_node()
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 1.5)
