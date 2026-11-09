extends Node
## 开发自测：带 --autotest 参数启动时模拟输入跑一段，
## 分时截图到 autotest_shots/ 并打印状态，然后自动退出。
## 正常启动时（无参数）本节点自删，不参与游戏。

const SHOTS_DIR := "autotest_shots"


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--autotest"):
		queue_free()
		return
	if _editor_online():
		printerr("[autotest] 检测到 Godot 编辑器在线，拒绝开跑：并发实例会重写 "
				+ ".godot/imported 的内存映射页，编辑器会被顶崩。请先关闭编辑器。")
		get_tree().quit()
		return
	RunState.hold_chapter = true # 探针需要世界原地活着：击败 BOSS 不触发章末黑场
	# 疾驰倍率冻结（run_loop.md §2）：探针一路杀怪会攒倍率→刷怪密度乘区跟着变，
	# 各段刷怪节奏漂移；冻结闸让涨/扣全停、乘区恒 1，探针照旧确定性。
	RunState.mult_frozen = true
	# 装备掉落冻结（run_loop.md §4，§6「autotest 不碰 mods」）：hold_chapter 已让击败
	# BOSS 不走掉落分支，这里再闸一道——满血还原/弹种按伤害值分辨等断言都按出厂账写。
	RunState.loot_frozen = true
	_run()


## 编辑器在线检测：枚举 godot* 进程的命令行，凡不带无头/自测参数的都是编辑器
## （2026-10-16"编辑器总被杀"的代码级防线）。powershell 缺失/查询失败时静默
## 放行——兜底仍是"跑任何无头命令前先 tasklist 查编辑器"的人工规矩。
func _editor_online() -> bool:
	if not OS.has_feature("windows"):
		return false
	var out: PackedStringArray = []
	OS.execute("powershell", ["-NoProfile", "-Command",
		"Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'godot*'} "
		+ "| ForEach-Object { \"$($_.ProcessId)|$($_.CommandLine)\" }"], out, true)
	var self_pid := OS.get_process_id()
	for line in out:
		var l := str(line).strip_edges()
		if l.find("|") < 0:
			continue
		if int(l.get_slice("|", 0)) == self_pid:
			continue
		var cmd := l.get_slice("|", 1).to_lower()
		if cmd.contains("--headless") or cmd.contains("--quit-after") \
				or cmd.contains("--autotest"):
			continue
		return true
	return false


