extends Node2D
## 局内循环探针（纯逻辑自退；不进正常启动流程）：
##   godot --headless res://scenes/previews/probe_run_loop.tscn
## 验 run_loop.md §1 的抽关账（新实例化 RunState 脚本，不碰游戏 autoload）：
##   A. start_run：首关∈FIRST_POOL 白名单，关卡/通关/RUSH 记号全归零；
##   B. 前 4 次抽关照走洗牌袋：stage 2..4、相邻不撞、无重复；
##   C. 第 4 关后进 RUSH：stage 钉 5、rush_active、阵容=没抽到的场景里取 3 台、
##      整局不重复（7 场景池时恰好覆盖全池各一次）；
##   D. 阵容逐台弹出（stage 不再涨），打空返回 "" 且 run_complete；
##   E. 携带血量取走即清（-1=不携带兜底）；
##   F. start_run 重开全归零（通关后再开新一局不残留）；
##   G. 疾驰倍率公式（run_loop.md §2）：输出（防御后实伤）涨进度+击杀收头、恰满
##      整除进档、一场 BOSS 战 400 实伤=+4 档锚点、受击按伤害量扣（唯一掉档来源，
##      无停手流失）、进度跨关保持（只 start_run 归零）、档位封顶、密度乘区、
##      局级统计（最高档/受击数）、冻结闸（autotest/transition_probe 确定性用）；
##   H. 难度阶梯（run_loop.md §3）：后摇按关序 ×0.95^(n−1)、第 4 关起齐射 +1、
##      凶度封顶第 4 关档（RUSH stage=5 与旧制滚动都封 RUN_NORMAL_LEVELS 档）；
##   I. 轻肉鸽装备（run_loop.md §4）：持有表/统一访问器、同槽位不爆（掉落表=未持有
##      槽，种子批跑）、全持有空掷、拾取清单文案、start_run 清空、冻结闸不随新局清、
##      携带盾量取即清、成员表完整（键全游戏唯一）、机动红线与容量黄线不进池。
## 全过打印 ALL OK 退出码 0；有 FAIL 退出码 1；10s 看门狗兜底退出码 2。
## 旧制回退（RUN_LOOP_ENABLED/MULT_ENABLED=false）是编译期常量开关，探针验不到：
## 这些路径=改前逻辑原样保留，回退验收=人肉跑一局。

