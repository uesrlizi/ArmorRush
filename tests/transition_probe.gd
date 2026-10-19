extends Node
## 章末转场端到端探针（无头）：进第一章 → 刷 BOSS → 击杀 →
## 验证延迟黑场后落在第二章、分数跨章持久、启动页被交接跳过、玩家满血；
## 再在第二章杀一次验证链到第三章；第三章为末章（next_scene 空），
## 杀 BOSS 后世界原地续跑不切场景。
## 用法：godot --headless res://tests/transition_probe.tscn
## 本探针自己不是 current_scene（_setup 里先放占位节点顶包），
## change_scene_to_file 只释放 current_scene，探针作为 root 兄弟节点存活。

const CHAIN: Array[String] = [
	"res://scenes/main.tscn",
	"res://scenes/main_ch2.tscn",
	"res://scenes/main_ch3.tscn",
]

var _t0 := 0


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
	# 兜底看门狗：40s 真实时间强制退出（三段转场链任何一环断了不吊死）
	var watchdog := Timer.new()
	watchdog.wait_time = 40.0
	watchdog.one_shot = true
	get_tree().root.add_child(watchdog)
	watchdog.timeout.connect(func() -> void: _fail("watchdog timeout"))
	watchdog.start()

	for i in CHAIN.size():
		var expect := CHAIN[i]
		get_tree().change_scene_to_file(expect)
		await get_tree().process_frame
		await get_tree().process_frame
		var chapter := get_tree().current_scene
		if chapter == null or chapter.scene_file_path != expect:
			return _fail("第 %d 章未加载: %s" % [i + 1, get_tree().current_scene])
		printerr("[probe] ch%d loaded (t=%.1fs)" % [i + 1, _elapsed()])

		if i == CHAIN.size() - 1:
			# 末章先验到达状态（分数=前两章击杀累计 200、满血），再杀 BOSS 验证原地续跑
			var score_label: Label = chapter.get_node("HUD/Root/ScoreLabel")
			if score_label.text != "得分 200":
				return _fail("分数未跨章持久: " + score_label.text)
			var player: Player = chapter.get_node("Player")
			if player.hp != Balance.PLAYER_MAX_HP:
				return _fail("第三章玩家未满血: %d" % player.hp)
			printerr("[probe] ch3 arrived: score=%s hp=%d" % [score_label.text, player.hp])
			var last_boss := (chapter.get_node("Spawner") as Spawner).debug_spawn_boss()
			if last_boss == null:
				return _fail("末章 BOSS 未刷出")
			await get_tree().process_frame
			last_boss.take_damage(99999, true)
			var hold := _elapsed()
			while _elapsed() - hold < 2.6:
				await get_tree().process_frame
			if get_tree().current_scene != chapter:
				return _fail("末章杀 BOSS 不应切场景: " + get_tree().current_scene.scene_file_path)
			printerr("[probe] ch3 (末章) boss killed, world stays — PASS")
			get_tree().quit(0)
			return

		# 刷 BOSS 并击杀（真实路径：killed → Spawner → enemy_killed/boss_defeated）
		var spawner: Spawner = chapter.get_node("Spawner")
		var boss := spawner.debug_spawn_boss()
		if boss == null:
			return _fail("第 %d 章 BOSS 未刷出" % [i + 1])
		await get_tree().process_frame
		boss.take_damage(99999, true)

		# 延迟 1.7s + 渐黑 0.5s + 停留 0.25s → 切场景
		var deadline := _elapsed() + 4.0
		while is_instance_valid(chapter) and get_tree().current_scene == chapter:
			if _elapsed() > deadline:
				return _fail("第 %d 章转场未发生（%.1fs 内仍原地）" % [i + 1, deadline])
			await get_tree().process_frame
		await get_tree().process_frame # 切换空档帧 current_scene 短暂为 null
		await get_tree().process_frame
		var landed := get_tree().current_scene
		if landed == null or landed.scene_file_path != CHAIN[i + 1]:
			return _fail("第 %d 章落点错误: %s" % [i + 1, landed])
		printerr("[probe] ch%d -> ch%d switched at t=%.1fs" % [i + 1, i + 2, _elapsed()])
		if RunState.take_handoff():
			return _fail("交接旗标未被新章消费（时序错）")
		if landed.get_node_or_null("TitleScreen") != null:
			return _fail("交接进新章但启动页仍在")