func _run() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(SHOTS_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var spawner: Spawner = get_parent().get_node("Spawner")
	var player: Player = get_tree().get_first_node_in_group("player")
	player.auto_fire = false # 探针默认关枪：开火全自动后枪会自己响（精英要活着等齐射、BOSS 别被
	                         # 攒失衡）；要开火的段（04 走射 / 04a 枪口焰 / 06d 自动开火）临时开闸，用完关回。

	# 开机亮屏：首启也从全黑渐亮（0.2s 时约半亮），先截中间帧再走启动页探针。
	# 黑屏在全局 Fade autoload 层：场景重载的空档帧它仍全盖着，不闪清屏色。
	await _wait(0.2)
	await _screenshot("00a_boot.png")
	print("[autotest] boot fade alpha=", Fade._rect.modulate.a,
			" (全局转场层渐亮中应≈0.3~0.6, visible=", Fade._rect.visible, ")")
	var cam: Camera2D = player.get_node("Camera2D")
	var cam_target := Vector2(player.global_position.x + BalanceGlobal.CAMERA_X_OFFSET,
			BalanceGlobal.CAMERA_Y)
	print("[autotest] boot camera center=", cam.get_screen_center_position(),
			" target=", cam_target,
			" (开机即位应重合，偏差<1px=无平滑滑入)")

	# 启动页：机甲在原点平地待命——截提示闪烁帧，验证无刷怪、无 HUD；
	# 用空格（=jump 键本身）触发开始：验证"开始那一下的按键不会直接变成起跳"
	# （操作延迟解锁，just_pressed 在解锁前已过期）。死亡重开现在黑屏回启动页，
	# 重载出的新探针会再跑本分支（00 系截图被等价内容覆盖，无碍）。
	await _wait(0.6)
	if get_parent().has_node("TitleScreen"):
		var start_x := player.global_position.x
		await _screenshot("00_title.png")
		print("[autotest] title standby: scroll_objects=",
				get_tree().get_nodes_in_group("scroll_objects").size(),
				" enemies=", get_tree().get_nodes_in_group("enemies").size(),
				" (待机应均为 0)")
		var start_key := InputEventKey.new()
		start_key.physical_keycode = KEY_SPACE
		start_key.pressed = true
		Input.parse_input_event(start_key)
		await _wait(0.15) # HUD 启动动画进行中
		await _screenshot("00b_start.png")
		print("[autotest] combat entered: player_stayed=",
				absf(player.global_position.x - start_x) < 1.0,
				" (待机站桩应=true), airborne=", not player.is_on_floor(),
				" (按跳键开始不应起跳，解锁延迟内应=false), thrust_target=",
				player.get_node("Visuals/NozzlePivot/Thruster")._target,
				" (开场无推进焰应=0), score_label=",
				get_parent().get_node("HUD/Root/ScoreLabel").visible,
				" spawner_active=", get_parent().get_node("Spawner")._active)
		# 启动页待机不计时：开始键后才起表（待机已站 0.8s+，误计会远超 0.5）。
		print("[autotest] clock at combat start: play_time=", snappedf(RunState.play_time, 0.01),
				" [", "OK" if RunState.play_time < 0.5 else "FAIL", "] (启动页不计时，应<0.5)")
		await _wait(0.6)
		# 释放开始键：空格=jump 动作，残留按下态会吃掉后续探针的 just_pressed 边沿（踩过）
		var stop_ev := InputEventKey.new()
		stop_ev.physical_keycode = KEY_SPACE
		stop_ev.pressed = false
		Input.parse_input_event(stop_ev)
	else:
		print("[autotest] restart run: title skipped (异常：重开应回启动页)")
	await _screenshot("01_start.png")

	# 验证画面跟随窗口缩放：中途改窗口尺寸再截一张。
	DisplayServer.window_set_size(Vector2i(1920, 864))
	await _wait(0.5)
	await _screenshot("01b_resized.png")
	# 再走一次最大化 → 还原，覆盖系统级缩放路径。
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	await _wait(0.5)
	await _screenshot("01c_maximized.png")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 720))
	await _wait(0.5)

	Input.action_press("move_right")
	# 滑行火花探针：等一帧真正"贴地+高速"的滑行再读数；顶墙卡死（速度归零）
	# 就退后 500px 重新起跑（随机地形一步台就能顶死，固定时序会被吃掉）。
	var run_t := 0.0
	var last_x := player.global_position.x
	var saw_slide := false
	while run_t < 4.0:
		await _wait(0.05)
		run_t += 0.05
		if player.is_on_floor() \
				and absf(player.velocity.x) > BalancePlayer.SLIDE_SPARK_MIN_SPEED:
			saw_slide = true
			break
		if run_t > 0.8 and absf(player.global_position.x - last_x) < 30.0:
			player.global_position.x -= 500.0 # 退后起跑
			last_x = player.global_position.x
		elif absf(player.global_position.x - last_x) > 30.0:
			last_x = player.global_position.x
	await _screenshot("02_run.png")
	print("[autotest] slide sparks while running: emitting=",
			player.get_node("Visuals/SlideSparks").emitting, " saw_slide=", saw_slide,
			" (贴地疾滑应=true)")

	# 跑局信息：直接开本关=第 1 关（未走 start_run，stage 默认 1）；用时只在战斗中走，
	# 右上读数与 RunState 累计秒同步（跳秒刷新，差不过 1s）。
	var hud: HUD = get_parent().get_node("HUD")
	var time_parts := hud._time_label.text.trim_prefix("用时 ").split(":")
	var shown_secs := int(time_parts[0]) * 60 + int(time_parts[1]) \
			if time_parts.size() == 2 else -1
	var info_ok: bool = hud._stage_label.text == " ".join(RunState.progress_parts()) \
			and RunState.play_time > 1.0 and absf(shown_secs - RunState.play_time) < 1.0
	print("[autotest] run info: stage=\"", hud._stage_label.text, "\" time=\"",
			hud._time_label.text, "\" play_time=", snappedf(RunState.play_time, 0.01),
			" [", "OK" if info_ok else "FAIL", "] (关卡数应与 RunState 一致；用时已走且读数同步)")

	# 短按跳 + 空中长按跳推进（AC6 式飞行）。先松开移动键原地跳：
	# 带速跳会撞上台阶提前落地，喷焰探针时序被随机地形吃掉（踩过：level 掉到 0.45/vy=0）。
	# 探针状态自适应：等真正离地推进再读数，并打印完整状态便于诊断。
	# 起跳必须走 parse_input_event：jump 读的是 is_action_just_pressed（边沿触发），
	# 计时器回调里的 Input.action_press 打的边沿时间戳在下一个物理帧已过期（踩过）。
	Input.action_release("move_right")
	var flame_node: ThrusterFlame = player.get_node("Visuals/NozzlePivot/Thruster")
	var jump_ev := InputEventKey.new()
	jump_ev.physical_keycode = KEY_SPACE
	jump_ev.pressed = false
	Input.parse_input_event(jump_ev) # 兜底释放，保证按下时是真边沿
	await _wait(0.08)
	jump_ev = InputEventKey.new()
	jump_ev.physical_keycode = KEY_SPACE
	jump_ev.pressed = true
	Input.parse_input_event(jump_ev)
	var waited := 0.0
	while player.is_on_floor() and waited < 1.0:
		await _wait(0.05)
		waited += 0.05
	await _wait(0.4) # 离地后稳定推进一段
	await _screenshot("03b_flight.png")
	print("[autotest] boost flame level=", flame_node._level,
			" airborne=", not player.is_on_floor(),
			" jump_held=", Input.is_action_pressed("jump"),
			" boost=", player.boost, " vy=", player.velocity.y,
			" slide_sparks=", player.get_node("Visuals/SlideSparks").emitting,
			" (推进态应 level≈1.0 且滑行火花=false)")
	jump_ev = InputEventKey.new()
	jump_ev.physical_keycode = KEY_SPACE
	jump_ev.pressed = false
	Input.parse_input_event(jump_ev)
	waited = 0.0
	while (player.is_on_floor() or player.velocity.y < 20.0) and waited < 1.5:
		await _wait(0.05)
		waited += 0.05
	await _screenshot("03d_fall_flame.png")
	print("[autotest] fall flame level=", flame_node._level,
			" vy=", player.velocity.y, " (下落反推应≈0.45 且 vy>0)")
	await _wait(1.0)

	# 行进间自动开火 + 单次跳越掩体（开火全自动、手动开火键已移除：本段临时开闸）。
	player.auto_fire = true
	for i in 4:
		Input.action_press("move_right")
		await _wait(0.9)
		Input.action_release("move_right")
		await _wait(0.25)
		Input.action_press("jump")
		await _wait(0.1)
		Input.action_release("jump")
		await _wait(0.55)
	player.auto_fire = false
	Input.action_release("move_right")
	await _screenshot("04_combat.png")

	# 确定性探针：把玩家传送回出生点附近（世界原点进画面）再刷靶开火——
	# 迸溅粒子若喷在容器原点（=出生点上空）当场可见；正常则应在弹着点。
	# 首发命中瞬间截帧 + 0.12s 后粒子飞离焰心再截一张对比。
	player.global_position = Vector2(300, 500)
	player.velocity = Vector2.ZERO
	await _wait(0.25) # 镜头平滑跟上
	# 真落地再开火：传送点离地 70px 要 ~0.42s 才落定；下落中枪口焰按渲染补间位画、
	# 枪口读物理位，两者差约一个物理步（3~4px）→ 下面的钉位断言误报 FAIL（2026-11-03 查明）。
	waited = 0.0
	while not player.is_on_floor() and waited < 1.0:
		await _wait(0.05)
		waited += 0.05
	var score_before: int = get_parent().score
	var probe_target: Enemy = spawner.debug_spawn_enemy(player.global_position.x + 260.0)
	if probe_target != null:
		await _wait(0.05)
		player.auto_fire = true # 开火全自动：靶在射程内即出膛
		await _wait(0.04) # 枪口焰全亮期
		await _screenshot("04a_muzzle_flash.png")
		# 回归断言：枪口焰必须钉在枪口上（top_level 后靠脚本显式贴回，曾闪在出生点上空）
		var flash: Node2D = player.get_node("Visuals/ArmPivot/Muzzle/Flash")
		var muzzle: Node2D = player.get_node("Visuals/ArmPivot/Muzzle")
		print("[autotest] muzzle flash pinned: ",
				"OK" if flash.global_position.distance_to(muzzle.global_position) < 2.0 else "FAIL",
				" flash=", flash.global_position, " muzzle=", muzzle.global_position)
		# 迸溅生成瞬间截帧：若粒子在 add_child→定位间隙喷到了容器原点（=出生点上空），
		# 当场可见；节点坐标由容器盘点兜底。
		var container: Node = get_tree().get_first_node_in_group("projectile_container")
		waited = 0.0
		var burst_at := Vector2.INF
		while waited < 0.6 and burst_at == Vector2.INF:
			await _wait(0.016)
			waited += 0.016
			for c in container.get_children():
				if c.name.begins_with("ImpactBurst"):
					burst_at = (c as Node2D).global_position
		print("[autotest] impact burst node at ", burst_at,
				" (玩家在 ", player.global_position, "，原点=", Vector2.ZERO, ")")
		await _wait(0.12) # 粒子飞离焰心 30-80px：喷对在弹着点、喷错在原点，一图定案
		await _screenshot("04b_bullet_impact.png")
		player.auto_fire = false # 关闸（原松开开火键位）：靶子留给下面的确定性击杀
		probe_target.take_damage(999)
		await _wait(0.09) # 爆炸白闪+火球进行中
		await _screenshot("04c_kill_explosion.png")
		await _wait(0.14) # 火球退场，火焰/烟尘/碎片粒子当空
		await _screenshot("04d_explosion_late.png")
		await _wait(0.21)
		print("[autotest] probe kill: score ", score_before, " -> ", get_parent().score,
				" pools=", spawner.get_pool_sizes())

	# 确定性探针：把敌人正对障碍中心刷下，验证重叠检测把它抬到顶面。
	var probe_info: String = spawner.debug_probe_obstacle_overlap()
	await _wait(0.25)
	await _screenshot("05b_enemy_on_obstacle.png")
	print("[autotest] ", probe_info)

	# 后退再前进，验证负位移会抵消刷怪累加器。
	# 顺带读三焰：面向随移动方向（无目标时），两相都是朝面向侧移动——
	# 应=腿焰全档+主焰巡航半档、腰焰 0（纯后退语义人工测：倒退=主焰熄火+腰焰全档）。
	Input.action_press("move_left")
	await _wait(1.2)
	printerr("[autotest] vernier flames (move_left): face_dir=", player._face_dir,
			" pack=", player.get_node("Visuals/NozzlePivot/Thruster")._level,
			" leg=", player.get_node("Visuals/LegThruster")._level,
			" waist=", player.get_node("Visuals/WaistThruster")._level)
	Input.action_release("move_left")
	Input.action_press("move_right")
	await _wait(1.2)
	printerr("[autotest] vernier flames (move_right): face_dir=", player._face_dir,
			" pack=", player.get_node("Visuals/NozzlePivot/Thruster")._level,
			" leg=", player.get_node("Visuals/LegThruster")._level,
			" waist=", player.get_node("Visuals/WaistThruster")._level)
	Input.action_release("move_right")
	await _screenshot("05_back_and_forth.png")

	# 近战二段斩探针：在玩家脚下同一地面确定性刷靶，K·K 连击，
	# 验证两段伤害/击杀/刃光+命中闪增+刃口碎光渲染。
	# 时序对齐 BalancePlayer（用户手调值）：闲置前摇 0.2 → 追击 1 帧 → 斩击 0.12；
	# 连段窗口=后摇 0.2（从斩击完成起算），二按必须落在后摇内才接二段。
	var melee_target: Enemy = spawner.debug_spawn_enemy(player.global_position.x + 130.0)
	if melee_target != null:
		var melee_score_before: int = get_parent().score
		player.global_position = melee_target.global_position + Vector2(-110, 0)
		player.velocity = Vector2.ZERO
		await _wait(0.2)
		Input.action_press("melee")
		await _wait(0.05)
		Input.action_release("melee")
		await _wait(0.21) # 前摇 0.2 + 进斩击 ~0.01
		printerr("[autotest] dash flames: pack=",
				player.get_node("Visuals/NozzlePivot/Thruster")._level,
				" leg=", player.get_node("Visuals/LegThruster")._level,
				" waist=", player.get_node("Visuals/WaistThruster")._level,
				" phase=", player._melee_phase,
				" (冲刺主焰+腿焰应≈1.5、腰焰 0；读数在爬坡途中会偏低)")
		await _screenshot("06_melee_swing1.png")
		await _wait(0.06) # 斩击中段：刃光半张+刃口碎光（命中闪增要命中才有，另看）
		await _screenshot("06a_melee_midstrike.png")
		await _wait(0.10) # t≈0.37：斩击已完成，处于后摇连段窗口内
		Input.action_press("melee")
		await _wait(0.05)
		Input.action_release("melee")
		await _wait(0.21) # 后摇走完 + 衔接前摇 0.05 + 进斩击，二段判定已结算
		await _screenshot("06b_melee_swing2.png")
		await _wait(0.5)
		print("[autotest] melee probe: score ", melee_score_before, " -> ",
				get_parent().score,
				" enemies_alive=", get_tree().get_nodes_in_group("enemies").size())
		await _screenshot("06c_melee_after.png")

	# ---- 键位探针：近战=S / ↓ / 手柄 X；旧键 J / X 已删（单手方案：WASD/方向键+空格） ----
	# 走真实输入事件（物理键码/手柄键）：验的是输入映射本身，不是动作名。无靶空挥会突进
	# 冲出 ~500px，先记落地站位、挥完复位（后面的自动开火探针按"出生点附近平地"写的）。
	await _wait(1.2) # 上面二段后摇走完、回空闲
	waited = 0.0
	while not player.is_on_floor() and waited < 1.0:
		await _wait(0.05)
		waited += 0.05
	var key_probe_pos := player.global_position
	var pad_x := InputEventJoypadButton.new()
	pad_x.button_index = JOY_BUTTON_X
	var melee_probes := [ # [输入事件, 应否出刀]
		[_key_event(KEY_S), true], [_key_event(KEY_DOWN), true], [pad_x, true],
		[_key_event(KEY_J), false], [_key_event(KEY_X), false],
	]
	for probe: Array in melee_probes:
		var press_ev: InputEvent = probe[0]
		var expect_swing: bool = probe[1]
		press_ev.set("pressed", true)
		Input.parse_input_event(press_ev)
		await _wait(0.05)
		var swung: bool = player._melee_phase != player.MeleePhase.IDLE
		var release_ev := press_ev.duplicate() as InputEvent
		release_ev.set("pressed", false)
		Input.parse_input_event(release_ev)
		print("[autotest] melee input ", press_ev.as_text(), ": swung=", swung,
				" [", "OK" if swung == expect_swing else "FAIL", "] (应",
				"进入近战起手" if expect_swing else "无反应——旧键已删", ")")
		# 出刀则等无靶空挥走完回空闲：前摇 0.2+突进满 0.45+斩 0.12+后摇 0.2
		await _wait(1.2 if swung else 0.1)
	player.global_position = key_probe_pos
	player.velocity = Vector2.ZERO
	await _wait(0.2)

	# ---- 自动开火探针：射程+通视线内自射；近战全程底层禁射（_fire 硬闸） ----
	# 单威胁源前置（同 BOSS 探针规矩）：清掉场上杂兵，别让流弹/杂兵蹭进弹计数。
	# 靶子给超量血：近战一段+流弹都打不死它，近战结束后自动开火得有活靶可恢复。
	for node in get_tree().get_nodes_in_group("enemies"):
		(node as Enemy).take_damage(99999)
	var auto_target: Enemy = spawner.debug_spawn_enemy(player.global_position.x + 600.0)
	if auto_target != null:
		auto_target._hp = 99999
		player.auto_fire = true
		await _wait(0.3) # 首发出膛+索敌射线采样几帧
		var auto_bullets := _count_projectiles(func(c: Node) -> bool:
			return c is Bullet and c.damage == BalancePlayer.PLAYER_BULLET_DAMAGE)
		print("[autotest] auto fire: bullets=", auto_bullets > 0, " count=", auto_bullets,
				" (靶在射程 600<1400 且通视，无输入应自射)")
		await _screenshot("06d_auto_fire.png")
		# 近战禁射：贴到靶边起手，全程（前摇→突进→斩击→后摇）弹计数必须归零——
		# 自动开火本来会接着打，被 _fire() 底层闸拦下才算过。
		player.global_position = auto_target.global_position + Vector2(-110, 0)
		player.velocity = Vector2.ZERO
		await _wait(0.15) # 起手前在飞的流弹先落定（110px 弹程 ~0.05s）
		Input.action_press("melee")
		await _wait(0.05)
		Input.action_release("melee")
		await _wait(0.25) # 前摇 0.2+进斩击：此刻在近战硬直里
		var lock_bullets := _count_projectiles(func(c: Node) -> bool:
			return c is Bullet and c.damage == BalancePlayer.PLAYER_BULLET_DAMAGE)
		var in_melee: bool = player._melee_phase != player.MeleePhase.IDLE
		await _screenshot("06e_melee_fire_lock.png")
		print("[autotest] melee fire lock: in_melee=", in_melee,
				" bullets_during=", lock_bullets,
				" [", "OK" if in_melee and lock_bullets == 0 else "FAIL",
				"] (近战全程应 in_melee=true 且无新弹)")
		# 恢复验证：近战一段已在上面结算（此刻读血作基准），后摇走完后自动开火
		# 恢复首发——弹寿仅 ~0.03s，单点采样会落在两发之间，改轮询靶子掉血
		#（恢复的首发命中=掉血，确定性信号）。
		var hp_after_swing: int = auto_target._hp
		var resumed := false
		waited = 0.0
		while waited < 1.5 and not resumed:
			await _wait(0.05)
			waited += 0.05
			resumed = is_instance_valid(auto_target) and auto_target._hp < hp_after_swing
		print("[autotest] auto fire resume: ", resumed,
				" (近战结束应自动恢复射击：靶子再掉血)")
		player.auto_fire = false # 还原：后面的精英/BOSS 探针按"靶子活着"的账写
		auto_target.take_damage(99999) # 清掉高血靶，别蹭进精英探针

	# ---- 精英探针：拉一只当前章的精英车，验证枪口预警后出重击弹 ----
		# （ch1=导弹车追踪导弹 HeavyMissile；ch2=熔渣臼炮车迫击炮弹 MortarShell；
		# ch3=布雷车电浆浮雷 PlasmaMine——PlasmaMissile 是 HeavyMissile 子类，自然命中；
		# ch4=海葵炮台车珊瑚重弹 CoralOrb；ch5=响哨防空炮车啸雷弹 FlakShell；
		# ch6=锚桩打桩车电网闸 ArcFence；ch7=岸炮海防炮车跳弹 SkipShell；
		# ch8=钻机车「喷井」裂地镖 SaltDart——mark 落地即计入威胁，镖=出手件）
	# 齐射触发是半衰期掷骰（平均 ~3.5s 一轮）+ 蓄力 0.5s，16s 窗口覆盖 ~99%。
	var elite: Enemy = spawner.debug_spawn_elite(player.global_position.x + 500.0)
	if elite != null:
		var saw_missile := false
		waited = 0.0
		while waited < 16.0 and not saw_missile:
			await _wait(0.1)
			waited += 0.1
			saw_missile = _count_projectiles(func(c: Node) -> bool:
				return c is HeavyMissile or c is MortarShell \
						or c is PlasmaMine or c is CoralOrb \
						or c is FlakShell or c is ArcFence \
						or c is SkipShell or c is SaltDart or c is LiveSpan \
						or c is SulfurVent) > 0
		await _screenshot("07_elite_volley.png")
		print("[autotest] elite heavy shot: ", saw_missile,
				" (当前章精英在场应出重击弹)")
		if is_instance_valid(elite) and elite.hp_ratio() > 0.0:
			elite.take_damage(999) # 探针结束即击杀：别让它的追踪导弹蹭进 BOSS 段

	# ---- BOSS 探针：不等距离直接拉一场追击。公共部分=入场/血条/WARNING/击杀快进，
	# 能力部分按机型分叉（ch1 直升机扫射+弹雨；ch2 驳船弹幕墙+熔渣封路）。
	var boss: Node2D = spawner.debug_spawn_boss()
	if boss != null:
		var boss_unit := boss as Enemy # 通用血量/击杀口；能力探针按机型分叉
		var hp_before_boss := player.hp
		await _wait(1.0) # 入场滑入完毕，血条/WARNING 应已亮
		await _screenshot("08_boss_enter.png")
		print("[autotest] boss engaged: alive=", is_instance_valid(boss_unit)
				and boss_unit.hp_ratio() > 0.0,
				" boss_bar=", get_parent().get_node("HUD")._boss_bar.visible,
				" warning=", get_parent().get_node("HUD")._warning_label.visible,
				" (入场后均应=true)")
		# 分型能力探针：各章 BOSS 招式不同，各验各的（子类判据必须在父类之前——
		# 白鲸也是 PursuitBoss，先匹配会被驳船分支错误接走并在取 WallPorts 时炸）
		if boss is BossSentinel:
			await _probe_boss_sentinel(boss as BossSentinel)
		elif boss is BossAngler:
			await _probe_boss_angler(boss as BossAngler)
		elif boss is BossInterceptor:
			await _probe_boss_interceptor(boss as BossInterceptor)
		elif boss is BossRedwheel:
			await _probe_boss_redwheel(boss as BossRedwheel)
		elif boss is BossAnchor:
			await _probe_boss_anchor(boss as BossAnchor)
		elif boss is BossSaltmill:
			await _probe_boss_saltmill(boss as BossSaltmill)
		elif boss is BossConductor:
			await _probe_boss_conductor(boss as BossConductor)
		elif boss is Boss:
			await _probe_boss_heli(boss as Boss)
		elif boss is BossBarge:
			await _probe_boss_barge(boss as BossBarge)
		else:
			# 没有通用能力探针的新章 BOSS（能力探针在本章 probe_world_N）：跳过，后面的
			# 击杀/阵亡/结算探针照跑。旧兜底把所有 PursuitBoss 塞进驳船探针，非驳船
			# 转型得 null 当场炸，血量停在 99999，后续死亡探针连锁失败。
			print("[autotest] boss ability probe: skipped (", boss.scene_file_path,
					" 无通用探针，见本章 probe_world_N)")
		# 立刻击杀快进：站桩吃整轮雨/火区会被打死，污染后面的死亡探针。
		# 此刻已出膛的 ≤2 发仍会命中（≤40 伤），玩家活。
		var hp_before_kill := player.hp
		if is_instance_valid(boss_unit) and boss_unit.hp_ratio() > 0.0:
			boss_unit.take_damage(999)
		var hp_after_kill := player.hp
		await _wait(1.3) # 已出膛导弹命中+爆闪
		await _screenshot("08d_boss_blast.png")
		print("[autotest] boss rain damage: hp ", hp_before_boss, " -> ",
				player.hp, "；击杀瞬间 ", hp_before_kill, "->", hp_after_kill,
				" (击败回血 +", hp_after_kill - hp_before_kill, "；",
				"站桩吃追踪雨/精英残弹蹭伤计入)！")

	print("[autotest] score=", get_parent().score,
			" player hp=", player.hp,
			" enemies_alive=", get_tree().get_nodes_in_group("enemies").size(),
			" scroll_objects=", get_tree().get_nodes_in_group("scroll_objects").size(),
			" pools=", spawner.get_pool_sizes())

	# 死亡 → 玩家爆炸演出（GAME_OVER_DELAY=1.1s）→ 出结算（世界不冻结：敌人/BOSS 认
	# is_dead 停火、移动层照常=自然待机）→ 任意键重开。
	# （受击无敌窗只拦不大于本窗峰值的伤害，999 照样一刀必死。重载会释放本节点，收尾交给树级定时器。）
	# 待机探针前置：现场刷一只 BOSS + 一只射程内杂兵，入场开打后再阵亡。
	var idle_boss: Node2D = spawner.debug_spawn_boss()
	spawner.debug_spawn_enemy(player.global_position.x + 500.0)
	await _wait(2.5) # BOSS 入场 0.9s + 首招开打；杂兵进扫射节奏
	player.take_damage(999)
	var play_time_at_death := RunState.play_time
	await _wait(0.15) # 爆炸白闪+火球进行中；HUD 退场动画进行中
	await _screenshot("07_player_explosion.png")
	await _wait(1.2) # 退场全程 0.6s 落定（tween 收尾帧 visible=false）
	var top_hidden := true
	for node in hud._combat_nodes():
		if (node as CanvasItem).visible:
			top_hidden = false
	print("[autotest] hud outro: topbar_hidden=", top_hidden,
			" [", "OK" if top_hidden else "FAIL", "] (阵亡退场后顶栏应全组隐藏)")
	await _wait(1.15) # 越过 GAME_OVER_DELAY：演出播完出结算
	print("[autotest] game over: paused=", get_tree().paused, " [",
			"OK" if not get_tree().paused else "FAIL", "] (结算后世界不冻结，应=false)")
	# 结算三组=阵亡瞬间的得分/关卡/用时；GAME_OVER_DELAY 演出窗口里表已停（不再走）。
	var expect_num: Array[String] = [str(get_parent().score), RunState.progress_parts()[1],
			HUD.format_time(play_time_at_death)]
	var got_num: Array[String] = []
	for gi in 3:
		got_num.append((hud._result_groups[gi][1] as Label).text)
	var nums_ok := got_num == expect_num and RunState.play_time == play_time_at_death
	print("[autotest] result numbers: ", got_num, " [", "OK" if nums_ok else "FAIL",
			"] 应=", expect_num, "（且阵亡后停表）")
	# 结算真立起来了（build 末尾 hide_result 全藏、show_result 复显——漏复显就全场白屏，
	# 实机踩过）：标题+提示+统计首段任一不可见即 FAIL。
	var result_up: bool = hud._result_title.visible and hud._result_hint.visible \
			and (hud._result_groups[0][0] as CanvasItem).visible
	print("[autotest] result panel up: ", result_up, " [", "OK" if result_up else "FAIL", "]")
	# 重开闸（防误触）：面板刚出、入场动画没播完时不受理重开，提示也还没亮。
	var touch_ctl: TouchControls = get_parent().get_node("TouchControls")
	var gate_shut: bool = not touch_ctl._restart_armed and hud._result_hint.modulate.a < 0.05
	print("[autotest] restart gate during intro: armed=", touch_ctl._restart_armed,
			" hint_a=", snappedf(hud._result_hint.modulate.a, 0.01),
			" [", "OK" if gate_shut else "FAIL", "] (入场动画内应未开闸、提示未亮)")
	# 结算建立帧截图放呼吸稳定后（先截会截到统计还没浮齐的中间态）。
	await _wait(0.8)
	await _screenshot("07_game_over.png")
	# 自然待机：阵亡时正在放的招收势、在飞的弹落地出画（~3s），之后 2s 窗口里敌方零新弹
	# （停火），BOSS 仍随锚浮动（没被冻住——旧版敌基类玩家死后整段 return，连移动出口
	# 一起跳过=冻成雕像，BOSS 却在子类里接着出招；当年结算冻结整棵树没露馅）。
	await _wait(3.0)
	var shots: Node = get_tree().get_first_node_in_group("projectile_container")
	var seen := {}
	for c in shots.get_children():
		seen[c.get_instance_id()] = true
	var new_hostile := 0
	var boss_ys: Array[float] = []
	for i in 10:
		await _wait(0.2)
		if is_instance_valid(idle_boss):
			boss_ys.append(idle_boss.global_position.y)
		for c in shots.get_children():
			if not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				if _is_hostile_shot(c):
					new_hostile += 1
	var boss_bob: float = boss_ys.max() - boss_ys.min() if boss_ys.size() > 1 else 0.0
	print("[autotest] post-death idle: new_hostile=", new_hostile,
			" boss_bob=", snappedf(boss_bob, 0.1), " [",
			"OK" if new_hostile == 0 and boss_bob > 1.0 else "FAIL",
			"] (阵亡后敌方应停火=0 新弹，BOSS 应仍在悬停浮动>1px)")
	# 入场动画早已播完：重开闸应已开、提示已亮（下面的任意键重开才有效）。
	var gate_open: bool = touch_ctl._restart_armed and hud._result_hint.modulate.a > 0.3
	print("[autotest] restart gate after intro: armed=", touch_ctl._restart_armed,
			" [", "OK" if gate_open else "FAIL", "] (动画播完应开闸、提示亮起)")
	await _screenshot("07c_idle_after_death.png")
	# 重开=任意键（结算画面）：用 N 键（不映射任何动作）验证任意键都能重开。
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_N
	ev.pressed = true
	Input.parse_input_event(ev)
	print("[autotest] restart requested (via any-key)")
	await _wait(0.35) # 黑屏淡入半程（FADE_OUT 0.5s，此时约半黑），重载尚未发生
	await _screenshot("07b_fade_out.png")
	# 重载会释放本节点，绑定到 SceneTree 的定时器负责退出（lambda 会随节点失效）。
	# 转场拉长后（0.5 淡入 + 0.25 全黑停留），重载在发键后 ~0.75s，第二轮探针要 1.9s+，
	# 窗口给 2.4s 才截得完。
	get_tree().create_timer(2.4).timeout.connect(Callable(get_tree(), "quit"))


