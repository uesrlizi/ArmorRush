class_name PursuitBoss
extends Enemy
## 追击 BOSS 公共框架——从 ch1 直升机 boss.gd 的走位/节奏层提炼。ch1 本体**不迁移**
## （仍独立 extends Enemy：已调稳的行为不为 DRY 冒回归险），章节 BOSS（现：第二章
## 悬浮冶炼驳船 boss_barge.gd）继承本类，只写能力层。框架内容（数值沿用 BOSS_* 公共段）：
##   走位：水平=放松弹簧构图位（BOSS_MOVE_STIFFNESS，满速倒退甩出画面右缘、
##     出画不停攻、推进反向压近）；竖直=悬浮锚（_hover_anchor_y 覆写）+呼吸浮动；
##   节奏：技能⇄普攻直射交替——_dispatch_next 轮换 skill_a→直射→skill_b→直射…，
##     动作之间只隔各自后摇（_enter_recover，二阶段 ×BOSS_PHASE2_RECOVER_SCALE），
##     入场到位即出第一手；
##   贴脸压招：离玩家水平距 < BOSS_ATTACK_MIN_DISTANCE 冻结出招（硬直贪刀后的
##     脱身反应窗），弹回安全距离重开，断在预警里的招由 _rewarn_after_hold 重走；
##   失衡：冲击打满→停摆+瘫沉（HUD 失衡条换源当硬直计时器）+受伤加深；
##   免击退/零重力（高度自管）/永不走左缘回收/死亡连爆演出+收血条。
## 状态机骨架：基类只认 ST_ENTER/ST_RECOVER，能力状态由子类自行编号。

const ST_ENTER := 0
const ST_RECOVER := 1

var _vel := Vector2.ZERO # 自管速度（水平喂 _control_vx、竖直喂 velocity.y，物理出口积分）
var _bstate := ST_ENTER
var _bt := 0.0
var _phase2 := false
var _death_played := false
var _hold_fire := false   # 贴脸压招中：攻击节拍冻结，弹回安全距离重开
var _next_direct := false # 下一段=普攻直射（技能后必插一段）
var _skill_flip := false  # 技能轮换旗标：a→b→a…


func _species_score() -> int:
	return BalanceCombat.BOSS_SCORE


func _defense() -> int:
	return BalanceCombat.BOSS_DEFENSE


func _hover_anchor_y() -> float:
	return BalanceCombat.BOSS_HOVER_Y # 默认 ch1 悬浮锚；子类覆写（驳船=BARGE_HOVER_Y）


## RUSH 终局血量打折（未经精英预教，run_loop.md §1；开关在 BalanceGlobal）。
## 二至七章 BOSS 全线继承本类，一处覆写全含。
func _rush_discount() -> bool:
	return true


## 难度阶梯体量增长资格（血量+失衡阈值，run_loop.md §3）：章 BOSS 全开。
func _ladder_scaling() -> bool:
	return true


func on_spawned() -> void:
	super()
	add_to_group("boss")
	_bstate = ST_ENTER
	_bt = BalanceCombat.BOSS_ENTER_TIME
	_vel = Vector2.ZERO
	_next_direct = false
	_skill_flip = false
	_hold_fire = false
	_phase2 = false
	_bob_t = randf() * TAU
	global_position.y = _hover_anchor_y()
	_reset_warnings() # 池化复用/预警中死亡的残光兜底
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
				_hover_anchor_y() + BalanceCombat.BOSS_STAGGER_SINK, 60.0 * delta)
		return
	_bob_t += delta
	_tick_visual(delta) # 子类挂件动画（旋翼等），默认空
	_tick_vertical(delta)
	_tick_screen_lock(delta)
	# 玩家已毁（结算后世界不冻结）：压招判定作废（不再为贴脸冻结出招、也不重走
	# 预警），正在放的招照常推进到收势；后摇到点 _dispatch_next 不再派新招=悬停待机。
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


## 高度控制：比例期望速度 + 加速度限制，锚到悬浮锚（子类可按状态改锚，如 ch1
## 直升机的扫射压高——它未迁移，仍用自己的覆写版）。只定 velocity.y，积分在
## 父类移动出口（重力已覆写 0）。
func _tick_vertical(delta: float) -> void:
	var bob := sin(_bob_t * BalanceCombat.BOSS_BOB_SPEED) * BalanceCombat.BOSS_BOB_AMPLITUDE
	var desired := clampf(
			(_hover_anchor_y() + bob - global_position.y) * BalanceCombat.BOSS_ANCHOR_STIFFNESS,
			-BalanceCombat.BOSS_VERT_MAX_SPEED, BalanceCombat.BOSS_VERT_MAX_SPEED)
	_vel.y = move_toward(_vel.y, desired, BalanceCombat.BOSS_VERT_ACCEL * delta)
	velocity.y = _vel.y


