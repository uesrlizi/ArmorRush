extends Node
## 往左乱跑体验探针（窗口小场景自退，--probe-backtrack 才跑，正常启动自删）：
## 装载 world_1（交接路径直进战斗）→ 关 BOSS/自动开火 → 依次验证：
##   ① 配置扫查：8 章杂兵/无人机/盾卫/精英的右缘回收资格=开，8 台 BOSS=关
##   ② 右缘余量带：出生点（右缘+360）与余量内（+1000）的敌人/断桥保留，
##      余量外（左缘越过右缘+ENEMY_LEFT_BEHIND_MARGIN）当帧回收；BOSS 甩到
##      右缘外 4000 仍在场（追击演出出画不清场）
##   ③ 负位移封顶：玩家往左瞬移 5000 后两个累加器止于 −SPAWN_BACKTRACK_MAX；
##      再往右回 SPAWN_BACKTRACK_MAX 即还清欠账（≈0）；精英门槛不随折返回落
##   ④ 跨档桥面悬高：300 个断桥逐一核对——顶面至少高出所跨整段最高地表
##      PLATFORM_HOVER_MIN、不高于 PLATFORM_HOVER_MAX（地表按 8px 独立取样，
##      不复用刷怪器的逐块算法）；并统计跨档样本数，防断言空转

const CHAPTERS := 8

var _fails := 0
var _world: Node2D
var _player: Player
var _spawner: Spawner
var _terrain: Terrain


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--probe-backtrack"):
		queue_free()
		return
	if _editor_online():
		printerr("[backtrack-probe] 检测到 Godot 编辑器在线，拒绝开跑。请先关闭编辑器。")
		get_tree().quit()
		return
	RunState.hold_chapter = true
	RunState.begin_handoff()
	seed(20261108)
	_world = (load("res://scenes/world/world_1.tscn") as PackedScene).instantiate()
	add_child(_world)
	_run()


