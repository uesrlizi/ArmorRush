extends Node
## 试装场（design/run_loop.md §4 的装备试玩入口，dev harness）：安全空白场里热键
## 配装，回车出击直接进真第一关开打。挂在 Main 下的子节点，_ready 先于 main.gd：
## 开机即 start_run（新局账，关卡 1、分数 0、装备清空）+ begin_handoff（main 跳过
## 启动页落地即战斗，本场景不刷怪——Spawner 关杂兵/障碍、Main 关 BOSS/精英）。
## 热键：数字键 1-6=按槽循环成员（空→m1→…→mN→空，绕回空位=卸下）；R=全卸；
## 回车=出击。装备授予走 spawn_loot_drop 真路径（芯片斜抛吸附+播报行+图标飞入），
## 卸下走 RunState.unequip + 玩家 _refresh_mod_visuals + HUD rebuild_loadout。
## 出击：捕获配装 → start_run（新局账+按 FIRST_POOL 抽真第一关）→ 重新装备
## （start_run 会清装备）→ 交接黑场进战斗。同槽快速连按会有多枚芯片在途、按到达
## 顺序授予（最后到达的生效）——dev 工具可接受；换装后延迟重摆拾取栏清陈旧图标。
## 自检：godot … res://scenes/previews/loot_armory.tscn -- --probe-armory
## 注入按键断言循环换装/卸下/出击账（无头可跑，只验断言不出图）。

const HINT_TEXT := "ARMORY  1-6 cycle slot (wrap=unequip)   R strip all   ENTER deploy"
const SWAP_ROW_SETTLE := 0.8 # 换装芯片落位后拾取栏重摆延迟（秒）：等飞入动画播完

var _probe := false
var _slot_members := {} # slot -> Array[StringName]（BalanceMods.MEMBERS 声明序）
var _deploying := false
var _last_deploy_path := "" # 探针记账：出击抽到的目标场景（真局直接切走不记账）

@onready var _main: Node2D = get_parent()
@onready var _player: Player = _main.get_node("Player")
@onready var _hud: HUD = _main.get_node("HUD")


func _ready() -> void:
	# 槽位→成员清单（同 BalanceMods.SLOTS 序=数字键序；成员按 MEMBERS 声明序）。
	for member: StringName in BalanceMods.MEMBERS:
		var slot: StringName = BalanceMods.MEMBERS[member]["slot"]
		if not _slot_members.has(slot):
			_slot_members[slot] = []
		_slot_members[slot].append(member)
	_build_hint()
	var args := OS.get_cmdline_user_args()
	_probe = args.has("--probe-armory")
	# 开机账：新局（关 1/分 0/装备空）+ 交接旗标（main._ready 随后取走=跳启动页）。
	RunState.start_run()
	RunState.begin_handoff()
	if _probe:
		_run_probe()


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var label := Label.new()
	label.text = HINT_TEXT
	label.position = Vector2(360.0, 984.0)
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = Color(0.13, 0.17, 0.21, 0.85)
	layer.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if _deploying or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).keycode
	if key >= KEY_1 and key <= KEY_6:
		_cycle_slot(BalanceMods.SLOTS[key - KEY_1])
	elif key == KEY_R:
		for slot: StringName in BalanceMods.SLOTS:
			RunState.unequip(slot)
		_refresh_after_unequip()
	elif key == KEY_ENTER:
		_deploy()


## 槽位循环：当前成员在清单里的下一位；末位/空位绕回空=卸下（首次按下=装第一件）。
func _cycle_slot(slot: StringName) -> void:
	var members: Array = _slot_members[slot]
	var current := RunState.mod_member(slot)
	if current.is_empty():
		_grant_member(members[0])
		return
	var idx := members.find(current)
	if idx >= members.size() - 1:
		RunState.unequip(slot)
		_refresh_after_unequip()
	else:
		_grant_member(members[idx + 1])
		# 同槽替换：旧图标要等新芯片授予后重摆才清得掉（播报飞入先播完）。
		get_tree().create_timer(SWAP_ROW_SETTLE, false, false, true).timeout.connect(
				_hud.rebuild_loadout)


## 真授予路径：spawn_loot_drop 生成芯片（斜抛→吸附→equip→播报行+图标飞入）。
func _grant_member(member: StringName) -> void:
	_main.spawn_loot_drop(member, _player.global_position + Vector2(40.0, -60.0))


## 卸下当场生效（无芯片）：机体视觉回出厂+拾取栏重摆（陈旧图标一并清）。
func _refresh_after_unequip() -> void:
	_player._refresh_mod_visuals()
	_hud.rebuild_loadout()


