extends Node
## F1/F2 录制隐藏档探针（窗口小场景自退，--probe-ui-tier 才跑，正常启动自删）：
## 装载 world_1（交接路径直进战斗+刷 BOSS）→ 逐档按键 → 断言显隐 + 截图四张。
## 断言账：
##   档 0 基线：顶栏可见 / 未静音 / 头顶条可见 / BOSS 条可见（在场）
##   F1 → 档 1：顶栏隐 / 静音（语音+字幕停）/ 头顶条保留（档 1 不涉及）/ BOSS 条保留
##   F2 → 档 2：头顶条隐 / BOSS 三件套隐 / WARNING 隐 / 顶栏仍隐
##   再按 F2 → 回落档 0：全还原

const SHOTS_DIR := "autotest_shots"

var _fails := 0


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--probe-ui-tier"):
		queue_free()
		return
	if _editor_online():
		printerr("[ui-tier-probe] 检测到 Godot 编辑器在线，拒绝开跑。请先关闭编辑器。")
		get_tree().quit()
		return
	RunState.hold_chapter = true
	RunState.begin_handoff()
	seed(20261104)
	var world: Node2D = (load("res://scenes/world/world_1.tscn") as PackedScene).instantiate()
	add_child(world)
	_run(world)


func _run(world: Node2D) -> void:
	var player: Player = world.get_node("Player")
	var hud: HUD = world.get_node("HUD")
	var pbar: OverheadBar = player.get_node("OverheadBar")
	var dir := ProjectSettings.globalize_path("res://").path_join(SHOTS_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(1.2) # 战斗启动 + 头顶条淡入完成
	world.get_node("Spawner").debug_spawn_boss()
	await _wait(0.6) # show_boss / flash_warning 已走（WARNING 闪烁中）

	_check("tier0 顶栏可见", hud._time_label.visible)
	_check("tier0 未静音", not Comms.muted)
	_check("tier0 头顶条可见", pbar.visible)
	_check("tier0 BOSS条可见", hud._boss_bar.visible)
	await _shot(dir, "ui_tier_0_normal.png")

	_press(KEY_F1)
	await _wait(0.3)
	_check("tier1 顶栏已隐", not hud._time_label.visible)
	_check("tier1 已静音", Comms.muted)
	_check("tier1 头顶条保留", pbar.visible)
	_check("tier1 BOSS条保留", hud._boss_bar.visible)
	await _shot(dir, "ui_tier_1_f1.png")

	_press(KEY_F2)
	await _wait(0.3)
	_check("tier2 头顶条已隐", not pbar.visible)
	_check("tier2 BOSS条已隐", not hud._boss_bar.visible)
	_check("tier2 WARNING已隐", not hud._warning_label.visible)
	_check("tier2 顶栏仍隐", not hud._time_label.visible)
	await _shot(dir, "ui_tier_2_f2.png")

	_press(KEY_F2)
	await _wait(0.3)
	_check("回落 顶栏还原", hud._time_label.visible)
	_check("回落 解除静音", not Comms.muted)
	_check("回落 头顶条还原", pbar.visible)
	_check("回落 BOSS条还原", hud._boss_bar.visible)
	await _shot(dir, "ui_tier_3_restored.png")

	print("[ui-tier-probe] done fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("[ui-tier-probe] ", what, ": ", "OK" if ok else "FAIL")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _shot(dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(file_name))


## 编辑器在线检测：与 autotest 同款。
func _editor_online() -> bool:
	if not OS.has_feature("windows"):
		return false
	var out: PackedStringArray = []
	OS.execute("powershell", ["-NoProfile", "-Command",
		"Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'godot*'} "
		+ "| ForEach-Object { \"$($_.ProcessId)|$($_.CommandLine)\" }"], out, true)
	var self_pid := OS.get_process_id()
	for line in out:
		var l := str(line).strip_edges()
		if l.find("|") < 0:
			continue
		if int(l.get_slice("|", 0)) == self_pid:
			continue
		var cmd := l.get_slice("|", 1).to_lower()
		if cmd.contains("--headless") or cmd.contains("--quit-after") \
				or cmd.contains("--autotest") or cmd.contains("--probe-ui-tier") \
				or cmd.contains("--check-only"):
			continue
		return true
	return false