## ---- BOSS 能力探针分型：ch1 直升机 / 追击框架章节 BOSS（现 ch2 驳船）各验各的 ----

## ch1 直升机：镜像换边（枪臂+尾梁）→ 压高扫射 → 追踪弹雨 → 失衡加深。
func _probe_boss_heli(boss: Boss) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 朝向镜像探针：玩家跳到 BOSS 右侧，Visuals 整层换边——枪臂/尾梁必须
	# 跟着换到玩家一侧（旧实现只翻主体贴图，武器/挂件钉在原地，本探针防回归）。
	var player_x_before_flip := player.global_position.x
	player.global_position = Vector2(boss.global_position.x + 420.0,
			player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.25) # 面向判定 + 镜像生效（物理帧内完成）
	var boss_rig: Node2D = boss.get_node("Visuals")
	var boss_muzzle_x: float = (boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D) \
			.global_position.x
	var boss_tail_x: float = (boss.get_node("Visuals/TailRotor") as Node2D) \
			.global_position.x
	var boss_flipped := boss_rig.scale.x < 0.0 \
			and boss_muzzle_x > boss.global_position.x \
			and boss_tail_x < boss.global_position.x
	await _screenshot("08c_boss_flip.png")
	print("[autotest] boss flip: ", "OK" if boss_flipped else "FAIL",
			" rig_scale_x=", boss_rig.scale.x,
			" muzzle-boss=", int(boss_muzzle_x - boss.global_position.x),
			" tail-boss=", int(boss_tail_x - boss.global_position.x),
			" (玩家在右侧时应全换边：镜像−1、枪口>0、尾梁<0)")
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 高位扫射：等机体压到射高开火（压高 ~0.45 + 蓄力 0.35，3.5s 处首波在屏）；
	# 玩家站桩贴地应安全（射高 410 在站立头顶 470 之上），只验弹幕在场。
	await _wait(2.5)
	await _screenshot("08a_boss_descend.png")
	print("[autotest] boss descending: y=", int(boss.global_position.y),
			" (扫射机动期应从 240 压向 390)")
	await _wait(1.0)
	var sweep_bullets := _count_projectiles(func(c: Node) -> bool:
		return c is Bullet and c.damage == BalanceCombat.BOSS_SWEEP_DAMAGE)
	await _screenshot("08b_boss_sweep.png")
	print("[autotest] boss sweep: y=", int(boss.global_position.y),
			" bullets_on_screen=", sweep_bullets,
			" (射高 ~390 且开火期应 ≥1)")
	# 导弹雨：轮询等追踪导弹出膛，截飞行帧；站桩→瞄脚底必爆脚边 → 验掉血。
	var missiles := 0
	var waited := 0.0
	while waited < 12.0 and missiles == 0:
		await _wait(0.1)
		waited += 0.1
		missiles = _count_projectiles(func(c: Node) -> bool:
			return c is HeavyMissile)
	await _wait(0.45) # 导弹飞至途中再截
	await _screenshot("08c_boss_missiles.png")
	print("[autotest] boss missiles launched: ", missiles > 0, " count=",
			missiles, " (导弹雨期应=true)")
	# 失衡探针（AC6 式冲击/STAGGER）：打满冲击 → 硬直停摆 + 受伤加深（10 应变 15）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] boss stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch2 驳船：镜像换边（枪臂+墙炮位，无尾梁）→ 弹幕墙（hover 恒定不压高）→
