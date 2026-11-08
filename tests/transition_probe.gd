extends Node
## 关卡轮换端到端探针（无头）：洗牌袋纯 API 直测 ×200（首抽必在开局白名单、
## 局内不重复（一局=普通段+RUSH 段）、相邻永不相同——含跨局连抽 10N 长跑）
## → 入口跳板自动抽关 → 首关死一次验"死亡重开=重掷新一局"（白名单首关+清分+
## 启动页，非原地复活）→ 真实打完一整局（RUN_NORMAL_LEVELS 普通关 + RUSH
## RUN_RUSH_COUNT 台逐台跳场景），逐关验证不变式：落地都在场景池、白名单只锁
## 首关、局内不重复、相邻不重复、RUSH 段 rush_active、通关原地结算（无末章
## 滚动——局内循环 v2，run_loop.md §1）、分数跨关累计、首关照常带启动页
## （入口纯跳板不交接）、后续关交接跳启动页、落地满血（RUSH 击破间探针全程
## 无伤=满血账不受 RUSH_NO_HEAL 影响）。
## 场景先后是随机的，所以只断言不变式，不断言固定链；RunState.SCENES 加新
## 场景后本探针自动覆盖，无需改这里。
## 用法：godot --headless res://tests/transition_probe.tscn
## 本探针自己不是 current_scene（_setup 里先放占位节点顶包），
## change_scene_to_file 只释放 current_scene，探针作为 root 兄弟节点存活。

const ENTRY := "res://scenes/entry.tscn"

var _t0 := 0
var _current: Node = null # 当前落地场景（等下一跳转场时对照用）


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	# 疾驰倍率冻结（run_loop.md §2）：倍率跨关保持后「每关得分=BOSS_SCORE×关序」
	# 不再成立（第 2 关起按携带档结账）；本探针验的是转场账不是倍率账，冻结回
	# 旧公式账最稳（倍率公式归 probe_run_loop G 段纯逻辑验）。
	RunState.mult_frozen = true
	# 装备掉落冻结（run_loop.md §4）：真实路径杀 BOSS 会爆装备——装甲板抬血量上限后
	# 「每关满血=PLAYER_MAX_HP」断言不再成立；本探针验转场账，冻结回出厂账。
	RunState.loot_frozen = true
	_setup.call_deferred() # 场景装载期内 root 忙，deferred 一拍再动


func _setup() -> void:
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder # 探针让出 current_scene 位，换场景时不会被释放
	_run.call_deferred()


