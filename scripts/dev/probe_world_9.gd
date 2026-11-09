extends Node2D
## 第九章「雷暴线场」威胁探针（窗口小场景自退；不改本体场景，不进正常启动流程）：
##   godot --log-file autotest_w9.log res://scenes/previews/probe_world_9.tscn
## 落地 world_9（交接路径跳启动页）→ 停刷清场=单威胁源 → 全部用例都在开局平地段
## [−640, 2560]（terrain.gd 段 −1/0 固定同档，g=600）里跑，输入按物理帧写死。
## 判据正本=art_proposals/storm_ch9/威胁设计_ch9.md + 终审 R11–R14：
##   E  精英「架线」跨缆：同台/高缆站桩 0/低缆站桩恰 15/带电前 0/满速+t2.0 跳按住 0/
##      时序（落地 1.3、带电 2.2）/R5 冷却闸/R6 平移补时/R7 脚手架避让与取消；
##   BA BOSS 跨缆网：p1 低缆满速+t2.0 跳按住 0；p2 两段（x1′=x1+680、带电晚 0.6）
##      满速钻高缆后 t2.45 跳按住 0；
##   BR BOSS 引雷针链：针落位/贴地、落地与放电时序、站缝心 0、满速直冲恰 15、
##      解一（t2.03 起刹停缝心）0、解二（t1.50 起刹停针列前）0、t2.30 纯跳恰 8、R7 避让；
##   AL BOSS 断缆甩弧：出膛点=Muzzle、方向恒定、静止恰 12、满速保持 0 且相遇 1.03s±1 帧。
## 探针坑规避：hp=99999；清杂兵跳过 boss 组；BOSS 冻结窗=_bstate=RECOVER+_bt=99；
## 按伤害值分辨弹种前已单威胁源；BOSS 构图位逐帧钉在玩家 +1400（防贴脸压招冻结）。
## 全过 ALL OK 退出码 0；有 FAIL 退出码 1；看门狗 240s 退出码 2。

