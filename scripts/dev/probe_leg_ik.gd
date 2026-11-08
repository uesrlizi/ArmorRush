extends Node2D
## 腿部 IK 探针（窗口小场景自退；不进正常启动流程）：
##   godot --log-file probe_leg_ik.log res://scenes/previews/probe_leg_ik.tscn
## 断言七组：
##   A. 站立 = 手绘站姿：Visuals.position.y ≈ 0，大腿骨增量角归零；
##   B. 滑行下蹲输入驱动：按 D 后逐物理帧采样，蹲过半深时实际速度仍低于
##      火花阈值（证明判据是输入不是速度）；随后蹲满、双脚掌世界钉地；
##   C. 换向滑行（Visuals 镜像）：下蹲不丢、脚掌仍钉地；
##   E. 慢起：松开输入后短暂仍明显蹲着（UP_RATE 慢），再缓起归零；
##   D. 浮空：跳起后回手绘站姿；
##   F. 落地缓冲（无移动指令）：落地必先快速蹲到底，随后慢起归零；
##   G. 落地缓冲+移动指令：缓冲蹲到底后无缝交还给滑行蹲，不中途弹起。
## 截图落 art_proposals/mech/work/leg_ik_preview/ingame_*.png 供人工终审。
## 全过打印 ALL OK 退出码 0；有 FAIL 退出码 1；40s 看门狗兜底退出码 2。

const SHOTS_DIR := "art_proposals/mech/work/leg_ik_preview"


