class_name Boss
extends Enemy
## 追击大型机（占位方块）：水平弹簧构图位与玩家同行——跑酷不断、镜头不接管，
## BOSS 是"追击段落"不是关卡。技能=扫射/弹雨轮换，技能之间各插一段普攻直射，
## 预警只在发射器上（枪口预警闪光，ThreatFlash，不给精灵染色），无虚空区域标记：
##   高位扫射：机体真的机动到射高（本体压下来就是预警）→ 枪口闪一下 → 机枪流
##     （小散布角扫成扇面），惩罚滞空（射高在最高地形站立头顶之上，贴地/起跳安全）；
##   导弹雨：背部导弹舱闪一下 → 真追踪导弹齐射（从舱口逐孔出膛、追脚底、
##     过冲锁向、撞地爆、球状爆伤），惩罚贴地（必须飞起来拉开爆炸球半径）；
##   普攻直射：同一把机枪换瞄准——枪臂真瞄玩家（无预判）朝人扫一短梭，跑动/起跳
##     即躲。无重击警告：枪臂全程真瞄，瞄准本身就是预警。机枪就一把：子弹永远真从
##     枪口出膛，招式之间只有瞄准方向与射击时长不同。枪口姿态随招式：高扫三态放平
##     （弹流是水平的），直射时枪口朝人。导弹与机枪彻底分家：VLS 仓口在背部
##     （4 孔=一轮弹数 1:1，逐孔轮发），预警闪光也钉在导弹舱上不占机枪口。
## 走位（水平=放松的弹簧，BOSS_MOVE_STIFFNESS）：推进把 BOSS 压近构图位内侧，
## 倒退把它甩出画面右缘（出画不打断出招，子弹照常飞），站定它自己踱回画内；
## 冲刺 900 > 机动上限 700，出招间隙硬追能破防贴脸。
## 节奏：技能（扫射/弹雨）与普攻直射交替，动作之间只隔各自后摇
## （BalanceWorld1.BOSS_*_RECOVER，到点直接出下一手，无独立间歇）；
## 离玩家水平距小于 BOSS_ATTACK_MIN_DISTANCE 时压住不出招——硬直贪刀后的
## 脱身反应窗：弹簧把 BOSS 弹回距离，回到位才重新出手，断在预警里的招重走完整预警。
## 移动是真物理：速度+加速度+比例趋近，无坐标瞬移/吸附；积分全部走
## Enemy 的移动出口合流（水平经 _control_vx、竖直经 velocity.y，重力已覆写 0），
## BOSS 自己不动 global_position。实时速度经 velocity 暴露——玩家子弹预判瞄准生效。
## 锚点从玩家位置直算（不经 Camera2D）：镜头震动走 offset，玩家死亡的震屏
## 不会喂进锚点把 BOSS 抽得瞬移（踩过）。
## 无 BlockingBody：近战突进可切进机体（占位期简化，不做推挤）。
## 数值全在 BalanceWorld1.BOSS_*；重击公共规约见 Balance 重击段。

enum BState { ENTER, SWEEP_MOVE, SWEEP_AIM, SWEEP_FIRE, RAIN_WARN, RAIN_FIRE, DIRECT_FIRE, RECOVER }
enum Attack { SWEEP, RAIN, DIRECT }
# ENEMY_BULLET / EXPLOSION / _bob_t 直接继承 Enemy 的同名成员，不重复声明

var _vel := Vector2.ZERO # BOSS 自管速度（水平喂 _control_vx、竖直喂 velocity.y，物理出口积分）
var _bstate := BState.ENTER
var _bt := 0.0
var _launch_t := 0.0 # RAIN_FIRE 期的导弹出膛节拍
var _next_attack := Attack.SWEEP # 下一段出招：技能与普攻直射交替
var _next_skill := Attack.RAIN   # 下一个技能：扫射⇄弹雨轮换（直射降为普攻不占轮）
var _hold_fire := false          # 贴脸压招中：攻击节拍冻结，弹回安全距离重开
var _sweep_shoot_t := 0.0   # 机枪发弹节拍
var _sweep_twin_next := false # 二阶段双机枪：上下枪口交替
var _rain_launched := 0
var _phase2 := false
var _death_played := false

