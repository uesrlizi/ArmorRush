extends Node
## 关卡轮换端到端探针（无头）：洗牌袋纯 API 直测 ×200（首抽必在开局白名单、
## 同周期不重复、整袋轮全）→ 入口跳板自动抽关 → 连续通关 N+2 关，逐关验证
## 不变式：落地都在场景池、白名单只锁首关、同周期不重复、通关永远滚动进
## 下一关（无末章）、分数跨关累计、首关照常带启动页（入口纯跳板不交接）、
## 后续关交接跳启动页、落地满血。
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

	# ---- 袋逻辑直测（纯 API，不进场景）----
	for trial in 200:
		var seen := {}
		var first := RunState.start_run()
		if not RunState.FIRST_POOL.has(first):
			return _fail("start_run 首抽不在白名单: %s" % first)
		seen[first] = true
		for _k in RunState.SCENES.size() - 1:
			var s := RunState.draw_next()
			if seen.has(s):
				return _fail("纯 API 周期内重复抽到 %s（trial %d）" % [s, trial])
			seen[s] = true
		if seen.size() != RunState.SCENES.size():
			return _fail("纯 API 一周期未轮全: %s" % [seen.keys()])
	printerr("[probe] bag sim x200 OK (t=%.1fs)" % _elapsed())

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
	var hops := RunState.SCENES.size() + 2 # 整轮一遍 + 新周期两关证"通关永远滚动"
	for i in hops:
		var scene: Node
		if i == 0:
			scene = first # 首关落地已在上面等到
		else:
			scene = await _await_next_scene()
			if scene == null:
				return # _await_next_scene 已报错
		_current = scene
		printerr("[probe] landed #%d = %s (t=%.1fs)"
				% [i + 1, scene.scene_file_path, _elapsed()])
		if not _check_landing(i, scene, cycle_seen):
			return
		if i == hops - 1:
			break # 末次落地本身即证明"又一关滚动进来了"
		if not await _kill_boss(scene):
			return
	printerr("[probe] PASS: %d 落地全过——白名单/整轮不重复/永远滚动/跨关分数/交接满血 (t=%.1fs)"
			% [hops, _elapsed()])
	get_tree().quit(0)


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


## 逐关不变式检查。cycle_seen 跨调用持有：逢周期边界（i % N == 0）清空，
## 周期内不允许重复（袋边界首尾相接是 Tetris 式合法行为，不清就会误报）。
func _check_landing(i: int, scene: Node, cycle_seen: Dictionary) -> bool:
	var path := scene.scene_file_path
	if not RunState.SCENES.has(path):
		_fail("第 %d 落地不在场景池: %s" % [i + 1, path])
		return false
	if i % RunState.SCENES.size() == 0:
		cycle_seen.clear()
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
	if player == null or player.hp != Balance.PLAYER_MAX_HP:
		var hp := -1 if player == null else player.hp
		_fail("第 %d 关玩家未满血: %d" % [i + 1, hp])
		return false
	# 探针每关只杀 BOSS：分数必须精确等于 BOSS_SCORE × 关序（0 起）
	var score_label: Label = scene.get_node("HUD/Root/ScoreLabel")
	var expect := "得分 %d" % (Balance.BOSS_SCORE * i)
	if score_label.text != expect:
		_fail("分数跨关累计错误: 期望「%s」实得「%s」" % [expect, score_label.text])
		return false
	return true


## 刷 BOSS 并击杀（真实路径：killed → Spawner → enemy_killed/boss_defeated）。
func _kill_boss(scene: Node) -> bool:
	var spawner: Spawner = scene.get_node("Spawner")
	var boss := spawner.debug_spawn_boss()
	if boss == null:
		_fail("BOSS 未刷出: " + scene.scene_file_path)
		return false
	await get_tree().process_frame
	boss.take_damage(99999, true)
	return true
