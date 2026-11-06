extends Node
## 小兵实体阻挡探针（窗口小场景自退，--probe-blocking 才跑，正常启动自删）：
## 装载 world_1（交接路径直进战斗）→ 冻结刷怪/清场 → 依次验证：
##   ① 配置扫查：28 个单位场景根 layer=68（Enemy+EnemyBody）、互 mask=33（敌人互穿保留）、
##      7 个 BOSS 场景根 layer=4（无阻挡保持，用户定案）、玩家 mask=97
##   ② 近战链路：S 斩命中步行兵掉血（打根节点，不受阻挡体影响）
##   ③ 步行兵阻挡：直冲被挡停（尾段位移≈0）且未越过敌体
##   ④ 子弹链路：贴脸自动开火命中（打根节点）
##   ⑤ 精英阻挡：同 ③
##   ⑥ BOSS 贴脸回正提速：压招窗内弹簧峰值须超巡航档（retreat 倍率生效），拉远回巡航档
## 断言账（修复前预期红的是 ①layer 断言 + ③ + ⑤；②④ 是对照组，前后都应绿）：
##   阻挡成立 ⇔ 按住右移末段位移 <40px（按住不动=被墙挡住的特征）且玩家未越过敌体中心。

const SHOTS_DIR := "autotest_shots"
const CHAPTERS := 7

var _fails := 0
var _world: Node2D
var _player: Player
var _spawner: Node


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--probe-blocking"):
		queue_free()
		return
	if _editor_online():
		printerr("[blocking-probe] 检测到 Godot 编辑器在线，拒绝开跑。请先关闭编辑器。")
		get_tree().quit()
		return
	RunState.hold_chapter = true
	RunState.begin_handoff()
	seed(20261104)
	_world = (load("res://scenes/world/world_1.tscn") as PackedScene).instantiate()
	add_child(_world)
	_run()