## 出击：捕获配装→新局账（清装备+抽 FIRST_POOL 第一关）→重新装备→交接黑场进战斗。
## start_run 必须在此刻调（试装期间热键授予不重置），跑局计时随 start_run 归零。
func _deploy() -> void:
	_deploying = true
	var armed := RunState.mods.duplicate()
	var path := RunState.start_run()
	_last_deploy_path = path
	for slot: StringName in armed:
		RunState.equip(armed[slot])
	RunState.begin_handoff() # 跳启动页：落地即战（满血来自全新玩家实例）
	if _probe:
		return # 探针只验账不切场景（切场景归真局，见 loot_armory 场景头注）
	get_tree().change_scene_to_file(path)


## ---- 自检探针：注入按键走真授予/卸下/出击账，只验断言（无头可跑） ----

var _fails := 0


func _check(ok: bool, tag: String, detail := "") -> void:
	if ok:
		printerr("[armory] %s [OK]" % tag)
	else:
		_fails += 1
		printerr("[armory] %s [FAIL] %s" % [tag, detail])


## 等某槽装备到指定成员（芯片在途 1.15~1.85s+错拍；墙钟兜底防永转）。
func _await_member(slot: StringName, member: StringName, timeout_s := 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if RunState.mod_member(slot) == member:
			return true
		await get_tree().physics_frame
	return RunState.mod_member(slot) == member


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)


func _run_probe() -> void:
	await get_tree().physics_frame
	_check(RunState.stage == 1 and RunState.mods.is_empty(), "P1 开机=新局空装备",
			"stage=%d mods=%s" % [RunState.stage, RunState.mods])
	_press(KEY_1)
	var first_gun: StringName = _slot_members[&"gun"][0]
	_check(await _await_member(&"gun", first_gun), "P2 键1=枪槽首成员授予",
			"got=%s want=%s" % [RunState.mod_member(&"gun"), first_gun])
	_press(KEY_1)
	var second_gun: StringName = _slot_members[&"gun"][1]
	_check(await _await_member(&"gun", second_gun), "P3 再按=同槽换下一成员",
			"got=%s want=%s" % [RunState.mod_member(&"gun"), second_gun])
	_press(KEY_1)
	var third_gun: StringName = _slot_members[&"gun"][2]
	_check(await _await_member(&"gun", third_gun), "P3b 换到末位成员",
			"got=%s want=%s" % [RunState.mod_member(&"gun"), third_gun])
	_press(KEY_1) # 末位再按=绕回空位
	_check(await _await_member(&"gun", &""), "P4 循环末位绕回空=卸下",
			"got=%s" % RunState.mod_member(&"gun"))
	_press(KEY_6)
	var rack: StringName = _slot_members[&"shoulder"][0]
	_check(await _await_member(&"shoulder", rack), "P5 键6=肩槽首成员",
			"got=%s want=%s" % [RunState.mod_member(&"shoulder"), rack])
	await get_tree().physics_frame
	_check(_player.get_node("Visuals/ShoulderPod").visible, "P6 肩炮上肩（芯片授予即亮）")
	_press(KEY_6) # rack → rail
	var rail: StringName = _slot_members[&"shoulder"][1]
	_check(await _await_member(&"shoulder", rail), "P7 肩槽换磁轨", "got=%s" % RunState.mod_member(&"shoulder"))
	_press(KEY_6) # rail → 空
	_check(await _await_member(&"shoulder", &""), "P8 肩槽卸下（pod 隐）")
	await get_tree().physics_frame
	_check(not _player.get_node("Visuals/ShoulderPod").visible, "P9 卸下后炮身隐藏")
	_press(KEY_1)
	var gun_again: StringName = _slot_members[&"gun"][0]
	await _await_member(&"gun", gun_again)
	_press(KEY_6) # P8 卸空的肩槽装回，出击时两槽都有货
	var rack_again: StringName = _slot_members[&"shoulder"][0]
	await _await_member(&"shoulder", rack_again)
	_press(KEY_ENTER)
	await get_tree().physics_frame
	_check(RunState.stage == 1, "P10 出击=新局第 1 关", "stage=%d" % RunState.stage)
	_check(RunState.mod_member(&"gun") == gun_again
			and RunState.mod_member(&"shoulder") == rack_again,
			"P11 出击保配装（start_run 清了再装回）",
			"gun=%s shoulder=%s" % [RunState.mod_member(&"gun"), RunState.mod_member(&"shoulder")])
	_check(RunState.take_handoff(), "P12 交接旗标已立（新场景跳启动页）")
	_check(RunState.SCENES.has(_last_deploy_path) or _last_deploy_path.is_empty(),
			"P13 出击目标在场景池", "path=%s" % _last_deploy_path)
	printerr("[armory] FAILS=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