@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash
@onready var _rain_warn: ThreatFlash = $Visuals/MissileWarn/ThreatFlash
@onready var _ports: Node2D = $Visuals/MissilePorts
@onready var _rotor: Sprite2D = $Visuals/Rotor
@onready var _tail_rotor: Sprite2D = $Visuals/TailRotor


## 血条上方显示的机体名（§8 索引名 dreadnought 只作文档键，不上屏）。
func _display_name() -> String:
	return "无畏"


func _species_max_hp() -> int:
	return BalanceCombat.BOSS_MAX_HP


## RUSH 终局血量打折（未经精英预教，run_loop.md §1；开关在 BalanceGlobal）。
func _rush_discount() -> bool:
	return true


## 难度阶梯体量增长资格（血量+失衡阈值，run_loop.md §3）：章 BOSS 全开。
func _ladder_scaling() -> bool:
	return true


func _species_score() -> int:
	return BalanceCombat.BOSS_SCORE


func _defense() -> int:
	return BalanceCombat.BOSS_DEFENSE


func _hover_height() -> float:
	return 0.0 # 悬浮高度走绝对锚（HOVER_Y/SWEEP_Y，不随地形成台阶跳变），不用 Enemy 的贴地抬升


func on_spawned() -> void:
	super()
	add_to_group("boss")
	_bstate = BState.ENTER
	_bt = BalanceCombat.BOSS_ENTER_TIME
	_next_attack = Attack.SWEEP
	_next_skill = Attack.RAIN
	_hold_fire = false
	_phase2 = false
	_vel = Vector2.ZERO
	_bob_t = randf() * TAU
	global_position.y = BalanceCombat.BOSS_HOVER_Y
	_warn.reset() # 池化复用/预警中死亡的残光兜底
	_rain_warn.reset()
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud != null:
		hud.flash_warning()
		hud.show_boss(_display_name())


## 父类 AI 两层整体替换：不走踱步层、不打机枪层（瞄准/朝向/浮动照旧）。
func _tick_move(_delta: float) -> void:
	pass