## 熔渣封路（定点弹落地留火区）→ 失衡加深（账同 ch1：加深×1.5 前置、防御 5 后置）。
func _probe_boss_barge(boss: BossBarge) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 给巨量血（同 ch4~ch6 探针）：墙→重弹→熔渣三段轮询站桩 ~10s，火区 tick 能把
	# 100 血磨到 0（2026-11-02 跑出 hp 100→0），玩家一死全局暂停冻结世界、后续探针
	# 落空。探针收尾还原满血，让结尾的一刀必死死亡探针照常工作。
	player.hp = 99999
	# 朝向镜像探针：Visuals 整层换边——枪口与船艏墙炮位一起换到玩家一侧。
	var player_x_before_flip := player.global_position.x
	player.global_position = Vector2(boss.global_position.x + 420.0,
			player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.25)
	var rig: Node2D = boss.get_node("Visuals")
	var muzzle_x: float = (boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D) \
			.global_position.x
	var port_x: float = (boss.get_node("Visuals/WallPorts/Port1") as Node2D) \
			.global_position.x
	var flipped := rig.scale.x < 0.0 \
			and muzzle_x > boss.global_position.x \
			and port_x > boss.global_position.x
	await _screenshot("08c_boss_flip.png")
	print("[autotest] barge flip: ", "OK" if flipped else "FAIL",
			" rig_scale_x=", rig.scale.x,
			" muzzle-boss=", int(muzzle_x - boss.global_position.x),
			" port-boss=", int(port_x - boss.global_position.x),
			" (玩家在右侧时应全换边：镜像−1、枪口>0、墙炮位>0)")
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 弹幕墙：入场第一手（skill_a），贴脸压招解除后重走预警 → 开火；船 hover
	# 恒 370 不压高（与直升机扫射的构图区别）。轮询等墙幕弹出膛——墙幕弹以
	# BARGE_WALL_DAMAGE 分辨（墙幕伤害已与机枪档分家；旧版"定时 2.5s 单次计数"
	# 其实是靠普攻短梭的同伤害弹蒙混过关，改轮询才诚实）。
	var wall_bullets := 0
	var waited := 0.0
	while waited < 8.0 and wall_bullets == 0:
		await _wait(0.1)
		waited += 0.1
		wall_bullets = _count_projectiles(func(c: Node) -> bool:
			return c is Bullet and c.damage == BalanceWorld2.BARGE_WALL_DAMAGE)
	await _screenshot("08a_barge_wall.png")
	print("[autotest] barge wall: y=", int(boss.global_position.y),
			" bullets_on_screen=", wall_bullets,
			" (hover 恒 370 附近、弹幕墙开火期应 ≥1)")
	# 排炮重弹（普攻）：墙后摇 1.3s 接普攻段——轮询等 slag_slug 出膛（单发慢弹
	# 寿命长，0.1s 轮询稳逮到）；弹种以伤害值分辨（BARGE_SLUG_DAMAGE≠BARGE_WALL_DAMAGE）。
	var slugs := 0
	waited = 0.0
	while waited < 6.0 and slugs == 0:
		await _wait(0.1)
		waited += 0.1
		slugs = _count_projectiles(func(c: Node) -> bool:
			return c is Bullet and c.damage == BalanceWorld2.BARGE_SLUG_DAMAGE)
	await _wait(0.4) # 重弹飞出 ~200px、离开枪口焰再截（慢弹寿命长，不怕错过）
	await _screenshot("08b_barge_slug.png")
	print("[autotest] barge slug: fired=", slugs > 0, " count=", slugs,
			" (普攻段应出 1 发慢速熔渣重弹，非机枪短梭)")
	# 熔渣封路：轮换 wall→direct→slag，首发熔渣 ≈ 重弹后摇 0.9+预警 0.5 后；
	# 轮询等迫击炮弹出膛 → 等真弹道落地（0.75s 解算精确）→ 验火区生成。
	var missiles := 0
	waited = 0.0
	while waited < 10.0 and missiles == 0:
		await _wait(0.1)
		waited += 0.1
		missiles = _count_projectiles(func(c: Node) -> bool:
			return c is MortarShell)
	await _wait(1.2) # 真弹道飞行 0.75s：落地火区应已生成
	var pools := get_tree().get_nodes_in_group("slag_pools").size()
	await _screenshot("08c_barge_slag.png")
	print("[autotest] barge slag: missiles=", missiles > 0, " count=", missiles,
			" pools=", pools, " (定点弹落地应留熔渣火区)")
	player.hp = BalancePlayer.PLAYER_MAX_HP # 还原：结尾死亡探针要一刀必死
	# 失衡探针：加深×1.5 在前、减防御在后（10 → ceili(15)−5 = 10）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] barge stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch3 哨兵：镜像换边（枪臂+布雷闸，无尾梁）→ 电浆弹雨（PlasmaMissile 追踪弹）
