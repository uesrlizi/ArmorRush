extends Node2D
## 装备掉落端到端探针（窗口小场景自退；不进正常启动流程）：
##   godot --log-file autotest_loot.log res://scenes/previews/probe_loot.tscn
## 带窗跑才出截图（autotest_shots/loot_*.png），无头跑只验断言。其余探针一律冻结
## 掉落（loot_frozen），本探针是 run_loop.md §4 整条链唯一的实机覆盖：
##   A. 装备芯片生命：芯片=槽位图标×成员色、全程直立 → 爆点朝玩家斜抛、先升后落、
##      渐混吸附（一条连续不停顿的弧，到手有读感且早于黑场）+ 主焰换色 → HUD 拾取播报
##      （图标飞到左上拾取栏队尾、栏下「成员名 效果」播报行）；
##   B. 装甲：上限 +25 并回补、头顶条加宽；
##   C. 护盾：壁垒（满盾亮环、吸收先于扣血、吸穿碎盾余伤扣血）+ 复层盾（碎盾后满盾
##      再立一次、两次充能尽才真碎）；
##   D. 肩部武器：蜂巢三枚错拍出筒+导弹伤、磁轨炮换炮身+高速杆弹出膛；双联装：主枪同拍两发；
##   E. 真实击杀路径：hold_chapter 关 → 杀 BOSS → 掉落（定种子保证掷中，终爆那一拍
##      爆出）→ 黑场延迟拉长到 LOOT_CLEAR_DELAY → 转场 → 新场景玩家按持有表恢复
##      （焰色/上限/肩部武器/满盾满充能）+ 拾取栏按持有表重摆；
##   F. 阵亡结算出「拾取」组，文案=RunState.loot_labels()；
##   G. 暗场章（珊瑚夜 world_4，浅墨 HUD）：芯片与播报行读法截图 + 播报行上屏。
## 全过打印 ALL OK 退出码 0；有 FAIL 退出码 1；90s 看门狗兜底退出码 2。