func _run() -> void:
	_player = _world.get_node("Player")
	_spawner = _world.get_node("Spawner")
	_terrain = _world.get_node("Terrain")
	_player.hp = 99999       # 全程免死
	_player.auto_fire = false # 不打掉探针自己刷的单位
	_spawner.boss_enabled = false # BOSS 在场会冻结小怪累加器，搅乱 ③ 的账
	await _wait(0.5)
	_clear_field()
	await _wait(0.3)

	_sweep_configs()
	await _probe_right_band()
	await _probe_backtrack_cap()
	_probe_deck_hover()
	await _probe_boss_offscreen()

	print("[backtrack-probe] done fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## ---------- ① 配置扫查 ----------

func _sweep_configs() -> void:
	for i in range(1, CHAPTERS + 1):
		for kind in ["enemy", "enemy_drone", "enemy_shield", "elite"]:
			var inst := _root_of("res://scenes/units/%s_%d.tscn" % [kind, i]) as ScrollObject
			if inst == null:
				_check("配置 %s_%d 可实例化" % [kind, i], false)
				continue
			_check("配置 %s_%d 右缘回收=开" % [kind, i], inst._despawn_past_right())
			inst.free()
		var boss := _root_of("res://scenes/units/boss_%d.tscn" % i) as ScrollObject
		if boss == null:
			_check("配置 boss_%d 可实例化" % i, false)
			continue
		_check("配置 boss_%d 右缘回收=关" % i, not boss._despawn_past_right())
		boss.free()
	var scaffold := _root_of("res://scenes/props/scaffold_1.tscn") as ScrollObject
	_check("配置 scaffold 右缘回收=开", scaffold != null and scaffold._despawn_past_right())
	if scaffold != null:
		scaffold.free()


## ---------- ② 右缘余量带 ----------

func _probe_right_band() -> void:
	var cam_r := _cam_right()
	var margin := BalanceGlobal.ENEMY_LEFT_BEHIND_MARGIN
	var e_spawn := _spawner.debug_spawn_enemy(cam_r + 360.0)
	var e_band := _spawner.debug_spawn_enemy(cam_r + margin - 200.0)
	var e_far := _spawner.debug_spawn_enemy(cam_r + margin + 400.0)
	var s_band := _spawner._spawn(_spawner.scaffold_scene, false, cam_r + 900.0)
	var s_far := _spawner._spawn(_spawner.scaffold_scene, false,
			cam_r + BalanceGlobal.OBSTACLE_DESPAWN_MARGIN + 600.0)
	for e in [e_spawn, e_band, e_far]:
		(e as Enemy)._hp = 99999
	await _wait(0.3)
	_check("右缘 出生点(+360)敌人保留", e_spawn.is_inside_tree())
	_check("右缘 余量内(+%d)敌人保留" % int(margin - 200.0), e_band.is_inside_tree())
	_check("右缘 余量外(+%d)敌人回收" % int(margin + 400.0), not e_far.is_inside_tree())
	_check("右缘 余量内(+900)断桥保留", s_band.is_inside_tree())
	_check("右缘 余量外断桥回收", not s_far.is_inside_tree())
	_clear_field()
	await _wait(0.3)


## ---------- ③ 负位移封顶 + 精英门槛 ----------

func _probe_backtrack_cap() -> void:
	var cap := BalanceGlobal.SPAWN_BACKTRACK_MAX
	var gate0 := _spawner._elite_gate_x
	_teleport_player(-5000.0)
	await _wait(1.0)
	var acc_e := _spawner._enemy_accumulator
	var acc_o := _spawner._obstacle_accumulator
	print("[backtrack-probe] 左移 5000 后 acc_enemy=%.1f acc_obstacle=%.1f gate=%.1f→%.1f" % [
			acc_e, acc_o, gate0, _spawner._elite_gate_x])
	_check("封顶 小怪累加器止于 −%d" % int(cap), absf(acc_e + cap) < 0.5)
	_check("封顶 障碍累加器止于 −%d" % int(cap), absf(acc_o + cap) < 0.5)
	_check("精英门槛不随折返回落", _spawner._elite_gate_x >= gate0)
	_teleport_player(cap)
	await _wait(1.0)
	acc_e = _spawner._enemy_accumulator
	acc_o = _spawner._obstacle_accumulator
	print("[backtrack-probe] 回头右移 %d 后 acc_enemy=%.1f acc_obstacle=%.1f" % [int(cap), acc_e, acc_o])
	_check("回头只补欠账：小怪累加器≈0", absf(acc_e) < 0.5)
	_check("回头只补欠账：障碍累加器≈0", absf(acc_o) < 0.5)
	_clear_field()
	await _wait(0.3)


## 玩家水平瞬移 dx（抬到空中落地，避免嵌进高档地块）。
func _teleport_player(dx: float) -> void:
	_player.velocity = Vector2.ZERO
	_player.global_position = Vector2(_player.global_position.x + dx, 300.0)


## ---------- ④ 跨档桥面悬高 ----------

func _probe_deck_hover() -> void:
	var lo_ok := true
	var hi_ok := true
	var crossings := 0
	var old_bug := 0 # 旧算法（只按中心取地表）以最小悬高出生时会比邻块矮的样本数
	var worst := INF
	var placed: Array[ScrollObject] = []
	for k in 300:
		var x := 50000.0 + k * 137.0
		var obj := _spawner._spawn(_spawner.scaffold_scene, false, x)
		placed.append(obj)
		var deck_top := obj.global_position.y - obj.feet_offset
		var half := obj.body_size.x * 0.5
		var highest := INF
		var lowest := -INF
		var sx := x - half
		while sx <= x + half:
			var s := _terrain.surface_y_at(sx)
			highest = minf(highest, s)
			lowest = maxf(lowest, s)
			sx += 8.0
		var s_end := _terrain.surface_y_at(x + half - 0.01)
		highest = minf(highest, s_end)
		lowest = maxf(lowest, s_end)
		if lowest - highest > 0.5:
			crossings += 1
		if _terrain.surface_y_at(x) - BalanceGlobal.PLATFORM_HOVER_MIN > highest:
			old_bug += 1
		var clearance := highest - deck_top
		worst = minf(worst, clearance)
		if clearance < BalanceGlobal.PLATFORM_HOVER_MIN - 0.5:
			lo_ok = false
		if clearance > BalanceGlobal.PLATFORM_HOVER_MAX + 0.5:
			hi_ok = false
	print("[backtrack-probe] 桥面样本 300：跨档 %d，旧算法会插地 %d，最小离最高地表 %.1f" % [
			crossings, old_bug, worst])
	_check("桥面 跨档样本足量(>20，断言不空转)", crossings > 20)
	_check("桥面 至少高出所跨最高地表 HOVER_MIN", lo_ok)
	_check("桥面 不高于所跨最高地表 HOVER_MAX", hi_ok)
	for obj in placed:
		obj.request_despawn()


## ---------- ② 续：BOSS 出画不清场 ----------

func _probe_boss_offscreen() -> void:
	var boss := _spawner.debug_spawn_boss()
	await _wait(0.2)
	boss.global_position.x = _cam_right() + 4000.0
	await _wait(0.3)
	var alive := boss.is_inside_tree() and not (boss as ScrollObject)._despawn_requested
	_check("BOSS 甩出右缘 4000 仍在场", alive)
	boss.queue_free()


## ---------- 基础设施 ----------

func _cam_right() -> float:
	var cam := get_viewport().get_camera_2d()
	return cam.get_screen_center_position().x + get_viewport().get_visible_rect().size.x * 0.5


func _clear_field() -> void:
	for grp in ["enemies", "obstacles"]:
		for node in get_tree().get_nodes_in_group(grp):
			if node is ScrollObject and not node.is_in_group("boss"):
				(node as ScrollObject).request_despawn()


func _root_of(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate()


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("[backtrack-probe] ", what, ": ", "OK" if ok else "FAIL")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


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
				or cmd.contains("--autotest") or cmd.contains("--probe-") \
				or cmd.contains("--check-only"):
			continue
		return true
	return false
