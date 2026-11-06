class_name Spawner
extends Node
## 按位移刷怪 + 对象池。
## 每帧把玩家本帧位移（含后退的负位移）累加进各分类的累加器，
## 累加值达到上一次掷出的间距就刷一个，然后重掷间距。
## BOSS 遭遇战期间小怪停刷（累计冻结，打完原地续；障碍照常，跑酷不断）。
## 回收的对象不销毁，按场景归类进池子复用。

signal enemy_killed(points: int)
signal boss_defeated # BOSS 被击败（死亡演出即启）：Main 借此排章末转场

@export var obstacles_enabled := true # 障碍生成开关
@export var crates_enabled := false   # 两种箱子（方块/长条平台）暂禁用，只刷脚手架平台
@export var elite_enabled := true  # 精英·导弹车生成开关（Main 的内容开关转发）
@export var boss_enabled := true   # 追击大型机生成开关（Main 的内容开关转发）
@export var enemy_scene: PackedScene
@export var drone_scene: PackedScene           # 悬浮无人机（更脆、悬空）
@export var shield_scene: PackedScene          # 盾卫（防御力挡弹，须近战）
@export var elite_scene: PackedScene           # 精英·导弹车（周期导弹齐射，落点预警）
@export var boss_scene: PackedScene            # 追击大型机（距离触发的追击段落）
@export var obstacle_scene: PackedScene        # 方块箱
@export var platform_scene: PackedScene        # 长条平台箱（实体障碍）
@export var scaffold_scene: PackedScene        # 脚手架（单向平台，浮空）
@export var spawn_margin := 120.0 # 出生点在屏幕右缘之外多少像素
@export var ground_y := 600.0

var _player: Node2D
var _container: Node
var _terrain: Terrain
var _last_player_x := 0.0
var _enemy_accumulator := 0.0
var _obstacle_accumulator := 0.0
var _enemy_next_distance := 0.0
var _obstacle_next_distance := 0.0
var _boss_score_accum := 0 # 距下一场 BOSS 的击杀分累计（打完一场清零重计）
var _boss_engaged := false
var _pools := {} # scene_path -> Array[ScrollObject]
var _stopped := false
var _active := false # 启动页待机时不刷怪，start() 后才上线


func _ready() -> void:
	_player = get_node("../Player") as Node2D
	_container = get_node("../ScrollObjects")
	_terrain = get_node("../Terrain")
	_last_player_x = _player.global_position.x
	_enemy_next_distance = _roll(true)
	_obstacle_next_distance = _roll(false)
	_player.died.connect(func() -> void: _stopped = true)


## 进入战斗才调：从这一刻起按位移开始刷（首次间距已掷好，起步留一段空白）。
## RUSH 终局（run_loop.md §1）例外：落地即战——BOSS 立即进场，不等击杀分
## （旧制 rush_active 恒假，照旧攒分触发）。
func start() -> void:
	_active = true
	_last_player_x = _player.global_position.x
	if RunState.rush_active and boss_enabled:
		debug_spawn_boss()


## 章末转场窗口：彻底停刷（障碍一并停，画面安静等黑场）。
func stop() -> void:
	_stopped = true


func _physics_process(_delta: float) -> void:
	if _stopped or not _active:
		return
	var dx := _player.global_position.x - _last_player_x
	_last_player_x = _player.global_position.x
	_obstacle_accumulator += dx
	var boss_here := get_tree().get_first_node_in_group("boss") != null
	# 杂兵闸：BOSS 遭遇战期间停刷；RUSH 终局（无杂兵细则，run_loop.md §1）
	# 整场停刷——小怪/精英一并停，障碍照常=跑酷不断。
	var mobs_allowed := not boss_here \
			and not (BalanceGlobal.RUSH_NO_MOBS and RunState.rush_active)
	if mobs_allowed:
		_enemy_accumulator += dx # 遭遇战期间冻结累计：打完不洪泛，刷怪节奏从原地续
	_tick_boss(boss_here)
	# 先刷障碍再刷敌人：同帧撞在一起时，敌人的重叠检测才能看到刚落地的障碍。
	# 障碍照常刷（跑酷不断），小怪在杂兵闸关着时停刷。
	if obstacles_enabled:
		while _obstacle_accumulator >= _obstacle_next_distance:
			_obstacle_accumulator -= _obstacle_next_distance
			_obstacle_next_distance = _roll(false)
			_spawn(_pick_obstacle_scene(), false)
	if mobs_allowed:
		while _enemy_accumulator >= _enemy_next_distance:
			_enemy_accumulator -= _enemy_next_distance
			_enemy_next_distance = _roll(true)
			_spawn(_pick_enemy_scene(), true)