func _ready() -> void:
	var runner: Node = Runner.new()
	runner.name = "ProbeLootRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var _fails := 0
	var _windowed := false

	func _ready() -> void:
		_windowed = DisplayServer.get_name() != "headless"
		get_tree().create_timer(90.0, true, false, true).timeout.connect(func() -> void:
			printerr("[probe_loot] TIMEOUT 90s")
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

	## 等某成员到手（同槽换装用：旧成员还占着槽，按槽等会立即返回假通过）。
	func _await_member(member: StringName, timeout: float) -> float:
		var slot: StringName = BalanceMods.MEMBERS[member]["slot"]
		var t := 0.0
		while RunState.mod_member(slot) != member and t < timeout:
			await _wait(0.05)
			t += 0.05
		return t if RunState.mod_member(slot) == member else -1.0

	## 等飞行图标落位（事件式；固定 wait 在无头/带窗两种帧率下都不稳）。
	func _await_fly_dock(hud: HUD, timeout := 2.0) -> void:
		var t := 0.0
		while hud._fly != null and t < timeout:
			await _wait(0.05)
			t += 0.05

	## 当前场景里的玩家弹（按弹体缩放分主枪/磁轨）。
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

		# ---- A. 装备芯片生命 + 推进液氢 ----
		var boss_like := Vector2(player.global_position.x + 1400.0, BalanceCombat.BOSS_HOVER_Y)
		var spawn_y := boss_like.y
		main.call("spawn_loot_drop", &"boost_regen", boss_like)
		# 逐物理帧采样轨迹（事件驱动，截图的帧等待不影响采样）：爆点弹出→朝玩家斜抛→渐混
		# 吸附必须是一条连续不停顿的弧（旧版落地立稳再磁吸=中途停顿，曾还瞬移 ~360px）。
		var pickup := get_tree().get_nodes_in_group("loot_pickups")[0] as LootPickup
		_check(pickup._glyph.texture == LootIcons.glyph(&"boost")
				and pickup._glyph.self_modulate.is_equal_approx(BalanceMods.MEMBERS[&"boost_regen"]["tint"]),
				"A0 芯片=槽位图标（推进喷口）×成员色")
		var trace := {"max": 0.0, "min": INF, "last": pickup.global_position, "rot": 0.0,
				"top": pickup.global_position.y, "vx0": 0.0, "launched": false}
		var sampler := func() -> void:
			if is_instance_valid(pickup) and not pickup._granted:
				var p := pickup.global_position
				if pickup._launched:
					if not trace["launched"]:
						trace["launched"] = true
						trace["vx0"] = pickup._vel.x
					else:
						var step := p.distance_to(trace["last"])
						trace["max"] = maxf(trace["max"], step)
						trace["min"] = minf(trace["min"], step)
				trace["last"] = p
				trace["top"] = minf(trace["top"], p.y)
				trace["rot"] = maxf(trace["rot"], absf(pickup.global_rotation))
		get_tree().physics_frame.connect(sampler)
		await _wait(0.15)
		_check(get_tree().get_nodes_in_group("loot_pickups").size() == 1, "A1 装备芯片出生（BOSS 锚点距 1400px）")
		await _shot("A_drop_pop")
		await _wait(0.55)
		await _shot("A_drop_arc") # 弧线中段（颜色/图标预告窗）
		var grant_t := await _await_slot(&"boost", 4.0)
		grant_t += 0.7
		get_tree().physics_frame.disconnect(sampler)
		_check(grant_t > 1.0 and grant_t < BalanceGlobal.LOOT_CLEAR_DELAY,
				"A2 斜抛+吸附到手：有读感（>1.0s）且早于黑场 %.1fs" % BalanceGlobal.LOOT_CLEAR_DELAY,
				"t=%.2fs" % grant_t)
		_check(trace["max"] < 60.0 and trace["min"] > 4.0,
				"A4 一条连续弧：逐物理帧位移 4~60px（不停顿、不瞬移）",
				"step=%.1f~%.1fpx" % [trace["min"], trace["max"]])
		_check(trace["vx0"] < 0.0 and trace["top"] < spawn_y - 40.0,
				"A8 朝玩家斜抛：出手水平速度指向玩家、先升后落（弧顶高出爆点）",
				"vx0=%.0f apex=%.0fpx" % [trace["vx0"], spawn_y - trace["top"]])
		var thr: ThrusterFlame = player.get_node("Visuals/NozzlePivot/Thruster")
		var cyan: Array = BalanceMods.MEMBERS[&"boost_regen"]["flame"]
		_check(thr._outer.is_equal_approx(cyan[0]) and thr._core.is_equal_approx(cyan[2])
				and get_tree().get_nodes_in_group("loot_pickups").is_empty(),
				"A3 主焰三层当场换青色、芯片授予即灭")
		_check(is_zero_approx(trace["rot"]), "A5 芯片全程直立（图标可读，不翻滚）",
				"max_rot=%.3f" % trace["rot"])
		# 拾取播报：图标从机体飞到左上拾取栏队尾（开局空栏→第 1 枚）；栏下「成员名 效果」。
		var hud_a := main.get_node("HUD") as HUD
		await _wait(0.2)
		var flying := hud_a._fly != null and is_instance_valid(hud_a._fly)
		await _shot("A_hud_fly")
		await _await_fly_dock(hud_a)
		var row_ok := (hud_a._fly == null and hud_a._loadout_members.size() == 1
				and hud_a._loadout_members[0] == &"boost_regen"
				and hud_a._loadout_row[0].modulate.is_equal_approx(BalanceMods.MEMBERS[&"boost_regen"]["tint"])
				and hud_a._loadout_row[0].position.is_equal_approx(Vector2.ZERO))
		_check(flying and row_ok, "A6 图标飞入拾取栏：空栏攒下第 1 枚（推进·成员色）",
				"flying=%s row=%s" % [flying, hud_a._loadout_members])
		_check(hud_a._notice.visible and hud_a._notice_name.text == BalanceMods.MEMBERS[&"boost_regen"]["label"]
				and hud_a._notice_desc.text == BalanceMods.MEMBERS[&"boost_regen"]["desc"],
				"A7 播报行「成员名 效果」上屏", "%s %s" % [hud_a._notice_name.text, hud_a._notice_desc.text])
		await _shot("A_hud_notice")

		# ---- B. 装甲 ----
		player.hp = 60
		var max0 := player.max_hp
		main.call("spawn_loot_drop", &"armor_plate", Vector2(player.global_position.x + 900.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_slot(&"armor", 3.0)
		_check(player.max_hp == max0 + 25 and player.hp == 85 and is_equal_approx(player.bar_width(),
				BalanceMods.MEMBERS[&"armor_plate"]["stats"][&"hp_bar_width"]),
				"B1 复合装甲：上限 +25 并回补同量、头顶条加宽", "hp=%d/%d w=%.0f" % [player.hp, player.max_hp, player.bar_width()])

		# ---- C. 护盾：壁垒（一次性大盾）→ 复层盾（碎盾后再立一次） ----
		main.call("spawn_loot_drop", &"shield_wall", Vector2(player.global_position.x + 700.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_slot(&"shield", 3.0)
		var ring := player.get_node("Visuals/ShieldRing") as Sprite2D
		var cap := int(BalanceMods.MEMBERS[&"shield_wall"]["stats"][&"shield_capacity"])
		_check(player.shield == cap and ring.visible, "C1 壁垒：满盾 %d、环亮" % cap)
		var hp1 := player.hp
		player.take_damage(10)
		_check(player.shield == cap - 10 and player.hp == hp1, "C2 吸收先于扣血（10 伤全吸、hp 不动）",
				"shield=%d hp=%d" % [player.shield, player.hp])
		player.take_damage(cap - 10 + 5)
		_check(player.shield == 0 and player.hp == hp1 - 5 and not ring.visible,
				"C3 吸穿碎盾：余 5 伤扣血、环隐（壁垒只有一次充能，不再立）",
				"shield=%d hp=%d" % [player.shield, player.hp])
		player.shield = cap # 还原满盾（后段截图要看环）
		player.call("_update_shield_ring")
		# 复层盾：碎盾后 SHIELD_REFORM_TIME 满盾再立一次，两次充能尽才真碎。
		main.call("spawn_loot_drop", &"shield_reform", Vector2(player.global_position.x + 600.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_member(&"shield_reform", 4.0) # 同槽换装：壁垒还占着盾槽，按成员等
		var rcap := int(BalanceMods.MEMBERS[&"shield_reform"]["stats"][&"shield_capacity"])
		_check(player.shield == rcap and player._shield_charges == 2,
				"C4 复层盾：满盾 %d、充能 2 次" % rcap, "shield=%d charges=%d" % [player.shield, player._shield_charges])
		player.take_damage(rcap) # 第一记全吸→碎盾（还剩一次充能）
		_check(player.shield == 0 and player._shield_charges == 1, "C5 复层盾第一碎：进再立倒计时")
		await _wait(BalanceMods.SHIELD_REFORM_TIME + 0.3)
		_check(player.shield == rcap and ring.visible, "C6 复层盾再立：%.1fs 后满盾环亮" % BalanceMods.SHIELD_REFORM_TIME,
				"shield=%d" % player.shield)
		player.take_damage(rcap) # 第二记碎盾（充能耗尽，不再立）
		await _wait(BalanceMods.SHIELD_REFORM_TIME + 0.3)
		_check(player.shield == 0 and player._shield_charges == 0 and not ring.visible,
				"C7 复层盾两次尽：真碎不再立")
		player.shield = rcap # 还原满盾+满充能（E 段跨关携带要看满盾）
		player._shield_charges = 2
		player.call("_update_shield_ring")

		# ---- D. 肩部武器（蜂巢/磁轨炮）+ 双联装（刷 BOSS 当靶子；hold_chapter=真，击败不转场）----
		main.call("spawn_loot_drop", &"shoulder_rack", Vector2(player.global_position.x + 700.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_slot(&"shoulder", 3.0)
		_check((player.get_node("Visuals/ShoulderPod") as Node2D).visible
				and (player.get_node("Visuals/ShoulderPod/PodPivot/MissilePod") as Sprite2D).visible,
				"D1 导弹舱在位（炮身挂 PodPivot 轴上）")
		var spawner: Spawner = main.get_node("Spawner")
		var boss := spawner.debug_spawn_boss()
		var missiles_seen := 0
		var t := 0.0
		Input.action_press("move_right") # 往前压近射程（BOSS 锚点在 1400 边缘）
		while t < 6.0 and missiles_seen < 3:
			await _wait(0.1)
			t += 0.1
			missiles_seen = 0
			for c in get_tree().get_first_node_in_group("projectile_container").get_children():
				if c is PlayerMissile:
					missiles_seen += 1
		Input.action_release("move_right")
		_check(missiles_seen >= 3, "D2 蜂巢齐射：三枚小导弹出筒（错拍+向上扇形）",
				"t=%.1fs n=%d" % [t, missiles_seen])
		if missiles_seen > 0:
			var pm_seen := false
			for c in get_tree().get_first_node_in_group("projectile_container").get_children():
				var pm := c as PlayerMissile
				if pm != null and pm.damage == int(BalanceMods.MEMBERS[&"shoulder_rack"]["stats"][&"missile_damage"]):
					pm_seen = true
			_check(pm_seen, "D3 导弹伤=成员账（6）")
		# 磁轨炮：替换肩部成员 → 细长杆弹直线出膛（按弹速分辨弹种）
		main.call("spawn_loot_drop", &"shoulder_rail", Vector2(player.global_position.x + 600.0, BalanceCombat.BOSS_HOVER_Y))
		await _await_member(&"shoulder_rail", 4.0) # 同槽换装：蜂巢还占着肩槽，按成员等
		_check((player.get_node("Visuals/ShoulderPod/PodPivot/RailGun") as Sprite2D).visible
				and not (player.get_node("Visuals/ShoulderPod/PodPivot/MissilePod") as Sprite2D).visible,
				"D4 磁轨炮在位（换炮身=换成员）")
		var rail_seen := false
		t = 0.0
		Input.action_press("move_right")
		while t < 6.0 and not rail_seen:
			await _wait(0.05)
			t += 0.05
			for b in _player_bullets(0.95, 1.05):
				if b.speed >= 3000.0 and b.damage == int(BalanceMods.MEMBERS[&"shoulder_rail"]["stats"][&"rail_damage"]):
					rail_seen = true
		Input.action_release("move_right")
		_check(rail_seen, "D5 磁轨弹出膛（速 3600 直线杆弹）", "t=%.2fs" % t)
		Input.action_press("jump") # 推进上升：主焰点燃（截图看液氢青焰）
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
		_check(twin_seen, "D6 双联装：主枪同拍两发（各 3 伤）", "t=%.2fs" % t)
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
		var kill_t := Time.get_ticks_msec()
		while get_tree().current_scene == old_scene \
				and Time.get_ticks_msec() - kill_t < 9000.0:
			await _wait(0.05)
		# 计时口径=墙钟毫秒（SceneTreeTimer 每次触发要走到帧边界，累计步数会低估
		# 真实时长 ~1.5 倍——阈值恰 LOOT_CLEAR_DELAY 时按步数累计会压线假 FAIL）。
		var clear_gap := (Time.get_ticks_msec() - kill_t) / 1000.0
		await _wait(0.6)
		_check(get_tree().current_scene != old_scene and RunState.mods.size() == held_before + 1,
				"E2 转场前到手（吸附或兜底），持有表 +1", "mods=%s" % [RunState.mods.values()])
		_check(clear_gap >= BalanceGlobal.LOOT_CLEAR_DELAY,
				"E4 有掉落时黑场延迟拉长（≥%.1fs，播报读得完）" % BalanceGlobal.LOOT_CLEAR_DELAY,
				"kill→切场景 %.1fs" % clear_gap)
		var p2 := _player()
		if p2 == null:
			_check(false, "E3 新场景玩家", "null")
		else:
			var thr2: ThrusterFlame = p2.get_node("Visuals/NozzlePivot/Thruster")
			_check(thr2._outer.is_equal_approx(cyan[0])
					and p2.max_hp == BalancePlayer.PLAYER_MAX_HP + 25 and p2.hp == p2.max_hp
					and (p2.get_node("Visuals/ShoulderPod") as Node2D).visible
					and p2.shield == p2.shield_max
					and p2.shield_max == int(BalanceMods.MEMBERS[RunState.mod_member(&"shield")]["stats"][&"shield_capacity"])
					and p2._shield_charges == int(BalanceMods.MEMBERS[RunState.mod_member(&"shield")]["stats"].get(&"shield_charges", 1.0)),
					"E3 跨关恢复：焰色/上限满血/肩部武器/满盾满充能全在",
					"hp=%d/%d shield=%d/%d charges=%d" % [p2.hp, p2.max_hp, p2.shield, p2.shield_max, p2._shield_charges])
			var hud2 := get_tree().current_scene.get_node("HUD") as HUD
			var expected: Array[StringName] = [] # 新关拾取栏=持有成员按槽位序各一枚
			for slot_id: StringName in BalanceMods.SLOTS:
				if not RunState.mod_member(slot_id).is_empty():
					expected.append(RunState.mod_member(slot_id))
			var row2_ok := hud2._loadout_members == expected
			for i in hud2._loadout_row.size():
				if not hud2._loadout_row[i].modulate.is_equal_approx(
						BalanceMods.MEMBERS[hud2._loadout_members[i]]["tint"]):
					row2_ok = false
			_check(row2_ok and hud2._loadout_row.size() == RunState.mods.size(),
					"E5 新关拾取栏按持有表重摆（槽位序、成员色，不画空槽）",
					"row=%d/%d" % [hud2._loadout_row.size(), RunState.mods.size()])
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

			# ---- G. 暗场章（珊瑚夜，浅墨 HUD）：芯片与装备栏/播报行读法 ----
			var g_member := &"boost_air" if RunState.mod_member(&"boost").is_empty() else &"blade_heavy"
			RunState.begin_handoff()
			get_tree().change_scene_to_file("res://scenes/world/world_4.tscn")
			await _wait(1.2)
			var main4 := get_tree().current_scene
			var p4 := _player()
			if p4 == null or not main4.has_method("spawn_loot_drop"):
				_check(false, "G0 world_4 落地", "player=%s" % p4)
			else:
				p4.hp = 99999
				main4.call("spawn_loot_drop", g_member,
						Vector2(p4.global_position.x + 1000.0, BalanceCombat.BOSS_HOVER_Y))
				await _wait(0.3)
				await _shot("G_dark_chip")
				var g_t := await _await_member(g_member, 4.5) # E 段后 6 槽全满：blade 上已有
				# 一员（按槽等会立即返回假通过），同槽换装按成员等
				await _wait(0.2)
				var hud4 := main4.get_node("HUD") as HUD
				await _await_fly_dock(hud4)
				var g_icon_ok := false # 落槽=拾取栏里这枚成员色图标已就位（同 E5 的账，按行查）
				for i in hud4._loadout_row.size():
					if hud4._loadout_members[i] == g_member \
							and hud4._loadout_row[i].modulate.is_equal_approx(
									BalanceMods.MEMBERS[g_member]["tint"]):
						g_icon_ok = true
				_check(g_t >= 0.0 and hud4._notice.visible
						and hud4._notice_name.text == BalanceMods.MEMBERS[g_member]["label"]
						and g_icon_ok,
						"G1 暗场章播报行与落槽", "%s %s" % [hud4._notice_name.text, hud4._notice_desc.text])
				await _shot("G_dark_notice")

		RunState.hold_chapter = false
		RunState.mult_frozen = false
		if _fails == 0:
			print("[probe_loot] ALL OK")
			get_tree().quit(0)
		else:
			printerr("[probe_loot] FAILS=%d" % _fails)
			get_tree().quit(1)