func _tick_fire(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	super(delta) # 瞄准玩家/镜像/失衡物理照旧
	if _despawn_requested or _hp <= 0:
		return
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud != null:
		hud.set_boss_hp(hp_ratio())
		# 失衡期冲击条改读硬直剩余：匀速排空=硬直计时器（失衡条从中心向两边收缩）
		hud.set_boss_impact(_stagger_t / _stagger_time() if is_staggered()
				else impact_ratio())
	if is_staggered():
		# 失衡硬直：出招/跟随全停，原地缓慢瘫沉——位置留给玩家的近战爆发窗
		_vel = Vector2.ZERO
		_control_vx = 0.0
		velocity = Vector2.ZERO
		global_position.y = move_toward(global_position.y,
				BalanceCombat.BOSS_HOVER_Y + BalanceCombat.BOSS_STAGGER_SINK, 60.0 * delta)
		return
	_bob_t += delta
	# 旋翼常转：主旋翼侧视是刃边只做呼吸摆动，尾桨盘平行屏幕整周旋转；
	# 失衡/死亡演出期间也照转（直升机没熄火）。
	_rotor.rotation = sin(_bob_t * BalanceCombat.BOSS_ROTOR_WOBBLE_SPEED) \
			* BalanceCombat.BOSS_ROTOR_WOBBLE
	_tail_rotor.rotation += BalanceCombat.BOSS_ROTOR_SPIN * delta
	# 高扫三态枪口放平（弹流是水平的，枪也摆平——画布空间本地角，换边不用管）；
	# 其余状态父类照旧瞄玩家——直射时"枪口朝人"本身就是预警。
	# 枪臂/旋翼/导弹舱/舱口预警的挂点镜像全部由 Visuals 一层承担，零补镜像。
	if _bstate in [BState.SWEEP_MOVE, BState.SWEEP_AIM, BState.SWEEP_FIRE]:
		_arm_pivot.rotation = 0.0
	_tick_vertical(delta)
	_tick_screen_lock(delta)
	# 玩家已毁（结算后世界不冻结）：压招判定作废（不再为贴脸冻结出招、也不重走
	# 预警），正在放的招照常推进到收势；后摇到点 _dispatch_next 不再派新招=悬停
	# 待机（旋翼照转=没熄火）。
	if _player_down():
		_hold_fire = false
		_tick_attack(delta)
		return
	# 贴脸压招：离玩家过近整段冻结出招（含硬直刚结束的贪刀窗）——弹簧把
	# BOSS 弹回安全距离，回到位才重新出手；断在预警里的招重走完整预警
	var close := _player_too_close()
	if close != _hold_fire:
		_hold_fire = close
		if not close:
			_rewarn_after_hold()
	if not _hold_fire:
		_tick_attack(delta)


## 高度控制：扫射三态机体压到射高（本体机动=扫射的预警），其余回悬浮锚。
## 比例期望速度 + 加速度限制；只定 velocity.y，积分在父类移动出口（重力已覆写 0）。
func _tick_vertical(delta: float) -> void:
	var sweeping := _bstate in [BState.SWEEP_MOVE, BState.SWEEP_AIM, BState.SWEEP_FIRE]
	var base_y := BalanceWorld1.BOSS_SWEEP_Y if sweeping else BalanceCombat.BOSS_HOVER_Y
	var bob := sin(_bob_t * BalanceCombat.BOSS_BOB_SPEED) * BalanceCombat.BOSS_BOB_AMPLITUDE
	var desired := clampf(
			(base_y + bob - global_position.y) * BalanceCombat.BOSS_ANCHOR_STIFFNESS,
			-BalanceCombat.BOSS_VERT_MAX_SPEED, BalanceCombat.BOSS_VERT_MAX_SPEED)
	_vel.y = move_toward(_vel.y, desired, BalanceCombat.BOSS_VERT_ACCEL * delta)
	velocity.y = _vel.y


## 横向：全程构图位锚定（含扫射三态——扫射只变高度，水平照旧钉构图位）。
##（玩家死亡冻在原地，BOSS 减速滑停，震屏抖不进来。）
func _tick_screen_lock(delta: float) -> void:
	var anchor_x := _anchor_x()
	if _bstate == BState.ENTER:
		# 入场：从画面外加速滑向锚点，到位（或兜底到时）进战斗循环
		#（入场吃纵向那档硬增益，滑入要利落，不跟水平弹簧一起放松）
		_accel_x(anchor_x, BalanceCombat.BOSS_ENTER_SPEED, delta, BalanceCombat.BOSS_ANCHOR_STIFFNESS)
		_bt -= delta
		if _bt <= 0.0 or absf(global_position.x - anchor_x) < 8.0:
			_vel.x = minf(_vel.x, BalanceCombat.BOSS_MOVE_MAX_SPEED) # 收敛到巡航档
			_dispatch_next() # 入场即出招（扫射自带压高+蓄力预警，无需另给间歇）
		return
	# 贴脸压招期：回正移速乘 retreat 倍率——出招被冻结的另一半惩罚是弹簧超速
	# 弹回安全距离（扫射三态只压高度，水平照吃提速）
	var cruise := BalanceCombat.BOSS_MOVE_MAX_SPEED
	if _player_too_close():
		cruise *= BalanceCombat.BOSS_RETREAT_SPEED_MULT
	_accel_x(anchor_x, cruise, delta, BalanceCombat.BOSS_MOVE_STIFFNESS)


## 锚点世界 x：玩家 + 镜头偏移 + 屏幕锚（绕开 Camera2D.offset——震屏走
## offset，喂进锚点会让 BOSS 在玩家死亡瞬间跟着瞬移抽动）。
func _anchor_x() -> float:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		return player.global_position.x + BalanceGlobal.CAMERA_X_OFFSET \
				+ BalanceCombat.BOSS_SCREEN_ANCHOR
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		return cam.get_screen_center_position().x + BalanceCombat.BOSS_SCREEN_ANCHOR
	return global_position.x


## 比例期望速度（饱和 max_speed）+ 加速度趋近目标 x；只定 _control_vx，
## 积分在父类移动出口（velocity.x = _control_vx + 击退[免疫=0] → move_and_slide）。
## 劲度由调用方给：入场=硬增益滑到位，战斗=放松的水平弹簧（甩得脱、踱得回）。
func _accel_x(target_x: float, max_speed: float, delta: float, stiffness: float) -> void:
	var desired := clampf(
			(target_x - global_position.x) * stiffness,
			-max_speed, max_speed)
	_vel.x = move_toward(_vel.x, desired, BalanceCombat.BOSS_MOVE_ACCEL * delta)
	_control_vx = _vel.x


## 贴脸判定：与玩家水平距离小于 BOSS_ATTACK_MIN_DISTANCE。
func _player_too_close() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return false
	return absf(player.global_position.x - global_position.x) \
			< BalanceCombat.BOSS_ATTACK_MIN_DISTANCE


## 压招期间断掉的预警，回距重走完整程——预警只认枪口，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		BState.SWEEP_AIM:
			_bt = BalanceWorld1.BOSS_SWEEP_AIM_TIME
			_warn.warn()
		BState.RAIN_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_rain_warn.warn()
		_:
			pass


## 出下一手：技能与普攻直射由 _next_attack 交替、技能内部 _next_skill 轮换。
## 各动作后摇（RECOVER）一到点就调这里——动作之间只隔后摇，没有独立间歇。
## 玩家已毁（结算后世界不冻结）：不再派下一手，停在后摇里悬停待机——正在放的
## 招照常放完、各自收势进后摇（不硬切状态，挂件/预警自然收尾）。
func _dispatch_next() -> void:
	if _player_down():
		_bstate = BState.RECOVER
		_bt = 0.0
		return
	match _next_attack:
		Attack.SWEEP:
			_begin_sweep()
		Attack.RAIN:
			_begin_rain()
		Attack.DIRECT:
			_begin_direct()


func _tick_attack(delta: float) -> void:
	match _bstate:
		BState.SWEEP_MOVE:
			# 压向射高：位置到位且竖直速度收敛（或兜底超时）即进入枪口蓄力
			_bt -= delta
			var bob := sin(_bob_t * BalanceCombat.BOSS_BOB_SPEED) * BalanceCombat.BOSS_BOB_AMPLITUDE
			if (absf(global_position.y - (BalanceWorld1.BOSS_SWEEP_Y + bob)) < 8.0
					and absf(_vel.y) < 50.0) or _bt <= 0.0:
				_bstate = BState.SWEEP_AIM
				_bt = BalanceWorld1.BOSS_SWEEP_AIM_TIME
				_warn.warn() # 预警统一入口：枪口闪光 + 警告音（开火节拍另行倒数）
		BState.SWEEP_AIM:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = BState.SWEEP_FIRE
				_bt = BalanceWorld1.BOSS_SWEEP_DURATION_P2 if _phase2 \
						else BalanceWorld1.BOSS_SWEEP_DURATION
				_sweep_shoot_t = 0.0
				_sweep_twin_next = false
		BState.SWEEP_FIRE:
			_bt -= delta
			_sweep_shoot_t -= delta
			if _sweep_shoot_t <= 0.0:
				_fire_gun_shot(Vector2(-1.0, 0.0).rotated(deg_to_rad(
						randf_range(-BalanceWorld1.BOSS_SWEEP_SPREAD_DEG,
						BalanceWorld1.BOSS_SWEEP_SPREAD_DEG)))) # 水平弹流自扫成扇面
				_sweep_shoot_t = BalanceCombat.BOSS_SWEEP_FIRE_INTERVAL
			if _bt <= 0.0:
				_enter_recover(BalanceWorld1.BOSS_SWEEP_RECOVER)
		BState.RAIN_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = BState.RAIN_FIRE
				_rain_launched = 0
				_launch_t = 0.0
				_bt = BalanceCombat.HEAVY_MISSILE_TRACK_MAX + 0.8 # 全部出膛+追踪窗口
		BState.RAIN_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld1.BOSS_RAIN_RECOVER)
		BState.DIRECT_FIRE:
			_bt -= delta
			_sweep_shoot_t -= delta
			if _sweep_shoot_t <= 0.0:
				var player := get_tree().get_first_node_in_group("player") as Player
				if player != null:
					_fire_gun_shot(_muzzle.global_position.direction_to(
							player.global_position)) # 直瞄：枪口→玩家当前位置
				_sweep_shoot_t = BalanceCombat.BOSS_SWEEP_FIRE_INTERVAL
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)
		BState.RECOVER:
			_bt -= delta
			if _bt <= 0.0:
				_dispatch_next()
		BState.ENTER:
			pass