## 横向：全程构图位锚定。玩家死亡冻在原地，BOSS 减速滑停，震屏抖不进来。
func _tick_screen_lock(delta: float) -> void:
	var anchor_x := _anchor_x()
	if _bstate == ST_ENTER:
		# 入场：从画面外加速滑向锚点，到位（或兜底到时）进战斗循环
		#（入场吃纵向那档硬增益，滑入要利落，不跟水平弹簧一起放松）
		_accel_x(anchor_x, BalanceCombat.BOSS_ENTER_SPEED, delta, BalanceCombat.BOSS_ANCHOR_STIFFNESS)
		_bt -= delta
		if _bt <= 0.0 or absf(global_position.x - anchor_x) < 8.0:
			_vel.x = minf(_vel.x, BalanceCombat.BOSS_MOVE_MAX_SPEED) # 收敛到巡航档
			_dispatch_next() # 入场即出招
		return
	# 贴脸压招期：回正移速乘 retreat 倍率——出招被冻结的另一半惩罚是弹簧超速
	# 弹回安全距离（ch5 俯冲覆写只在俯冲态绕过本函数，非俯冲态照吃提速）
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


## 出下一手：技能与普攻直射交替——技能之后必插一段直射，直射把下一段还给
## 技能轮换（skill_a→直射→skill_b→直射…）。各动作后摇到点就调这里。
## 玩家已毁（结算后世界不冻结）：不再派下一手，停在后摇里随构图位悬停待机——
## 正在放的招照常放完、各自收势进后摇（不硬切状态，挂件/预警自然收尾）；
## 入场途中阵亡的同理，到位即转待机。
func _dispatch_next() -> void:
	if _player_down():
		_bstate = ST_RECOVER
		_bt = 0.0
		return
	if _next_direct:
		_next_direct = false
		_begin_direct()
	else:
		_next_direct = true
		_skill_flip = not _skill_flip
		if _skill_flip:
			_begin_skill_a()
		else:
			_begin_skill_b()


func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		_bt -= delta
		if _bt <= 0.0:
			_dispatch_next()


## 动作收势：各招自己的后摇（二阶段按比例缩短，再乘难度阶梯的关序缩放——
## 阶梯只管 BOSS 出招密度，run_loop.md §3），到点直接出下一手。
func _enter_recover(base: float) -> void:
	_bstate = ST_RECOVER
	_bt = base * RunState.ladder_recover_factor() \
			* (BalanceCombat.BOSS_PHASE2_RECOVER_SCALE if _phase2 else 1.0)


func take_damage(amount: int, ignore_defense: bool = false) -> void:
	super(amount, ignore_defense)
	if _hp > 0 and not _phase2 and hp_ratio() <= BalanceCombat.BOSS_PHASE2_RATIO:
		_phase2 = true


## 巨物免疫击退：位置完全自管（锚点吸附），冲量没有出口。
func apply_knockback(_impulse: Vector2) -> void:
	pass


## 高度自管（悬浮锚），不吃重力积分。
func _gravity() -> float:
	return 0.0


## 追击体永不走镜头左缘回收：位置自管，甩脱了追回来即可（同 ch1 boss.gd 的
## 木桩 bug 防线：被左缘判定闩上 _despawn_requested 就会冻成木桩）。
func is_past_left_edge() -> bool:
	return false


## 右缘回收闸同此防线（同 boss.gd）：满速倒退甩出画面是追击演出的一部分，
## 按出画清场会把遭遇战清没（还会闩上 _despawn_requested 冻成木桩）。
func _despawn_past_right() -> bool:
	return false


func _impact_resistance() -> float:
	return BalanceCombat.IMPACT_RESIST_BOSS * RunState.ladder_growth_factor()


func _stagger_time() -> float:
	return BalanceCombat.STAGGER_TIME_BOSS


func _stagger_key() -> StringName:
	return &"stagger_boss"


func _stagger_immunity() -> float:
	return BalanceCombat.STAGGER_IMMUNITY_BOSS


## ---- 能力层钩子：子类覆写 ----

## 血条上方显示的机体名（哨兵/钢嵴/鮟鱇/断云/赤轮…；§0b「单位名写在血条」）。
func _display_name() -> String:
	return "未登记大型机"


func _begin_skill_a() -> void:
	pass


func _begin_skill_b() -> void:
	pass


func _begin_direct() -> void:
	pass


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	pass


func _reset_warnings() -> void:
	pass


## 子类挂件动画（旋翼/涡轮等），逐物理帧调。
func _tick_visual(_delta: float) -> void:
	pass


## 击退演出：父类单体爆炸照播，再补一串错峰爆炸 + 收血条，1.4s 后自清。
## （本章通关的转场由 Main 监听 Spawner.boss_defeated 排程。）
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