func _run() -> void:
	_player = _world.get_node("Player")
	_spawner = _world.get_node("Spawner")
	_player.hp = 99999 # 全程免死：阻挡与命中断言不因玩家阵亡失真
	_spawner.set_physics_process(false) # 冻结位移刷怪，场上只留探针自己刷的单位
	_clear_field()
	var dir := ProjectSettings.globalize_path("res://").path_join(SHOTS_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(0.5) # 清场退树 + 玩家落稳

	_sweep_configs()
	await _probe_melee(dir)
	await _probe_block(false, dir)
	await _probe_bullets()
	await _probe_block(true, dir)
	await _probe_boss_retreat()

	print("[blocking-probe] done fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## ---------- ① 配置扫查（批量改场景的回归网） ----------

func _sweep_configs() -> void:
	for i in range(1, CHAPTERS + 1):
		for kind in ["enemy", "enemy_drone", "enemy_shield", "elite"]:
			var path := "res://scenes/units/%s_%d.tscn" % [kind, i]
			var inst := _root_of(path)
			if inst == null:
				_check("配置 %s 可实例化" % path, false)
				continue
			_check("配置 %s 根layer=68" % path.get_file(), inst.collision_layer == 68)
			_check("配置 %s 根mask=33(敌人互穿保留)" % path.get_file(), inst.collision_mask == 33)
			inst.free()
	for i in range(1, CHAPTERS + 1):
		var path := "res://scenes/units/boss_%d.tscn" % i
		var inst := _root_of(path)
		if inst == null:
			_check("配置 %s 可实例化" % path, false)
			continue
		_check("配置 %s 根layer=4(BOSS无阻挡保持)" % path.get_file(), inst.collision_layer == 4)
		inst.free()
	var player_root := _root_of("res://scenes/player/player.tscn")
	if player_root != null:
		_check("配置 player mask=97", player_root.collision_mask == 97)
		player_root.free()


func _root_of(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate()


## ---------- ② 近战链路（对照组：修复前后都应绿） ----------

func _probe_melee(dir: String) -> void:
	var walker := _spawn_walker(_player.global_position.x + 300.0)
	var hp0: int = walker._hp
	Input.action_press("melee")
	await _wait(0.05)
	Input.action_release("melee")
	await _wait(2.0) # WINDUP→DASH→STRIKE→RECOVER 全程
	_check("近战 斩击命中(掉血)", walker._hp < hp0)
	_check("近战 玩家未卡死", is_instance_valid(_player) and not _player.is_dead())
	walker.request_despawn()
	await _wait(0.3)


## ---------- ③/⑤ 阻挡（修复前红：直冲穿过；修复后绿：挡停） ----------

func _probe_block(is_elite: bool, dir: String) -> void:
	var label := "精英" if is_elite else "步行兵"
	var target := _spawn_elite(_player.global_position.x + 520.0) if is_elite \
			else _spawn_walker(_player.global_position.x + 520.0)
	await _wait(0.4) # 落稳 + AI 起步
	Input.action_press("move_right")
	var drive := await _drive_right(2.2)
	Input.action_release("move_right")
	_check("%s 挡停(按住右移末段位移<40px, 实测%.0f)" % [label, drive.tail_shift],
			drive.tail_shift < 40.0)
	_check("%s 未穿过(玩家仍在敌体左侧)" % label,
			_player.global_position.x < target.global_position.x + 30.0)
	await _shot(dir, "blocking_%s.png" % ["elite" if is_elite else "walker"])
	target.request_despawn()
	await _wait(0.3)


## ---------- ⑥ BOSS 贴脸回正提速 ----------
## 判据：把玩家瞬移到 d=400（<700 压招窗），回正期望速度=锚距×劲度、饱和到
## ×2 上限——压招窗内 _vel.x 峰值必须明显高于巡航档 700（ cruising 档最多到
## 700）；玩家拉远压招解除后，峰值须回落到巡航档+余量（提速只属于贴脸窗）。

func _probe_boss_retreat() -> void:
	var boss := _spawner.debug_spawn_boss() as Boss # world_1 = ch1 直升机（boss.gd 路径）
	await _wait(1.8) # 入场滑入(0.9s) + 出招起步，锚点附近就位
	_player.global_position.x = boss.global_position.x - 400.0
	_player.reset_physics_interpolation()
	await _wait(0.2)
	_check("BOSS 压招已开(贴脸冻结出招)", boss._hold_fire == true)
	var boosted := await _boss_speed_peak(boss, 1.2)
	_check("BOSS 贴脸回正提速(峰值%.0f > 巡航%.0f+100)" % [boosted, BalanceCombat.BOSS_MOVE_MAX_SPEED],
			boosted > BalanceCombat.BOSS_MOVE_MAX_SPEED + 100.0)
	_player.global_position.x = boss.global_position.x - 2600.0
	_player.reset_physics_interpolation()
	await _wait(1.5) # 反向减速+回锚爬坡稳定
	var cruise := await _boss_speed_peak(boss, 0.6)
	_check("BOSS 非贴脸恢复巡航(峰值%.0f ≤ 巡航%.0f+80)" % [cruise, BalanceCombat.BOSS_MOVE_MAX_SPEED],
			cruise <= BalanceCombat.BOSS_MOVE_MAX_SPEED + 80.0)


## 采样 BOSS 水平速度窗口，返回窗口内峰值（含加速爬坡段）。
func _boss_speed_peak(boss: Boss, seconds: float) -> float:
	var peak := 0.0
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		peak = maxf(peak, absf(boss._vel.x))
	return peak


## ---------- ④ 子弹链路（对照组） ----------

func _probe_bullets() -> void:
	var walker := _spawn_walker(_player.global_position.x + 520.0)
	await _wait(0.4)
	Input.action_press("move_right")
	await _wait(1.6) # 顶到脸上，自动开火持续命中
	Input.action_release("move_right")
	_check("子弹 贴脸命中(掉血)", walker._hp < 99999)
	walker.request_despawn()
	await _wait(0.3)


## ---------- 基础设施 ----------

func _clear_field() -> void:
	# 走 request_despawn 正规回收（直 queue_free 会让池里留悬空引用）
	for grp in ["enemies", "obstacles"]:
		for node in get_tree().get_nodes_in_group(grp):
			if node is ScrollObject:
				(node as ScrollObject).request_despawn()


func _spawn_walker(at_x: float) -> Enemy:
	var e := _spawner.debug_spawn_enemy(at_x) as Enemy
	e._hp = 99999
	return e


func _spawn_elite(at_x: float) -> Enemy:
	var e := _spawner.debug_spawn_elite(at_x) as Enemy
	e._hp = 99999
	return e


## 按住右移 driving seconds，返回首尾推进量与末段 0.5s 位移（挡停判据）。
func _drive_right(seconds: float) -> Dictionary:
	var samples: Array[float] = []
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		samples.append(_player.global_position.x)
	var tail_start := samples[maxi(samples.size() - 30, 0)]
	return {
		"advance": samples[-1] - samples[0],
		"tail_shift": absf(samples[-1] - tail_start),
		"end_x": samples[-1],
	}


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("[blocking-probe] ", what, ": ", "OK" if ok else "FAIL")


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
				or cmd.contains("--probe-blocking") or cmd.contains("--check-only"):
			continue
		return true
	return false