## ---- BOSS 调度：按击杀分拉遭遇——攒满 BOSS_SCORE_TRIGGER 刷一场，
## 打完（组里没号）清零重计，再攒 200 分约下一场 ----
## 非池化：BOSS 自管死亡演出与 queue_free，这里只管"何时该有一只"。

func _tick_boss(boss_here: bool) -> void:
	if boss_scene == null or not boss_enabled:
		return
	if boss_here:
		_boss_engaged = true
		return
	if _boss_engaged: # 刚退场（死亡演出结束自清后组里没号了）：清零重计
		_boss_engaged = false
		_boss_score_accum = 0
		return
	if _boss_score_accum >= BalanceGlobal.BOSS_SCORE_TRIGGER:
		debug_spawn_boss()


## BOSS 不走池化 _spawn：位置自己管（悬浮绝对高度 + 画面右缘锚定）。
## 返回放宽到 Node2D：章节 BOSS 各是自己的脚本（ch1=Boss 直升机，ch2=BossBarge
## 驳船），悬浮锚在各自 on_spawned 里落位。
func debug_spawn_boss() -> Node2D:
	var boss := boss_scene.instantiate() as Node2D
	var x := _right_edge() + 1000.0
	boss.global_position = Vector2(x, BalanceCombat.BOSS_HOVER_Y)
	_container.add_child(boss) # 入树即 _ready→on_spawned：亮血条 + WARNING
	boss.killed.connect(_on_killed)
	boss.killed.connect(func(_points: int) -> void: boss_defeated.emit())
	boss.reset_physics_interpolation()
	return boss


## 敌人选型：跑过 ELITE_MIN_DISTANCE 后，精英·导弹车 15% /
## 步行炮台 40% / 悬浮无人机 25% / 盾卫 20%。
## 新场景导出为空时兜底回步行者，老主场景不接线也不炸。
func _pick_enemy_scene() -> PackedScene:
	var r := randf()
	var elite_ok := elite_enabled and elite_scene != null \
			and _player.global_position.x >= BalanceGlobal.ELITE_MIN_DISTANCE
	if elite_ok and r < 0.15:
		return elite_scene
	if r < 0.55 or drone_scene == null:
		return enemy_scene
	if r < 0.8 or shield_scene == null:
		return drone_scene
	return shield_scene


func _roll(is_enemy: bool) -> float:
	if is_enemy:
		return randf_range(BalanceGlobal.SPAWN_ENEMY_GAP_MIN, BalanceGlobal.SPAWN_ENEMY_GAP_MAX)
	return randf_range(BalanceGlobal.SPAWN_OBSTACLE_GAP_MIN, BalanceGlobal.SPAWN_OBSTACLE_GAP_MAX)


## 障碍选择：两种箱子禁用期间只刷脚手架平台。
func _pick_obstacle_scene() -> PackedScene:
	if not crates_enabled:
		return scaffold_scene
	var r := randf()
	if r < 0.45:
		return obstacle_scene
	if r < 0.75:
		return platform_scene
	return scaffold_scene


func _spawn(scene: PackedScene, is_enemy: bool, at_x: float = INF) -> ScrollObject:
	var obj := _acquire(scene)
	# 出生在屏幕右缘外；敌人额外错开一段，避免和同帧刷出的障碍重叠。
	var jitter_x := randf_range(100.0, 240.0) if is_enemy else randf_range(0.0, 80.0)
	var x := _right_edge() + spawn_margin + jitter_x
	if at_x != INF:
		x = at_x
	elif not is_enemy:
		x += obj.body_size.x * 0.5 # 障碍按右缘锚定：平台再长也不会探进画面
	# 敌人贴地块表面站（高低地形），浮空障碍例外
	var y := _terrain.surface_y_at(x) - obj.feet_offset
	var obstacle := obj as Obstacle
	if obstacle != null and obstacle.floating:
		# 空中平台（断桥）：顶面悬在所在地表上方 PLATFORM_HOVER_* 区间，随地形起伏。
		var surface := _terrain.surface_y_at(x)
		var top := maxf(surface - randf_range(BalanceGlobal.PLATFORM_HOVER_MIN, BalanceGlobal.PLATFORM_HOVER_MAX), 20.0)
		y = top + obj.feet_offset
	obj.global_position = Vector2(x, y)
	if is_enemy:
		_resolve_enemy_on_obstacles(obj)
	elif obstacle != null:
		# 反向补检：敌人先刷、障碍后落时，把压在障碍里的敌人抬上去。
		_resolve_enemies_on_new_obstacle(obstacle)
	obj.on_spawned()
	# 入树（含池复用）后才定位到位：重置插值基点，否则开物理插值后
	# 会从旧位置（池复用=上次回收点，新实例=原点）向出生点拖一帧残影。
	obj.reset_physics_interpolation()
	return obj