## 动作收势：各招自己的后摇（二阶段按比例缩短，再乘难度阶梯的关序缩放——
## 阶梯只管 BOSS 出招密度，run_loop.md §3），到点直接出下一手。
func _enter_recover(base: float) -> void:
	_bstate = BState.RECOVER
	_bt = base * RunState.ladder_recover_factor() \
			* (BalanceCombat.BOSS_PHASE2_RECOVER_SCALE if _phase2 else 1.0)


func _begin_sweep() -> void:
	_next_attack = Attack.DIRECT # 技能之后必插一段普攻直射
	_next_skill = Attack.RAIN
	_bstate = BState.SWEEP_MOVE
	_bt = 1.5 # 到位判定带速度收敛条件，这是防卡兜底（物理压高 ~1.2s）


func _begin_rain() -> void:
	_next_attack = Attack.DIRECT
	_next_skill = Attack.SWEEP
	_bstate = BState.RAIN_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_rain_warn.warn() # 预警统一入口：导弹舱闪光 + 警告音（机枪口留给扫射）


## 普攻直射：无重击警告（枪臂全程真瞄玩家，瞄准本身就是预警），进场即开火，
## 短梭即收；下一段还给技能轮换。
func _begin_direct() -> void:
	_next_attack = _next_skill
	_bstate = BState.DIRECT_FIRE
	_bt = BalanceCombat.BOSS_DIRECT_DURATION
	_sweep_shoot_t = 0.0 # 首发即出


