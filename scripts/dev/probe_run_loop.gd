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
##   F. start_run 重开全归零（通关后再开新一局不残留）。
## 全过打印 ALL OK 退出码 0；有 FAIL 退出码 1；10s 看门狗兜底退出码 2。
## 旧制回退（RUN_LOOP_ENABLED=false）是编译期常量开关，探针验不到：
## 该路径=改前 draw_next 原文搬运，回退验收=人肉跑一局。

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

		rs.free()
		if _fails == 0:
			print("[probe_run_loop] ALL OK")
			get_tree().quit(0)
		else:
			printerr("[probe_run_loop] FAILS=%d" % _fails)
			get_tree().quit(1)