func _fail(msg: String) -> void:
	printerr("[probe] FAIL: " + msg)
	get_tree().quit(1)


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _run() -> void:
	# 兜底看门狗：90s 真实时间强制退出（多跳转场链任何一环断了不吊死）
	var watchdog := Timer.new()
	watchdog.wait_time = 90.0
	watchdog.one_shot = true
	get_tree().root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: _fail("watchdog timeout"))
	watchdog.start()

	# ---- 袋逻辑直测（纯 API，不进场景；局内循环 v2 语义=design/run_loop.md §1）----
	# 一局 = 首关 +（RUN_NORMAL_LEVELS−1）普通抽 + RUSH 阵容（RUN_RUSH_COUNT 台）
	# + ""（通关结算原地）。一局看 普通关+RUSH 阵容 台（阵容从没抽到的里挑）；
	# 局内（=旧「周期」概念）不重复、相邻永不相同——普通段/RUSH 段/两段边界都算。
	for trial in 200:
		var seen := {}
		var prev := RunState.start_run()
		if not RunState.FIRST_POOL.has(prev):
			return _fail("start_run 首抽不在白名单: %s" % prev)
		seen[prev] = true
		for _k in BalanceGlobal.RUN_NORMAL_LEVELS - 1:
			var s := RunState.draw_next()
			if s.is_empty():
				return _fail("普通段提前返回空串（trial %d）" % trial)
			if s == prev:
				return _fail("相邻两关相同: %s（trial %d）" % [s, trial])
			if seen.has(s):
				return _fail("纯 API 一局内重复抽到 %s（trial %d）" % [s, trial])
			seen[s] = true
			prev = s
		# 第 RUN_NORMAL_LEVELS 次抽关即进 RUSH（stage 越过普通关数）：该抽
		# 返回阵容首台——普通段与 RUSH 段的边界抽。
		var first_rush := RunState.draw_next()
		if first_rush.is_empty():
			return _fail("进 RUSH 的边界抽返回空串（trial %d）" % trial)
		if not RunState.rush_active:
			return _fail("普通段抽满未进 RUSH（trial %d）" % trial)
		if first_rush == prev:
			return _fail("相邻两关相同: %s（trial %d）" % [first_rush, trial])
		if seen.has(first_rush):
			return _fail("纯 API 一局内重复抽到 %s（trial %d）" % [first_rush, trial])
		seen[first_rush] = true
		prev = first_rush
		for _k in BalanceGlobal.RUN_RUSH_COUNT - 1:
			var s := RunState.draw_next()
			if s.is_empty():
				return _fail("RUSH 阵容提前打空（trial %d）" % trial)
			if s == prev:
				return _fail("相邻两关相同: %s（trial %d）" % [s, trial])
			if seen.has(s):
				return _fail("纯 API 一局内重复抽到 %s（trial %d）" % [s, trial])
			seen[s] = true
			prev = s
		if not RunState.draw_next().is_empty():
			return _fail("阵容打空后未返回空串（通关结算信号，trial %d）" % trial)
		# 一局张数 = 普通关 + RUSH 阵容（阵容=没抽到的里至多 RUN_RUSH_COUNT 台）：
		# 8 场景池时恰=池−1；池再大（9 起）恰=RUN_NORMAL_LEVELS+RUN_RUSH_COUNT。
		var expect_run := BalanceGlobal.RUN_NORMAL_LEVELS + mini(BalanceGlobal.RUN_RUSH_COUNT,
				RunState.SCENES.size() - BalanceGlobal.RUN_NORMAL_LEVELS)
		if seen.size() != expect_run:
			return _fail("纯 API 一局落地 %d 张，应=普通关+RUSH 阵容（%d；trial %d）"
					% [seen.size(), expect_run, trial])
	# 长跑连抽压测（跨局边界）：通关空串即开新一局续抽——相邻相同在任何边界
	# （普通袋尾/RUSH 阵容/新一局首抽）都不允许。start_run 的返回值=新一局
	# 首关，必须接进比较链（漏了会把「隔一关」误当「相邻」假 FAIL）。
	var prev2 := ""
	for _i in RunState.SCENES.size() * 10:
		var s2 := RunState.draw_next()
		if s2.is_empty():
			prev2 = RunState.start_run() # 通关=新一局：首抽直接当 prev
			continue
		if s2 == prev2:
			return _fail("长跑连抽相邻相同: %s" % s2)
		prev2 = s2
	printerr("[probe] bag sim x200 一局账 + 10N 跨局连抽防相邻 OK (t=%.1fs)" % _elapsed())

	# ---- 真实流程：入口跳板自动抽关 → 连续通关 N+2 关 ----
	# 入口是纯跳板：装载完当帧末就 change_scene 到抽中的第一关，全程只有
	# 1~2 帧，抓不住引用也不必抓——直接等第一个落地场景出现。
	get_tree().change_scene_to_file(ENTRY)
	var deadline := _elapsed() + 5.0
	var first: Node = null
	while _elapsed() < deadline:
		await get_tree().process_frame
		first = get_tree().current_scene
		if first != null and first.scene_file_path != ENTRY:
			break
	if first == null or first.scene_file_path == ENTRY:
		return _fail("入口未跳转到第一关（5s 超时）")
	printerr("[probe] first scene landed: %s (t=%.1fs)" % [first.scene_file_path, _elapsed()])
	var cycle_seen := {}
	_current = first
	printerr("[probe] landed #0 = %s (t=%.1fs)" % [first.scene_file_path, _elapsed()])
	if not _check_landing(0, first, cycle_seen):
		return

	# ---- 死亡重开探针：首关死一次，重开必须重掷新一局（非原地复活）----
	# 重开输入路由（任意键/点屏+防抖）由带窗 autotest 覆盖，这里直呼重开逻辑。
	var old_id := first.get_instance_id()
	(first.get_node("Player") as Player).take_damage(999)
	await _wait(1.4) # GAME_OVER_DELAY=1.1s：爆炸演出播完定格暂停（结算出现）
	first._on_restart_requested()
	var rerolled := await _await_landing_by_instance(old_id)
	if rerolled == null:
		return
	_current = rerolled
	cycle_seen = {} # 重掷=新一局：整袋重洗，周期从零起算
	printerr("[probe] rerolled new run: %s (t=%.1fs)" % [rerolled.scene_file_path, _elapsed()])
	if not _check_landing(0, rerolled, cycle_seen):
		return

	# ---- 真实流程·一整局：4 普通关 + RUSH 3 台逐台跳场景 → 通关结算原地 ----
	# （局内循环 v2：通关即结束，不再有旧制「永远滚动」；run_loop.md §1）
	var hops := BalanceGlobal.RUN_NORMAL_LEVELS + BalanceGlobal.RUN_RUSH_COUNT
	# 上一关路径先存字符串：change_scene 会立刻释放旧场景节点，
	# 落地等待后再解引用 _current 必踩 previously freed（踩过）。
	var prev_path := rerolled.scene_file_path
	for i in hops:
		var scene: Node
		if i == 0:
			scene = rerolled # 首关落地已在上面等到
		else:
			scene = await _await_next_scene()
			if scene == null:
				return # _await_next_scene 已报错
		if i > 0 and scene.scene_file_path == prev_path:
			return _fail("相邻两关相同: %s" % scene.scene_file_path)
		_current = scene
		prev_path = scene.scene_file_path
		printerr("[probe] landed #%d = %s (t=%.1fs)"
				% [i + 1, scene.scene_file_path, _elapsed()])
		if not _check_landing(i, scene, cycle_seen):
			return
		if not await _kill_boss(scene):
			return
		if i == hops - 1:
			break # 末台 RUSH BOSS 已击杀：随后应通关原地结算（不再有新关）
	# 通关断言：阵容打空 → draw_next 返回 "" → 不切场景原地出结算
	#（CHAPTER_CLEAR_DELAY 1.7s + 黑场余量；旧制这里已切进新关=本断言 FAIL）
	var last_scene := _current
	await _wait(2.6)
	if get_tree().current_scene != last_scene or not is_instance_valid(last_scene):
		return _fail("通关后应原地结算（无新关落地）")
	if not RunState.run_complete:
		return _fail("通关记号未置真（run_complete）")
	printerr("[probe] PASS: 死亡重掷 + 一整局 %d 落地全过（4 普通关+RUSH 3 台）——白名单/局内不重复/相邻不同/通关原地结算/跨关分数/交接满血 (t=%.1fs)"
			% [hops, _elapsed()])
	get_tree().quit(0)


