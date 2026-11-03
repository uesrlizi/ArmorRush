extends Node2D
## 交接连续性探针（窗口小场景自退；不进正常启动流程）：
##   godot --log-file probe_handoff.log res://scenes/previews/probe_handoff.tscn
## 验章末黑场交接的"跨关衔接不断"，三组断言：
##   A. 键盘按住 D（move_right）跨关：动作态不被离场触控件无条件清掉（认领闸）、
##      新关操作立即解锁、不松手落地就在走；
##   B. 交接不播系统启动播报（Comms 字幕盒保持隐藏）；
##   C. 触控交接端到端：旧场景摇杆/按钮的按住指（合成认领）经 RunState 暂存，
##      新场景自动认领并压回动作态（move_left/jump），且认领边沿不误发起跳。
## 全过打印 ALL OK 并退出码 0；有 FAIL 退出码 1；30s 看门狗兜底退出码 2。

func _ready() -> void:
	# 探针本体挂到 /root：change_scene 换的是 current_scene，本场景根节点会随
	# 第一次转场被释放，Runner 必须活在场景外层才能跑完全程。
	var runner: Node = Runner.new()
	runner.name = "ProbeHandoffRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	const WALK_MIN := 300.0 # 落地续走判据：速度爬坡后应远超此值（满速 600）
	var _fails := 0

	func _ready() -> void:
		get_tree().create_timer(30.0, true, false, true).timeout.connect(func() -> void:
			printerr("[probe_handoff] TIMEOUT 30s")
			get_tree().quit(2))
		_run()

	func _wait(sec: float) -> void:
		await get_tree().create_timer(sec, true, false, true).timeout

	func _check(ok: bool, label: String, detail := "") -> void:
		if not ok:
			_fails += 1
		print("[probe_handoff] ", label, " [", "OK" if ok else "FAIL", "] ", detail)

	func _player() -> Player:
		return get_tree().get_first_node_in_group("player") as Player

	## 等当前场景切走（章末交接真路径：延迟 1.7s + 黑场 0.75s + 装载）。
	func _await_scene_switch(old_scene: Node, timeout := 6.0) -> float:
		var waited := 0.0
		while get_tree().current_scene == old_scene and waited < timeout:
			await _wait(0.1)
			waited += 0.1
		return waited

	func _run() -> void:
		# ---- 进 world_1（直开=标题页路径），点开始进战斗 ----
		get_tree().change_scene_to_file("res://scenes/world/world_1.tscn")
		await _wait(0.6)
		var start_ev := InputEventKey.new()
		start_ev.physical_keycode = KEY_SPACE
		start_ev.pressed = true
		# 标题页有 400ms 防误触窗（ARM_DELAY_MS），场景装载时刻有抖动——轮询重发，
		# 标题页受理（_done/已 freed）即停，立即松键：别让残留边沿撞上解锁时刻。
		var accept_waited := 0.0
		while accept_waited < 4.0:
			var title := get_tree().current_scene.get_node_or_null("TitleScreen")
			if title == null or (title.get("_done") as bool):
				break
			Input.parse_input_event(start_ev)
			await _wait(0.3)
			accept_waited += 0.3
		var stop_ev := start_ev.duplicate() as InputEventKey
		stop_ev.pressed = false
		Input.parse_input_event(stop_ev)
		await _wait(0.1)
		# 受理后延迟解锁 0.5s：轮询等真解锁（确定性判据）
		var player := _player()
		var unlock_waited := 0.0
		while unlock_waited < 1.5:
			await _wait(0.1)
			unlock_waited += 0.1
			player = _player()
			if player != null and player.input_enabled:
				break
		_check(player != null and player.input_enabled,
				"A0a title path unlocked", "input_enabled=%s"
						% (player.input_enabled if player != null else false))
		Input.action_press("move_right")
		# 走起来（软判据）：随机地形一步台能顶死起步（autotest 同坑），退后 500 重跑，
		# 退不过出生点（脚下地面才有保证）；顶墙不判 FAIL——交接断言不依赖开局走位。
		var walked := false
		var run_t := 0.0
		var spawn_x := player.global_position.x if player != null else 0.0
		var last_x := spawn_x
		while run_t < 2.5:
			await _wait(0.1)
			run_t += 0.1
			if player != null and player.velocity.x > WALK_MIN:
				walked = true
				break
			if player != null and player.global_position.x - last_x < 15.0:
				player.global_position.x = maxf(player.global_position.x - 500.0, spawn_x)
			if player != null:
				last_x = player.global_position.x
		if not walked:
			print("[probe_handoff] A0b world_1 walking [SOFT-FAIL] （顶墙软失败，",
					"只影响开局走位不影响交接断言）")

		# ---- 第一次章末交接：走 main._on_boss_defeated 原路径 ----
		player.hp = 99999 # 交接窗口里杂兵蹭血别打死玩家（死亡会取消切场景）
		var old_scene := get_tree().current_scene
		old_scene.call("_on_boss_defeated")
		var waited := await _await_scene_switch(old_scene)
		_check(get_tree().current_scene != old_scene, "A1 scene switched",
				"waited=%.1fs" % waited)
		await _wait(0.15) # 落地一拍
		var player2 := _player()
		_check(Input.is_action_pressed("move_right"),
				"A2 move_right still held across handoff",
				"(离场触控件不得清物理按住态=认领闸修复核心)")
		_check(player2 != null and player2.input_enabled,
				"A3 input unlocked instantly",
				"input_enabled=%s" % (player2.input_enabled if player2 != null else false))
		await _wait(0.5) # 速度爬坡
		_check(player2 != null and player2.velocity.x > WALK_MIN,
				"A4 walking after landing without re-press",
				"vx=%.0f" % (player2.velocity.x if player2 != null else -1.0))
		_check(not Comms._box.visible, "B1 no combat-start announce on handoff",
				"(字幕盒应保持隐藏：系统启动音整局只播一次)")

		# ---- 第二次交接前：当前场景合成两个"按住指"（触控交接端到端）----
		# 摇杆右半区（MOVE_RIGHT）+ 跳按钮。直接摆认领态（_touch_id/_pressed_id +
		# 坐标 + 动作压回），离场时走真实的暂存路径，新场景 TouchControls._ready
		# 自动分发认领。（先松掉 A 段按的 D：摇杆认领语义=接管两个移动动作。）
		Input.action_release("move_right")
		var js := get_tree().current_scene.get_node("TouchControls/Joystick") as Control
		var jb := get_tree().current_scene.get_node("TouchControls/JumpButton") as Control
		var js_pos: Vector2 = js.get_global_transform() \
				* ((js.call("center") as Vector2) + Vector2(120.0, 0.0))
		var jb_pos: Vector2 = jb.get_global_transform() * (jb.call("center") as Vector2)
		js.set("_touch_id", 5)
		js.set("_last_touch_pos", js_pos)
		js.call("_apply_axis", 120.0) # 右半区=MOVE_RIGHT（向右走=正向跑道，无左缘出界风险）
		jb.set("_pressed_id", 6)
		jb.set("_last_press_pos", jb_pos)
		Input.action_press("jump", 1.0)
		player2.hp = 99999
		var old_scene2 := get_tree().current_scene
		old_scene2.call("_on_boss_defeated")
		await _await_scene_switch(old_scene2)
		await _wait(0.15)
		var player3 := _player()
		_check(Input.is_action_pressed("move_right"), "C1 joystick hold auto-adopted",
				"(旧摇杆按住指应在新场景自动认领并压回 MOVE_RIGHT)")
		_check(not Input.is_action_pressed("jump"),
				"C2 jump hold claimed without action edge",
				"(边沿型动作只认领不压回：与键盘按住空格跨关不自动触发同语义)")
		_check(player3 != null and player3.input_enabled, "C3 input unlocked instantly")
		_check(player3 != null and player3.is_on_floor(),
				"C4 adoption edge must not spawn-jump", "(认领边沿在装载帧，物理帧读不到)")
		await _wait(0.5)
		_check(player3 != null and player3.velocity.x > WALK_MIN,
				"C5 walking right via adopted joystick",
				"vx=%.0f" % (player3.velocity.x if player3 != null else 0.0))

		# ---- 收尾：清认领与动作态，汇总 ----
		if js != null:
			js.call("release")
		if jb != null:
			jb.call("release")
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("jump")
		print("[probe_handoff] ALL OK" if _fails == 0 else "[probe_handoff] HAS FAIL: %d" % _fails)
		get_tree().quit(0 if _fails == 0 else 1)