## 机枪单发（唯一开火出口）：子弹真从枪口出膛，方向由招式给——
## 高扫=水平+散布，直射=枪口→玩家。二阶段双机枪：上下枪口交替出弹，
## 节奏不变、密度翻倍。
func _fire_gun_shot(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var gun_y := 0.0
	if _phase2:
		gun_y = BalanceWorld1.BOSS_SWEEP_TWIN_OFFSET * (1.0 if _sweep_twin_next else -1.0)
		_sweep_twin_next = not _sweep_twin_next
	var b := ENEMY_BULLET.instantiate() as Bullet
	b.speed = BalanceCombat.BOSS_SWEEP_SPEED
	b.damage = BalanceCombat.BOSS_SWEEP_DAMAGE
	b.impact_tint = Color(1.0, 0.32, 0.25)
	b.setup(dir, Vector2.ZERO) # 所见即弹道
	container.add_child(b)
	b.global_position = _muzzle.global_position + Vector2(0.0, gun_y)
	b.reset_physics_interpolation()
	Sfx.play(&"fire_enemy")


## RAIN_FIRE 期发射节拍：蓄力结束首发即出，此后按 STAGGER 陆续出膛。
func _launch_ticker(delta: float) -> void:
	if _rain_launched >= _rain_count():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var ports := _ports.get_children()
	# 逐孔轮发：前舱→后舱顺序出膛（4 孔=一轮 1:1，二阶段 +2 回绕复用前孔）；
	# 垂发姿态：近乎竖直、朝玩家一侧微倾 ±扇面——此向量即炮口朝向，弹体姿态
	# 沿它不动；动量继承 BOSS 速度（_vel）——后退带得动弹，姿态不会"朝后飞"；
	# 拱顶与追踪由导弹自理
	var from := (ports[_rain_launched % ports.size()] as Node2D).global_position
	var lean := signf(player.global_position.x - from.x)
	var dir := (Vector2.UP + Vector2(0.28 * lean, 0.0)).normalized()
	dir = dir.rotated(deg_to_rad(randf_range(-BalanceCombat.HEAVY_MISSILE_SPREAD_DEG,
			BalanceCombat.HEAVY_MISSILE_SPREAD_DEG)))
	var missile := HeavyMissile.new()
	missile.damage = BalanceWorld1.BOSS_RAIN_DAMAGE
	missile.blast_radius = BalanceWorld1.BOSS_RAIN_BLAST_RADIUS
	container.add_child(missile)
	missile.launch(terrain, from, dir, true, _vel)
	_rain_launched += 1
	_launch_t = BalanceWorld1.BOSS_RAIN_STAGGER
	Sfx.play(&"fire_enemy") # 占位发射声（暂用敌枪声，导弹音效后续单独配方）


func _rain_count() -> int:
	return BalanceWorld1.BOSS_RAIN_COUNT \
			+ (BalanceWorld1.BOSS_PHASE2_RAIN_BONUS if _phase2 else 0) \
			+ RunState.ladder_bullets_extra()


func take_damage(amount: int, ignore_defense: bool = false) -> void:
	super(amount, ignore_defense)
	if _hp > 0 and not _phase2 and hp_ratio() <= BalanceCombat.BOSS_PHASE2_RATIO:
		_phase2 = true


## 巨物免疫击退：位置完全自管（锚点吸附/扫射机动），冲量没有出口。
func apply_knockback(_impulse: Vector2) -> void:
	pass


## 高度自管（悬浮 + 扫射机动），不吃重力积分。
func _gravity() -> float:
	return 0.0


## 追击体永不走镜头左缘回收：位置自管，甩脱了追回来即可；且本机非池化、
## despawned 无人监听（Spawner 只接 killed），一旦被左缘判定闩上
## _despawn_requested 就会冻成木桩——_physics_process 在 HUD 刷新前提前
## return，移动/出招/血条全部停格但照样挨打。
func is_past_left_edge() -> bool:
	return false


## 右缘回收闸同此防线：满速倒退甩出画面是追击演出的一部分，按出画清场
## 会把遭遇战清没（还会闩上 _despawn_requested 冻成木桩）。
func _despawn_past_right() -> bool:
	return false


## 失衡（AC6 式冲击/STAGGER）：枪弹持续命中 ≈4s 打满上限即瘫——
## 停摆+受伤加深+瘫沉，这就是近战爆发窗（枪射攒失衡→砍的正式循环）。
func _impact_resistance() -> float:
	return BalanceCombat.IMPACT_RESIST_BOSS * RunState.ladder_growth_factor()


func _stagger_time() -> float:
	return BalanceCombat.STAGGER_TIME_BOSS


func _stagger_key() -> StringName:
	return &"stagger_boss"


func _stagger_immunity() -> float:
	return BalanceCombat.STAGGER_IMMUNITY_BOSS


## 击退演出：父类单体爆炸照播，再补一串错峰爆炸 + 收血条，1.4s 后自清。
## （本章通关的转场由 Main 监听 Spawner.boss_defeated 排程：延迟→黑场→下一章，
## 玩家满血来自新章的全新实例——原"击败回血"随章节机制废除。）
func _explode() -> void:
	super()
	if _death_played:
		return
	_death_played = true
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud != null:
		hud.hide_boss()
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		for i in 5:
			var boom := EXPLOSION.instantiate() as Node2D
			boom.scale = Vector2(1.2, 1.2)
			get_tree().create_timer(0.18 * i).timeout.connect(func() -> void:
				if not is_instance_valid(container):
					return
				boom.position = global_position + Vector2(
						randf_range(-120.0, 120.0), randf_range(-70.0, 70.0))
				container.add_child(boom)
				Sfx.play(&"boom_enemy")
			)
	get_tree().create_timer(1.4).timeout.connect(queue_free)
