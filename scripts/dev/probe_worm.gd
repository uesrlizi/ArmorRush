extends Node2D
## 第三章 BOSS·机械冰蠕「冰钻」探针（窗口小场景自退；不改本体场景，不进正常启动流程）：
##   godot --log-file autotest_worm.log res://scenes/previews/probe_worm.tscn
## 落地 world_3（交接路径跳启动页）→ 停刷清场=单威胁源 → 全部用例都在开局平地段
## [−640, 2560]（terrain.gd 段 −1/0 固定同档，g=600）里跑，输入按物理帧写死。
##   R  BOSS 名单登记表（纯 API，新实例化 RunState）：雪原登记两台、主位=哨兵、现抽两台都出、
##      打过的让位、RUSH 先抽 BOSS 再配场景（配的是该 BOSS 的登记场景、没打过的 BOSS 优先）；
##   S  出场：默认 debug_spawn_boss() 出主位哨兵；指定场景出冰钻；冰钻挂在地形后方容器、
##      全埋时不可索敌；
##   W  潜行航迹 / 各招巡览截图（跃袭 / 露头吐锥 / 横冲 / 失衡击出 / 死亡连锁爆）；
##   G  几何账：跃袭（站桩 0 / 满速跑被砸 18）、横冲（站桩被撞 18 / 推进升空 0）、
##      露头（站桩吃啄击 18 / 预告后离开 0）、露头位够得着地面近战（仰角 ≤28°、斩距内）、
##      露出才可打（子弹打得到露出的头、打不进地里）；
##   K 失衡=击出地面：露出时打满冲击→摔出地表滑到玩家脚下（身体摊地、头朝左、无接触伤）、
##      硬直到点入地；跃袭途中挨满的折回分支；
##   D 死亡：尾→头连锁爆、终爆时刻清场；
##   T 台阶地形烟测（探针注入高低档位）：三招+失衡在高低不平的地里都收得住。
## 探针坑规避：hp=99999；清杂兵跳过 boss 组；冻结窗=_bstate=RECOVER+_bt=99。
## 全过 ALL OK 退出码 0；有 FAIL 退出码 1；看门狗 300s 退出码 2（带窗截图多，跑 ~3.5 分钟）。

const DT := 1.0 / 60.0
const WORM := "res://scenes/units/boss_worm_3.tscn"
const WORLD := "res://scenes/world/world_3.tscn"