func _ready() -> void:
	var runner: Node = Runner.new()
	runner.name = "ProbeWorld9Runner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	const DT := 1.0 / 60.0
	var _fails := 0
	var _windowed := false
	var _player: Player
	var _main: Node
	var _spawner: Spawner
	var _terrain: Terrain
	var _boss: BossConductor
	var _pin_boss := false
	var _g := 600.0

	func _ready() -> void:
		_windowed = DisplayServer.get_name() != "headless"
		get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
			print("[autotest] w9 TIMEOUT 240s")
			get_tree().quit(2))
		get_tree().physics_frame.connect(_on_physics)
		_run()

	func _on_physics() -> void:
		if _boss == null or not is_instance_valid(_boss):
			return
		if _boss._bstate == PursuitBoss.ST_RECOVER:
			_boss._bt = 99.0 # 冻结窗：只倒数不出招
		if _pin_boss and is_instance_valid(_player):
			_boss.global_position.x = _player.global_position.x + 1400.0
			_boss._vel.x = _player.velocity.x

	func _check(ok: bool, label: String, detail := "") -> void:
		if not ok:
			_fails += 1
		print("[autotest] w9 ", label, " [", "OK" if ok else "FAIL", "] ", detail)

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
		get_viewport().get_texture().get_image().save_png("res://autotest_shots/w9_%s.png" % tag)

	func _key(pressed: bool) -> void:
		var ev := InputEventAction.new()
		ev.action = &"jump"
		ev.pressed = pressed
		Input.parse_input_event(ev)

	## 清场：全部危险件/弹/杂兵（跳过 boss 组）/障碍。
	func _clear() -> void:
		for grp in ["live_spans", "rod_chains"]:
			for n in get_tree().get_nodes_in_group(grp):
				n.queue_free()
		var container := get_tree().get_first_node_in_group("projectile_container")
		if container != null:
			for c in container.get_children():
				if c is Bullet or c is GroundBlast:
					c.queue_free()
		for n in get_tree().get_nodes_in_group("enemies"):
			if n.is_in_group("boss") or n is EliteStringer:
				continue
			n.queue_free()
		for n in get_tree().get_nodes_in_group("obstacles"):
			n.queue_free()

	## 站到 x（贴地静止），落稳后返回。
	func _stand(x: float) -> void:
		Input.action_release("move_right")
		Input.action_release("move_left")
		_key(false)
		_player.global_position = Vector2(x, _g - 30.0)
		_player.velocity = Vector2.ZERO
		_player.reset_physics_interpolation()
		await _frames(30)
		_player.velocity = Vector2.ZERO

	## 从 −600 起跑到满速且越过 x_trig，返回（此刻=该用例的 t=0）。
	func _run_up(x_trig := -350.0) -> void:
		await _stand(-600.0)
		Input.action_press("move_right")
		var guard := 0
		while (_player.velocity.x < 599.0 or _player.global_position.x < x_trig) and guard < 300:
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
		get_tree().change_scene_to_file("res://scenes/world/world_9.tscn")
		await _wait(1.2)
		_main = get_tree().current_scene
		_player = get_tree().get_first_node_in_group("player") as Player
		_terrain = get_tree().get_first_node_in_group("terrain") as Terrain
		if _player == null or _terrain == null or _main == null:
			_check(false, "S0 world_9 落地", "player=%s terrain=%s" % [_player, _terrain])
			get_tree().quit(1)
			return
		_spawner = _main.get_node("Spawner") as Spawner
		_spawner.stop()
		_player.auto_fire = false
		_player.hp = 99999
		_player.hurt_window_enabled = false # 几何探针：多段累计伤害账（N×单发）按无窗算
		_clear()
		var flat := true
		for x in range(-640, 2560, 32):
			if not is_equal_approx(_terrain.surface_y_at(float(x)), 600.0):
				flat = false
		_check(flat, "S1 开局平地段 [-640,2560] 同档 g=600（用例场地）")
		await _shot("land")
		await _elite_suite()
		await _boss_suite()
		Input.action_release("move_right")
		_key(false)
		print("[autotest] w9 ", "ALL OK" if _fails == 0 else "FAILS=%d" % _fails)
		get_tree().quit(0 if _fails == 0 else 1)

	# ================= 精英「架线」 =================

	## 跑一套精英跨缆：t=0 begin_volley（闪光+lead 采样），逐帧推进精英闸、记录
	## 掉血/阶段；actions={帧号: Callable}。返回记录字典。
	func _elite_volley(elite: EliteStringer, high: bool, frames: int, actions := {}) -> Dictionary:
		elite._next_high = high
		var hp0 := _hp()
		var rec := {"span": null, "land_f": -1, "live_f": -1, "dmg_before_live": 0,
				"hp0": hp0, "px0": _player.global_position.x, "vx0": _player.velocity.x,
				"max_spans": 0}
		elite.begin_volley()
		for f in frames + 1:
			if actions.has(f):
				(actions[f] as Callable).call()
			if elite._volley_state == EliteStringer.VolleyState.TELEGRAPH:
				elite._tick_volley(DT)
			var spans := get_tree().get_nodes_in_group("live_spans")
			rec["max_spans"] = maxi(rec["max_spans"], elite.live_span_count())
			if not rec.has("snap") and not spans.is_empty():
				rec["span"] = spans[0]
				rec["snap"] = {}
			var ls: LiveSpan = null
			if rec.has("snap") and is_instance_valid(rec["span"]):
				ls = rec["span"] as LiveSpan
			if ls != null:
				rec["snap"] = {"x1": ls.x1, "shift": ls.shift, "lead_x1": ls.lead_x1}
				if rec["land_f"] < 0 and ls._phase != LiveSpan.Phase.FLY:
					rec["land_f"] = f
				if rec["live_f"] < 0 and ls.is_live():
					rec["live_f"] = f
					rec["dmg_before_live"] = hp0 - _hp()
			await get_tree().physics_frame
		rec["dmg"] = hp0 - _hp()
		return rec

	func _elite_suite() -> void:
		var elite := _spawner.debug_spawn_elite(2450.0) as EliteStringer
		if elite == null:
			_check(false, "E0 精英「架线」刷出")
			return
		await _frames(10)
		elite.set_physics_process(false) # 精英冻结：闸由探针逐帧推进（出手路径不变）
		_check(elite._next_high, "E0 第一套固定高缆（先教别跳）")
		var tol := 2.0 * DT + 0.001

		# E2/E1/时序：高缆 × 站桩静止玩家，跑满 4s 掉血 0
		await _stand(600.0)
		var r := await _elite_volley(elite, true, 240)
		var sp: Dictionary = r.get("snap", {})
		var tier_ok := not sp.is_empty() and is_equal_approx(_terrain.surface_y_at(float(sp["x1"])),
				_terrain.surface_y_at(float(sp["x1"]) + BalanceWorld9.LIVE_SPAN_LENGTH))
		_check(tier_ok, "E1 两桩同台", "x1=%s" % (float(sp["x1"]) if not sp.is_empty() else -1))
		_check(r["dmg"] == 0, "E2 高缆对站立静止玩家 4s 掉血 0", "dmg=%d" % r["dmg"])
		_check(absf(r["land_f"] * DT - 1.3) <= tol and absf(r["live_f"] * DT - 2.2) <= tol,
				"E-T 时序：落地 1.3 / 带电 2.2（闪光 t=0 起算，±2 帧）",
				"land=%.3f live=%.3f" % [r["land_f"] * DT, r["live_f"] * DT])
		_check(not sp.is_empty() and absf(float(sp["x1"]) + 160.0 - r["px0"]) < 1.0,
				"E-L 站桩落位：缆以玩家为中心（x1=px−160）", "x1-px=%.1f" % ((float(sp["x1"]) if not sp.is_empty() else 0.0) - r["px0"]))
		await _frames(30)

		# E3/E5：低缆 × 站桩：带电前 0、带电后恰 15 一次
		await _stand(600.0)
		r = await _elite_volley(elite, false, 240)
		await _shot("elite_low_hit")
		_check(r["dmg_before_live"] == 0, "E5 idle/爬电期在缆带内掉血 0", "dmg=%d" % r["dmg_before_live"])
		_check(r["dmg"] == BalanceWorld9.LIVE_SPAN_DAMAGE, "E3 低缆对站立静止玩家恰 15 一次", "dmg=%d" % r["dmg"])
		await _frames(30)

		# E4：低缆 × 满速 + t=2.0 起跳按住推进 → 0（R14）
		await _run_up()
		var acts := {120: func() -> void: _key(true)}
		r = await _elite_volley(elite, false, 200, acts)
		_key(false)
		Input.action_release("move_right")
		sp = r.get("snap", {})
		_check(r["dmg"] == 0, "E4 低缆满速+t2.0 起跳按住 掉血 0", "dmg=%d px0=%.0f x1=%.0f" % [
				r["dmg"], r["px0"], float(sp["x1"]) if not sp.is_empty() else -1.0])
		_check(not sp.is_empty() and absf(float(sp["x1"]) - (r["px0"] - 160.0 + 1260.0)) < 1.0 and float(sp["x1"]) > r["px0"] + 20.0,
				"E7a 满速 lead：x1=px−160+1260，缆左端在玩家前缘之前",
				"x1-px=%.1f" % ((float(sp["x1"]) if not sp.is_empty() else 0.0) - r["px0"]))
		await _frames(60)

		# E6：R5 冷却闸——套在场时掷骰（delta=10 必中）也不出新套
		await _stand(600.0)
		elite.begin_volley()
		for f in 50:
			if elite._volley_state == EliteStringer.VolleyState.TELEGRAPH:
				elite._tick_volley(DT)
			await get_tree().physics_frame
		var before := elite.live_span_count()
		elite._tick_volley(10.0)
		var gated := elite._volley_state == EliteStringer.VolleyState.COOLDOWN
		_check(before == 1 and gated and elite.live_span_count() <= 1,
				"E6 冷却闸：同一精英 live_spans ≤1（在场时不进预警）", "count=%d state=%d" % [before, elite._volley_state])
		await _frames(200)

		# E7/E8：脚手架逼平移（R6/R7）+ 补时 + 取消
		await _stand(600.0)
		var base := 600.0 - 160.0
		var sc := _spawner._spawn(_spawner.scaffold_scene, false, base + 10.0 - 360.0) as Obstacle
		await _frames(2)
		sc.global_position.x = base + 10.0 - 360.0 # 右缘=base+10 → 需平移 ≥50 → 步进 64
		r = await _elite_volley(elite, true, 200)
		sp = r.get("snap", {})
		var ok7 := not sp.is_empty() and is_equal_approx(float(sp["shift"]), 64.0) \
				and absf((float(sp["x1"]) + 160.0) - (float(sp["lead_x1"]) + 160.0)) <= 160.0
		_check(ok7, "E7 平移只向前 ≤160（步进 32，期望 64）", "shift=%s" % (float(sp["shift"]) if not sp.is_empty() else -1.0))
		var exp_live := 2.2 + 64.0 / 600.0
		_check(not sp.is_empty() and absf(r["live_f"] * DT - exp_live) <= tol,
				"E7b 平移补时：带电 = 2.2 + 位移/600", "live=%.3f 应=%.3f" % [r["live_f"] * DT, exp_live])
		var hw := sc.body_size.x * 0.5
		var ok8 := not sp.is_empty() and (sc.global_position.x + hw <= float(sp["x1"]) - 40.0 \
				or sc.global_position.x - hw >= float(sp["x1"]) + 360.0)
		_check(ok8, "E8 [x1−40, x1+360] 与 floating 脚手架零重叠")
		sc.global_position.x = base + 200.0 # 覆盖 [base−160, base+560] → 平移 160 仍撞
		var cancel := LiveSpan.plan_x1(get_tree(), _terrain, base)
		_check(cancel.is_empty(), "E8b 平移上限内放不下 → 取消本次", "plan=%s" % cancel)
		sc.queue_free()
		await _frames(30)
		elite.queue_free()
		_clear()

	# ================= BOSS「引雷」 =================

	func _boss_suite() -> void:
		await _stand(600.0)
		_boss = _spawner.debug_spawn_boss() as BossConductor
		if _boss == null:
			_check(false, "B0 BOSS「引雷」刷出（BossConductor）")
			return
		_pin_boss = true
		await _wait(1.5)
		_boss._bstate = PursuitBoss.ST_RECOVER
		_boss._bt = 99.0
		await _frames(120)
		_clear()
		await _shot("boss_idle")
		await _span_suite()
		await _rod_suite()
		await _lash_suite()
		_pin_boss = false

	## 一手 BOSS 技能（t=0 = 调用帧），逐帧记录掉血。
	func _boss_take(begin: Callable, frames: int, actions := {}) -> Dictionary:
		var hp0 := _hp()
		var rec := {"px0": _player.global_position.x, "vx0": _player.velocity.x, "hp_f": []}
		begin.call()
		for f in frames + 1:
			if actions.has(f):
				(actions[f] as Callable).call()
			(rec["hp_f"] as Array).append(hp0 - _hp())
			await get_tree().physics_frame
		rec["dmg"] = hp0 - _hp()
		return rec

	func _span_suite() -> void:
		# BA1：p1 低缆 × 满速 + t=2.0 起跳按住 → 0
		_boss._phase2 = false
		_boss._span_high_first = false
		await _run_up()
		var r := await _boss_take(_boss._begin_skill_a, 200, {120: func() -> void: _key(true)})
		_key(false)
		Input.action_release("move_right")
		var spans := get_tree().get_nodes_in_group("live_spans")
		_check(r["dmg"] == 0, "BA1 p1 低缆满速+t2.0 起跳按住 掉血 0", "dmg=%d spans=%d" % [r["dmg"], spans.size()])
		await _frames(90)
		_clear()
		await _frames(5)
		# BA2：p2 两段先高后低，满速钻高缆，t=2.45 起跳按住飞低缆 → 0
		_boss._phase2 = true
		await _run_up()
		var px0 := _player.global_position.x
		var seen: Array[Dictionary] = []
		var probe_spans := func() -> void:
			for n in get_tree().get_nodes_in_group("live_spans"):
				var ls := n as LiveSpan
				seen.append({"x1": ls.x1, "h": ls.height, "shift": ls.shift, "delay": ls.extra_delay})
		r = await _boss_take(_boss._begin_skill_a, 240, {60: probe_spans, 147: func() -> void: _key(true)})
		_key(false)
		Input.action_release("move_right")
		await _shot("boss_span_p2")
		var ok := seen.size() == 2
		if ok:
			var a := seen[0]
			var b := seen[1]
			if float(a["x1"]) > float(b["x1"]):
				var tmp := a
				a = b
				b = tmp
			var dx1 := float(b["x1"]) - (float(a["x1"]) + BalanceWorld9.LIVE_SPAN_LENGTH + 360.0) - float(b["shift"])
			var dd := (float(b["delay"]) - float(a["delay"])) - 0.6 - float(b["shift"]) / 600.0
			ok = float(a["h"]) > 70.0 and float(b["h"]) < 70.0 and absf(dx1) < 1.0 and absf(dd) < 0.001
			_check(ok, "BA2a p2 两段：先高后低、x1′=x1+680、带电晚 0.6",
					"x1=px+%.0f x1'=px+%.0f" % [float(a["x1"]) - px0, float(b["x1"]) - px0])
		else:
			_check(false, "BA2a p2 两段：先高后低、x1′=x1+680、带电晚 0.6", "spans=%d" % seen.size())
		_check(r["dmg"] == 0, "BA2 p2 满速钻高缆 + t2.45 起跳按住飞低缆 掉血 0", "dmg=%d" % r["dmg"])
		_boss._phase2 = false
		await _frames(120)
		_clear()

	func _rod_suite() -> void:
		_boss._phase2 = false
		var hop := BalanceWorld9.ROD_HOP
		var tol := 2.0 * DT + 0.001
		# BR1/BR2/BR3：站桩落位 + 时序 + 站缝心 px+150 全程 0
		await _stand(600.0)
		var px := _player.global_position.x
		var after := func() -> void:
			_player.global_position.x = px + 150.0
			_player.velocity = Vector2.ZERO
		var chain_ref: Array = []
		var land: Array = [-1, -1, -1]
		var dis: Array = [-1, -1, -1]
		var r: Dictionary
		_boss._begin_skill_b()
		var hp0 := _hp()
		after.call()
		var dmg_charge := -1
		for f in 230:
			await get_tree().physics_frame
			var chs := get_tree().get_nodes_in_group("rod_chains")
			var ch: RodChain = null
			if not chs.is_empty():
				ch = chs[0] as RodChain
			if ch != null:
				chain_ref = [{"rod_xs": ch.rod_xs.duplicate(), "rod_ground": ch.rod_ground.duplicate()}]
				for k in mini(3, ch.rod_xs.size()):
					if land[k] < 0 and ch.land_t[k] >= 0.0:
						land[k] = f + 1
					if dis[k] < 0 and ch.discharge_t[k] >= 0.0:
						dis[k] = f + 1
			if dmg_charge < 0 and dis[0] > 0:
				dmg_charge = hp0 - _hp()
		var dmg := hp0 - _hp()
		if chain_ref.is_empty():
			_check(false, "BR0 针链出场")
			return
		var c0: Dictionary = chain_ref[0]
		var rxs: Array = c0["rod_xs"]
		var rgs: Array = c0["rod_ground"]
		var pos_ok := rxs.size() == 3
		for k in rxs.size():
			pos_ok = pos_ok and absf(float(rxs[k]) - (px + 300.0 * k)) < 1.0 \
					and is_equal_approx(float(rgs[k]), _terrain.surface_y_at(float(rxs[k])))
		_check(pos_ok, "BR1 站桩针位 px/px+300/px+600 且贴当地地表", "xs-px=%s" % [rxs.map(func(v): return v - px)])
		var t_ok := true
		var tl := PackedStringArray()
		for k in 3:
			var el := 1.2 + 0.1 * k
			var ed := 2.2 + hop * k
			t_ok = t_ok and absf(land[k] * DT - el) <= tol and absf(dis[k] * DT - ed) <= tol
			tl.append("%.3f/%.3f" % [land[k] * DT, dis[k] * DT])
		_check(t_ok, "BR2 时序：落地 1.2/1.3/1.4、放电 2.2 起每 0.25（±2 帧）", "land/dis=%s" % ", ".join(tl))
		_check(dmg_charge == 0, "BR6 充能期（放电前）掉血 0", "dmg=%d" % dmg_charge)
		_check(dmg == 0, "BR3 站缝心 px+150 放电全程掉血 0", "dmg=%d" % dmg)
		await _frames(60)
		_clear()

		# BR5：vx=0 站 px+150，t=2.30 纯跳（点按不按住）→ 恰 8
		await _stand(600.0)
		px = _player.global_position.x
		r = await _boss_take(func() -> void:
				_boss._begin_skill_b()
				_player.global_position.x = px + 150.0
				_player.velocity = Vector2.ZERO,
				220, {138: func() -> void: _key(true), 140: func() -> void: _key(false)})
		_check(r["dmg"] == BalanceWorld9.ROD_ARC_DAMAGE, "BR5 t2.30 纯跳穿针1→针2 弧带 恰 12", "dmg=%d" % r["dmg"])
		await _frames(60)
		_clear()

		# BR4a：满速直冲不刹 → 恰 15（t2.45 压针2 底爆，R12）
		await _run_up()
		var rod1 := [0.0]
		r = await _boss_take(_boss._begin_skill_b, 200, {5: func() -> void:
				var chs := get_tree().get_nodes_in_group("rod_chains")
				if not chs.is_empty():
					rod1[0] = (chs[0] as RodChain).rod_xs[0]})
		Input.action_release("move_right")
		var lead_ok := absf(float(rod1[0]) - (r["px0"] + 1170.0)) < 1.0
		_check(lead_ok, "BR4-L 满速针位 px+1170/+1470/+1770", "rod1-px=%.0f" % (float(rod1[0]) - r["px0"]))
		_check(r["dmg"] == BalanceWorld9.ROD_BURST_DAMAGE, "BR4a 满速直冲不刹 恰 15（压针2 底爆）", "dmg=%d" % r["dmg"])
		await _frames(60)
		_clear()

		# BR4b：解一——t≈2.03 起刹（1220）停缝心 1320 → 0
		await _run_up()
		var px1 := _player.global_position.x
		var stop_x := [0.0]
		r = await _boss_take(_boss._begin_skill_b, 200, {122: func() -> void: Input.action_release("move_right"),
				170: func() -> void: stop_x[0] = _player.global_position.x})
		var rel: float = float(stop_x[0]) - px1
		_check(r["dmg"] == 0 and rel >= 1280.0 and rel <= 1360.0,
				"BR4b 解一：t2.03 起刹停缝心（缝区 [1280,1360]）掉血 0", "stop=px+%.0f dmg=%d" % [rel, r["dmg"]])
		await _frames(60)
		_clear()

		# BR4c：解二——t=1.50 起刹停针列前（≤1040）→ 0
		await _run_up()
		px1 = _player.global_position.x
		r = await _boss_take(_boss._begin_skill_b, 200, {90: func() -> void: Input.action_release("move_right"),
				170: func() -> void: stop_x[0] = _player.global_position.x})
		rel = float(stop_x[0]) - px1
		_check(r["dmg"] == 0 and rel <= 1040.0, "BR4c 解二：t1.50 起刹停针列前 掉血 0",
				"stop=px+%.0f dmg=%d" % [rel, r["dmg"]])
		await _frames(60)
		_clear()

		# BR7：脚手架避让（各针 ±110 不碰 floating 件，重叠后移 +300）
		await _stand(600.0)
		var sc := _spawner._spawn(_spawner.scaffold_scene, false, 1260.0) as Obstacle
		await _frames(2)
		sc.global_position.x = 900.0 + 360.0 + 60.0 # 左缘 960 → 压住 px+300=900 的 ±110
		var xs := _boss.plan_rod_xs(600.0, 0.0)
		var ok7 := xs.size() > 0
		var hw := sc.body_size.x * 0.5
		for x in xs:
			ok7 = ok7 and (x + 110.0 <= sc.global_position.x - hw or x - 110.0 >= sc.global_position.x + hw)
		_check(ok7, "BR7 针 ±110 与 floating 脚手架零重叠（重叠后移/取消）", "xs=%s" % [xs])
		sc.queue_free()
		_clear()

	func _lash_suite() -> void:
		var tol := DT + 0.002
		for mode in ["static", "run"]:
			if mode == "static":
				await _stand(600.0)
			else:
				await _run_up()
			var hp0 := _hp()
			var px0 := _player.global_position.x
			_boss.global_position = Vector2(px0 + 1400.0, BalanceWorld9.CONDUCTOR_HOVER_Y)
			await get_tree().physics_frame
			var muzzle := _boss.get_node("Visuals/ArmPivot/Muzzle") as Node2D
			var from := muzzle.global_position
			var pxf := _player.global_position.x
			var b := _boss.fire_lash(from.direction_to(_player.global_position))
			var dir0 := b.rotation
			var max_turn := 0.0
			var meet := -1.0
			var origin_ok := false
			var prev_gap := INF
			var prev_lt := 0.0
			for f in 150:
				await get_tree().physics_frame
				if not is_instance_valid(b):
					break
				if f == 0:
					origin_ok = b._spawn_pos.distance_to(from) < 0.5
				max_turn = maxf(max_turn, absf(rad_to_deg(angle_difference(dir0, b.rotation))))
				var gap := b.global_position.x - _player.global_position.x
				if meet < 0.0 and gap <= 0.0 and prev_gap > 0.0:
					meet = prev_lt + (b._lifetime - prev_lt) * prev_gap / (prev_gap - gap)
				prev_gap = gap
				prev_lt = b._lifetime
			await _frames(30)
			var dmg := hp0 - _hp()
			Input.action_release("move_right")
			if mode == "static":
				_check(origin_ok and absf(from.x - (pxf + 1332.0)) < 3.0 and from.y > 296.0 and from.y < 320.0,
						"AL2 出膛点 = Muzzle global_position（≈x_p+1332，y≈306 随臂俯仰）",
						"from=(px+%.1f, %.1f)" % [from.x - pxf, from.y])
				_check(max_turn < 0.5, "AL1 出手后方向恒定（夹角变化 <0.5°）", "max=%.3f°" % max_turn)
				_check(dmg == BalanceWorld9.ARC_LASH_DAMAGE, "AL3 静止玩家恰 12", "dmg=%d" % dmg)
			else:
				_check(dmg == 0, "AL4 满速保持前跑钻过弹 掉血 0", "dmg=%d" % dmg)
				_check(absf(meet - 1.03) <= tol, "AL4t 相遇时刻 1.03s ±1 帧", "meet=%.3f" % meet)
			await _frames(30)
			_clear()