## → 浮雷封锁（PlasmaMine 悬停）→ 失衡加深（账同 ch2：加深×1.5 前置、防御 5 后置）。
func _probe_boss_sentinel(boss: BossSentinel) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 朝向镜像探针：Visuals 整层换边——枪口与艇腹布雷闸一起换到玩家一侧。
	var player_x_before_flip := player.global_position.x
	player.global_position = Vector2(boss.global_position.x + 420.0,
			player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.25)
	var rig: Node2D = boss.get_node("Visuals")
	var muzzle_x: float = (boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D) \
			.global_position.x
	var bay_x: float = (boss.get_node("Visuals/BayPort") as Node2D) \
			.global_position.x
	var flipped := rig.scale.x < 0.0 \
			and muzzle_x > boss.global_position.x \
			and bay_x > boss.global_position.x
	await _screenshot("08c_boss_flip.png")
	print("[autotest] sentinel flip: ", "OK" if flipped else "FAIL",
			" rig_scale_x=", rig.scale.x,
			" muzzle-boss=", int(muzzle_x - boss.global_position.x),
			" bay-boss=", int(bay_x - boss.global_position.x),
			" (玩家在右侧时应全换边：镜像−1、枪口>0、布雷闸>0)")
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 电浆弹雨：入场第一手（skill_a），贴脸压招解除后重走预警 → 开火；hover 恒
	# 370 不压高（同 ch2 驳船的构图区别），验追踪电浆弹在场。
	await _wait(2.5)
	var plasma := _count_projectiles(func(c: Node) -> bool:
		return c is PlasmaMissile)
	await _screenshot("08a_sentinel_rain.png")
	print("[autotest] sentinel rain: y=", int(boss.global_position.y),
			" plasma_missiles=", plasma,
			" (hover 恒 370 附近、电浆弹雨开火期应 ≥1)")
	# 浮雷封锁：轮换 rain→direct→mine，首发浮雷 ≈ 入场+雨(0.5 警告+3.8 追踪窗)
	# +后摇1.4+直射(0.5+0.9)+后摇+预警 0.5 ≈ 7~9s；轮询等浮雷出舱 → 入位悬停。
	var mines := 0
	var waited := 0.0
	while waited < 14.0 and mines == 0:
		await _wait(0.1)
		waited += 0.1
		mines = get_tree().get_nodes_in_group("plasma_mines").size()
	await _wait(0.8) # 入位悬停+蓄能渐显
	await _screenshot("08c_sentinel_mines.png")
	print("[autotest] sentinel mines: dropped=", mines > 0, " count=", mines,
			" (浮雷封锁期应 ≥1 且悬停在承诺带上)")
	# 失衡探针：加深×1.5 在前、减防御在后（10 → ceili(15)−5 = 10）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] sentinel stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch4 灯笼鱼：镜像换边（钓灯+背炮+腹闸，无尾梁）→ 珊瑚重炮（CoralOrb 慢弹）
## → 珊瑚潮（CoralTide 涌浪）→ 失衡加深（账同 ch2/ch3：加深×1.5 前置、
## 防御 5 后置）。
func _probe_boss_angler(boss: BossAngler) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 给巨量血：灯笼鱼轮换深（珊瑚潮排第二技能），站桩探针期全程吃直射/重弹
	# 蹭血——回满 100 也扛不住 ~20s 磨血，玩家一死全局暂停冻结世界，后续
	# 探针全部落空（踩过：预警冻在腹闸、潮永不到来）。探针收尾还原满血，
	# 让结尾的一刀必死死亡探针照常工作。
	player.hp = 99999
	# 朝向镜像探针：Visuals 整层换边——钓灯炮口与臂根（肩座）都换到玩家一侧；
	# 背炮炮口与腹闸都在船体中轴（局部 x=0），镜像后仍居中（≈0）。各归其位
	# 即证明挂件随整层镜像（没随层的挂件会停在原侧，此处必 FAIL）。
	var player_x_before_flip := player.global_position.x
	player.global_position = Vector2(boss.global_position.x + 420.0,
			player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.25)
	var rig: Node2D = boss.get_node("Visuals")
	var muzzle_x: float = (boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D) \
			.global_position.x
	var pivot_x: float = (boss.get_node("Visuals/ArmPivot") as Node2D) \
			.global_position.x
	var cannon_x: float = (boss.get_node("Visuals/Cannon/Muzzle") as Node2D) \
			.global_position.x
	var bay_x: float = (boss.get_node("Visuals/BayPort") as Node2D) \
			.global_position.x
	var flipped := rig.scale.x < 0.0 \
			and muzzle_x > boss.global_position.x \
			and pivot_x > boss.global_position.x \
			and absf(cannon_x - boss.global_position.x) < 4.0 \
			and absf(bay_x - boss.global_position.x) < 4.0
	await _screenshot("08c_boss_flip.png")
	print("[autotest] angler flip: ", "OK" if flipped else "FAIL",
			" rig_scale_x=", rig.scale.x,
			" muzzle-boss=", int(muzzle_x - boss.global_position.x),
			" pivot-boss=", int(pivot_x - boss.global_position.x),
			" cannon-boss=", int(cannon_x - boss.global_position.x),
			" bay-boss=", int(bay_x - boss.global_position.x),
			" (玩家在右侧时应换边：镜像−1、艏部钓灯/臂根>0、背炮口与腹闸居中)")
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 珊瑚重炮：入场第一手（skill_a），贴脸压招解除后重走预警 → 逐发慢弹；
	# hover 恒 370 不压高（同 ch2/ch3 的构图区别），验珊瑚重弹在场。
	await _wait(2.5)
	var orbs := 0
	var waited := 0.0
	while waited < 12.0 and orbs == 0:
		await _wait(0.05) # 慢弹寿命长（飞抵 ~1.5s）：0.05s 轮询稳逮到
		waited += 0.05
		orbs = _count_projectiles(func(c: Node) -> bool:
			return c is CoralOrb)
	await _screenshot("08a_angler_volley.png")
	print("[autotest] angler volley: y=", int(boss.global_position.y),
			" coral_orbs=", orbs > 0, " count=", orbs,
			" (重炮期应 ≥1，慢速能量弹在飞)")
	# 钓灯爆闪（普攻）：重炮后摇 1.4s 接普攻段——轮询等径向慢矢出膛（coral_bolt
	# 以 ANGLER_FLASH_DAMAGE 分辨）。一帧齐出 N 矢，朝地/朝天的会很快撞地或出屏，
	# 轮询步长 0.05s 首见值 ≥1 即证明形态换了（非机枪短梭的 8 伤弹）。
	var flash_bolts := 0
	waited = 0.0
	while waited < 8.0 and flash_bolts == 0:
		await _wait(0.05)
		waited += 0.05
		flash_bolts = _count_projectiles(func(c: Node) -> bool:
			return c is Bullet and c.damage == BalanceWorld4.ANGLER_FLASH_DAMAGE)
	await _screenshot("08b_angler_flash.png")
	print("[autotest] angler flash: fired=", flash_bolts > 0, " count=", flash_bolts,
			" (普攻段应径向齐放 ", BalanceWorld4.ANGLER_FLASH_COUNT, " 矢慢弹，非机枪短梭)")
	# 珊瑚潮：自然轮换里它排第二技能（重炮→直射→潮 ≈ +7s），探针直接戳
	# _begin_skill_b 走完整链路（预警→腹舱出潮→涌浪贴地爬）——确定性，
	# 不吃轮换时序漂移。
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss._begin_skill_b()
	var tides := 0
	waited = 0.0
	while waited < 8.0 and tides == 0:
		await _wait(0.1)
		waited += 0.1
		tides = get_tree().get_nodes_in_group("coral_tides").size()
	await _wait(0.4) # 涌浪爬出一段再截
	await _screenshot("08c_angler_tide.png")
	print("[autotest] angler tide: dropped=", tides > 0, " count=", tides,
			" (珊瑚潮期应 ≥1 且贴地涌动)")
	player.hp = BalancePlayer.PLAYER_MAX_HP # 还原：结尾死亡探针要一刀必死
	# 失衡探针：加深×1.5 在前、减防御在后（10 → ceili(15)−5 = 10）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] angler stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch5 截击机：镜像换边（机鼻炮+背炮+机鼻预警点，无尾梁无旋翼）→ 啸雷齐射