## 等重开转场落地：以实例身份判别——重掷可能抽中死掉的同一关（跨局掷骰
## 自由），同路径的新实例也算落地成功。
func _await_landing_by_instance(old_id: int) -> Node:
	var deadline := _elapsed() + 8.0
	while _elapsed() < deadline:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur != null and cur.get_instance_id() != old_id:
			await get_tree().process_frame
			await get_tree().process_frame
			return cur
	_fail("重开转场未发生（8s 内仍原地）")
	return null


## 秒级等待（真实时间；默认 process_always，结算暂停期照走）。
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## 等当前场景被转场换走，返回新落地的场景节点。
func _await_next_scene() -> Node:
	var deadline := _elapsed() + 8.0
	while is_instance_valid(_current) and get_tree().current_scene == _current:
		if _elapsed() > deadline:
			_fail("转场未发生（8s 内仍原地: %s）" % _current.scene_file_path)
			return null
		await get_tree().process_frame
	await get_tree().process_frame # 切换空档帧 current_scene 短暂为 null
	await get_tree().process_frame
	if get_tree().current_scene == null:
		_fail("落地空档：current_scene 为 null")
		return null
	return get_tree().current_scene


## 逐关不变式检查。cycle_seen 跨调用持有：逢局边界（i==0）清空，局内不重复
##（局内循环 v2：一局=普通段+RUSH 段，跨局经死亡重开重掷，探针内只走一局）。
## RUSH 段（i ≥ RUN_NORMAL_LEVELS）必须 rush_active=true（关号钉死+无杂兵账）。
func _check_landing(i: int, scene: Node, cycle_seen: Dictionary) -> bool:
	var path := scene.scene_file_path
	if not RunState.SCENES.has(path):
		_fail("第 %d 落地不在场景池: %s" % [i + 1, path])
		return false
	if i % RunState.SCENES.size() == 0:
		cycle_seen.clear()
	if i >= BalanceGlobal.RUN_NORMAL_LEVELS and not RunState.rush_active:
		_fail("第 %d 落地应已进 RUSH（rush_active=false）" % (i + 1))
		return false
	if cycle_seen.has(path):
		_fail("同一周期内重复落地 %s（第 %d 关）" % [path, i + 1])
		return false
	cycle_seen[path] = true
	if i == 0 and not RunState.FIRST_POOL.has(path):
		_fail("首关不在开局白名单: %s" % path)
		return false
	if RunState.take_handoff():
		_fail("交接旗标未被新关消费（时序错）")
		return false
	# 首关不经交接（入口纯跳板），启动页必须还在；后续关必须被交接跳过
	if i == 0:
		if scene.get_node_or_null("TitleScreen") == null:
			_fail("首关启动页不在（入口是纯跳板，启动页归第一关自己）")
			return false
	elif scene.get_node_or_null("TitleScreen") != null:
		_fail("交接进新关但启动页仍在")
		return false
	var player: Player = scene.get_node_or_null("Player")
	if player == null or player.hp != BalancePlayer.PLAYER_MAX_HP:
		var hp := -1 if player == null else player.hp
		_fail("第 %d 关玩家未满血: %d" % [i + 1, hp])
		return false
	# 探针每关只杀 BOSS：分数必须精确等于 BOSS_SCORE × 关序（0 起）
	var score_label: Label = scene.get_node("HUD/Root/ScoreLabel")
	var expect := "得分 %d" % (BalanceCombat.BOSS_SCORE * i)
	if score_label.text != expect:
		_fail("分数跨关累计错误: 期望「%s」实得「%s」" % [expect, score_label.text])
		return false
	return true


## 杀 BOSS（真实路径：killed → Spawner → enemy_killed/boss_defeated）。
## RUSH 落地即战（Spawner.start() 已自动刷 BOSS）：组里已有就直杀现役，
## 别 debug_spawn 出第二只（双 boss_defeated 会把转场账搅乱）。
func _kill_boss(scene: Node) -> bool:
	var spawner: Spawner = scene.get_node("Spawner")
	var boss := scene.get_tree().get_first_node_in_group("boss") as Enemy
	if boss == null:
		boss = spawner.debug_spawn_boss() as Enemy
	if boss == null:
		_fail("BOSS 未刷出: " + scene.scene_file_path)
		return false
	await get_tree().process_frame
	boss.take_damage(99999, true)
	return true
