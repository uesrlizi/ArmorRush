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

	# 开机亮屏：首启也从全黑渐亮（0.2s 时约半亮），先截中间帧再走启动页探针。
	# 黑屏在全局 Fade autoload 层：场景重载的空档帧它仍全盖着，不闪清屏色。
	await _wait(0.2)
	await _screenshot("00a_boot.png")
	print("[autotest] boot fade alpha=", Fade._rect.modulate.a,
			" (全局转场层渐亮中应≈0.3~0.6, visible=", Fade._rect.visible, ")")
	var cam: Camera2D = player.get_node("Camera2D")
	var cam_target := Vector2(player.global_position.x + Balance.CAMERA_X_OFFSET,
			Balance.CAMERA_Y)
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
				and absf(player.velocity.x) > Balance.SLIDE_SPARK_MIN_SPEED:
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

	# 行进间走射为主 + 单次跳射过掩体：地面高度子弹才能命中站桩敌人。
	Input.action_press("fire")
	for i in 4:
		Input.action_press("move_right")
		await _wait(0.9)
		Input.action_release("move_right")
		await _wait(0.25)
		Input.action_press("jump")
		await _wait(0.1)
		Input.action_release("jump")
		await _wait(0.55)
	Input.action_release("fire")
	Input.action_release("move_right")
	await _screenshot("04_combat.png")

	# 确定性探针：把玩家传送回出生点附近（世界原点进画面）再刷靶开火——
	# 迸溅粒子若喷在容器原点（=出生点上空）当场可见；正常则应在弹着点。
	# 首发命中瞬间截帧 + 0.12s 后粒子飞离焰心再截一张对比。
	player.global_position = Vector2(300, 500)
	player.velocity = Vector2.ZERO
	await _wait(0.25) # 落地 + 镜头平滑跟上
	var score_before: int = get_parent().score
	var probe_target: Enemy = spawner.debug_spawn_enemy(player.global_position.x + 260.0)
	if probe_target != null:
		await _wait(0.05)
		Input.action_press("fire")
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
		Input.action_release("fire")
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
	# 时序对齐 Balance（用户手调值）：闲置前摇 0.2 → 追击 1 帧 → 斩击 0.12；
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

	# ---- 精英探针：拉一只导弹车，验证枪口预警后出真追踪导弹（爆伤组件 BOSS 探针已覆盖） ----
	# 齐射触发是半衰期掷骰（平均 ~3.2s 一轮）+ 蓄力 0.5s，12s 窗口覆盖 ~98%。
	var elite: EliteMortar = spawner.debug_spawn_elite(player.global_position.x + 500.0)
	if elite != null:
		var saw_missile := false
		waited = 0.0
		while waited < 12.0 and not saw_missile:
			await _wait(0.1)
			waited += 0.1
			saw_missile = _count_projectiles(func(c: Node) -> bool:
				return c is HeavyMissile) > 0
		await _screenshot("07_elite_volley.png")
		print("[autotest] elite tracking missile: ", saw_missile,
				" (导弹车在场应出真追踪导弹)")
		if is_instance_valid(elite) and elite.hp_ratio() > 0.0:
			elite.take_damage(999) # 探针结束即击杀：别让它的追踪导弹蹭进 BOSS 段

	# ---- BOSS 探针：不等距离直接拉一场追击，验证入场/扫射机动/导弹雨/球状爆区伤 ----
	# 时序账：ENTER 0.9 → SWEEP(压高 ~0.45 + 蓄力 0.35 + 3波×0.55) → 后摇 1.2
	# → DIRECT 0.5(普攻) → 后摇 0.9 → RAIN(蓄力 0.5 + 首发)：拉怪到首轮出弹 ≈ 6.5s。
	var boss: Boss = spawner.debug_spawn_boss()
	if boss != null:
		var hp_before_boss := player.hp
		await _wait(1.0) # 入场滑入完毕，血条/WARNING 应已亮
		await _screenshot("08_boss_enter.png")
		print("[autotest] boss engaged: alive=", is_instance_valid(boss)
				and boss.hp_ratio() > 0.0,
				" boss_bar=", get_parent().get_node("HUD")._boss_bar.visible,
				" warning=", get_parent().get_node("HUD")._warning_label.visible,
				" (入场后均应=true)")
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
			return c is Bullet and c.damage == Balance.BOSS_SWEEP_DAMAGE)
		await _screenshot("08b_boss_sweep.png")
		print("[autotest] boss sweep: y=", int(boss.global_position.y),
				" bullets_on_screen=", sweep_bullets,
				" (射高 ~390 且开火期应 ≥1)")
		# 导弹雨：轮询等追踪导弹出膛，截飞行帧；站桩→瞄脚底必爆脚边 → 验掉血。
		# 首发命中就收账并击杀 BOSS 快进——站桩吃整轮雨会打死玩家，污染后面的死亡探针。
		var missiles := 0
		waited = 0.0
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
			var applied := roundi((ratio_pre - boss.hp_ratio()) * Balance.BOSS_MAX_HP)
			var expected := ceili(10 * Balance.STAGGER_DMG_MULT) - Balance.BOSS_DEFENSE
			await _screenshot("08e_boss_stagger.png")
			print("[autotest] boss stagger: staggered=", staggered,
					" impact_bar=", get_parent().get_node("HUD")._boss_impact_bar.visible,
					" take 10 -> ", applied, " (失衡加深×防御应=", expected, ")")
		# 立刻击杀快进：站桩吃整轮雨会被追踪导弹打死，污染后面的死亡探针。
		# 此刻已出膛的 ≤2 发仍会命中（≤40 伤），玩家活。击杀触发击败回血，
		# 击杀瞬间的差值=回血量（可能抵掉已吃的伤）。
		var hp_before_kill := player.hp
		if is_instance_valid(boss) and boss.hp_ratio() > 0.0:
			boss.take_damage(999)
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

	# 死亡 → 玩家爆炸演出（GAME_OVER_DELAY=1.1s 内世界照跑）→ 定格暂停 → 按 R 重开。
	# （无敌帧已移除：一刀必死。重载会释放本节点，收尾交给树级定时器。）
	player.take_damage(999)
	await _wait(0.15) # 爆炸白闪+火球进行中
	await _screenshot("07_player_explosion.png")
	await _wait(1.15) # 越过 GAME_OVER_DELAY：演出播完才暂停
	print("[autotest] game over, paused=", get_tree().paused)
	await _screenshot("07_game_over.png")
	await _wait(0.5) # 结算防抖（RESTART_DEBOUNCE_MS=400，从定格起算）：一出结算就按键会被挡
	# 重开=任意键（结算画面）：用 N 键（不映射任何动作）验证非 R 也能重开。
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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