## （FlakShell 定距空爆弹）→ 俯冲突袭（确定性戳 _begin_skill_b：机体冲撞
## 掉血断言）→ 失衡加深（账同 ch2/ch3/ch4：加深×1.5 前置、防御 5 后置）。
func _probe_boss_interceptor(boss: BossInterceptor) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 给巨量血：截击机轮换深（俯冲排第二技能），站桩探针期全程吃直射/啸雷
	# 蹭血——回满 100 也扛不住 ~20s 磨血，玩家一死全局暂停冻结世界，后续
	# 探针全部落空（同灯笼鱼探针的教训）。探针收尾还原满血。
	player.hp = 99999
	# 朝向镜像探针：Visuals 整层换边——机鼻炮口与臂根（炮座）都换到玩家一侧；
	# 背炮塔与机鼻预警点都在机体中轴附近（局部 x=0/-136→镜像后 -0/+136…
	# 机鼻点在轴上 x=-136≠0：镜像后应变正）。各归其位即证明挂件随整层镜像。
	var player_x_before_flip := player.global_position.x
	player.global_position = Vector2(boss.global_position.x + 420.0,
			player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.25)
	var rig: Node2D = boss.get_node("Visuals")
	var muzzle_x: float = (boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D) \
			.global_position.x
	var pivot_x: float = (boss.get_node("Visuals/ArmPivot") as Node2D) \
			.global_position.x
	var nose_x: float = (boss.get_node("Visuals/Nose") as Node2D) \
			.global_position.x
	var flipped := rig.scale.x < 0.0 \
			and muzzle_x > boss.global_position.x \
			and pivot_x > boss.global_position.x \
			and nose_x > boss.global_position.x
	await _screenshot("08c_boss_flip.png")
	print("[autotest] interceptor flip: ", "OK" if flipped else "FAIL",
			" rig_scale_x=", rig.scale.x,
			" muzzle-boss=", int(muzzle_x - boss.global_position.x),
			" pivot-boss=", int(pivot_x - boss.global_position.x),
			" nose-boss=", int(nose_x - boss.global_position.x),
			" (玩家在右侧时应换边：镜像−1、机鼻炮/炮座/机鼻预警点>0)")
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 啸雷齐射：入场第一手（skill_a），贴脸压招解除后重走预警 → 逐发定距
	# 空爆弹；hover 恒 370 不压高（同 ch2/ch3/ch4 的构图区别），验啸雷弹在场。
	await _wait(2.5)
	var flak := 0
	var waited := 0.0
	while waited < 12.0 and flak == 0:
		await _wait(0.05) # 弹速 2400 寿命短：0.05s 轮询稳逮到
		waited += 0.05
		flak = _count_projectiles(func(c: Node) -> bool:
			return c is FlakShell)
	await _screenshot("08a_interceptor_flak.png")
	print("[autotest] interceptor flak: y=", int(boss.global_position.y),
			" flak_shells=", flak > 0, " count=", flak,
			" (啸雷期应 ≥1，定距空爆弹在飞)")
	# 俯冲突袭：确定性戳 _begin_skill_b 走完整链路（机鼻预警→锁定→直线通场
	# 冲撞）。玩家放在锁定通道里站桩（距 BOSS 1400>贴脸窗 700，出招不被压），
	# 验冲撞掉血必须恰好=INTERCEPTOR_DIVE_DAMAGE。**单威胁源前置**（同 ch1
	# 重击探针规矩）：清掉场上杂兵（它们朝站桩玩家开火，1 伤/发污染断言）+
	# 等 BOSS 威胁弹（啸雷/直射曳光）排空再戳——上一手余弹落在基准血读取
	# 之后会抢跑（2026-10-22 踩：掉血 10/8 分别被误当冲撞，实为啸雷/曳光余弹）。
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
		if terrain != null:
			var lane_x := boss.global_position.x - 1400.0
			player.global_position = Vector2(lane_x,
					terrain.surface_y_at(lane_x) - 30.0)
			player.velocity = Vector2.ZERO
			for node in get_tree().get_nodes_in_group("enemies"):
				if node.is_in_group("boss"):
					continue # BOSS 也在 enemies 组（Enemy.on_spawned）：清场别误伤本体
				(node as Enemy).take_damage(999) # 单威胁源：杂兵清场
			waited = 0.0
			while waited < 8.0:
				var leftover := _count_projectiles(func(c: Node) -> bool:
					return c is FlakShell or (c is Bullet \
							and c.damage == BalanceCombat.BOSS_SWEEP_DAMAGE))
				# 双闸：容器干净 + BOSS 不在开火态（ST_FLAK_FIRE=4/ST_DIRECT=7，
				# 直射 0.085s/发，单查容器会采到两发之间的空隙误判排空）
				var quiet := leftover == 0 \
						and boss._bstate != 4 and boss._bstate != 7
				if quiet:
					break
				await _wait(0.2)
				waited += 0.2
			player.clear_hurt_window() # 量伤前清受击无敌窗（上一下的窗会吞掉/折扣这一下）
			var hp_pre_dive := player.hp
			boss._begin_skill_b()
			waited = 0.0
			while waited < 5.0 and player.hp >= hp_pre_dive:
				await _wait(0.1)
				waited += 0.1
			var dive_damage := hp_pre_dive - player.hp
			var dive_ok := dive_damage == BalanceWorld5.INTERCEPTOR_DIVE_DAMAGE
			await _screenshot("08c_interceptor_dive.png")
			print("[autotest] interceptor dive: hp ", hp_pre_dive, " -> ",
					player.hp, " damage=", dive_damage, " [",
					"OK" if dive_ok else "FAIL", " 应=", BalanceWorld5.INTERCEPTOR_DIVE_DAMAGE,
					"；少报=余弹抢跑/未中=查锁定校平账]")
	# 还原：结尾死亡探针要一刀必死
	player.hp = BalancePlayer.PLAYER_MAX_HP
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 失衡探针：加深×1.5 在前、减防御在后（10 → ceili(15)−5 = 10）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] interceptor stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch6 赤轮：镜像换边（斗轮毂心+炮座随 Visuals 换边；腹闸轴向居中判据）
## → 电网闸（自然首手，数 arc_fences 组）→ 凿岩齐射（确定性戳 _begin_skill_b：
## 单威胁源前置=清杂兵+等威胁件排空，玩家站走廊中心，掉血恰=CHARGE_DAMAGE）
## → 失衡加深（账同 ch2~ch5：加深×1.5 前置、防御 5 后置）。
func _probe_boss_redwheel(boss: BossRedwheel) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 给巨量血：赤轮轮换深（凿岩齐射排第二技能），站桩探针期全程吃抛石/电网/
	# 装药蹭血——回满 100 也扛不住 ~20s 磨血，玩家一死全局暂停冻结世界，
	# 后续探针全部落空（同灯笼鱼/截击机探针的教训）。探针收尾还原满血。
	player.hp = 99999
	# 朝向镜像探针：Visuals 整层换边——斗轮毂心与臂根（毂座）都换到玩家一侧；
	# 腹舱在机体中轴（局部 x=0），镜像后仍居中（≈0）。各归其位即证明挂件
	# 随整层镜像（背甲炮架偏侧 x=60，镜像后换边不单独断言）。
	var player_x_before_flip := player.global_position.x
	player.global_position = Vector2(boss.global_position.x + 420.0,
			player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.25)
	var rig: Node2D = boss.get_node("Visuals")
	var muzzle_x: float = (boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D) \
			.global_position.x
	var pivot_x: float = (boss.get_node("Visuals/ArmPivot") as Node2D) \
			.global_position.x
	var bay_x: float = (boss.get_node("Visuals/BayPort") as Node2D) \
			.global_position.x
	var flipped := rig.scale.x < 0.0 \
			and muzzle_x > boss.global_position.x \
			and pivot_x > boss.global_position.x \
			and absf(bay_x - boss.global_position.x) < 4.0
	await _screenshot("08c_boss_flip.png")
	print("[autotest] redwheel flip: ", "OK" if flipped else "FAIL",
			" rig_scale_x=", rig.scale.x,
			" muzzle-boss=", int(muzzle_x - boss.global_position.x),
			" pivot-boss=", int(pivot_x - boss.global_position.x),
			" bay-boss=", int(bay_x - boss.global_position.x),
			" (玩家在右侧时应换边：镜像−1、斗轮毂心/毂座>0、腹闸居中)")
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 电网闸：入场第一手（skill_a），贴脸压招解除后重走预警 → 落桩围栏；
	# hover 恒 370 不压高（同 ch2~ch5 的构图区别），数 arc_fences 组。
	await _wait(2.5)
	var fences := 0
	var waited := 0.0
	while waited < 12.0 and fences == 0:
		await _wait(0.1)
		waited += 0.1
		fences = get_tree().get_nodes_in_group("arc_fences").size()
	await _screenshot("08a_redwheel_fence.png")
	print("[autotest] redwheel fence: y=", int(boss.global_position.y),
			" arc_fences=", fences > 0, " count=", fences,
			" (电网闸期应 ≥1，锚桩在飞/电幕已立)")
	# 斗轮抛石（普攻）：电网后摇 1.3s 接普攻段——轮询等抛体弹石出膛（red_lob 以
	# REDWHEEL_LOB_DAMAGE 分辨；抛体飞 0.6~1.2s，0.1s 轮询稳逮到），截空中弧线帧。
	var lobs := 0
	waited = 0.0
	while waited < 8.0 and lobs == 0:
		await _wait(0.1)
		waited += 0.1
		lobs = _count_projectiles(func(c: Node) -> bool:
			return c is Bullet and c.damage == BalanceWorld6.REDWHEEL_LOB_DAMAGE)
	await _wait(0.25) # 石群出到半程再截：弧线在空中
	await _screenshot("08b_redwheel_lob.png")
	print("[autotest] redwheel lob: thrown=", lobs > 0, " count=", lobs,
			" (普攻段应抛出弹石群走弧线，非机枪短梭)")
	# 凿岩齐射：确定性戳 _begin_skill_b 走完整链路（腹舱预警→lead 走廊齐射→
	# 落地定延时起爆）。玩家站桩（距 BOSS 1400，出招不被贴脸窗压；站桩
	# lead=0→中央装药正落脚下）。验掉血必须恰好=REDWHEEL_CHARGE_DAMAGE。
	# **单威胁源前置**（同 ch1/ch5 规矩）：清掉场上杂兵 + 等威胁件（电网/
	# 装药/弹石）排空且 BOSS 回到 ENTER/RECOVER 稳态再戳——电网幕漏判会在
	# 基准血读取后抢跑（同为 10 伤无法区分，双闸必须连预警态一起避开）。
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
		if terrain != null:
			var lane_x := boss.global_position.x - 1400.0
			player.global_position = Vector2(lane_x,
					terrain.surface_y_at(lane_x) - 30.0)
			player.velocity = Vector2.ZERO
			for node in get_tree().get_nodes_in_group("enemies"):
				if node.is_in_group("boss"):
					continue # BOSS 也在 enemies 组（Enemy.on_spawned）：清场别误伤本体
				(node as Enemy).take_damage(999) # 单威胁源：杂兵清场
			waited = 0.0
			while waited < 8.0:
				var leftover := _count_projectiles(func(c: Node) -> bool:
					return c is ArcFence or c is DrillCharge or (c is Bullet \
							and c.damage == BalanceWorld6.REDWHEEL_LOB_DAMAGE))
				# 三闸：容器干净 + BOSS 回稳态（0=ENTER/1=RECOVER，预警态
				# 3/5 虽无弹但马上要出，一并避开）
				var quiet := leftover == 0 \
						and (boss._bstate == 0 or boss._bstate == 1)
				if quiet:
					break
				await _wait(0.2)
				waited += 0.2
			player.clear_hurt_window() # 量伤前清受击无敌窗（上一下的窗会吞掉/折扣这一下）
			var hp_pre_charge := player.hp
			boss._begin_skill_b()
			waited = 0.0
			while waited < 3.0 and get_tree().get_nodes_in_group("drill_charges").is_empty():
				await _wait(0.1)
				waited += 0.1
			await _wait(1.1) # 飞行 0.7 落地 + 引信中段：装药钉地红灯渐急帧
			await _screenshot("08c_redwheel_charge.png")
			waited = 0.0
			while waited < 6.0 and player.hp >= hp_pre_charge:
				await _wait(0.1)
				waited += 0.1
			var charge_damage := hp_pre_charge - player.hp
			var charge_ok := charge_damage == BalanceWorld6.REDWHEEL_CHARGE_DAMAGE
			print("[autotest] redwheel charge: hp ", hp_pre_charge, " -> ",
					player.hp, " damage=", charge_damage, " [",
					"OK" if charge_ok else "FAIL", " 应=", BalanceWorld6.REDWHEEL_CHARGE_DAMAGE,
					"；少报=余威胁抢跑/未中=查走廊落点与引信账]")
	# 还原：结尾死亡探针要一刀必死
	player.hp = BalancePlayer.PLAYER_MAX_HP
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 失衡探针：加深×1.5 在前、减防御在后（10 → ceili(15)−5 = 10）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] redwheel stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch7 沉锚：镜像换边（艏炮枢/管口随 Visuals 换边；艉舱口在舷侧 x=+86，
## 镜像后必须换到玩家对侧=轴向判据非居中）→ 跳弹齐射（自然首手，数
## skip_shells 组）→ 深弹涌浪（确定性戳 _begin_skill_b：单威胁源前置=清杂兵
## +等威胁件排空，玩家站**基准档低地**（脚底 664 > 水面 620 才吃——探针在
## BOSS 前方扫一段当地地表 ≥655 的低地落脚，找不到=地形账外，明说并跳过不
## 给假绿），掉血恰=SEA_SURGE_DAMAGE）→ 失衡加深（账同 ch2~ch6）。
func _probe_boss_anchor(boss: BossAnchor) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 给巨量血：沉锚轮换深（涌浪排第二技能），站桩探针期全程吃跳弹/直射蹭血
	# ——同赤轮/截击机探针的教训，玩家一死全局暂停冻结世界，后续探针全部落空。
	# 探针收尾还原满血。
	player.hp = 99999
	# 朝向镜像探针：Visuals 整层换边——艏炮枢/管口与艏部下管（鱼雷管）都换到
	# 玩家一侧；艉舱口（局部 x=+76）镜像后换到对侧（<0）。
	var player_x_before_flip := player.global_position.x
	player.global_position = Vector2(boss.global_position.x + 420.0,
			player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.25)
	var rig: Node2D = boss.get_node("Visuals")
	var muzzle_x: float = (boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D) \
			.global_position.x
	var pivot_x: float = (boss.get_node("Visuals/ArmPivot") as Node2D) \
			.global_position.x
	var bay_x: float = (boss.get_node("Visuals/BayPort") as Node2D) \
			.global_position.x
	var tube_x: float = (boss.get_node("Visuals/TorpedoPort") as Node2D) \
			.global_position.x
	var flipped := rig.scale.x < 0.0 \
			and muzzle_x > boss.global_position.x \
			and pivot_x > boss.global_position.x \
			and tube_x > boss.global_position.x \
			and bay_x < boss.global_position.x
	await _screenshot("08c_boss_flip.png")
	print("[autotest] anchor flip: ", "OK" if flipped else "FAIL",
			" rig_scale_x=", rig.scale.x,
			" muzzle-boss=", int(muzzle_x - boss.global_position.x),
			" pivot-boss=", int(pivot_x - boss.global_position.x),
			" tube-boss=", int(tube_x - boss.global_position.x),
			" bay-boss=", int(bay_x - boss.global_position.x),
			" (玩家在右侧时应换边：镜像−1、艏炮枢/管口/鱼雷管>0、艉舱口<0)")
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 跳弹齐射：入场第一手（skill_a），数 skip_shells 组（hover 恒 370 不压高，
	# 同 ch2~ch6 的构图区别）。
	await _wait(2.5)
	var skips := 0
	var waited := 0.0
	while waited < 12.0 and skips == 0:
		await _wait(0.1)
		waited += 0.1
		skips = get_tree().get_nodes_in_group("skip_shells").size()
	await _screenshot("08a_anchor_skip.png")
	print("[autotest] anchor skip: y=", int(boss.global_position.y),
			" skip_shells=", skips > 0, " count=", skips,
			" (跳弹齐射期应 ≥1，弹在飞/已落地弹跳)")
	# 深弹涌浪：确定性戳 _begin_skill_b 走完整链路（艉舱预警→深弹落海闷爆→
	# 涌浪漫桥）。玩家须站**会被淹的低地**（基准档 surface ≥655：脚底 664>水面
	# 620 才吃；找不到就借 p2 水面账 584 退而求二档 ≥590 的段并临时置
	# _phase2——涌浪对高处合法免伤，但探针必须真的吃到一口才算数）；
	# 掉血必须恰好=SEA_SURGE_DAMAGE。**单威胁源前置**（同 ch1/ch5/ch6 规矩）：
	# 清掉场上杂兵 + 等威胁件（跳弹/深弹/涌浪/直射）排空且 BOSS 回到
	# ENTER/RECOVER 稳态再戳——上一手的余弹抢跑会污染掉血断言。
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
		if terrain != null:
			var lane_x := -1.0
			var borrow_p2 := false
			for dx in range(800, 3200, 80): # 先找基准档（p1 水面 620 淹得到）
				var x := boss.global_position.x - float(dx)
				if terrain.surface_y_at(x) >= 655.0:
					lane_x = x
					break
			if lane_x < 0.0: # 退而求二档：借 p2 水面 584 的账（临时置 _phase2）
				for dx in range(800, 3200, 80):
					var x := boss.global_position.x - float(dx)
					if terrain.surface_y_at(x) >= 590.0:
						lane_x = x
						borrow_p2 = true
						break
			if lane_x < 0.0:
				print("[autotest] anchor surge: SKIP（BOSS 前方 3200px 内无 ≤二档低地，",
						"本次地形随机账外；涌浪对高处合法免伤）")
			else:
				var phase2_before: bool = boss._phase2
				if borrow_p2:
					boss._phase2 = true
				player.global_position = Vector2(lane_x,
						terrain.surface_y_at(lane_x) - 30.0)
				player.velocity = Vector2.ZERO
				for node in get_tree().get_nodes_in_group("enemies"):
					if node.is_in_group("boss"):
						continue # BOSS 也在 enemies 组（Enemy.on_spawned）：清场别误伤本体
					(node as Enemy).take_damage(999) # 单威胁源：杂兵清场
				waited = 0.0
				while waited < 10.0:
					var leftover := _count_projectiles(func(c: Node) -> bool:
						return c is SkipShell or c is DepthCharge or c is SeaSurge \
								or (c is Bullet \
								and c.damage == BalanceCombat.BOSS_SWEEP_DAMAGE))
					# 闸门：容器干净 + BOSS 回稳态（0=ENTER/1=RECOVER，预警态
					# 3/5 虽无弹但马上要出，一并避开）
					var quiet := leftover == 0 \
							and (boss._bstate == 0 or boss._bstate == 1)
					if quiet:
						break
					await _wait(0.2)
					waited += 0.2
				player.clear_hurt_window() # 量伤前清受击无敌窗（上一下的窗会吞掉/折扣这一下）
				var hp_pre_surge := player.hp
				boss._begin_skill_b()
				waited = 0.0
				while waited < 3.0 and get_tree().get_nodes_in_group("sea_surges").is_empty():
					await _wait(0.1)
					waited += 0.1
				await _wait(2.2) # 闷爆+涨潮+漫桥中段：水面应已压在桥面带上
				await _screenshot("08c_anchor_surge.png")
				waited = 0.0
				while waited < 4.0 and player.hp >= hp_pre_surge:
					await _wait(0.1)
					waited += 0.1
				var surge_damage := hp_pre_surge - player.hp
				var surge_ok := surge_damage == BalanceWorld7.SEA_SURGE_DAMAGE
				boss._phase2 = phase2_before # 借完 p2 水面账还原（下面失衡探针用本来相位）
				print("[autotest] anchor surge: hp ", hp_pre_surge, " -> ",
						player.hp, " damage=", surge_damage, " [",
						"OK" if surge_ok else "FAIL", " 应=", BalanceWorld7.SEA_SURGE_DAMAGE,
						"] lane_surface=", int(terrain.surface_y_at(lane_x)),
						" p2账=", borrow_p2,
						"；少报=余威胁抢跑/未中=查落点低地与水面账")
	# 还原：结尾死亡探针要一刀必死
	player.hp = BalancePlayer.PLAYER_MAX_HP
	player.global_position = Vector2(player_x_before_flip, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 失衡探针：加深×1.5 在前、减防御在后（10 → ceili(15)−5 = 10）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] anchor stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch8 盐磨：无镜像换边探针（镜阵翼枢/腹口都钉机体中轴 x=0，翻转不产生
