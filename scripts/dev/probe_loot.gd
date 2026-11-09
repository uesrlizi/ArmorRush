extends Node2D
## 装备掉落端到端探针（窗口小场景自退；不进正常启动流程）：
##   godot --log-file autotest_loot.log res://scenes/previews/probe_loot.tscn
## 带窗跑才出截图（autotest_shots/loot_*.png），无头跑只验断言。其余探针一律冻结
## 掉落（loot_frozen），本探针是 run_loop.md §4 整条链唯一的实机覆盖：
##   A. 掉落小件生命：出膛弹跳落地 → 磁吸飞向玩家 → 授予（转场窗口内到手）+ 主焰换色；
##   B. 装甲：上限 +25 并回补、头顶条加宽；
##   C. 护盾：满盾亮环、吸收先于扣血、吸穿碎盾余伤扣血、环隐；
##   D. 肩炮：挂件在位、副炮弹出膛（小一号+成员色）；双曳光：主枪同拍两发；
##   E. 真实击杀路径：hold_chapter 关 → 杀 BOSS → 掉落（定种子保证掷中）→ 转场 →
##      新场景玩家按持有表恢复（焰色/上限/肩炮/满盾）；
##   F. 阵亡结算出「拾取」组，文案=RunState.loot_labels()。
## 全过打印 ALL OK 退出码 0；有 FAIL 退出码 1；60s 看门狗兜底退出码 2。