## 自测辅助：在指定 x 处刷一只贴地敌人并返回（确定性探针用）。
func debug_spawn_enemy(at_x: float) -> Enemy:
	return _spawn(enemy_scene, true, at_x) as Enemy


## 自测辅助：在指定 x 处刷一只当前章的精英车（绕过距离门控，确定性探针用）。
## 返回放宽到 Enemy：章节精英各是自己的脚本（ch1=EliteMortar，ch2=EliteSlag）。
func debug_spawn_elite(at_x: float) -> Enemy:
	if elite_scene == null:
		return null
	return _spawn(elite_scene, true, at_x) as Enemy


## 自测探针：正反两个顺序各验证一遍"敌人站在障碍顶面"。
func debug_probe_obstacle_overlap() -> String:
	var report := PackedStringArray()
	# 正向：先障碍后敌人
	for node in get_tree().get_nodes_in_group("obstacles"):
		var ob := node as Obstacle
		if ob != null and not ob.floating:
			_spawn(enemy_scene, true, ob.global_position.x)
			report.append("forward: enemy_y=%.0f (obstacle top=%.0f)" % [
				(obstacles_enemy_at(ob.global_position.x)), ob.global_position.y - ob.body_size.y * 0.5])
			break
	# 浮空断桥：敌人刷在桥面 x 范围内应被放到桥面顶上（悬空也不相交）。
	for node in get_tree().get_nodes_in_group("obstacles"):
		var floating_ob := node as Obstacle
		if floating_ob == null or not floating_ob.floating:
			continue
		var deck_x := floating_ob.global_position.x
		var deck_top := floating_ob.global_position.y - floating_ob.body_size.y * 0.5
		_spawn(enemy_scene, true, deck_x)
		var deck_enemy_y := obstacles_enemy_at(deck_x)
		var ok2 := "OK" if absf(deck_enemy_y - (deck_top - 24.0)) < 0.5 else "FAIL"
		report.append("floating: enemy_y=%.0f top=%.0f [%s]" % [deck_enemy_y, deck_top, ok2])
		break
	# 反向：先敌人后障碍，落在长条平台上（平台贴地表生成）。
	# 落点避开所有现存障碍（含 720 宽浮空脚手架的 x 范围）——否则敌人被
	# 合理地抬上更高的旧障碍顶，探针读数取决于跑图时机（世界状态竞态）。
	var x := _right_edge() + 2000.0
	for node in get_tree().get_nodes_in_group("obstacles"):
		var ob := node as Obstacle
		if ob != null:
			x = maxf(x, ob.global_position.x + ob.body_size.x * 0.5 + 400.0)
	_spawn(enemy_scene, true, x)
	_spawn(platform_scene, false, x)
	var enemy_y := -1.0
	var top := -1.0
	var feet := 24.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and absf(e.global_position.x - x) < 1.0:
			enemy_y = e.global_position.y
			feet = e.feet_offset
	for node in get_tree().get_nodes_in_group("obstacles"):
		var ob := node as Obstacle
		if ob != null and absf(ob.global_position.x - x) < 1.0:
			top = ob.global_position.y - ob.body_size.y * 0.5
	var ok := "OK" if absf(enemy_y - (top - feet)) < 0.5 else "FAIL"
	report.append("reverse: enemy_y=%.0f top=%.0f [%s]" % [enemy_y, top, ok])
	return " | ".join(report)


func obstacles_enemy_at(x: float) -> float:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and absf(e.global_position.x - x) < 1.0:
			return e.global_position.y
	return -1.0