func _ready() -> void:
	var runner: Node = Runner.new()
	runner.name = "ProbeLegIkRunner"
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	const CROUCH := BalancePlayer.SLIDE_CROUCH_HEIGHT
	var _fails := 0

	func _ready() -> void:
		get_tree().create_timer(40.0, true, false, true).timeout.connect(func() -> void:
			printerr("[probe_leg_ik] TIMEOUT 40s")
			get_tree().quit(2))
		_run()

	func _wait(sec: float) -> void:
		await get_tree().create_timer(sec, true, false, true).timeout

	func _check(ok: bool, label: String, detail := "") -> void:
		if not ok:
			_fails += 1
		print("[probe_leg_ik] ", label, " [", "OK" if ok else "FAIL", "] ", detail)

	func _player() -> Player:
		return get_tree().get_first_node_in_group("player") as Player

	func _shot(file_name: String) -> void:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://")
				.path_join(SHOTS_DIR).path_join(file_name))
		print("[probe_leg_ik] saved ", file_name)

	## 轮询等待落地（玩家 is_on_floor 为真），返回等到为止的总秒数。
	func _await_touchdown(timeout := 2.0) -> float:
		var waited := 0.0
		var player := _player()
		while not player.is_on_floor() and waited < timeout:
			await _wait(0.02)
			waited += 0.02
		return waited

	func _run() -> void:
		# ---- 进 world_1（标题页路径），点开始进战斗（轮询重发防误触窗抖动）----
		get_tree().change_scene_to_file("res://scenes/world/world_1.tscn")
		await _wait(0.6)
		var accept_waited := 0.0
		while accept_waited < 4.0:
			var title := get_tree().current_scene.get_node_or_null("TitleScreen")
			if title == null or not is_instance_valid(title):
				break
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_SPACE
			ev.pressed = true
			Input.parse_input_event(ev)
			await _wait(0.1)
			var ev_up := InputEventKey.new()
			ev_up.physical_keycode = KEY_SPACE
			ev_up.pressed = false
			Input.parse_input_event(ev_up)
			accept_waited += 0.1
		await _wait(1.2) # 等操作解锁与落地稳定

		var player := _player()
		if player == null:
			_check(false, "player found")
			get_tree().quit(1)
			return
		var visuals: Node2D = player.get_node("Visuals")
		var hip_far: Node2D = visuals.get_node("LegRig/HipFar") # = 大腿骨
		var foot_far: Sprite2D = visuals.get_node("LegRig/FootFar")
		var foot_near: Sprite2D = visuals.get_node("LegRig/FootNear")

		# ---- A. 站立 ----
		var foot_y0 := foot_far.global_position.y
		var foot_ny0 := foot_near.global_position.y
		_check(absf(visuals.position.y) < 0.05, "A1 stand: visuals.y≈0",
				"y=%.4f" % visuals.position.y)
		_check(absf(hip_far.rotation) < 0.02, "A2 stand: thigh delta≈0",
				"rot=%.5f" % hip_far.rotation)
		await _shot("ingame_1_stand.png")

		# ---- B. 滑行下蹲：输入驱动（按下即蹲，快于速度爬坡）----
		Input.action_press("move_right")
		var proof_v := -1.0
		for i in 40: # 逐物理帧采样：半深蹲到达帧的实际速度（阈值 220，起蹲只需 ~2 帧）
			await get_tree().physics_frame
			if visuals.position.y >= CROUCH * 0.5 and proof_v < 0.0:
				proof_v = player.velocity.x
				break
		_check(proof_v >= 0.0 and proof_v < BalancePlayer.SLIDE_SPARK_MIN_SPEED,
				"B1 input-driven: half-crouch below speed threshold",
				"v=%.0f want<%.0f" % [proof_v, BalancePlayer.SLIDE_SPARK_MIN_SPEED])
		await _wait(0.9)
		_check(player.is_on_floor(), "B0 sliding on floor")
		_check(absf(visuals.position.y - CROUCH) < 0.15, "B2 slide: visuals.y→crouch",
				"y=%.4f want=%.2f" % [visuals.position.y, CROUCH])
		_check(absf(foot_far.global_position.y - foot_y0) < 0.6,
				"B3 slide: far foot pinned",
				"dy=%.4f" % (foot_far.global_position.y - foot_y0))
		_check(absf(foot_near.global_position.y - foot_ny0) < 0.6,
				"B4 slide: near foot pinned",
				"dy=%.4f" % (foot_near.global_position.y - foot_ny0))
		await _shot("ingame_2_slide.png")

		# ---- C. 换向滑行（镜像）----
		Input.action_release("move_right")
		Input.action_press("move_left")
		await _wait(1.0)
		_check(absf(visuals.position.y - CROUCH) < 0.15, "C1 mirror slide: crouch kept",
				"y=%.4f" % visuals.position.y)
		_check(absf(foot_far.global_position.y - foot_y0) < 0.6,
				"C2 mirror slide: far foot pinned",
				"dy=%.4f" % (foot_far.global_position.y - foot_y0))
		_check(absf(foot_near.global_position.y - foot_ny0) < 0.6,
				"C3 mirror slide: near foot pinned",
				"dy=%.4f" % (foot_near.global_position.y - foot_ny0))
		await _shot("ingame_3_slide_mirror.png")

		# ---- E. 慢起（快蹲慢起的后半）：松开输入，起立显著慢于蹲下 ----
		Input.action_release("move_left")
		await _wait(0.25)
		var y_early := visuals.position.y
		_check(y_early > CROUCH * 0.15 and y_early < CROUCH * 0.95,
				"E1 slow rise: still visibly crouched at +0.25s",
				"y=%.3f want %.2f..%.2f" % [y_early, CROUCH * 0.15, CROUCH * 0.95])
		await _wait(1.6)
		_check(visuals.position.y < 0.1, "E2 slow rise: settled upright",
				"y=%.4f" % visuals.position.y)

		# ---- D. 浮空 ----
		Input.action_press("jump")
		var air_waited := 0.0
		while player.is_on_floor() and air_waited < 1.0:
			await _wait(0.02)
			air_waited += 0.02
		Input.action_release("jump") # 离地即松：自由落体，落地好测缓冲
		await _wait(0.25)
		_check(not player.is_on_floor(), "D0 airborne")
		_check(visuals.position.y < 0.5, "D1 air: crouch released",
				"y=%.4f" % visuals.position.y)
		await _shot("ingame_4_air.png")

		# ---- F. 落地缓冲（无移动指令）：先快速蹲到底，再慢起 ----
		await _await_touchdown()
		await _wait(0.15)
		var y_down := visuals.position.y
		_check(y_down > CROUCH * 0.4, "F1 land buffer: crouched fast w/o input",
				"y=%.3f want>%.2f" % [y_down, CROUCH * 0.4])
		await _wait(0.55)
		var y_rising := visuals.position.y
		_check(y_rising < CROUCH * 0.7, "F2 land buffer: rising after bottom",
				"y=%.3f want<%.2f" % [y_rising, CROUCH * 0.7])
		await _wait(1.2)
		_check(visuals.position.y < 0.1, "F3 land buffer: settled upright",
				"y=%.4f" % visuals.position.y)

		# ---- G. 落地缓冲+移动指令：到底后无缝交还滑行蹲（不中途弹起）----
		Input.action_press("jump")
		air_waited = 0.0
		while player.is_on_floor() and air_waited < 1.0:
			await _wait(0.02)
			air_waited += 0.02
		Input.action_release("jump")
		Input.action_press("move_right") # 空中按住方向：落地缓冲应衔接滑行蹲
		await _await_touchdown()
		await _wait(0.8)
		_check(visuals.position.y > CROUCH * 0.6,
				"G1 buffer→slide: stays crouched, no mid pop-up",
				"y=%.3f want>%.2f" % [visuals.position.y, CROUCH * 0.6])
		_check(absf(foot_far.global_position.y - foot_y0) < 0.6,
				"G2 buffer→slide: far foot pinned",
				"dy=%.4f" % (foot_far.global_position.y - foot_y0))
		await _shot("ingame_5_land_slide.png")
		Input.action_release("move_right")
		await _wait(1.8)

		# ---- H. 跳跃伸腿：滑行蹲满深起跳，空中伸腿明显快于慢起（UP_RATE 6 下
		# 同点会还剩 ~2.2，伸腿速率 |跳跃初速|×GAIN=45 下 0.1s 只剩 ~0.04）----
		Input.action_press("move_right")
		await _wait(0.9) # 蹲满
		_check(visuals.position.y > CROUCH * 0.9, "H0 slide crouch full",
				"y=%.3f" % visuals.position.y)
		Input.action_press("jump")
		air_waited = 0.0
		while player.is_on_floor() and air_waited < 1.0:
			await _wait(0.02)
			air_waited += 0.02
		Input.action_release("jump")
		await _wait(0.1)
		_check(not player.is_on_floor() and visuals.position.y < CROUCH * 0.25,
				"H1 jump extend: legs snapped open in air, not slow rise",
				"y=%.3f want<%.2f" % [visuals.position.y, CROUCH * 0.25])
		await _await_touchdown() # 落地按住 D：滑行蹲照常接管
		await _wait(0.5)
		_check(visuals.position.y > CROUCH * 0.6, "H2 land back to slide crouch",
				"y=%.3f want>%.2f" % [visuals.position.y, CROUCH * 0.6])
		Input.action_release("move_right")

		if _fails == 0:
			print("[probe_leg_ik] ALL OK")
			get_tree().quit(0)
		else:
			printerr("[probe_leg_ik] FAILED x%d" % _fails)
			get_tree().quit(1)