## 轴向位移，断言不成立）→ 间歇泉幕（入场首手自然出招：玩家原地站桩=恰吃
## 一枚 mark 的汽柱 10；再戳一手、镖出膛后瞬移跑离=0——「离=唯一反制」）
## → 定镜灼烤（戳 _begin_skill_b：站桩吃首个 tick 恰 6 → 急停瞬移挪位后
## 不再掉血=「变速变向免」）→ **单威胁源排空把 mark/灼点连预警态算进
## quiet 判据**（ch6 教训④：驻留危险件+预警态一起排空）→ 失衡加深（账同
## ch2~ch7，hp=99999 贯穿收尾还原）。
func _probe_boss_saltmill(boss: BossSaltmill) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	# 给巨量血：站桩探针期全程吃泉幕/灼点/直射蹭血——玩家一死全局暂停冻结
	# 世界，后续探针全部落空（ch5/ch6/ch7 同教训）。探针收尾还原满血。
	player.hp = 99999
	var player_x_before_run := player.global_position.x # 收尾还原位（跑离/挪位都从这里推）
	# 单威胁源：清掉场上杂兵（BOSS 也在 enemies 组，别误伤本体）。
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.is_in_group("boss"):
			continue
		(node as Enemy).take_damage(999)
	# ---- 技能A·间歇泉幕：确定性戳招（入场首手不定时——入场收尾快时镖在
	#      探针动作前就出膛，观测窗口不稳；ch7 同款=先排空再戳）。站桩玩家
	#      恰在「身后 28」mark 的柱半宽内（|−28| < 45+26）→ 恰吃一枚 10 ----
	# 排空自然首手：威胁件出清 + BOSS 回稳态（0=ENTER/1=RECOVER）才动戳。
	var waited := 0.0
	while waited < 12.0:
		var leftover := _count_projectiles(func(c: Node) -> bool:
			return c is SaltDart or c is SaltGeyser or c is MirrorBurn \
					or (c is Bullet \
					and c.damage != BalancePlayer.PLAYER_BULLET_DAMAGE))
		var quiet := leftover == 0 \
				and (boss._bstate == 0 or boss._bstate == 1)
		if quiet:
			break
		await _wait(0.2)
		waited += 0.2
	for c in get_tree().get_nodes_in_group("salt_darts"):
		c.queue_free()
	for c in get_tree().get_nodes_in_group("salt_geysers"):
		c.queue_free()
	await _wait(0.2)
	player.velocity = Vector2.ZERO
	player.clear_hurt_window() # 量伤前清受击无敌窗（上一下的窗会吞掉/折扣这一下）
	var hp_pre_geyser := player.hp
	boss._begin_skill_a()
	var geysers := 0
	waited = 0.0
	while waited < 3.0 and geysers == 0:
		await _wait(0.1)
		waited += 0.1
		geysers = get_tree().get_nodes_in_group("salt_geysers").size()
	waited = 0.0
	while waited < 2.0 and player.hp >= hp_pre_geyser:
		await _wait(0.1)
		waited += 0.1
	# 掉血已确认=喷发进行中（柱寿 0.55s 窗口内）再截：柱必须满幅在画
	await _screenshot("08a_saltmill_geyser.png")
	var geyser_damage := hp_pre_geyser - player.hp
	print("[autotest] saltmill geyser: marks=", geysers,
			" hp ", hp_pre_geyser, " -> ", player.hp, " damage=", geyser_damage,
			" [", "OK" if geyser_damage == BalanceWorld8.SALT_GEYSER_DAMAGE else "FAIL",
			" 应=", BalanceWorld8.SALT_GEYSER_DAMAGE,
			"]（站桩=恰吃一枚 mark 的汽柱；跳≠过，离=唯一反制）")
	# ---- 技能A·跑离=免：再戳一手，镖出膛（mark 锚定）后瞬移跑离 500px，
	#      全部柱在原位喷发→不掉血 ----
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		waited = 0.0
		while waited < 10.0:
			var leftover := _count_projectiles(func(c: Node) -> bool:
				return c is SaltDart or c is SaltGeyser or c is MirrorBurn \
						or (c is Bullet \
						and c.damage != BalancePlayer.PLAYER_BULLET_DAMAGE))
			var quiet := leftover == 0 \
					and (boss._bstate == 0 or boss._bstate == 1)
			if quiet:
				break
			await _wait(0.2)
			waited += 0.2
		boss._begin_skill_a()
		waited = 0.0
		while waited < 2.0 and get_tree().get_nodes_in_group("salt_darts").is_empty():
			await _wait(0.1)
			waited += 0.1
		player.global_position = Vector2(player_x_before_run - 500.0,
				player.global_position.y)
		player.velocity = Vector2.ZERO
		await _wait(2.8) # 出膛+飞行+mark+喷发全程走完
		var run_damage := hp_pre_geyser - player.hp - geyser_damage
		print("[autotest] saltmill geyser run-away: damage=", run_damage,
				" [", "OK" if run_damage == 0 else "FAIL",
				"]（mark 锚定后跑离 500px：柱在原位喷发，应=0）")
	# ---- 技能B·定镜灼烤：两段账。①站桩吃首个 tick 恰 6（lead≈0 落脚下，
	#      停=吃 6/0.3s）；②「读线挪位」——每枚灼点出线后（光束线窗 0.4s）
	#      即挪开，梯次连点逐点躲=全章语言「变速变向」，余下 tick 全落空。
	#      注：只躲首枚不够——梯次连点本来就是压挪位的（第二枚 lead 取的是
	#      挪完后的新位置），逐点各躲各的才是机制正解。----
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		waited = 0.0
		while waited < 10.0:
			var leftover := _count_projectiles(func(c: Node) -> bool:
				return c is SaltDart or c is SaltGeyser or c is MirrorBurn \
						or (c is Bullet \
						and c.damage != BalancePlayer.PLAYER_BULLET_DAMAGE))
			var quiet := leftover == 0 \
					and (boss._bstate == 0 or boss._bstate == 1)
			if quiet:
				break
			await _wait(0.2)
			waited += 0.2
		var player_x_before_burn := player.global_position.x
		boss._begin_skill_b()
		waited = 0.0
		while waited < 2.5 and get_tree().get_nodes_in_group("mirror_burns").is_empty():
			await _wait(0.1)
			waited += 0.1
		await _wait(0.15) # 光束线驻留中段（蓄热窗 0.4s）
		await _screenshot("08b_saltmill_burn.png")
		player.clear_hurt_window() # 量伤前清受击无敌窗（上一下的窗会吞掉/折扣这一下）
		var hp_pre_burn := player.hp
		waited = 0.0
		while waited < 2.0 and player.hp >= hp_pre_burn:
			await _wait(0.1)
			waited += 0.1
		var burn_damage := hp_pre_burn - player.hp
		# 首枚已吃一口，先挪出它的 tick 区（0.9s/0.3s 还剩至多 3 拍要躲）。
		player.global_position = Vector2(player_x_before_burn + 500.0,
				player.global_position.y)
		player.velocity = Vector2.ZERO
		# ②逐点躲：每见一枚新灼点出线就再挪 500（出线判定=mirror_burns 计数
		# 增加），光束窗内挪开=该点落空；首枚已吃的一口不算躲账。
		var dodge_from := player_x_before_burn + 500.0
		var seen_burns := get_tree().get_nodes_in_group("mirror_burns").size()
		waited = 0.0
		while waited < 3.0:
			await _wait(0.1)
			waited += 0.1
			var now_burns := get_tree().get_nodes_in_group("mirror_burns").size()
			if now_burns > seen_burns:
				dodge_from += 500.0
				player.global_position = Vector2(dodge_from, player.global_position.y)
				player.velocity = Vector2.ZERO
				seen_burns = now_burns
			if now_burns == 0:
				break
		var burn_total := hp_pre_burn - player.hp
		print("[autotest] saltmill burn: first_tick=", burn_damage,
			" total_after_dodge_all=", burn_total,
			" [", "OK" if burn_damage == BalanceWorld8.MIRROR_BURN_DAMAGE
			and burn_total == BalanceWorld8.MIRROR_BURN_DAMAGE else "FAIL",
			" 应首 tick=", BalanceWorld8.MIRROR_BURN_DAMAGE, " 逐点躲后仍=",
			BalanceWorld8.MIRROR_BURN_DAMAGE,
			"]（停=吃 6/0.3s；读线逐点挪位=免）")
	# 还原：结尾死亡探针要一刀必死
	player.hp = BalancePlayer.PLAYER_MAX_HP
	player.global_position = Vector2(player_x_before_run, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(0.1)
	# 失衡探针：加深×1.5 在前、减防御在后（10 → ceili(15)−5 = 10）
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		await _screenshot("08e_boss_stagger.png")
		print("[autotest] saltmill stagger: staggered=", staggered,
				" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
				" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")


## ch9 引雷：autotest 段只做在场/接线冒烟（跨缆在场、针链在场+针数、失衡账），
## 躲法判据的确定性断言在本章独立探针 scenes/previews/probe_world_9.tscn。
func _probe_boss_conductor(boss: BossConductor) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	player.hp = 99999
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.is_in_group("boss"):
			continue
		(node as Enemy).take_damage(999)
	boss._bstate = PursuitBoss.ST_RECOVER
	boss._bt = 99.0
	for c in get_tree().get_nodes_in_group("live_spans") + get_tree().get_nodes_in_group("rod_chains"):
		c.queue_free()
	await _wait(0.3)
	boss._begin_skill_a()
	await _wait(1.0)
	var spans := get_tree().get_nodes_in_group("live_spans").size()
	await _screenshot("08a_conductor_span.png")
	print("[autotest] conductor span: live_spans=", spans, " [", "OK" if spans >= 1 else "FAIL",
			"]（跨缆网出膛应 ≥1 套）")
	await _wait(2.6)
	boss._bstate = PursuitBoss.ST_RECOVER
	boss._bt = 99.0
	boss._begin_skill_b()
	await _wait(1.6)
	var chains := get_tree().get_nodes_in_group("rod_chains")
	var rods := (chains[0] as RodChain).rod_xs.size() if not chains.is_empty() else 0
	await _screenshot("08b_conductor_rods.png")
	print("[autotest] conductor rods: chains=", chains.size(), " rods=", rods, " [",
			"OK" if rods >= BalanceWorld9.ROD_COUNT else "FAIL", "]（针链应 ≥", BalanceWorld9.ROD_COUNT, " 针）")
	await _wait(1.6)
	boss._bstate = PursuitBoss.ST_RECOVER
	boss._bt = 0.5
	player.hp = BalancePlayer.PLAYER_MAX_HP
	await _wait(0.1)
	if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
		boss.add_impact(999)
		await _wait(0.15)
		var staggered := boss.is_staggered()
		var ratio_pre := boss.hp_ratio()
		boss.take_damage(10)
		await _wait(0.05)
		var applied := roundi((ratio_pre - boss.hp_ratio()) * BalanceCombat.BOSS_MAX_HP)
		var expected := ceili(10 * BalanceCombat.STAGGER_DMG_MULT) - BalanceCombat.BOSS_DEFENSE
		print("[autotest] conductor stagger: staggered=", staggered, " take 10 -> ", applied,
				" [", "OK" if staggered and applied == expected else "FAIL", "] (失衡加深×防御应=", expected, ")")

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## 物理键码按键事件（键位探针用：走真实输入映射，不走动作名）。
func _key_event(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


## 敌方直接出手的弹/投放件（阵亡待机探针用：只认发射方出手的主件；次生件——
## 火区、地爆闪、深弹涌浪——由旧弹落地衍生，不算"又开火"）。
func _is_hostile_shot(c: Node) -> bool:
	if c is Bullet:
		return (c as Bullet).damage != BalancePlayer.PLAYER_BULLET_DAMAGE
	return c is HeavyMissile or c is MortarShell or c is PlasmaMine or c is CoralOrb \
			or c is CoralTide or c is FlakShell or c is ArcFence or c is SkipShell \
			or c is DrillCharge or c is DepthCharge or c is SaltDart 			or c is LiveSpan or c is RodChain or c is SulfurVent or c is SulfurCloud


## 弹容器里按谓词数弹（BOSS 探针用：扫射弹/导弹分类计数）。
func _count_projectiles(predicate: Callable) -> int:
	var container: Node = get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return 0
	var n := 0
	for c in container.get_children():
		if predicate.call(c):
			n += 1
	return n


func _screenshot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join(SHOTS_DIR).path_join(file_name))
	print("[autotest] saved ", file_name)