## 敌人出生点若与障碍重叠，抬到最高那块障碍的顶面上站立，而不是嵌在里面。
## 浮空断桥特殊：桥面悬在出生点上方（hover 100~200），贴地出生的敌人矩形
## 和它不相交——只要桥的 x 范围压住出生点且桥体整体在出生点上方，
## 就把敌人放到桥面顶上（桥面炮台位），而不是留在桥下地面。
func _resolve_enemy_on_obstacles(enemy: ScrollObject) -> void:
	var e_half := enemy.body_size * 0.5
	var pos := enemy.global_position
	var stand_top := _terrain.surface_y_at(pos.x) # 默认贴地块表面
	var lifted := false
	for node in get_tree().get_nodes_in_group("obstacles"):
		var obstacle := node as Obstacle
		if obstacle == null:
			continue
		var o_half := obstacle.body_size * 0.5
		var oc := obstacle.global_position
		if absf(pos.x - oc.x) >= e_half.x + o_half.x:
			continue # x 范围不搭
		if obstacle.floating:
			# 桥底在敌人头顶之上 → 视作"出生在桥下方"，提上桥面顶。
			if oc.y + o_half.y <= pos.y - e_half.y + 1.0:
				stand_top = minf(stand_top, oc.y - o_half.y) # 取最高的顶面
				lifted = true
			continue
		if absf(pos.y - oc.y) < e_half.y + o_half.y:
			stand_top = minf(stand_top, oc.y - o_half.y) # 取最高的顶面
			lifted = true
	if lifted:
		enemy.global_position.y = stand_top - enemy.feet_offset


## 新障碍落下时，把已刷在重叠位置上的敌人抬到它的顶面
## （覆盖"敌人先刷、障碍后刷"的顺序，否则会嵌在一起）。
## 浮空断桥同上：桥体 x 压住敌人且整体在其上方时，也把敌人提上桥面。
func _resolve_enemies_on_new_obstacle(obstacle: Obstacle) -> void:
	var o_half := obstacle.body_size * 0.5
	var oc := obstacle.global_position
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var e_half := enemy.body_size * 0.5
		var ep := enemy.global_position
		if absf(ep.x - oc.x) >= e_half.x + o_half.x:
			continue
		if obstacle.floating:
			if oc.y + o_half.y <= ep.y - e_half.y + 1.0:
				enemy.global_position.y = oc.y - o_half.y - enemy.feet_offset
			continue
		if absf(ep.y - oc.y) < e_half.y + o_half.y:
			enemy.global_position.y = oc.y - o_half.y - enemy.feet_offset


## 从池里取，取不到才实例化；新实例在这里一次性接好信号。
func _acquire(scene: PackedScene) -> ScrollObject:
	var key := scene.resource_path
	var pool: Array = _pools.get(key, [])
	var obj: ScrollObject
	if pool.is_empty():
		obj = scene.instantiate() as ScrollObject
		obj.despawned.connect(_on_despawned.bind(key))
		obj.killed.connect(_on_killed)
		_container.add_child(obj)
	else:
		obj = pool.pop_back() as ScrollObject
		_container.add_child(obj)
	return obj


## 回收可能发生在物理回调内，延迟一帧移出场景树。
func _on_despawned(obj: ScrollObject, key: String) -> void:
	_retire.call_deferred(obj, key)


func _retire(obj: ScrollObject, key: String) -> void:
	if obj.is_inside_tree():
		_container.remove_child(obj)
	if not _pools.has(key):
		_pools[key] = []
	_pools[key].append(obj)


func _on_killed(points: int) -> void:
	_boss_score_accum += points # BOSS 遭遇战中也在涨，但打完统一清零，不计入下一场
	enemy_killed.emit(points)


func _right_edge() -> float:
	var cam := get_viewport().get_camera_2d()
	var center := _player.global_position.x
	if cam != null:
		center = cam.get_screen_center_position().x
	return center + get_viewport().get_visible_rect().size.x * 0.5


## 供自测脚本观察池化情况。
func get_pool_sizes() -> Dictionary:
	var sizes := {}
	for key in _pools:
		sizes[key.get_file()] = _pools[key].size()
	return sizes


## 池里的节点已移出场景树，退出/重载场景时显式释放，避免泄漏。
func _exit_tree() -> void:
	for key in _pools:
		for obj in _pools[key]:
			obj.free()
	_pools.clear()
