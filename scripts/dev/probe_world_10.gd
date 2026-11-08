extends Node2D
## 第十章「硫焰地热田」威胁探针（窗口小场景自退；不改本体场景，不进正常启动流程）：
##   godot --log-file autotest_w10.log res://scenes/previews/probe_world_10.tscn
## 落地 world_10（交接路径跳启动页）→ 停刷清场=单威胁源 → 地形一律注入固定 tier 序列
## （Terrain.probe_tier_fn，R13），脚手架=停刷后清空（需要时探针自己放），x 判据写相对
## 出手帧 px 的偏移，允差 ±1 物理帧位移；输入按物理帧写死。
## 判据正本=art_proposals/sulfur_ch10/威胁设计_ch10.md + 终审 R1–R17：
##   E  精英「窜井」：lead=px+1440/origin.y=g/ThreatFlash 同帧亮；息窗中点穿 0；第二喷
##      穿恰 10；亮井期站井心 0；R10 边界避让 +96 与脚手架取消；冷却闸 ≤1；
##   BA BOSS 井压线：三口 px+1440/1800/2160、首喷 2.3/2.9/3.5；盲冲 30；绿波 0；
##      3.2 起步 30；亮井期站井心 0；R11 闪烁单调+至多一口封顶；R10 脚手架取消 k=1
##      其余口不变；冷却=单套寿命内不重铺；
##   BB BOSS 硫云爆燃：带 y 恒 [428,512]、xL 满速 px+600/站桩 px、火锋公式；全程 tier2
##      满速贴地 12、1.7 起跳 12、站桩 12；点燃前/燃完后 0；派招闸（全程 tier1/tier0 连续
##      3 轮改派 A；tier2 只在 px+640..960 → R16 改派 A）；force_cast_b 下 tier1/tier0
##      满速贴地 0、推进飞越（tier1 1.3 起跳 / tier2 1.5 起跳，按住 1.2s）0；
##   SW BOSS 硫焰扫掠：起点=NozzlePort（y=424）、方向恒定；站桩 21；前冲 7；满速保持 0；
##      满速即刹 14；单轮 ≤48；R9 tier0+前方 tier2 台阶抬角表+弹体入地帧数 0。
## 探针坑规避：hp=99999；清杂兵跳过 boss 组；BOSS 冻结窗=_bstate=RECOVER+_bt=99；
## BOSS 构图位逐帧钉在玩家 +偏移、y=370（防贴脸压招、去呼吸浮动）；按伤害值分辨弹种前
## 已单威胁源；已 queue_free 的件只读快照。
## 全过 ALL OK 退出码 0；有 FAIL 退出码 1；看门狗 300s 退出码 2。