func _ready() -> void:
	var runner: Node = Runner.new()
	runner.name = "ProbeLootRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var _fails := 0
	var _windowed := false

	func _ready() -> void:
		_windowed = DisplayServer.get_name() != "headless"
		get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
			printerr("[probe_loot] TIMEOUT 60s")
			get_tree().quit(2))
		_run()

	func _wait(sec: float) -> void:
		await get_tree().create_timer(sec, true, false, true).timeout

	func _check(ok: bool, label: String, detail := "") -> void:
		if not ok:
			_fails += 1
		print("[probe_loot] ", label, " [", "OK" if ok else "FAIL", "] ", detail)

	func _player() -> Player:
		return get_tree().get_first_node_in_group("player") as Player

	## 截图（带窗才有渲染帧）：改状态后先等两帧再读回（读回滞后一帧的老坑）。
	func _shot(tag: String) -> void:
		if not _windowed:
			return
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://autotest_shots"))
		get_viewport().get_texture().get_image().save_png("res://autotest_shots/loot_%s.png" % tag)

	## 等某槽位被授予（返回耗时；超时返回 -1）。
	func _await_slot(slot: StringName, timeout: float) -> float:
		var t := 0.0
		while RunState.mod_member(slot).is_empty() and t < timeout:
			await _wait(0.05)
			t += 0.05
		return t if not RunState.mod_member(slot).is_empty() else -1.0

	## 当前场景里的玩家弹（按弹体缩放分主枪/肩炮）。
	func _player_bullets(scale_lo: float, scale_hi: float) -> Array[Bullet]:
		var out: Array[Bullet] = []
		var container := get_tree().get_first_node_in_group("projectile_container")
		if container == null:
			return out
		for c in container.get_children():
			var b := c as Bullet
			if b != null and b.collision_layer == 8 and b.scale.x >= scale_lo and b.scale.x <= scale_hi:
				out.append(b)
		return out

	func _run() -> void:
		RunState.start_run()
		RunState.mult_frozen = true   # 倍率与本探针无关：冻结保刷怪/计分确定
		RunState.loot_frozen = false
		RunState.hold_chapter = true  # A-D 段击败 BOSS 不转场（E 段再放开走真实路径）
		RunState.begin_handoff()      # 跳过启动页：落地即战（交接路径操作立即解锁）
		get_tree().change_scene_to_file("res://scenes/world/world_1.tscn")
		await _wait(1.0)
		var main := get_tree().current_scene
		var player := _player()
		if player == null or not main.has_method("spawn_loot_drop"):
			_check(false, "S0 world_1 落地", "player=%s" % player)
			get_tree().quit(1)
			return

		# ---- A. 掉落小件生命 + 背推青焰 ----
		var boss_like := Vector2(player.global_position.x + 1400.0, BalanceCombat.BOSS_HOVER_Y)
		main.call("spawn_loot_drop", &"back_cyan", boss_like)
		# 逐物理帧采样轨迹（事件驱动，截图的帧等待不影响采样）：出膛→落地→磁吸必须
		# 连续——曾有定时弧到点还在半空、一帧瞬移到地面 ~360px，读成「弹出两次」。
		var pickup := get_tree().get_nodes_in_group("loot_pickups")[0] as LootPickup
		var trace := {"max": 0.0, "last": pickup.global_position, "grounded": false}
		var sampler := func() -> void:
			if is_instance_valid(pickup) and not pickup._granted:
				var p := pickup.global_position
				trace["max"] = maxf(trace["max"], p.distance_to(trace["last"]))
				trace["last"] = p
				if pickup._landed and not pickup._magnet:
					trace["grounded"] = true
		get_tree().physics_frame.connect(sampler)
		await _wait(0.15)
		_check(get_tree().get_nodes_in_group("loot_pickups").size() == 1, "A1 掉落小件出生（BOSS 锚点距 1400px）")
		await _shot("A_drop_pop")
		var grant_t := await _await_slot(&"back", 3.0)
		grant_t += 0.15
		get_tree().physics_frame.disconnect(sampler)
		_check(grant_t > 0.15 and grant_t < BalanceGlobal.CHAPTER_CLEAR_DELAY,
				"A2 磁吸到手早于转场窗口 %.1fs" % BalanceGlobal.CHAPTER_CLEAR_DELAY, "t=%.2fs" % grant_t)
		_check(trace["max"] < 60.0 and trace["grounded"],
				"A4 轨迹连续：先落地立稳再磁吸，逐物理帧位移 <60px（禁瞬移）",
				"max_step=%.0fpx" % trace["max"])
		var thr: ThrusterFlame = player.get_node("Visuals/NozzlePivot/Thruster")
		var cyan: Array = BalanceMods.MEMBERS[&"back_cyan"]["flame"]
		_check(thr._outer.is_equal_approx(cyan[0]) and thr._core.is_equal_approx(cyan[2])
				and get_tree().get_nodes_in_group("loot_pickups").is_empty(),
				"A3 主焰三层当场换青色、小件授予即灭")

		# ---- B. 装甲 ----
		player.hp = 60
		var max0 := player.max_hp
		main.call("spawn_loot_drop", &"armor_plate", Vector2(player.global_position.x + 900.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_slot(&"armor", 3.0)
		_check(player.max_hp == max0 + 25 and player.hp == 85 and is_equal_approx(player.bar_width(),
				BalanceMods.MEMBERS[&"armor_plate"]["stats"][&"hp_bar_width"]),
				"B1 装甲板：上限 +25 并回补同量、头顶条加宽", "hp=%d/%d w=%.0f" % [player.hp, player.max_hp, player.bar_width()])

		# ---- C. 护盾 ----
		main.call("spawn_loot_drop", &"shield_phase", Vector2(player.global_position.x + 700.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_slot(&"shield", 3.0)
		var ring := player.get_node("Visuals/ShieldRing") as Sprite2D
		var cap := int(BalanceMods.MEMBERS[&"shield_phase"]["stats"][&"shield_capacity"])
		_check(player.shield == cap and ring.visible, "C1 相位盾：满盾 %d、环亮" % cap)
		var hp1 := player.hp
		player.take_damage(10)
		_check(player.shield == cap - 10 and player.hp == hp1, "C2 吸收先于扣血（10 伤全吸、hp 不动）",
				"shield=%d hp=%d" % [player.shield, player.hp])
		player.take_damage(cap - 10 + 5)
		_check(player.shield == 0 and player.hp == hp1 - 5 and not ring.visible,
				"C3 吸穿碎盾：余 5 伤扣血、环隐", "shield=%d hp=%d" % [player.shield, player.hp])
		player.shield = cap # 还原满盾（后段截图要看环）
		player.call("_update_shield_ring")

		# ---- D. 肩炮 + 双曳光（刷 BOSS 当靶子；hold_chapter=真，击败不转场）----
		main.call("spawn_loot_drop", &"shoulder_tracer", Vector2(player.global_position.x + 700.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_slot(&"shoulder", 3.0)
		_check((player.get_node("Visuals/ShoulderPod") as Node2D).visible, "D1 肩炮挂件在位")
		var spawner: Spawner = main.get_node("Spawner")
		var boss := spawner.debug_spawn_boss()
		var pod_seen := false
		var t := 0.0
		Input.action_press("move_right") # 往前压近射程（BOSS 锚点在 1400 边缘）
		while t < 6.0 and not pod_seen:
			await _wait(0.1)
			t += 0.1
			pod_seen = not _player_bullets(0.5, 0.7).is_empty()
		Input.action_release("move_right")
		_check(pod_seen, "D2 副炮弹出膛（小一号弹体）", "t=%.1fs" % t)
		if pod_seen:
			var pb: Bullet = _player_bullets(0.5, 0.7)[0]
			_check(pb.damage == int(BalanceMods.MEMBERS[&"shoulder_tracer"]["stats"][&"pod_damage"])
					and (pb.get_node("Sprite2D") as Sprite2D).modulate.is_equal_approx(
							BalanceMods.MEMBERS[&"shoulder_tracer"]["tint"]),
					"D3 副炮弹伤/曳光色=成员账")
		Input.action_press("jump") # 推进上升：主焰点燃（截图看青焰）
		await _wait(0.35)
		await _shot("D_mech_loadout")
		Input.action_release("jump")
		main.call("spawn_loot_drop", &"gun_twin", Vector2(player.global_position.x + 600.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_slot(&"gun", 3.0)
		var twin_seen := false
		t = 0.0
		while t < 4.0 and not twin_seen:
			await _wait(0.05)
			t += 0.05
			var twins := 0
			for b in _player_bullets(0.95, 1.05):
				if b.damage == int(BalanceMods.MEMBERS[&"gun_twin"]["stats"][&"bullet_damage"]):
					twins += 1
			twin_seen = twins >= 2
		_check(twin_seen, "D4 双曳光：主枪同拍两发（各 3 伤）", "t=%.2fs" % t)
		if is_instance_valid(boss):
			(boss as Enemy).take_damage(99999, true)
		await _wait(1.6)

		# ---- E. 真实击杀路径：掉落 → 转场兜底 → 新场景按持有表恢复 ----
		RunState.hold_chapter = false
		var rng := RandomNumberGenerator.new() # 找一个首掷必中爆率的种子（同算法同序列）
		var seed_hit := 0
		for s in 500:
			rng.seed = s
			if rng.randf() < BalanceGlobal.LOOT_DROP_CHANCE:
				seed_hit = s
				break
		var held_before := RunState.mods.size()
		boss = spawner.debug_spawn_boss()
		await _wait(1.5)
		RunState._rng.seed = seed_hit
		var old_scene := get_tree().current_scene
		player.hp = 99999 # 转场窗口里别被残弹打死（死亡会取消切场景）
		(boss as Enemy).take_damage(99999, true)
		# 掉落跟 BOSS 终爆同拍爆出（击杀后 BOSS_DEATH_FINALE_TIME）：小爆炸链期间不该有
		await _wait(0.2)
		_check(get_tree().get_nodes_in_group("loot_pickups").is_empty(), "E1a 小爆炸链期间未掉（等终爆）")
		await _wait(BalanceCombat.BOSS_DEATH_FINALE_TIME)
		_check(get_tree().get_nodes_in_group("loot_pickups").size() == 1,
				"E1 真实击杀路径掉落（种子定中，终爆那一拍爆出）")
		var waited := 0.0
		while get_tree().current_scene == old_scene and waited < 6.0:
			await _wait(0.1)
			waited += 0.1
		await _wait(0.6)
		_check(get_tree().current_scene != old_scene and RunState.mods.size() == held_before + 1,
				"E2 转场前到手（磁吸或兜底），持有表 +1", "mods=%s" % [RunState.mods.values()])
		var p2 := _player()
		if p2 == null:
			_check(false, "E3 新场景玩家", "null")
		else:
			var thr2: ThrusterFlame = p2.get_node("Visuals/NozzlePivot/Thruster")
			_check(thr2._outer.is_equal_approx(cyan[0])
					and p2.max_hp == BalancePlayer.PLAYER_MAX_HP + 25 and p2.hp == p2.max_hp
					and (p2.get_node("Visuals/ShoulderPod") as Node2D).visible
					and p2.shield == p2.shield_max and p2.shield_max == cap,
					"E3 跨关恢复：焰色/上限满血/肩炮/满盾全在",
					"hp=%d/%d shield=%d/%d" % [p2.hp, p2.max_hp, p2.shield, p2.shield_max])
			await _shot("E_new_scene")

			# ---- F. 阵亡结算出「拾取」组 ----
			RunState.hold_chapter = true
			p2.shield = 0
			p2.take_damage(99999)
			await _wait(BalanceGlobal.GAME_OVER_DELAY + 1.4)
			var hud := get_tree().current_scene.get_node("HUD")
			var group: Array = hud.get("_loot_group")
			var shown: bool = not group.is_empty() and (group[1] as Label).visible
			_check(shown and (group[1] as Label).text == RunState.loot_labels()
					and hud.get("_result_groups").has(group),
					"F1 阵亡结算「拾取」组上屏", RunState.loot_labels())
			await _shot("F_result")

		RunState.hold_chapter = false
		RunState.mult_frozen = false
		if _fails == 0:
			print("[probe_loot] ALL OK")
			get_tree().quit(0)
		else:
			printerr("[probe_loot] FAILS=%d" % _fails)
			get_tree().quit(1)