func _ready() -> void:
	var runner: Node = Runner.new()
	runner.name = "ProbeRunLoopRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var _fails := 0

	func _ready() -> void:
		get_tree().create_timer(10.0, true, false, true).timeout.connect(func() -> void:
			printerr("[probe_run_loop] TIMEOUT 10s")
			get_tree().quit(2))
		_run()

	func _check(ok: bool, label: String, detail := "") -> void:
		if not ok:
			_fails += 1
		print("[probe_run_loop] ", label, " [", "OK" if ok else "FAIL", "] ", detail)

	func _run() -> void:
		var rs: Node = load("res://scripts/core/run_state.gd").new()
		var all: Array[String] = rs.SCENES

		# ---- A. 开局 ----
		var first: String = rs.start_run()
		var in_first_pool: bool = first in rs.FIRST_POOL
		_check(in_first_pool, "A1 首关在白名单", first.get_file())
		_check(rs.stage == 1 and not rs.rush_active and not rs.run_complete
				and rs.handover_hp == -1, "A2 开局记号归零")
		var total_levels := BalanceGlobal.RUN_NORMAL_LEVELS + 1
		var prog: String = " ".join(rs.progress_parts())
		_check(prog == "关卡 1/%d" % total_levels, "A3 进度文案带分母", prog)

		# ---- B. 前 4 关照旧抽袋（首关算第 1 关，再抽 3 次到第 4 关）----
		var drawn: Array[String] = [first]
		var ok_seq := true
		var ok_adj := true
		for i in 3:
			var s: String = rs.draw_next()
			drawn.append(s)
			if rs.stage != i + 2 or not (s in all) or drawn.count(s) > 1:
				ok_seq = false
			if s == drawn[drawn.size() - 2] and drawn.size() >= 2:
				ok_adj = false
		_check(ok_seq, "B1 前 4 关袋内不重复、stage 2..4 递进",
				"stage=%d" % rs.stage)
		_check(ok_adj, "B2 相邻两关不撞")
		prog = " ".join(rs.progress_parts())
		_check(prog == "关卡 %d/%d" % [BalanceGlobal.RUN_NORMAL_LEVELS, total_levels],
				"B3 末个普通关进度", prog)

		# ---- C. 进 RUSH：第 4 关打完这一抽应转身进终局 ----
		var rush_first: String = rs.draw_next()
		_check(rs.rush_active and rs.stage == BalanceGlobal.RUN_NORMAL_LEVELS + 1,
				"C1 进 RUSH：rush_active + stage 钉 %d" % (BalanceGlobal.RUN_NORMAL_LEVELS + 1),
				"stage=%d rush=%s" % [rs.stage, rs.rush_active])
		_check(not rush_first.is_empty() and not rs.rush_lineup.is_empty(),
				"C1b RUSH 首台已弹出、阵容仍有余台")
		prog = " ".join(rs.progress_parts())
		_check(prog == "最终战 1/%d" % BalanceGlobal.RUN_RUSH_COUNT, "C1c RUSH 首台进度", prog)
		# 完整阵容 = 出膛顺序拼回：首台已在进 RUSH 那一抽弹出，余下队列保持原序
		var lineup_all: Array[String] = [rush_first]
		lineup_all.append_array(rs.rush_lineup)
		_check(lineup_all.size() == BalanceGlobal.RUN_RUSH_COUNT,
				"C2 阵容=%d 台" % BalanceGlobal.RUN_RUSH_COUNT,
				"lineup=%s" % [lineup_all])
		# 覆盖账（池大小无关）：阵容全是本局没抽到的场景、整局无重复；
		# 池恰好 = 普通关+阵容台数时（7 场景池）每局看满全池各一次。
		var seen: Array[String] = drawn.duplicate()
		seen.append_array(lineup_all)
		var coverage_ok := true
		for s in seen:
			if not (s in all) or seen.count(s) > 1:
				coverage_ok = false
		for s in lineup_all:
			if s in drawn:
				coverage_ok = false
		if all.size() == BalanceGlobal.RUN_NORMAL_LEVELS + BalanceGlobal.RUN_RUSH_COUNT:
			coverage_ok = coverage_ok and seen.size() == all.size()
		_check(coverage_ok, "C3 阵容=没抽到的场景、整局不重复（池=%d）" % all.size())

		# ---- D. 阵容打空=通关 ----
		var ok_rush_seq := true
		for i in lineup_all.size() - 1: # 剩余台数（首台已在 C 弹出）
			var s: String = rs.draw_next()
			if rs.stage != BalanceGlobal.RUN_NORMAL_LEVELS + 1 or s != lineup_all[i + 1]:
				ok_rush_seq = false
		_check(ok_rush_seq, "D1 RUSH 逐台跳场景、关号不涨",
				"stage=%d" % rs.stage)
		var last: String = rs.draw_next()
		_check(last.is_empty() and rs.run_complete, "D2 阵容打空返回空串+通关记号")
		prog = " ".join(rs.progress_parts())
		_check(prog == "最终战 %d/%d" % [BalanceGlobal.RUN_RUSH_COUNT, BalanceGlobal.RUN_RUSH_COUNT],
				"D2b 通关结算进度=满额", prog)
		var again: String = rs.draw_next()
		_check(again.is_empty(), "D3 通关后再抽仍空串（幂等）")

		# ---- E. 携带血量取走即清 ----
		rs.handover_hp = 42
		_check(rs.take_handover_hp() == 42 and rs.take_handover_hp() == -1,
				"E1 携带血量取走即清、默认 -1")

		# ---- F. 重开归零 ----
		rs.start_run()
		_check(rs.stage == 1 and not rs.rush_active and not rs.run_complete
				and rs.handover_hp == -1 and rs.rush_lineup.is_empty(),
				"F1 通关后重开不残留（rush/通关/携带全归零）")

		# ---- G. 疾驰倍率账（run_loop.md §2；数字全读 BalanceGlobal 常量不抄死值）----
		_check(rs.multiplier() == 1 and is_equal_approx(rs.mult_density_factor(), 1.0),
				"G1 开局 ×1、密度乘区 1")
		rs.mult_add_damage(99)
		_check(rs.multiplier() == 1, "G2 输出 99→19.8 进度差一格仍 ×1",
				"progress=%.1f" % rs.mult_progress)
		rs.mult_add_damage(1)
		_check(rs.multiplier() == 2, "G3 输出 100→恰满 20 进度整除进 ×2",
				"progress=%.1f" % rs.mult_progress)
		rs.mult_take_hit(2)
		_check(rs.multiplier() == 1 and rs.hits_taken == 1,
				"G4 受击 ×10：2 伤蹭弹掉半档+清零+计数", "progress=%.1f" % rs.mult_progress)
		rs.mult_add_damage(BalanceCombat.BOSS_MAX_HP) # 一场 BOSS 战的实伤量（用户锚点）
		var boss_tiers := int(BalanceCombat.BOSS_MAX_HP * BalanceGlobal.MULT_DAMAGE_FACTOR
				/ BalanceGlobal.MULT_STEP)
		_check(rs.multiplier() == clampi(1 + boss_tiers, 1, BalanceGlobal.MULT_MAX)
				and rs.mult_max_run == rs.multiplier(),
				"G5 无伤一场 BOSS=+%d 档（输出系数锚点）" % boss_tiers,
				"progress=%.1f ×%d" % [rs.mult_progress, rs.multiplier()])
		rs.mult_take_hit(12) # 严苛档：一发重击 12 伤=-120，顶格进度也清空
		_check(rs.multiplier() == 1 and is_equal_approx(rs.mult_progress, 0.0)
				and rs.hits_taken == 2, "G6 重击清空（掉档唯一来源=受击）")
		for _i in 4:
			rs.mult_add_kill(25) # 击杀收头渠道独立有效：盾卫 15/次 攒 60
		_check(rs.multiplier() == 4, "G7 击杀收头 4 杀 60 进度=×4",
				"progress=%.1f" % rs.mult_progress)
		rs.mult_add_kill(50)
		_check(rs.multiplier() == BalanceGlobal.MULT_MAX,
				"G8 进度封顶、档位止于 ×%d" % BalanceGlobal.MULT_MAX,
				"progress=%.1f" % rs.mult_progress)
		_check(is_equal_approx(rs.mult_density_factor(),
				pow(BalanceGlobal.MULT_GAP_STEP, float(BalanceGlobal.MULT_MAX - 1))),
				"G9 顶档密度乘区=GAP_STEP^(MAX-1)")
		_check(rs.mult_max_run == BalanceGlobal.MULT_MAX, "G10 局级最高档只涨不落")
		rs.mult_frozen = true
		var frozen_progress: float = rs.mult_progress
		rs.mult_add_damage(400)
		rs.mult_add_kill(50)
		rs.mult_take_hit(5)
		_check(is_equal_approx(rs.mult_progress, frozen_progress)
				and rs.multiplier() == 1
				and is_equal_approx(rs.mult_density_factor(), 1.0),
				"G11 冻结闸：涨/扣全停、档位恒 ×1、乘区恒 1（autotest 确定性用）")
		rs.mult_frozen = false
		rs.start_run()
		_check(rs.mult_progress == 0.0 and rs.mult_max_run == 1 and rs.hits_taken == 0,
				"G12 进度跨关保持不清档、只 start_run 归零")

		# ---- H. 难度阶梯账（run_loop.md §3；LADDER_ENABLED=false 是编译期开关，探针验不到）----
		rs.stage = 1
		_check(is_equal_approx(rs.ladder_recover_factor(), 1.0)
				and rs.ladder_bullets_extra() == 0,
				"H1 第 1 关：后摇系数 1、弹数不加成")
		rs.stage = 2
		_check(is_equal_approx(rs.ladder_recover_factor(),
				BalanceGlobal.LADDER_RECOVER_MULT),
				"H2 第 2 关：后摇 ×0.95")
		rs.stage = 4
		var stage4 := maxf(pow(BalanceGlobal.LADDER_RECOVER_MULT, 3.0),
				BalanceGlobal.LADDER_RECOVER_MIN)
		_check(is_equal_approx(rs.ladder_recover_factor(), stage4)
				and rs.ladder_bullets_extra() == 1,
				"H3 第 4 关：后摇 ×0.95³、齐射 +1（阶梯满档）")
		rs.stage = BalanceGlobal.RUN_NORMAL_LEVELS + 1 # RUSH：stage 钉 5
		_check(is_equal_approx(rs.ladder_recover_factor(), stage4)
				and rs.ladder_bullets_extra() == 1,
				"H4 RUSH 凶度封顶=第 4 关档（stage=%d 取 %d 档）"
						% [rs.stage, BalanceGlobal.RUN_NORMAL_LEVELS])
		rs.stage = BalanceGlobal.RUN_NORMAL_LEVELS + 3 # 旧制无限滚动继续涨
		_check(is_equal_approx(rs.ladder_recover_factor(), stage4),
				"H5 旧制滚动同封顶（凶度有顶）")
		# 体量增长账（血量/失衡阈值同系数；实例侧资格闸门=Enemy._ladder_scaling，
		# 纯逻辑探针验不到，autotest 真局覆盖）
		rs.stage = 2
		var g2: float = rs.ladder_growth_factor()
		rs.stage = 4
		var g4: float = rs.ladder_growth_factor()
		_check(is_equal_approx(g2, BalanceGlobal.LADDER_GROWTH_MULT)
				and is_equal_approx(g4, minf(pow(BalanceGlobal.LADDER_GROWTH_MULT,
						float(BalanceGlobal.RUN_NORMAL_LEVELS - 1)),
						BalanceGlobal.LADDER_GROWTH_MAX)),
				"H6 体量增长：×1.12/关、封顶 ×%s" % BalanceGlobal.LADDER_GROWTH_MAX,
				"g2=%.3f g4=%.3f" % [g2, g4])
		rs.stage = BalanceGlobal.RUN_NORMAL_LEVELS + 1
		_check(is_equal_approx(rs.ladder_growth_factor(), g4),
				"H7 RUSH 体量同封顶（×0.7 折扣叠加后 ≈0.98 原血量）")
		rs.stage = 1

		# ---- I. 轻肉鸽装备账（run_loop.md §4；成员数值全读 BalanceMods 不抄死值）----
		rs.start_run()
		_check(rs.mods.is_empty() and rs.mod_member(&"gun").is_empty()
				and is_equal_approx(rs.mod_stat(&"fire_cooldown", 0.22), 0.22),
				"I1 开局空持有表：mod_member 空、mod_stat 回默认值")
		var whitehot_cd: float = BalanceMods.MEMBERS[&"gun_whitehot"]["stats"][&"fire_cooldown"]
		var slot: StringName = rs.equip(&"gun_whitehot")
		_check(slot == &"gun" and rs.mod_member(&"gun") == &"gun_whitehot"
				and is_equal_approx(rs.mod_stat(&"fire_cooldown", 0.22), whitehot_cd)
				and is_equal_approx(rs.mod_stat(&"melee_damage_1", 15.0), 15.0),
				"I2 装备入表：返回所属槽、访问器只改本成员的键",
				"cd=%.2f" % rs.mod_stat(&"fire_cooldown", 0.22))
		rs._rng.seed = 20261108 # 掉落掷骰走同一把 _rng：定种子批跑可复现
		var gun_rolled := false
		var slots_seen := {}
		for _i in 300:
			var m: StringName = rs.roll_loot()
			var s: StringName = BalanceMods.MEMBERS[m]["slot"]
			slots_seen[s] = true
			if s == &"gun":
				gun_rolled = true
		_check(not gun_rolled, "I3 同槽位不爆：持有枪槽时 300 掷从不出枪槽成员")
		_check(slots_seen.size() == BalanceMods.SLOTS.size() - 1,
				"I4 掉落表=全部未持有槽（300 掷覆盖 %d 槽）" % (BalanceMods.SLOTS.size() - 1),
				"seen=%s" % [slots_seen.keys()])
		for s: StringName in BalanceMods.SLOTS:
			for id: StringName in BalanceMods.MEMBERS:
				if BalanceMods.MEMBERS[id]["slot"] == s:
					rs.equip(id)
					break
		_check(rs.mods.size() == BalanceMods.SLOTS.size() and rs.roll_loot().is_empty(),
				"I5 全持有=掉落表空：空掷不掉")
		var labels: PackedStringArray = []
		for s: StringName in BalanceMods.SLOTS:
			labels.append(BalanceMods.MEMBERS[rs.mods[s]]["label"])
		_check(rs.loot_labels() == "·".join(labels), "I6 拾取清单按槽位序 · 连接",
				rs.loot_labels())
		rs.loot_frozen = true
		rs.handover_shield = 17
		rs.start_run()
		_check(rs.mods.is_empty() and rs.loot_labels().is_empty() and rs.loot_frozen
				and rs.handover_shield == -1,
				"I7 start_run 清持有表/携带盾量；冻结闸不随新局清（同 mult_frozen 惯例）")
		rs.loot_frozen = false
		rs.handover_shield = 9
		_check(rs.take_handover_shield() == 9 and rs.take_handover_shield() == -1,
				"I8 携带盾量取走即清、默认 -1")
		# 成员表完整：每槽 ≥1 成员、成员 slot 合法、tint 齐、stats 键全游戏唯一
		# （每把"钥匙"只属于一个槽——mod_stat 首个命中即返回的前提）
		var table_ok := true
		var key_owner := {}
		for s: StringName in BalanceMods.SLOTS:
			var roster := 0
			for id: StringName in BalanceMods.MEMBERS:
				var mem: Dictionary = BalanceMods.MEMBERS[id]
				if not (mem["slot"] in BalanceMods.SLOTS) or not mem.has("tint") \
						or not mem.has("label") or not mem.has("stats"):
					table_ok = false
				if mem["slot"] != s:
					continue
				roster += 1
				for k: StringName in mem["stats"]:
					if key_owner.has(k) and key_owner[k] != s:
						table_ok = false
					key_owner[k] = s
			if roster == 0:
				table_ok = false
		_check(table_ok, "I9 成员表完整：%d 槽各有成员、键全游戏唯一" % BalanceMods.SLOTS.size(),
				"members=%d keys=%d" % [BalanceMods.MEMBERS.size(), key_owner.size()])
		# 机动红线（不进池）：跳跃初速/最大上升速度；容量=黄线（±0.3s 内）
		var redline_ok := true
		for k: StringName in key_owner:
			var ks := String(k)
			if ks.contains("jump") or ks.contains("ascent"):
				redline_ok = false
		for id: StringName in BalanceMods.MEMBERS:
			var stats: Dictionary = BalanceMods.MEMBERS[id]["stats"]
			if stats.has(&"boost_capacity") and absf(float(stats[&"boost_capacity"])
					- BalancePlayer.BOOST_CAPACITY) > 0.3 + 0.0001:
				redline_ok = false
		_check(redline_ok, "I10 机动红线不进池（跳跃/上升无键）、容量在黄线 ±0.3s 内")
		# 爆率账：空持有表下批跑 2000 台 BOSS，掉落频率≈LOOT_DROP_CHANCE（±0.04 容差，
		# 定种子=确定性）；全持有时一台都不掉（爆率闸在前、掉落表空在后）。
		rs.start_run()
		rs._rng.seed = 7
		var dropped := 0
		for _i in 2000:
			if not rs.roll_drop().is_empty():
				dropped += 1
		var rate := dropped / 2000.0
		for s: StringName in BalanceMods.SLOTS:
			for id: StringName in BalanceMods.MEMBERS:
				if BalanceMods.MEMBERS[id]["slot"] == s:
					rs.equip(id)
					break
		var full_drops := 0
		for _i in 200:
			if not rs.roll_drop().is_empty():
				full_drops += 1
		_check(absf(rate - BalanceGlobal.LOOT_DROP_CHANCE) < 0.04 and full_drops == 0,
				"I11 爆率≈%.0f%%、全持有一台都不掉" % (BalanceGlobal.LOOT_DROP_CHANCE * 100.0),
				"rate=%.3f full=%d" % [rate, full_drops])
		rs.start_run()

		rs.free()
		if _fails == 0:
			print("[probe_run_loop] ALL OK")
			get_tree().quit(0)
		else:
			printerr("[probe_run_loop] FAILS=%d" % _fails)
			get_tree().quit(1)