func _ready() -> void:
	var runner: Node = Runner.new()
	runner.name = "ProbeWorld10Runner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	const DT := 1.0 / 60.0
	var _fails := 0
	var _windowed := false
	var _player: Player
	var _main: Node
	var _spawner: Spawner
	var _terrain: Terrain
	var _boss: BossWellhead
	var _pin_boss := false
	var _pin_off := 1400.0
	var _g := 600.0
	var _tier := 1

	func _ready() -> void:
		_windowed = DisplayServer.get_name() != "headless"
		get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
			print("[autotest] w10 TIMEOUT 300s")
			get_tree().quit(2))
		get_tree().physics_frame.connect(_on_physics)
		_run()

	func _on_physics() -> void:
		if _boss == null or not is_instance_valid(_boss):
			return
		if _boss._bstate == PursuitBoss.ST_RECOVER:
			_boss._bt = 99.0 # 冻结窗：只倒数不出招
		if _pin_boss and is_instance_valid(_player):
			_boss.global_position = Vector2(_player.global_position.x + _pin_off,
					BalanceWorld10.WELLHEAD_HOVER_Y)
			_boss._vel = Vector2(_player.velocity.x, 0.0)

	func _check(ok: bool, label: String, detail := "") -> void:
		if not ok:
			_fails += 1
		print("[autotest] w10 ", label, " [", "OK" if ok else "FAIL", "] ", detail)

	func _wait(sec: float) -> void:
		await get_tree().create_timer(sec, true, false, true).timeout

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().physics_frame

	func _shot(tag: String) -> void:
		if not _windowed:
			return
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://autotest_shots"))
		get_viewport().get_texture().get_image().save_png("res://autotest_shots/w10_%s.png" % tag)

	func _key(pressed: bool) -> void:
		var ev := InputEventAction.new()
		ev.action = &"jump"
		ev.pressed = pressed
		Input.parse_input_event(ev)

	func _release_all() -> void:
		Input.action_release("move_right")
		Input.action_release("move_left")
		_key(false)

	## 地形注入：fn(i)->tier（i=块序号），重建全部地块。
	func _inject(fn: Callable) -> void:
		_terrain.probe_tier_fn = fn
		_terrain.probe_rebuild()
		await _frames(3)

	func _uniform(tier: int) -> void:
		_tier = tier
		_g = 664.0 - 64.0 * tier
		await _inject(func(_i: int) -> int: return tier)

	## 清场：全部危险件/弹/杂兵（跳过 boss 组与精英）/障碍。
	func _clear() -> void:
		for grp in ["sulfur_vents", "sulfur_clouds"]:
			for n in get_tree().get_nodes_in_group(grp):
				n.queue_free()
		var container := get_tree().get_first_node_in_group("projectile_container")
		if container != null:
			for c in container.get_children():
				if c is Bullet or c is GroundBlast:
					c.queue_free()
		for n in get_tree().get_nodes_in_group("enemies"):
			if n.is_in_group("boss") or n is EliteFountain:
				continue
			n.queue_free()
		for n in get_tree().get_nodes_in_group("obstacles"):
			n.queue_free()

	## 站到 x（贴地静止），落稳后返回。
	func _stand(x: float) -> void:
		_release_all()
		_player.global_position = Vector2(x, _terrain.surface_y_at(x) - 30.0)
		_player.velocity = Vector2.ZERO
		_player.reset_physics_interpolation()
		await _frames(30)
		_player.velocity = Vector2.ZERO

	## 从 x_trig−900 起跑到满速且越过 x_trig，返回（此刻=该用例的 t=0）。
	func _run_up(x_trig: float) -> void:
		await _stand(x_trig - 900.0)
		Input.action_press("move_right")
		var guard := 0
		while (_player.velocity.x < 599.0 or _player.global_position.x < x_trig) and guard < 400:
			await get_tree().physics_frame
			guard += 1

	func _hp() -> int:
		return _player.hp

	func _run() -> void:
		RunState.start_run()
		RunState.mult_frozen = true
		RunState.loot_frozen = true
		RunState.hold_chapter = true
		RunState.begin_handoff()
		get_tree().change_scene_to_file("res://scenes/world/world_10.tscn")
		await _wait(1.2)
		_main = get_tree().current_scene
		_player = get_tree().get_first_node_in_group("player") as Player
		_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
		if _player == null or _terrain == null or _main == null:
			_check(false, "S0 world_10 落地", "player=%s terrain=%s" % [_player, _terrain])
			get_tree().quit(1)
			return
		_spawner = _main.get_node("Spawner") as Spawner
		_spawner.stop()
		_player.auto_fire = false
		_player.hp = 99999
		_player.shield = 0
		_clear()
		await _uniform(1)
		var flat := true
		for x in range(0, 8000, 32):
			if not is_equal_approx(_terrain.surface_y_at(float(x)), 600.0):
				flat = false
		_check(flat, "S1 注入地形全程 tier1(g=600)（R13）")
		await _shot("land")
		await _elite_suite()
		await _boss_suite()
		_release_all()
		_terrain.probe_tier_fn = Callable()
		print("[autotest] w10 ", "ALL OK" if _fails == 0 else "FAILS=%d" % _fails)
		get_tree().quit(0 if _fails == 0 else 1)

	# ================= 精英「窜井」 =================

	## 一套精英井：t=0 begin_volley（可覆写落点），逐帧推进精英闸，记录掉血。
	func _elite_volley(elite: EliteFountain, frames: int, plan_override := NAN, actions := {}) -> Dictionary:
		var hp0 := _hp()
		var rec := {"px0": _player.global_position.x, "vx0": _player.velocity.x,
				"vent": null, "snap": {}, "max_vents": 0, "flash_f0": false, "dmg_lit": -1}
		var ok := elite.begin_volley()
		rec["began"] = ok
		rec["flash_f0"] = elite._warn._t >= 0.0
		if not is_nan(plan_override):
			elite._plan_x = plan_override
		for f in frames + 1:
			if actions.has(f):
				(actions[f] as Callable).call()
			var alive := is_instance_valid(elite) and elite.is_inside_tree()
			if alive and elite.is_telegraphing():
				elite._tick_volley(DT)
			if alive:
				rec["max_vents"] = maxi(rec["max_vents"], elite.vent_count())
			var vs := get_tree().get_nodes_in_group("sulfur_vents")
			if rec["vent"] == null and not vs.is_empty():
				rec["vent"] = vs[0]
			if rec["vent"] != null and is_instance_valid(rec["vent"]):
				var v := rec["vent"] as SulfurVent
				rec["snap"] = {"x": v.global_position.x, "y": v.global_position.y,
						"first": v.first_pulse_t(), "ext": v.extinguish_t()}
				if rec["dmg_lit"] < 0 and v.t_abs() >= v.first_pulse_t() - DT * 0.5:
					rec["dmg_lit"] = hp0 - _hp()
			await get_tree().physics_frame
		rec["dmg"] = hp0 - _hp()
		return rec

	var _elite: EliteFountain

	## 每个用例换一台新精英，钉在 at_x 地面（冻结：闸由探针逐帧推进，出手路径不变）。
	## 精英出右缘会被回收，所以放在用例 t=0 时的屏内。
	func _fresh_elite(at_x: float) -> EliteFountain:
		if _elite != null and is_instance_valid(_elite):
			_elite.queue_free()
		_elite = _spawner.debug_spawn_elite(at_x) as EliteFountain
		if _elite == null:
			return null
		_elite.set_physics_process(false) # 入树即冻结：不走自身回收闸（出右缘不被清）
		_elite._player = _player          # 冻结后不走自身的玩家查找，探针代填
		await _frames(2)
		return _elite

	func _elite_suite() -> void:
		var elite := await _fresh_elite(9000.0)
		if elite == null:
			_check(false, "E0 精英「窜井」刷出（EliteFountain）")
			return
		var tolx := 600.0 * DT + 1.0

		# E1：满速出手 → 井 origin.x=px+1440、y=g，ThreatFlash t=0 同帧亮
		elite = await _fresh_elite(9000.0)
		await _run_up(3200.0)
		var r := await _elite_volley(elite, 150)
		_release_all()
		var sp: Dictionary = r["snap"]
		_check(r["flash_f0"], "E1a DrillPort ThreatFlash 与 begin_volley 同帧亮（warn() 同拍）")
		_check(not sp.is_empty() and absf(float(sp["x"]) - r["px0"] - 1440.0) <= 1.0
				and absf(float(sp["y"]) - 600.0) < 0.5,
				"E1 满速：井 origin=(px+1440, 600)", "dx=%.1f y=%.1f" % [
				float(sp.get("x", 0.0)) - r["px0"], float(sp.get("y", 0.0))])
		_check(not sp.is_empty() and absf(float(sp["first"]) - 2.3) < 0.001 and absf(float(sp["ext"]) - 3.95) < 0.001,
				"E1t 精英井：首喷 2.3、熄灭 3.95（2 喷）", "first=%.3f ext=%.3f" % [
				float(sp.get("first", 0.0)), float(sp.get("ext", 0.0))])
		await _frames(200)
		_clear()

		# E2：息窗中点满速穿（玩家 t=0 在 px−435，井在 px+1440）→ 0
		elite = await _fresh_elite(9000.0)
		await _run_up(3200.0)
		var p0 := _player.global_position.x
		r = await _elite_volley(elite, 270, p0 + 435.0 + 1440.0)
		_release_all()
		_check(r["dmg"] == 0, "E2 息窗中点满速穿 掉血 0", "dmg=%d" % r["dmg"])
		await _frames(60)
		_clear()

		# E3：第二喷中点满速穿（t=0 在 px−795）→ 恰 10
		elite = await _fresh_elite(9000.0)
		await _run_up(3200.0)
		p0 = _player.global_position.x
		r = await _elite_volley(elite, 290, p0 + 795.0 + 1440.0)
		_release_all()
		_check(r["dmg"] == BalanceWorld10.VENT_DAMAGE, "E3 第二喷期间满速穿 恰 10", "dmg=%d" % r["dmg"])
		await _frames(60)
		_clear()

		# E4：亮井期 [1.7,2.3) 探针体站在井心 → 0（首喷后照吃）
		elite = await _fresh_elite(9000.0)
		await _stand(4640.0)
		r = await _elite_volley(elite, 150, 4640.0)
		_check(r["dmg_lit"] == 0, "E4 亮井期站井心 掉血 0（亮≠喷）", "dmg_lit=%d" % r["dmg_lit"])
		_check(r["dmg"] == BalanceWorld10.VENT_DAMAGE, "E4b 首喷后站井心 吃 10", "dmg=%d" % r["dmg"])
		await _frames(120)
		_clear()

		# E5：R10 边界避让（静态规划同一把尺）
		var n320 := 3200.0
		var xa := SulfurVent.plan_x(get_tree(), n320 - 20.0)
		_check(absf(xa - (n320 + 76.0)) < 0.01, "E5a lead=320n−20 → origin=320n+76（+96 合格）", "x=%.1f" % xa)
		var sc := _spawner._spawn(_spawner.scaffold_scene, false, n320 - 20.0) as Obstacle
		await _frames(2)
		sc.global_position.x = n320 - 20.0
		var xb := SulfurVent.plan_x(get_tree(), n320 - 20.0)
		_check(is_nan(xb), "E5b +96/−96 皆与脚手架 ±104 重叠 → 取消", "x=%s" % xb)
		elite = await _fresh_elite(9000.0)
		await _stand(n320 - 20.0 - 1440.0 - 600.0)
		Input.action_press("move_right")
		var guard := 0
		while (_player.velocity.x < 599.0 or _player.global_position.x < n320 - 20.0 - 1440.0) and guard < 200:
			await get_tree().physics_frame
			guard += 1
		r = await _elite_volley(elite, 60, n320 - 20.0) # 覆写前先看 begin_volley 自己的规划
		_release_all()
		_check(get_tree().get_nodes_in_group("sulfur_vents").is_empty() or not r["began"],
				"E5c 脚手架下本口取消（sulfur_vents 计数 0）", "began=%s" % r["began"])
		_clear()
		await _frames(30)
		_clear()

		# E6：冷却闸——井在场时掷骰（delta=10 必中）也不进预警
		elite = await _fresh_elite(9000.0)
		await _stand(4640.0)
		elite.begin_volley()
		for f in 60:
			if elite.is_telegraphing():
				elite._tick_volley(DT)
			await get_tree().physics_frame
		var before := elite.vent_count()
		elite._tick_volley(10.0)
		_check(before == 1 and not elite.is_telegraphing(), "E6 冷却闸：同主 sulfur_vents ≤1（在场不进预警）",
				"count=%d tele=%s" % [before, elite.is_telegraphing()])
		await _frames(240)
		_clear()
		if is_instance_valid(elite):
			elite.queue_free()
		await _frames(5)

	# ================= BOSS「井口」 =================

	func _boss_suite() -> void:
		await _stand(3000.0)
		_boss = _spawner.debug_spawn_boss() as BossWellhead
		if _boss == null:
			_check(false, "B0 BOSS「井口」刷出（BossWellhead）")
			return
		_pin_boss = true
		_pin_off = 1400.0
		await _wait(1.5)
		_boss._bstate = PursuitBoss.ST_RECOVER
		_boss._bt = 99.0
		await _frames(60)
		_clear()
		await _shot("boss_idle")
		await _vent_suite()
		await _cloud_suite()
		await _sweep_suite()
		_pin_boss = false

	func _freeze() -> void:
		_boss._bstate = PursuitBoss.ST_RECOVER
		_boss._bt = 99.0

	## 一手 BOSS 技能（t=0 = 调用帧），逐帧记录掉血；sample(f) 每帧回调。
	func _boss_take(begin: Callable, frames: int, actions := {}, sample := Callable()) -> Dictionary:
		var hp0 := _hp()
		var rec := {"px0": _player.global_position.x, "vx0": _player.velocity.x}
		begin.call()
		for f in frames + 1:
			if actions.has(f):
				(actions[f] as Callable).call()
			if sample.is_valid():
				sample.call(f)
			await get_tree().physics_frame
		rec["dmg"] = hp0 - _hp()
		return rec

	func _vent_snap() -> Array:
		var out := []
		for n in get_tree().get_nodes_in_group("sulfur_vents"):
			var v := n as SulfurVent
			out.append({"k": v.k_index, "x": v.global_position.x, "y": v.global_position.y,
					"first": v.first_pulse_t()})
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["k"] < b["k"])
		return out

	func _vent_suite() -> void:
		await _uniform(1)
		# BA1/BA2/BA5：满速盲冲（恒 600）——落位/首喷/掉血 30/R11 闪烁
		await _run_up(3200.0)
		var snap := []
		var r11 := {"bad": 0, "capped_max": 0, "pairs": 0}
		var sample := func(f: int) -> void:
			if f == 60:
				snap.assign(_vent_snap())
			var lit := []
			for n in get_tree().get_nodes_in_group("sulfur_vents"):
				var v := n as SulfurVent
				if v.is_lit() and v.active_pulse() < 0:
					var rem := v.first_pulse_t() - v.t_abs()
					if rem > 0.0:
						lit.append([rem, v.blink_hz()])
			var capped := 0
			for a in lit:
				if a[1] >= BalanceWorld10.VENT_BLINK_MAX_HZ - 0.0001:
					capped += 1
				for b in lit:
					if a[0] > 0.25 and b[0] > 0.25 and a[0] < b[0] - 0.0001:
						r11["pairs"] += 1
						if not (a[1] > b[1]):
							r11["bad"] += 1
			r11["capped_max"] = maxi(r11["capped_max"], capped)
		var r := await _boss_take(_boss._begin_skill_a, 340, {}, sample)
		_release_all()
		var px0: float = r["px0"]
		var xs_ok := snap.size() == 3
		var detail := ""
		for i in snap.size():
			var e: Dictionary = snap[i]
			detail += "k%d=(px+%.0f,%.0f,%.2f) " % [e["k"], float(e["x"]) - px0, e["y"], e["first"]]
			if absf(float(e["x"]) - px0 - (1440.0 + 360.0 * i)) > 1.0 or absf(float(e["y"]) - 600.0) > 0.5 \
					or absf(float(e["first"]) - (2.3 + 0.6 * i)) > 0.001:
				xs_ok = false
		_check(xs_ok, "BA1 三口 origin=px+1440/1800/2160、y=600、首喷 2.3/2.9/3.5", detail)
		_check(r["dmg"] == 3 * BalanceWorld10.VENT_DAMAGE, "BA2 满速盲冲 掉血 30", "dmg=%d" % r["dmg"])
		_check(r11["bad"] == 0 and r11["pairs"] > 0 and r11["capped_max"] <= 1,
				"BA5 R11 亮井闪烁：剩余首喷更少者 f 严格更大，任一时刻至多一口封顶 4Hz",
				"pairs=%d bad=%d capped_max=%d" % [r11["pairs"], r11["bad"], r11["capped_max"]])
		await _frames(30)
		_freeze()
		_clear()

		# BA3：绿波脚本（t=2.113 刹停，2.75 起步满速）→ 0；BA4：3.2 起步 → 30
		for go in [2.75, 3.2]:
			await _run_up(3200.0)
			var acts := {
				roundi(2.113 / DT): func() -> void: Input.action_release("move_right"),
				roundi(float(go) / DT): func() -> void: Input.action_press("move_right"),
			}
			r = await _boss_take(_boss._begin_skill_a, 420, acts)
			_release_all()
			if is_equal_approx(float(go), 2.75):
				_check(r["dmg"] == 0, "BA3 绿波：t2.113 刹停、2.75 起步满速 掉血 0", "dmg=%d" % r["dmg"])
			else:
				_check(r["dmg"] == 3 * BalanceWorld10.VENT_DAMAGE, "BA4 同脚本 3.2 起步 掉血 30", "dmg=%d" % r["dmg"])
			await _frames(30)
			_freeze()
			_clear()

		# BA3b：亮井期站井心 0（站桩：井在 px+240/600/960，站到 k=0 井心上）
		await _stand(3200.0)
		var hp0 := _hp()
		_boss._begin_skill_a()
		var lit_dmg := -1
		var moved := false
		for f in 200:
			var vs := _vent_snap()
			if not moved and not vs.is_empty():
				var x0 := float(vs[0]["x"])
				_player.global_position = Vector2(x0, 570.0)
				_player.velocity = Vector2.ZERO
				_player.reset_physics_interpolation()
				moved = true
			if f == roundi(2.28 / DT):
				lit_dmg = hp0 - _hp()
			await get_tree().physics_frame
		_check(lit_dmg == 0, "BA3b 亮井期（首喷前）站井心 掉血 0", "dmg=%d" % lit_dmg)
		await _frames(60)
		_freeze()
		_clear()

		# BA6：R10 脚手架让 k=1 的 lead/+96/−96 全部失格 → k=1 取消，k=0/k=2 不变
		await _run_up(3200.0)
		var pxs := _player.global_position.x
		var lead1 := pxs + 600.0 * DT + 1800.0 # 下一帧 begin 时的玩家位（满速 1 帧位移）
		var sc := _spawner._spawn(_spawner.scaffold_scene, false, lead1) as Obstacle
		sc.body_size = Vector2(300.0, 28.0) # 只给避让尺读：窄架只罩住 k=1 的三个候选
		await get_tree().physics_frame
		sc.global_position.x = lead1
		px0 = _player.global_position.x
		_boss._begin_skill_a()
		await _frames(50)
		snap.assign(_vent_snap())
		_release_all()
		var ks := []
		detail = ""
		for e in snap:
			ks.append(int(e["k"]))
			detail += "k%d=(px+%.0f,%.2f) " % [e["k"], float(e["x"]) - px0, e["first"]]
		var ok6 := ks == [0, 2]
		if ok6:
			ok6 = absf(float(snap[0]["x"]) - px0 - 1440.0) <= 1.0 and absf(float(snap[1]["x"]) - px0 - 2160.0) <= 1.0 \
					and absf(float(snap[0]["first"]) - 2.3) < 0.001 and absf(float(snap[1]["first"]) - 3.5) < 0.001
		_check(ok6, "BA6 R10：k=1 三候选皆罩脚手架→取消，k=0/k=2 落位与首喷不变（不重排）", detail)
		await _frames(260)
		_freeze()
		_clear()

		# BA7：冷却——一套寿命内 BOSS 不重铺（状态机走完前 sulfur_vents 只来自这一套）
		await _stand(3200.0)
		var max_n := 0
		_boss._begin_skill_a()
		for f in 360:
			max_n = maxi(max_n, get_tree().get_nodes_in_group("sulfur_vents").size())
			await get_tree().physics_frame
		_check(max_n == 3, "BA7 一套寿命内井数恒 ≤3（不重铺）", "max=%d" % max_n)
		_freeze()
		_clear()

	# ---------- 硫云爆燃 ----------

	func _cloud() -> SulfurCloud:
		var cs := get_tree().get_nodes_in_group("sulfur_clouds")
		return null if cs.is_empty() else cs[0] as SulfurCloud

	## 一手 B：script 动作表；返回 {dmg, cast, xl, px0, band_ok, front_ok, pre, post}
	func _cloud_take(frames: int, acts := {}) -> Dictionary:
		var hp0 := _hp()
		var px0 := _player.global_position.x
		var cast0 := _boss.cloud_cast_count
		var rec := {"px0": px0, "band_ok": true, "front_ok": true, "pre": -1, "post_dmg": 0,
				"xl": NAN, "seen": false, "gone_by": -1.0}
		_boss._begin_skill_b()
		var hp_post0 := -1
		for f in frames + 1:
			if acts.has(f):
				(acts[f] as Callable).call()
			var c := _cloud()
			var t := f * DT
			if c != null:
				rec["seen"] = true
				rec["xl"] = c.x_left
				for s in c._tiles:
					if absf(s.global_position.y - BalanceWorld10.SULFUR_CLOUD_BAND_TOP) > 0.01:
						rec["band_ok"] = false
				var ta := c.t_abs()
				if ta >= 1.85 and ta <= 2.35:
					var expect := maxf(c.x_right() - 2500.0 * (ta - 1.8), c.x_left)
					if absf(c.front_x() - expect) > 0.5:
						rec["front_ok"] = false
			elif rec["seen"] and rec["gone_by"] < 0.0:
				rec["gone_by"] = t
			if rec["pre"] < 0 and t >= 1.78:
				rec["pre"] = hp0 - _hp()
			if hp_post0 < 0 and t >= 2.42:
				hp_post0 = _hp()
			await get_tree().physics_frame
		rec["dmg"] = hp0 - _hp()
		rec["post_dmg"] = (hp_post0 - _hp()) if hp_post0 >= 0 else 0
		rec["cast"] = _boss.cloud_cast_count - cast0
		return rec

	func _cloud_suite() -> void:
		await _uniform(2)
		# BB1：全程 tier2 满速贴地 → 12；带 y 恒 428；火锋公式；xL=px+600；点燃前/燃完后 0
		await _run_up(3200.0)
		var r := await _cloud_take(200)
		_release_all()
		_check(r["cast"] == 1, "BB0 全程 tier2：派招闸放行（R7/R16）", "cast=%d" % r["cast"])
		_check(r["band_ok"], "BB1a 带 y 恒 [428,512]（节点钉绝对坐标，零地形跟随）")
		_check(r["front_ok"], "BB1b 火锋 = 右端 − 2500×(t−1.8)，推到左端停")
		_check(absf(float(r["xl"]) - r["px0"] - 600.0) <= 1.0, "BB4a 满速 带左端 = px+600", "xl−px=%.1f" % (float(r["xl"]) - r["px0"]))
		_check(r["dmg"] == BalanceWorld10.SULFUR_CLOUD_DAMAGE, "BB2a tier2 满速贴地 掉血 12", "dmg=%d" % r["dmg"])
		_check(r["pre"] == 0, "BB3a 点燃前（t<1.8）掉血 0", "pre=%d" % r["pre"])
		_check(r["post_dmg"] == 0 and r["gone_by"] > 0.0 and r["gone_by"] <= 2.75,
				"BB3b 燃完后（t>2.4）掉血 0 且云自清无驻留", "post=%d gone=%.2f" % [r["post_dmg"], r["gone_by"]])
		_freeze()
		_clear()
		await _frames(20)
		# BB2b：tier2 满速 1.7 起跳 → 12
		await _run_up(3200.0)
		r = await _cloud_take(200, {roundi(1.7 / DT): func() -> void: _key(true),
				roundi(1.7 / DT) + 2: func() -> void: _key(false)})
		_release_all()
		_check(r["dmg"] == BalanceWorld10.SULFUR_CLOUD_DAMAGE, "BB2b tier2 满速 1.7 起跳 掉血 12", "dmg=%d" % r["dmg"])
		_freeze()
		_clear()
		await _frames(20)
		# BB2c：tier2 站桩 → 12；带左端 = px
		await _stand(3200.0)
		r = await _cloud_take(200)
		_check(r["dmg"] == BalanceWorld10.SULFUR_CLOUD_DAMAGE, "BB2c tier2 站桩 掉血 12（本招不保站桩）", "dmg=%d" % r["dmg"])
		_check(absf(float(r["xl"]) - r["px0"]) <= 1.0, "BB4b 站桩 带左端 = px（lead ≥0，不铺身后）", "xl−px=%.1f" % (float(r["xl"]) - r["px0"]))
		_freeze()
		_clear()
		await _frames(20)
		# BB2d：tier2 满速 1.5 起跳按住 1.2s（R8 最晚免伤 1.6 − 0.1）→ 0
		await _run_up(3200.0)
		r = await _cloud_take(200, {roundi(1.5 / DT): func() -> void: _key(true),
				roundi(2.7 / DT): func() -> void: _key(false)})
		_release_all()
		_check(r["dmg"] == 0, "BB2d tier2 满速 1.5 起跳按住 1.2s 推进飞越 掉血 0", "dmg=%d" % r["dmg"])
		_freeze()
		_clear()
		await _frames(60)

		# BB5：派招闸——全程 tier1 / tier0 连续 3 轮改派 A，B 派出 0
		for tier in [1, 0]:
			await _uniform(int(tier))
			await _run_up(3200.0)
			var cast0 := _boss.cloud_cast_count
			var gated0 := _boss.cloud_gated_count
			var to_a := 0
			for k in 3:
				_boss._begin_skill_b()
				if _boss._bstate == BossWellhead.ST_VENT_WARN:
					to_a += 1
				_freeze()
				_clear()
				await _frames(2)
			_release_all()
			_check(_boss.cloud_cast_count == cast0 and _boss.cloud_gated_count - gated0 == 3 and to_a == 3,
					"BB5 全程 tier%d：连续 3 轮 B 派出 0、被拦轮次改派 A" % tier,
					"cast=%d gated=%d toA=%d" % [_boss.cloud_cast_count - cast0, _boss.cloud_gated_count - gated0, to_a])
			_check(_boss._skill_flip, "BB5b 改派后 B 冷却不消耗（下一轮技能仍是 B）")
			await _frames(10)

		# BB6：R16——tier2 只在 px+640..960（满速）→ 带内宽 320 过 R7、与受罚区间交集 0 → 改派 A
		var px_plan := 3200.0
		await _inject(func(i: int) -> int: return 2 if i == 12 else 1) # 块 12=[3840,4160]=px+640..960
		_g = 600.0
		await _run_up(px_plan)
		var gate := _boss.cloud_gate(_player.global_position.x, 600.0)
		var cast1 := _boss.cloud_cast_count
		_boss._begin_skill_b()
		_release_all()
		_check(_boss.cloud_cast_count == cast1 and _boss._bstate == BossWellhead.ST_VENT_WARN,
				"BB6 R16：tier2 在 px+640..960（满速）→ B 派出 0、改派 A",
				"band_w=%.0f pen_w=%.0f I=[px+%.0f,px+%.0f]" % [gate["band_w"], gate["pen_w"],
				float(gate["i_lo"]) - _player.global_position.x, float(gate["i_hi"]) - _player.global_position.x])
		_freeze()
		_clear()
		await _frames(10)

		# BB7：force_cast_b（探针开关）绕闸：全程 tier1/tier0 满速贴地 0；tier1 1.3 起跳按住 0
		_boss.force_cast_b = true
		for tier in [1, 0]:
			await _uniform(int(tier))
			await _run_up(3200.0)
			r = await _cloud_take(200)
			_release_all()
			_check(r["cast"] == 1 and r["dmg"] == 0, "BB7 force_cast_b 全程 tier%d 满速贴地 掉血 0" % tier,
					"cast=%d dmg=%d" % [r["cast"], r["dmg"]])
			_freeze()
			_clear()
			await _frames(20)
		await _uniform(1)
		await _run_up(3200.0)
		r = await _cloud_take(200, {roundi(1.3 / DT): func() -> void: _key(true),
				roundi(2.5 / DT): func() -> void: _key(false)})
		_release_all()
		_check(r["dmg"] == 0, "BB7b force_cast_b tier1 满速 1.3 起跳按住 1.2s 掉血 0（R8 最晚 1.4 − 0.1）", "dmg=%d" % r["dmg"])
		_freeze()
		_clear()
		_boss.force_cast_b = false
		await _frames(20)

	# ---------- 硫焰扫掠 ----------

	func _puffs() -> Array:
		var out := []
		var container := get_tree().get_first_node_in_group("projectile_container")
		for c in container.get_children():
			if c is FlarePuff and not c.is_queued_for_deletion():
				out.append(c)
		return out

	## 一轮扫掠：t=0 _begin_direct；返回 {dmg, origin_ok, max_turn, inside, lifts, duds}
	func _sweep_take(frames: int, acts := {}, down := true) -> Dictionary:
		_boss._sweep_down = down
		var hp0 := _hp()
		var rec := {"px0": _player.global_position.x, "origin_ok": true, "max_turn": 0.0,
				"inside": 0, "n": 0}
		var nozzle := (_boss.get_node("Visuals/NozzlePort") as Node2D).global_position
		rec["nozzle"] = nozzle
		_boss._begin_direct()
		rec["lifts"] = _boss.sweep_lifts.duplicate()
		rec["duds"] = _boss.sweep_duds
		var dir0 := {}
		for f in frames + 1:
			if acts.has(f):
				(acts[f] as Callable).call()
			for b in _puffs():
				var id: int = b.get_instance_id()
				if not dir0.has(id):
					dir0[id] = b.rotation
					rec["n"] += 1
					if b._started and b._spawn_pos.distance_to(nozzle) > 0.5:
						rec["origin_ok"] = false
				rec["max_turn"] = maxf(rec["max_turn"], absf(rad_to_deg(angle_difference(dir0[id], b.rotation))))
				if b._started and b.global_position.y > _terrain.surface_y_at(b.global_position.x) + 0.5:
					rec["inside"] += 1
			await get_tree().physics_frame
		rec["dmg"] = hp0 - _hp()
		return rec

	func _sweep_suite() -> void:
		await _uniform(1)
		_pin_off = 1400.0
		# SW1/SW2：站桩 → 21；起点 = NozzlePort（y=424）；方向恒定
		await _stand(3200.0)
		var r := await _sweep_take(170)
		var nz: Vector2 = r["nozzle"]
		_check(r["origin_ok"] and absf(nz.y - 424.0) < 0.5 and absf(nz.x - r["px0"] - 1254.0) < 0.5,
				"SW1a 7 团起点 = NozzlePort.global_position（世界 (px+1254, 424)）", "nozzle=(px+%.1f, %.1f) n=%d" % [nz.x - r["px0"], nz.y, r["n"]])
		_check(r["max_turn"] < 0.5, "SW1b 出手后各团方向恒定（夹角变化 <0.5°）", "max=%.3f°" % r["max_turn"])
		_check(r["dmg"] == 3 * BalanceWorld10.FLARE_SWEEP_DAMAGE, "SW2a 站桩 掉血 21（三团各 7）", "dmg=%d" % r["dmg"])
		_check(r["dmg"] <= 48, "SW3 单轮扫掠 ≤48", "dmg=%d" % r["dmg"])
		_freeze()
		_clear()
		await _frames(20)
		# SW2b：0.35s 反应后向 BOSS 前冲 → 恰 7
		await _stand(3200.0)
		r = await _sweep_take(170, {roundi(0.35 / DT): func() -> void: Input.action_press("move_right")})
		_release_all()
		_check(r["dmg"] == BalanceWorld10.FLARE_SWEEP_DAMAGE, "SW2b 0.35s 反应后向 BOSS 前冲 恰 7", "dmg=%d" % r["dmg"])
		_freeze()
		_clear()
		await _frames(20)
		# SW2c/SW2d：BOSS 锚定 px+900、玩家 vx=600：满速保持 0；满速出手即刹 14
		_pin_off = 900.0
		await _run_up(3200.0)
		r = await _sweep_take(170)
		_release_all()
		_check(r["dmg"] == 0, "SW2c 满速保持（BOSS 锚 px+900）掉血 0", "dmg=%d" % r["dmg"])
		_freeze()
		_clear()
		await _frames(20)
		await _run_up(3200.0)
		r = await _sweep_take(170, {0: func() -> void: Input.action_release("move_right")})
		_release_all()
		_check(r["dmg"] == 2 * BalanceWorld10.FLARE_SWEEP_DAMAGE, "SW2d 满速出手即刹 掉血 14", "dmg=%d" % r["dmg"])
		_freeze()
		_clear()
		await _frames(20)
		# SW5：R9 校平——tier0，玩家 px=3320，块 11=[3520,3840]=px+200..520 为 tier2；喷嘴 px+1254
		_pin_off = 1400.0
		_tier = 0
		_g = 664.0
		await _inject(func(i: int) -> int: return 2 if i == 11 else 0)
		await _stand(3320.0)
		r = await _sweep_take(170, {}, true)
		var lifts: Array = r["lifts"]
		_check(lifts == [0, 0, 0, 1, 1, 1, 1] and r["duds"] == 0,
				"SW5a R9 抬角表：h=210/175/140 不抬、h=105/70/35/0 各抬 1 次、无哑火", "lifts=%s duds=%d" % [lifts, r["duds"]])
		_check(r["inside"] == 0, "SW5b R9 全程弹体处于地形内帧数 0", "inside=%d n=%d" % [r["inside"], r["n"]])
		await _shot("sweep_r9")
		_freeze()
		_clear()
		await _uniform(1)