func _ready() -> void:
	var runner: Node = Runner.new()
	runner.name = "ProbeWormRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var _fails := 0
	var _windowed := false
	var _player: Player
	var _main: Node
	var _spawner: Spawner
	var _terrain: Terrain
	var _g := 600.0

	func _ready() -> void:
		_windowed = DisplayServer.get_name() != "headless"
		if OS.get_cmdline_user_args().has("minimized"):
			# 带窗但全程最小化（窗口不绘制）：复现「跑到一半窗口不再绘制」的退出路径用
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
			print("[probe_worm] TIMEOUT 300s")
			get_tree().quit(2))
		_run()

	func _check(ok: bool, label: String, detail := "") -> void:
		if not ok:
			_fails += 1
		print("[probe_worm] ", label, " [", "OK" if ok else "FAIL", "] ", detail)

	func _wait(sec: float) -> void:
		await get_tree().create_timer(sec, true, false, true).timeout

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().physics_frame

	func _shot(tag: String) -> void:
		if not _windowed:
			return
		await get_tree().process_frame
		await get_tree().process_frame
		# 窗口被最小化/遮住时引擎不出绘制帧：等一拍超时就跳过这张（别把整轮探针吊死在
		# frame_post_draw 上）；逻辑账不靠截图，无头照跑。
		var drawn := [false]
		RenderingServer.frame_post_draw.connect(func() -> void: drawn[0] = true, CONNECT_ONE_SHOT)
		var waited := 0
		while not drawn[0] and waited < 90:
			await get_tree().process_frame
			waited += 1
		if not drawn[0]:
			print("[probe_worm]   截图跳过（窗口未绘制）: ", tag)
			return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://autotest_shots"))
		get_viewport().get_texture().get_image().save_png("res://autotest_shots/worm_%s.png" % tag)

	func _hp() -> int:
		return _player.hp

	## 泄漏哨兵：每个套件收尾后等 2.5s（延迟释放/自清件走完），孤儿节点数必须回到开局基线
	## ——只涨不落=有节点没被释放（冰钻的特效件/本体哪条收尾路径漏了）。基线在「开局」记。
	var _orphans0 := 0

	func _leak(label: String) -> void:
		await _wait(2.5)
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		print("[probe_worm] 泄漏哨兵 %s: 孤儿节点=%d 节点总数=%d" % [label, orphans,
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
		_check(orphans == _orphans0, "L %s 套件收尾后无孤儿节点（=%d）" % [label, _orphans0],
				"orphans=%d" % orphans)

	func _leak_report(label: String) -> void:
		_orphans0 = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		print("[probe_worm] 泄漏哨兵 %s: 孤儿节点=%d 节点总数=%d" % [label, _orphans0,
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])

	func _run() -> void:
		RunState.start_run()
		RunState.mult_frozen = true
		RunState.loot_frozen = true
		RunState.hold_chapter = true
		RunState.begin_handoff()
		get_tree().change_scene_to_file(WORLD)
		await _wait(1.2)
		_main = get_tree().current_scene
		_player = get_tree().get_first_node_in_group("player") as Player
		_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
		if _player == null or _terrain == null or _main == null:
			_check(false, "S0 world_3 落地", "player=%s terrain=%s" % [_player, _terrain])
			get_tree().quit(1)
			return
		_spawner = _main.get_node("Spawner") as Spawner
		_spawner.stop()
		_player.auto_fire = false
		_player.hp = 99999
		_player.hurt_window_enabled = false # 几何探针：多段累计伤害账（N×单发）按无窗算
		var flat := true
		for x in range(-640, 2560, 32):
			if not is_equal_approx(_terrain.surface_y_at(float(x)), _g):
				flat = false
		_check(flat, "S1 开局平地段 [-640,2560] 同档 g=600（用例场地）")
		_leak_report("开局")
		await _registry_suite()
		await _leak("R 登记表")
		await _spawn_suite()
		await _leak("S 出场")
		await _tour()
		await _leak("W 巡览")
		await _geometry_suite()
		await _leak("G 几何")
		await _stagger_suite()
		await _leak("K 失衡")
		await _death_suite()
		await _leak("D 死亡")
		await _terrain_suite()
		await _leak("T 台阶")
		Input.action_release("move_right")
		Input.action_release("move_left")
		if _fails == 0:
			print("[probe_worm] ALL OK")
			get_tree().quit(0)
		else:
			printerr("[probe_worm] FAILS=%d" % _fails)
			get_tree().quit(1)

	## ---- R. 登记表（纯 API：新实例化 RunState，不碰游戏 autoload） ----
	func _registry_suite() -> void:
		var rs: Node = load("res://scripts/core/run_state.gd").new()
		var roster: Array[String] = rs.boss_roster(WORLD)
		_check(roster.size() == 2 and roster[0] == "res://scenes/units/boss_3.tscn" and roster[1] == WORM,
				"R1 雪原登记两台：主位=哨兵、次位=冰钻", str(roster))
		var ok_table := true
		var missing: Array[String] = []
		for w: String in rs.SCENES:
			if rs.boss_roster(w).is_empty():
				ok_table = false
			for b: String in rs.boss_roster(w):
				if not ResourceLoader.exists(b):
					missing.append(b)
		_check(ok_table and missing.is_empty(), "R2 每个在池场景都登记了 BOSS 且场景文件存在",
				"missing=%s" % [missing])
		var hosts: Array[String] = rs.boss_hosts(WORM)
		_check(hosts == [WORLD] and rs.all_bosses().size() == 11, "R3 冰钻的登记场景=雪原；在池 BOSS 共 11 台",
				"hosts=%s all=%d" % [hosts, rs.all_bosses().size()])
		rs._rng.seed = 7
		rs.start_run()
		var seen := {}
		for i in 400:
			var b: String = rs.draw_boss_for_world(WORLD)
			if not roster.has(b):
				seen["bad"] = true
			seen[b] = true
		_check(seen.size() == 2 and seen.has(roster[0]) and seen.has(roster[1]),
				"R4 现抽只出名单内两台、两台都出过（400 掷）", str(seen.keys()))
		# 打过的让位：新一局先打哨兵，下一抽必是冰钻；两台都打过=清账重抽（两台都可能再出）
		rs.start_run()
		var first_draw: String = rs.draw_boss_for_world(WORLD)
		var next_draw: String = rs.draw_boss_for_world(WORLD)
		var again := {}
		for i in 100:
			again[rs.draw_boss_for_world(WORLD)] = true
		_check(first_draw == "res://scenes/units/boss_3.tscn" and next_draw == WORM and again.size() == 2,
				"R5 本局已打过的让位：打过哨兵后下一抽必是冰钻；两台都打过才重抽",
				"first=%s next=%s again=%s" % [first_draw.get_file(), next_draw.get_file(), again.keys()])
		# RUSH：先抽 BOSS 再配场景
		var rush_ok := true
		var host_ok := true
		var fresh_ok := true
		var count_ok := true
		var pending_ok := true
		for trial in 120:
			var first: String = rs.start_run()
			var fought := {}
			fought[first] = true
			var prev := first
			for k in BalanceGlobal.RUN_NORMAL_LEVELS - 1:
				var s: String = rs.draw_next()
				if s == prev:
					rush_ok = false
				fought[s] = true
				rs.draw_boss_for_world(s) # 普通关落地后各自现抽一台
				prev = s
			var last: String = rs.draw_next() # 进 RUSH 的边界抽
			var lineup: Array[String] = [last]
			var bosses: Array[String] = [rs.pending_boss]
			for k in BalanceGlobal.RUN_RUSH_COUNT - 1:
				lineup.append(rs.draw_next())
				bosses.append(rs.pending_boss)
			for i in lineup.size():
				var s: String = lineup[i]
				var b: String = bosses[i]
				if not rs.boss_hosts(b).has(s):
					host_ok = false # 配的场景必须是这台 BOSS 的登记场景
				if fought.has(s) and rs.boss_hosts(b).any(func(h: String) -> bool: return not fought.has(h)):
					rush_ok = false # 有没去过的场景就不该重访
				if rs._fought.has(b) and rs.all_bosses().any(
						func(o: String) -> bool: return not rs._fought.has(o) and not bosses.has(o)):
					fresh_ok = false # 还有没打过的 BOSS 就不该抽打过的
			var uniq := {}
			for b in bosses:
				uniq[b] = true
			if uniq.size() != BalanceGlobal.RUN_RUSH_COUNT or lineup.size() != BalanceGlobal.RUN_RUSH_COUNT:
				count_ok = false
			if rs.draw_next() != "" or not rs.run_complete:
				count_ok = false
			# 取走即清
			rs.pending_boss = bosses[0]
			if rs.take_pending_boss() != bosses[0] or rs.take_pending_boss() != "":
				pending_ok = false
		_check(rush_ok and host_ok and fresh_ok and count_ok and pending_ok,
				"R6 RUSH 先抽 BOSS 再配场景：阵容不重复=%s 配的是登记场景=%s 没打过的优先=%s 台数/通关=%s 取即清=%s（120 局）"
				% [rush_ok, host_ok, fresh_ok, count_ok, pending_ok])
		rs.free()

	## ---- S. 出场 ----
	func _spawn_suite() -> void:
		var primary: Node2D = _spawner.debug_spawn_boss()
		var is_sentinel := primary is BossSentinel
		primary.queue_free()
		await _frames(2)
		_check(is_sentinel, "S2 默认 debug_spawn_boss() 出主位（哨兵）", primary.scene_file_path if primary != null else "null")
		# 现抽路径：定种子跑 60 次，两台都该出过（清场=直接释放，不走击杀：追击框架的死亡演出会
		# 预建 5 个小爆炸等定时器挂场，节点在定时器前被释放=5 个孤儿节点/台，正常游戏踩不到——
		# BOSS 死后活满 0.9s、转场更晚——但这轮压测会留 480 个孤儿，泄漏哨兵 S 段盯着）
		RunState._rng.seed = 11
		var got := {}
		for i in 60:
			var b: Node2D = _spawner.spawn_run_boss()
			if b == null:
				_check(false, "F1 战斗路径刷出 BOSS（刷不出=脚本没编译过）")
				break
			got[b.scene_file_path.get_file()] = true
			await _frames(1)
			b.queue_free()
			await _frames(2)
		_check(got.has("boss_3.tscn") and got.has("boss_worm_3.tscn"), "S3 战斗路径现抽两台都出过（60 次）",
				str(got.keys()))

	func _clear() -> void:
		var container := get_tree().get_first_node_in_group("projectile_container")
		if container != null:
			for c in container.get_children():
				if c is Bullet:
					c.queue_free()
		for n in get_tree().get_nodes_in_group("enemies"):
			if n.is_in_group("boss"):
				continue
			n.queue_free()

	func _stand(x: float) -> void:
		Input.action_release("move_right")
		Input.action_release("move_left")
		_key(false)
		_player.global_position = Vector2(x, _g - 30.0)
		_player.velocity = Vector2.ZERO
		_player.reset_physics_interpolation()
		await _frames(20)
		_player.velocity = Vector2.ZERO

	func _key(pressed: bool) -> void:
		var ev := InputEventAction.new()
		ev.action = &"jump"
		ev.pressed = pressed
		Input.parse_input_event(ev)

	## 刷冰钻、等入场潜行落定后冻在潜行态（只潜行不出招）。
	## 刷不出=脚本没编译过（转型失败）：后面用例全作废，直接判死退出（不许假通过）。
	func _worm() -> BossWorm:
		var w := _spawner.debug_spawn_boss(load(WORM)) as BossWorm
		if w == null:
			_check(false, "F0 冰钻刷出（脚本没编译过=后面用例全部作废）")
			printerr("[probe_worm] FAILS=%d" % _fails)
			get_tree().quit(1)
		await _wait(0.25)
		if w == null:
			return null
		w._bstate = PursuitBoss.ST_RECOVER # 入场即冻在潜行态（第一手跃袭还没排上）
		w._bt = 99.0
		await _wait(1.5)
		return w

	## 等到进入指定状态（超时返回 false）。
	func _await_state(w: BossWorm, state: int, limit := 300) -> bool:
		for i in limit:
			if w._bstate == state:
				return true
			await get_tree().physics_frame
		return w._bstate == state

	## 回到冻结的潜行态（上一手的余弹/特效清掉）。
	func _refreeze(w: BossWorm) -> void:
		_clear()
		w._bstate = PursuitBoss.ST_RECOVER
		w._bt = 99.0
		w._release_mound()
		await _frames(40)

	func _kill_worm(w: BossWorm) -> void:
		_clear()
		w._bstate = PursuitBoss.ST_RECOVER
		w._bt = 99.0
		w.take_damage(99999, true)
		await _wait(1.2)

	## ---- W. 巡览截图（按状态翻拍，不按死时间） ----
	func _tour() -> void:
		await _stand(0.0)
		var w := await _worm()
		_check(w.get_parent() == get_tree().get_first_node_in_group("burrow_container"),
				"S4 冰钻挂在地形后方容器 burrow_container（地下被地块盖住）",
				w.get_parent().name if w.get_parent() != null else "null")
		await _shot("01_cruise")
		_check(not w.is_targetable(), "S5 潜行（全埋）时不可索敌", "target_index=%d" % w._target_index)
		# 跃袭
		w._begin_skill_a()
		await _frames(24)
		await _shot("02_approach")
		await _await_state(w, BossWorm.ST_WINDUP)
		await _frames(18)
		await _shot("03_mound")
		await _await_state(w, BossWorm.ST_LEAP)
		await _frames(12)
		await _shot("03_leap_rise")
		await _frames(14)
		await _shot("04_leap_apex")
		await _frames(12)
		await _shot("05_leap_fall")
		await _frames(12)
		await _shot("06_leap_slam")
		await _frames(30)
		await _shot("07_leap_runout")
		# 露头吐锥
		await _refreeze(w)
		w._begin_direct()
		await _await_state(w, BossWorm.ST_REAR_RISE)
		await _frames(14)
		await _shot("08_rear_rise")
		await _await_state(w, BossWorm.ST_REAR_HOLD)
		await _frames(8)
		await _shot("09_rear_pose")
		await _frames(10)
		await _shot("10_rear_shards")
		await _await_state(w, BossWorm.ST_REAR_TELL)
		await _frames(14)
		await _shot("11_rear_tell")
		await _await_state(w, BossWorm.ST_REAR_PECK)
		await _frames(7)
		await _shot("12_rear_peck")
		await _frames(20)
		await _shot("13_rear_burrow")
		# 横冲
		await _refreeze(w)
		w._begin_skill_b()
		await _await_state(w, BossWorm.ST_WINDUP)
		await _frames(18)
		await _shot("14_sweep_mound")
		await _await_state(w, BossWorm.ST_SWEEP)
		await _frames(8)
		await _shot("15_sweep_out")
		await _frames(14)
		await _shot("16_sweep_pass")
		await _frames(14)
		await _shot("17_sweep_dive")
		await _wait(0.8)
		# 横冲二阶段：扎入后从地下甩回地表带位、高位回冲一趟再扎入
		await _refreeze(w)
		w._phase2 = true
		w._begin_skill_b()
		await _await_state(w, BossWorm.ST_SWEEP)
		await _frames(34)
		await _shot("17b_sweep_turn")
		await _frames(16)
		await _shot("17c_sweep_return")
		await _frames(16)
		await _shot("17d_sweep_return_pass")
		await _frames(16)
		await _shot("17e_sweep_dive2")
		await _wait(0.8)
		w._phase2 = false
		await _kill_worm(w)

	## ---- G. 几何账 ----

	## 一手招式的伤害账：t=0=调 _begin 的那一帧，记到招走完（回潜行态且场上没敌弹）为止；
	## on_state=进入某状态的那帧触发（输入按状态给，不按死帧数——各招都有地下接近段）。
	func _take(w: BossWorm, begin: Callable, on_state := {}) -> Dictionary:
		var hp0 := _hp()
		var container := get_tree().get_first_node_in_group("projectile_container")
		var left := false
		var settle := 0
		var frames := 0
		begin.call()
		for f in 480:
			frames = f
			await get_tree().physics_frame
			if on_state.has(w._bstate):
				(on_state[w._bstate] as Callable).call()
				on_state.erase(w._bstate)
			if w._bstate != PursuitBoss.ST_RECOVER:
				left = true
			var flying := false
			for c in container.get_children():
				if c is Bullet:
					flying = true
			if left and w._bstate == PursuitBoss.ST_RECOVER and not flying:
				settle += 1
				if settle > 3:
					break
			else:
				settle = 0
		Input.action_release("move_right")
		return {"dmg": hp0 - _hp(), "frames": frames}

	## 一手招式按状态分段记掉血（返回 {状态号: 该状态期间的掉血, "dmg": 总掉血}）；
	## on_state=进入某状态的那帧触发。招走完回潜行态、且场上冰锥飞尽了才收。
	func _take_states(w: BossWorm, begin: Callable, on_state := {}) -> Dictionary:
		var hp0 := _hp()
		var per := {}
		var last := -1
		var seg_hp := _hp()
		var settle := 0
		var container := get_tree().get_first_node_in_group("projectile_container")
		begin.call()
		for f in 420:
			await get_tree().physics_frame
			if w._bstate != last:
				if last >= 0:
					per[last] = seg_hp - _hp()
				last = w._bstate
				seg_hp = _hp()
				if on_state.has(last):
					(on_state[last] as Callable).call()
			var flying := false
			for c in container.get_children():
				if c is Bullet:
					flying = true
			if last == PursuitBoss.ST_RECOVER and not flying:
				settle += 1
				if settle > 3:
					break
			else:
				settle = 0
		if last >= 0:
			per[last] = seg_hp - _hp()
		per["dmg"] = hp0 - _hp()
		return per

	func _geometry_suite() -> void:
		var w := await _worm()
		# G1 跃袭 × 站桩：砸落点在身前 290，弧下站着=免
		await _stand(0.0)
		var r := await _take(w, w._begin_skill_a)
		_check(r["dmg"] == 0, "G1 跃袭×站桩 掉血 0", "dmg=%d frames=%d" % [r["dmg"], r["frames"]])
		await _frames(80)
		# G2 跃袭 × 满速跑：砸落点按跑速预测=被砸
		w._bstate = PursuitBoss.ST_RECOVER
		w._bt = 99.0
		await _frames(30)
		await _stand(-600.0)
		Input.action_press("move_right")
		var guard := 0
		while (_player.velocity.x < 599.0 or _player.global_position.x < -350.0) and guard < 300:
			await get_tree().physics_frame
			guard += 1
		r = await _take(w, w._begin_skill_a)
		_check(r["dmg"] == BalanceWorld3.WORM_RAM_DAMAGE, "G2 跃袭×满速跑 被砸 18", "dmg=%d px=%.0f" % [r["dmg"], _player.global_position.x])
		await _frames(80)
		# G3 横冲 × 站桩：通场带盖站立=被撞
		w._bstate = PursuitBoss.ST_RECOVER
		w._bt = 99.0
		await _frames(30)
		await _stand(0.0)
		r = await _take(w, w._begin_skill_b)
		_check(r["dmg"] == BalanceWorld3.WORM_RAM_DAMAGE, "G3 横冲×站桩 被撞 18", "dmg=%d frames=%d" % [r["dmg"], r["frames"]])
		await _frames(60)
		# G4 横冲 × 预警期起跳推进：离地超带=免
		w._bstate = PursuitBoss.ST_RECOVER
		w._bt = 99.0
		await _frames(30)
		await _stand(0.0)
		r = await _take(w, w._begin_skill_b, {
			BossWorm.ST_WINDUP: func() -> void: _key(true), # 隆起预警一亮就起跳推进、按住不放
		})
		_key(false)
		_check(r["dmg"] == 0, "G4 横冲×预警期起跳按住 掉血 0", "dmg=%d frames=%d" % [r["dmg"], r["frames"]])
		await _frames(60)
		# G5 露头 × 站桩（受击窗照常：一轮三连只结算一发 6）：吐锥期吃 6~12、啄击期 ≥12
		#    （啄击 18；窗内先擦到冰锥则只补差价）；G6 口部闪光那一拍起跑：啄击期 0
		_player.hurt_window_enabled = true
		await _refreeze(w)
		await _stand(0.0)
		var per := await _take_states(w, w._begin_direct)
		var hold_dmg: int = per.get(BossWorm.ST_REAR_HOLD, 0)
		var peck_dmg: int = per.get(BossWorm.ST_REAR_PECK, 0)
		_check(hold_dmg == 6 or hold_dmg == 12, "G5a 露头×站桩 吐锥期吃 6~12（每轮结算一发）", "hold=%d" % hold_dmg)
		_check(peck_dmg >= 12, "G5b 露头×站桩 啄击期 ≥12（站原地=吃）", "peck=%d all=%s" % [peck_dmg, per])
		await _refreeze(w)
		await _stand(0.0)
		per = await _take_states(w, w._begin_direct, {
			BossWorm.ST_REAR_TELL: func() -> void: Input.action_press("move_right"),
		})
		Input.action_release("move_right")
		peck_dmg = per.get(BossWorm.ST_REAR_PECK, 0)
		_check(peck_dmg == 0, "G6 露头×口部闪光即起跑 啄击期 0", "peck=%d all=%s" % [peck_dmg, per])
		# G9 横冲二阶段 × 站桩：只吃去程一下 18（一次招式至多一下；高位回冲本就碰不到贴地的人）
		await _refreeze(w)
		w._phase2 = true
		await _stand(0.0)
		r = await _take(w, w._begin_skill_b)
		_check(r["dmg"] == BalanceWorld3.WORM_RAM_DAMAGE, "G9 横冲二阶段×站桩 只吃去程 18",
				"dmg=%d frames=%d" % [r["dmg"], r["frames"]])
		# G10 横冲二阶段 × 躲过去程后悬在低空：高位回冲撞到——「先升后降」的「后降」
		await _refreeze(w)
		await _stand(0.0)
		var hp0 := _hp()
		w._begin_skill_b()
		var sw := -1
		var held := false
		var lanes := {}
		for i in 520:
			await get_tree().physics_frame
			if w._bstate == BossWorm.ST_WINDUP and not held:
				_key(true) # 预警一亮就起跳推进按住：去程（低带）从脚下过去
				held = true
			if w._bstate == BossWorm.ST_SWEEP:
				sw += 1
				lanes[w._sweep_lane] = true
				if sw == 30:
					# 去程（低带）从脚下过去后松手下落：抛物线在 ~[1.2s, 1.7s] 穿过高位带 [95,275]，
					# 回冲 ~1.45s 掠过——「正赶在它回冲时往下落」=吃；早落回地面/一直悬在高处=免
					_key(false)
					held = false
			if sw > 0 and w._bstate == PursuitBoss.ST_RECOVER:
				break
		if held:
			_key(false)
		w._phase2 = false
		_check(lanes.size() == 2 and hp0 - _hp() == BalanceWorld3.WORM_RAM_DAMAGE,
				"G10 横冲二阶段×升空躲过去程后落到低空 被回冲撞 18（两趟带位不同）",
				"dmg=%d lanes=%s sw=%d" % [hp0 - _hp(), lanes.keys(), sw])
		# G7 露头位够得着地面近战：头在玩家右前方、仰角 ≤28°（斩距内一冲即到）、可索敌
		# G8 露头期贴身无接触伤：受击窗照常——冰锥一帧至多掉 6，单帧掉 ≥12 只可能是接触伤（18）
		await _refreeze(w)
		await _stand(0.0)
		w._begin_direct()
		var pose_ok := false
		var contact_hit := false
		var was_hold := false
		var hp_hold := _hp()
		for i in 400:
			await get_tree().physics_frame
			if w._bstate == BossWorm.ST_REAR_HOLD:
				if not was_hold:
					var aim0: Vector2 = w.aim_point()
					var dx := aim0.x - _player.global_position.x
					var pitch := rad_to_deg(atan2(-(aim0.y - _player.global_position.y), maxf(dx, 1.0)))
					pose_ok = w.is_targetable() and dx > 0.0 and dx <= 700.0 \
							and pitch <= BalancePlayer.MELEE_PITCH_MAX_DEG and w._ram_hit
					print("[probe_worm]   露头位: 头在玩家右 %.0fpx、仰角 %.1f°" % [dx, pitch])
				was_hold = true
				_player.global_position = Vector2(w.global_position.x - 120.0, _g - 30.0) # 贴到头边站着
				_player.velocity = Vector2.ZERO
				var loss := hp_hold - _hp()
				if loss >= 12:
					contact_hit = true
				hp_hold = _hp()
			elif was_hold:
				break
		_player.hurt_window_enabled = false
		_check(pose_ok, "G7 露头位够得着地面近战（仰角 ≤28°、在玩家右前方、可索敌）")
		_check(not contact_hit, "G8 露头期贴身无接触伤")
		await _kill_worm(w)

	## ---- K. 失衡=击出地面 ----
	func _stagger_suite() -> void:
		await _stand(0.0)
		var w := await _worm()
		# 先让它露头，再在露出时打满冲击
		w._bstate = PursuitBoss.ST_RECOVER
		w._bt = 99.0
		await _frames(10)
		w._begin_direct()
		for i in 400:
			await get_tree().physics_frame
			if w._bstate == BossWorm.ST_REAR_HOLD:
				break
		w.add_impact(9999.0)
		await _frames(2)
		var knocked := w.is_staggered() and w._bstate == BossWorm.ST_KO_OUT
		_check(knocked, "K1 露出时打满冲击→击出（ST_KO_OUT）", "state=%d" % w._bstate)
		await _wait(0.22)
		await _shot("17_knockout")
		await _await_state(w, BossWorm.ST_KO_REST, 200)
		var resting := w._bstate == BossWorm.ST_KO_REST
		var head := w.global_position
		var ground := _terrain.surface_y_at(head.x)
		var player := _player.global_position
		var near := head.x - player.x >= -170.0 and head.x - player.x <= 800.0
		_check(resting and head.y < ground - 20.0 and near,
				"K2 瘫在地上：头在地上、停在玩家身边（左 170..右 800 内=贴脸近战）",
				"state=%d head=(%.0f,%.0f) g=%.0f px=%.0f" % [w._bstate, head.x, head.y, ground, player.x])
		var facing_left := absf(wrapf(w._head_angle - PI, -PI, PI)) < deg_to_rad(60.0)
		_check(facing_left, "K3 瘫倒时头朝左（脸对着玩家）", "deg=%.0f" % rad_to_deg(w._head_angle))
		# 瘫地姿态=身体摊在地上：露出的体节数 ≥ 头+3 节（前身跟着滑行段落到地面）
		var exposed := 0
		for e in w._seg_exposed:
			if e:
				exposed += 1
		_check(exposed >= 9, "K3b 瘫地时身体整条摊在地上（12 节露出 ≥9）", "exposed=%d" % exposed)
		var hp0 := _hp()
		_player.global_position = w.global_position + Vector2(-40.0, 0.0)
		_player.velocity = Vector2.ZERO
		await _frames(40)
		_check(_hp() == hp0, "K4 瘫地期贴身无接触伤")
		_check(w.is_targetable(), "K5 瘫地期可索敌（近战爆发窗）")
		await _shot("18_ko_rest")
		# 硬直到点→入地→回潜行
		var buried_after := false
		for i in 600:
			await get_tree().physics_frame
			if w._bstate == PursuitBoss.ST_RECOVER:
				buried_after = true
				break
		_check(buried_after and not w.is_staggered(), "K6 硬直到点→入地→回潜行")
		await _frames(60)
		# K7 跃袭途中（头在玩家身后上空、航向朝上）挨满：冲过头折回，同样滑到玩家身边、头朝左
		await _refreeze(w)
		await _stand(0.0)
		w._begin_skill_a()
		for i in 300:
			await get_tree().physics_frame
			if w._bstate == BossWorm.ST_LEAP and w.global_position.y < _g - 150.0:
				break
		var behind := w.global_position.x < _player.global_position.x
		w._impact_lock_t = 0.0 # 上一次失衡的免疫期还没走完：探针手动清掉
		w.add_impact(9999.0)
		await _await_state(w, BossWorm.ST_KO_REST, 300)
		head = w.global_position
		player = _player.global_position
		facing_left = absf(wrapf(w._head_angle - PI, -PI, PI)) < deg_to_rad(70.0)
		_check(behind and w._bstate == BossWorm.ST_KO_REST \
				and head.x - player.x >= -170.0 and head.x - player.x <= 800.0 and facing_left,
				"K7 跃袭途中（身后上空）挨满→冲过头折回瘫落：头滑到玩家身边、朝左",
				"state=%d head=(%.0f,%.0f) px=%.0f deg=%.0f" % [w._bstate, head.x, head.y, player.x, rad_to_deg(w._head_angle)])
		await _shot("18b_ko_rest_leap")
		for i in 600:
			await get_tree().physics_frame
			if w._bstate == PursuitBoss.ST_RECOVER:
				break
		await _kill_worm(w)

	## ---- D. 死亡连锁爆 ----
	func _death_suite() -> void:
		await _stand(0.0)
		var w := await _worm()
		var container := get_tree().get_first_node_in_group("projectile_container")
		# 等它露出时再杀（露出部分的节原地爆）
		w._begin_direct()
		for i in 400:
			await get_tree().physics_frame
			if w._bstate == BossWorm.ST_REAR_HOLD:
				break
		var booms0 := 0
		for c in container.get_children():
			if c is ExplosionBurst:
				booms0 += 1
		var id := w.get_instance_id()
		w.take_damage(99999, true)
		# 连锁从尾（多埋着=地表代爆）往头（露着=原地爆）走：0.66s 时露出的中段正在逐节爆
		await _wait(0.66)
		await _shot("19_death_chain")
		var booms1 := 0
		for c in container.get_children():
			if c is ExplosionBurst:
				booms1 += 1
		_check(booms1 > booms0, "D1 死亡连锁爆逐节出爆（露出的节原地爆）", "booms %d→%d" % [booms0, booms1])
		await _wait(0.4)
		var gone := not is_instance_valid(w) or w.get_instance_id() != id
		_check(gone, "D2 终爆后本体清场")
		var leftover := 0
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is BossWorm:
				leftover += 1
		_check(leftover == 0, "D3 enemies/boss 组无残留")
		await _shot("20_death_finale")

	## ---- T. 台阶地形烟测：探针注入档位函数（中/高/低交错），三招 + 失衡各走一遍都收得回潜行，
	## 且落点离墙余量成立（破土/砸落点不贴更高的邻块——贴墙冒头身子会嵌进台阶侧壁） ----
	func _terrain_suite() -> void:
		_terrain.probe_tier_fn = func(i: int) -> int:
			return [1, 2, 0, 1, 1, 2, 0, 2][posmod(i, 8)]
		_terrain.probe_rebuild()
		await _frames(10)
		_check(not is_equal_approx(_terrain.surface_y_at(400.0), _terrain.surface_y_at(100.0)),
				"T0 台阶地形已生效（x=100 与 x=400 不同档）",
				"g(100)=%.0f g(400)=%.0f" % [_terrain.surface_y_at(100.0), _terrain.surface_y_at(400.0)])
		await _stand(0.0)
		var w := await _worm()
		var stuck := ""
		var walled := ""
		var names := ["跃袭", "露头", "横冲二阶段"]
		for m in 3:
			await _refreeze(w)
			await _stand(0.0)
			w._phase2 = m == 2
			match m:
				0:
					w._begin_skill_a()
				1:
					w._begin_direct()
				2:
					w._begin_skill_b()
			var done := false
			var shot_windup := false
			var move_frames := -1
			var arc_shots := 0
			for i in 640:
				await get_tree().physics_frame
				if not shot_windup and w._bstate == BossWorm.ST_WINDUP:
					shot_windup = true
					if not _off_walls(w._plan_point):
						walled += "%s(破土点 x=%.0f) " % [names[m], w._plan_point.x]
					await _frames(16)
					await _shot("t%d_steps_windup" % (m + 1))
				if shot_windup and move_frames < 0 \
						and w._bstate in [BossWorm.ST_LEAP, BossWorm.ST_REAR_HOLD, BossWorm.ST_SWEEP]:
					move_frames = 0
					if m == 0 and not _off_walls(w._slam_point):
						walled += "%s(砸落点 x=%.0f) " % [names[m], w._slam_point.x]
				if move_frames >= 0:
					move_frames += 1
					# 跃袭拍两帧（破土上升/过顶），露头拍定住位，横冲拍通场
					var at: int = 12 if m == 0 else 6
					if (m == 0 and (move_frames == at or move_frames == 30) or (m > 0 and move_frames == at)):
						arc_shots += 1
						await _shot("t%d_steps_move%d" % [m + 1, arc_shots])
				if i > 0 and w._bstate == PursuitBoss.ST_RECOVER:
					done = true
					break
			if not done:
				stuck += names[m] + " "
			await _frames(20)
		_check(stuck.is_empty(), "T1 台阶地形上三招都收得回潜行", "stuck=%s" % stuck)
		_check(walled.is_empty(), "T1b 台阶地形上破土/砸落点离「更高的邻块」≥ 离墙余量", "walled=%s" % walled)
		# 失衡击出 + 入地
		await _refreeze(w)
		await _stand(0.0)
		w._phase2 = false
		w._begin_direct()
		for i in 400:
			await get_tree().physics_frame
			if w._bstate == BossWorm.ST_REAR_HOLD:
				break
		w.add_impact(9999.0)
		var rested := await _await_state(w, BossWorm.ST_KO_REST, 240)
		await _shot("t4_steps_ko")
		var head := w.global_position
		var on_ground := absf(head.y - (_terrain.surface_y_at(head.x) - BalanceWorld3.WORM_REST_HEIGHT)) < 6.0
		var back := false
		for i in 700:
			await get_tree().physics_frame
			if w._bstate == PursuitBoss.ST_RECOVER:
				back = true
				break
		_check(rested and on_ground and back, "T2 台阶地形上失衡瘫落贴当地地表、入地回潜行",
				"rested=%s on_ground=%s back=%s head=(%.0f,%.0f) g=%.0f" % [rested, on_ground, back,
				head.x, head.y, _terrain.surface_y_at(head.x)])
		await _kill_worm(w)
		_terrain.probe_tier_fn = Callable()
		_terrain.probe_rebuild()
		await _frames(10)

	## 落点离墙判定（与 BossWorm._off_walls 同一账）：点所在块的两邻块若更高，点到那侧块边
	## 的距离须 ≥ WORM_WALL_MARGIN。
	func _off_walls(p: Vector2) -> bool:
		var cw := BalanceGlobal.TERRAIN_CHUNK_WIDTH
		var ci := floori(p.x / cw)
		if _terrain.surface_y_at(p.x - cw) < p.y - 1.0 and p.x - ci * cw < BalanceWorld3.WORM_WALL_MARGIN - 0.5:
			return false
		if _terrain.surface_y_at(p.x + cw) < p.y - 1.0 and (ci + 1) * cw - p.x < BalanceWorld3.WORM_WALL_MARGIN - 0.5:
			return false
		return true
