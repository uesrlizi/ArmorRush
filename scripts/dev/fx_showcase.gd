extends Node2D
## 全游戏特效总览预览台 v2：**真地形版**——每页实例化该章 Terrain（皮肤/桥式
## 配置照搬 world 场景）+ Ground 边界体 + 弹容器 + 相机，条目全部按实际发生
## 逻辑播放：敌人生成后击杀（死亡爆炸）、炮弹按弹道打地形（拖尾/爆裂/熔渣池
## 自然出现）、潮墙按绝对高度带涌过。供美术/配色评审在配套背景下对特效判断。
## 手动跑：godot --path . res://scenes/previews/fx_showcase.tscn（←/→ 或按钮翻页）
## 自动巡览截图（zcode 自查用）：同命令追加 `-- --shots`，拍完全页自退。
## 守则同 touch_icons_preview：跑前后清残留 godot 进程，编辑器在线别跑。

const SHOT_DIR := "res://autotest_shots"
const GROUND_Y := 664.0 # 地表碰撞线（同 world 场景 Ground 边界体）

var _pages: Array = []
var _page_idx := 0
var _page_root: Node2D
var _page_entries: Array = []
var _terrain: Terrain

@onready var _prev: Button = %Prev
@onready var _next: Button = %Next
@onready var _title: Label = %Title


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_pages = _build_pages()
	_prev.pressed.connect(func() -> void: _switch(-1))
	_next.pressed.connect(func() -> void: _switch(1))
	_show_page(0)
	if OS.get_cmdline_user_args().has("--shots"):
		_tour()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_switch(-1)
	elif event.is_action_pressed("ui_right"):
		_switch(1)


func _switch(dir: int) -> void:
	_show_page((_page_idx + dir + _pages.size()) % _pages.size())


func _show_page(idx: int) -> void:
	_page_idx = idx
	if is_instance_valid(_page_root):
		_page_root.queue_free()
	var p: Dictionary = _pages[idx]
	_page_root = Node2D.new()
	_page_root.name = "Page"
	add_child(_page_root)
	_title.text = "特效总览 · %s（%d/%d）" % [p.title, idx + 1, _pages.size()]
	_build_backdrop(_page_root, p)
	_page_entries = p.entries
	for e in p.entries:
		var lpos: Vector2 = e.get("lpos", e.pos)
		_label(_page_root, lpos, e.label)
		_start_entry(_page_root, e)


func _start_entry(root: Node2D, e: Dictionary) -> void:
	_spawn(root, e)
	if e.period > 0.0:
		var t := Timer.new()
		t.wait_time = e.period
		t.autostart = true
		t.timeout.connect(_spawn.bind(root, e))
		root.add_child(t)


func _spawn(root: Node2D, e: Dictionary) -> void:
	if not is_instance_valid(root):
		return
	var n: Node = e.mk.call()
	if n == null:
		return
	root.add_child(n)
	if n is Node2D:
		(n as Node2D).position = e.pos
	var af: Callable = e.get("af", Callable())
	if not af.is_null():
		af.call(n, e.pos)


func _label(root: Node2D, pos: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(clampf(pos.x, 80.0, 2160.0) - 80.0, pos.y + 44)
	l.modulate = Color(1, 1, 1, 0.6)
	root.add_child(l)


func _build_backdrop(root: Node2D, p: Dictionary) -> void:
	var sky := ColorRect.new()
	sky.color = p.sky
	sky.size = Vector2(2400, 1080)
	root.add_child(sky)
	if p.far != "":
		var far_tex: Texture2D = load(p.far)
		for i in 5:
			var s := Sprite2D.new()
			s.texture = far_tex
			s.scale = Vector2(0.5, GROUND_Y / 1300.0)
			s.position = Vector2(256 + i * 512, GROUND_Y / 2.0)
			root.add_child(s)
	# 相机：terrain 按镜头窗口生成地块
	var cam := Camera2D.new()
	cam.position = Vector2(1200, 540)
	root.add_child(cam)
	# 真地形：各章皮肤/桥式配置
	var t := Terrain.new()
	t.band_texture = load(p.band)
	t.fill_texture = load(p.fill)
	t.seam_color = p.seam
	t.detail_color = p.detail
	if p.get("bridge", false):
		t.bridge_girder_texture = load("res://assets/world_5/env_dawn_girder.svg")
		t.bridge_brace_texture = load("res://assets/world_5/env_dawn_brace.svg")
		var cols: Array[Texture2D] = [
			load("res://assets/world_5/env_dawn_column_1.svg"),
			load("res://assets/world_5/env_dawn_column_2.svg"),
			load("res://assets/world_5/env_dawn_column_3.svg"),
		]
		t.bridge_column_textures = cols
		t.bridge_sea_y = 860.0
	root.add_child(t)
	_terrain = t
	# 地表碰撞线（同 world 场景 Ground 边界体）
	var body := StaticBody2D.new()
	body.position = Vector2(0, GROUND_Y)
	var cs := CollisionShape2D.new()
	cs.shape = WorldBoundaryShape2D.new()
	body.add_child(cs)
	root.add_child(body)
	# 弹容器（烟 reparent/池化清理按真实容器走）
	var projectiles := Node.new()
	projectiles.name = "Projectiles"
	projectiles.add_to_group("projectile_container")
	root.add_child(projectiles)


# ---- 生成器（mk：入树前构造；af：入树后补设置，签名 (n, pos)）----

func _mk_scene(path: String) -> Node:
	return (load(path) as PackedScene).instantiate()


func _mk_enemy(path: String) -> Node:
	return (load(path) as PackedScene).instantiate()


func _mk_missile() -> Node:
	return HeavyMissile.new()


func _mk_mortar() -> Node:
	return MortarShell.new()


func _mk_flak() -> Node:
	return FlakShell.new()


func _mk_mine() -> Node:
	return PlasmaMine.new()


func _mk_orb() -> Node:
	return CoralOrb.new()


func _mk_tide() -> Node:
	return CoralTide.new()


func _mk_slidespark() -> Node:
	return (load("res://scenes/fx/ground_sparks.tscn") as PackedScene).instantiate()


func _mk_wrapped(path: String) -> Node:
	# 枪口焰/预警的钉位配方假设父节点=枪口挂点（top_level 贴 parent 全局位）：
	# 预览里包一层定位包装，否则闪在页面原点。
	var wrap := Node2D.new()
	wrap.add_child((load(path) as PackedScene).instantiate())
	return wrap


func _af_emit(n: Node, _pos: Vector2) -> void:
	# 发射器可能在包装 Node2D 之下：向下找齐所有 GPUParticles2D 开闸。
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is GPUParticles2D:
			(cur as GPUParticles2D).emitting = true
		for c in cur.get_children():
			stack.append(c)


func _af_fire(n: Node, _pos: Vector2, dir: float) -> void:
	for c in n.get_children():
		if is_instance_valid(c) and c.has_method("fire"):
			c.fire(dir)
			return


func _af_warn(n: Node, _pos: Vector2) -> void:
	for c in n.get_children():
		if is_instance_valid(c) and c.has_method("warn"):
			c.warn()
			return


func _af_slidespark(n: Node, _pos: Vector2) -> void:
	var m = n
	m.set_slide(true, 1.0)


func _af_bullet(n: Node, _pos: Vector2, speed: float) -> void:
	var m = n
	m.speed = speed
	m.setup(Vector2.LEFT, Vector2.ZERO)


func _af_missile(n: Node, pos: Vector2, dir: Vector2) -> void:
	var m = n
	m.launch(_terrain, pos, dir, true)
	get_tree().create_timer(5.0).timeout.connect(_cleanup.bind(m))


func _af_mortar(n: Node, pos: Vector2) -> void:
	var m = n
	m.launch(_terrain, pos, pos + Vector2(1300, 60), 0.9)


func _af_flak(n: Node, pos: Vector2) -> void:
	var m = n
	m.launch(_terrain, pos, Vector2(-0.3, -1).normalized(), 0.85)


func _af_mine(n: Node, pos: Vector2) -> void:
	var m = n
	m.launch(_terrain, pos + Vector2(600, -320), pos, 0.7)


func _af_orb(n: Node, pos: Vector2) -> void:
	var m = n
	var aim := Vector2(pos.x - 1500.0, GROUND_Y - 10.0)
	m.launch(_terrain, pos, pos.direction_to(aim))


func _af_tide(n: Node, pos: Vector2) -> void:
	var m = n
	m.launch(_terrain, pos, -1.0)


func _af_enemy(n: Node, _pos: Vector2) -> void:
	var m = n
	m.on_spawned()
	get_tree().create_timer(0.9).timeout.connect(_kill.bind(m))


func _kill(m) -> void:
	if is_instance_valid(m):
		m.take_damage(99999)


func _cleanup(m) -> void:
	if is_instance_valid(m):
		m.queue_free()


# ---- 页面配置 ----

func _build_pages() -> Array:
	var cols: Array = [300.0, 800.0, 1300.0, 1800.0, 2250.0]
	var pages: Array = []

	# 通用/玩家（锈雨地表做底）
	var common: Array = [
		{"label": "枪口焰", "pos": Vector2(cols[0], 470), "period": 1.2,
			"mk": _mk_wrapped.bind("res://scenes/fx/muzzle_flash.tscn"),
			"af": _af_fire.bind(PI)},
		{"label": "预警闪光", "pos": Vector2(cols[1], 470), "period": 1.6,
			"mk": _mk_wrapped.bind("res://scenes/fx/threat_flash.tscn"),
			"af": _af_warn},
		{"label": "受击火花", "pos": Vector2(cols[2], 470), "period": 1.5,
			"mk": _mk_scene.bind("res://scenes/fx/spark_burst.tscn")},
		{"label": "击毁爆炸", "pos": Vector2(cols[3], 470), "period": 1.8,
			"mk": _mk_scene.bind("res://scenes/fx/explosion_burst.tscn")},
		{"label": "玩家曳光弹", "pos": Vector2(2400, 380), "period": 1.3,
			"mk": _mk_scene.bind("res://scenes/weapons/player_bullet.tscn"),
			"af": _af_bullet.bind(1400.0)},
		{"label": "爆区闪(橙)", "pos": Vector2(cols[1], 300), "period": 1.4,
			"mk": _mk_scene.bind("res://scenes/fx/flash_burst.tscn")},
		{"label": "滑铲火花(常驻)", "pos": Vector2(cols[2], 610), "period": 0.0,
			"mk": _mk_slidespark, "af": _af_slidespark},
		{"label": "敌人击毁", "pos": Vector2(cols[3], 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_1.tscn"),
			"af": _af_enemy},
	]
	pages.append({"id": "common", "title": "通用 · 玩家", "sky": Color("14181d"),
			"far": "", "band": "res://assets/world_1/env_rust_ground_top.svg",
			"fill": "res://assets/world_1/env_rust_ground_fill.svg",
			"seam": Color("1f1d16"), "detail": Color("6a5a48"),
			"enemy": "res://scenes/units/enemy_1.tscn", "entries": common})

	# 第一章 锈雨
	pages.append({"id": "w1", "title": "一章 · 锈雨", "sky": Color("1a1114"),
			"far": "res://assets/world_1/env_rust_far.svg",
			"band": "res://assets/world_1/env_rust_ground_top.svg",
			"fill": "res://assets/world_1/env_rust_ground_fill.svg",
			"seam": Color("1f1d16"), "detail": Color("6a5a48"),
			"enemy": "res://scenes/units/enemy_1.tscn", "entries": [
		{"label": "导弹雨(抛射→落地爆)", "pos": Vector2(2600, 160), "period": 2.4,
			"mk": _mk_missile, "af": _af_missile.bind(Vector2(-0.55, 0.4).normalized())},
		{"label": "敌人击毁", "pos": Vector2(cols[1], 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_1.tscn"),
			"af": _af_enemy},
		{"label": "爆区闪(橙)", "pos": Vector2(cols[2], 420), "period": 1.4,
			"mk": _mk_scene.bind("res://scenes/fx/flash_burst.tscn")},
		{"label": "枪口焰", "pos": Vector2(cols[0], 620), "period": 1.2,
			"mk": _mk_wrapped.bind("res://scenes/fx/muzzle_flash.tscn"),
			"af": _af_fire.bind(PI)},
	]})

	# 第二章 精炼
	pages.append({"id": "w2", "title": "二章 · 精炼", "sky": Color("12161c"),
			"far": "res://assets/world_2/env_ref_far.svg",
			"band": "res://assets/world_2/env_ref_ground_top.svg",
			"fill": "res://assets/world_2/env_ref_ground_fill.svg",
			"seam": Color(0.0863, 0.1137, 0.0941), "detail": Color(0.302, 0.3529, 0.3137),
			"enemy": "res://scenes/units/enemy_2.tscn", "entries": [
		{"label": "迫击炮弹(落点=爆+熔渣池)", "pos": Vector2(250, 560),
			"lpos": Vector2(250, 540), "period": 2.6, "mk": _mk_mortar, "af": _af_mortar},
		{"label": "敌人击毁", "pos": Vector2(cols[3], 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_2.tscn"),
			"af": _af_enemy},
		{"label": "爆区闪(橙)", "pos": Vector2(cols[4], 420), "period": 1.4,
			"mk": _mk_scene.bind("res://scenes/fx/flash_burst.tscn")},
	]})

	# 第三章 电浆雪原
	pages.append({"id": "w3", "title": "三章 · 电浆雪原", "sky": Color("9fadc0"),
			"far": "res://assets/world_3/env_snow_far.svg",
			"band": "res://assets/world_3/env_snow_ground_top.svg",
			"fill": "res://assets/world_3/env_snow_ground_fill.svg",
			"seam": Color(0.5765, 0.6549, 0.7059), "detail": Color(0.5608, 0.6471, 0.702),
			"enemy": "res://scenes/units/enemy_3.tscn", "entries": [
		{"label": "电浆镖", "pos": Vector2(2400, 300), "period": 1.3,
			"mk": _mk_scene.bind("res://scenes/weapons/plasma_bolt.tscn"),
			"af": _af_bullet.bind(1200.0)},
		{"label": "电浆浮雷", "pos": Vector2(cols[1], 560), "period": 3.2,
			"mk": _mk_mine, "af": _af_mine},
		{"label": "电浆爆", "pos": Vector2(cols[2], 420), "period": 1.8,
			"mk": _mk_scene.bind("res://scenes/fx/plasma_burst.tscn")},
		{"label": "电浆导弹(抛射→落地爆)", "pos": Vector2(2600, 140), "period": 3.0,
			"mk": _plasma_missile, "af": _af_missile.bind(Vector2(-0.55, 0.4).normalized())},
	]})

	# 第四章 珊瑚夜（潮墙高度带 520..640 为绝对世界坐标，压在地表碰撞线上沿）
	pages.append({"id": "w4", "title": "四章 · 珊瑚夜", "sky": Color("0a101c"),
			"far": "res://assets/world_4/env_coral_far.svg",
			"band": "res://assets/world_4/env_coral_ground_top.svg",
			"fill": "res://assets/world_4/env_coral_ground_fill.svg",
			"seam": Color(0.0275, 0.0392, 0.0863), "detail": Color(1, 0.4157, 0.2392),
			"enemy": "res://scenes/units/enemy_4.tscn", "entries": [
		{"label": "钓灯能量镖", "pos": Vector2(2400, 480), "period": 1.2,
			"mk": _mk_scene.bind("res://scenes/weapons/coral_bolt.tscn"),
			"af": _af_bullet.bind(900.0)},
		{"label": "珊瑚重弹(落地爆蕗)", "pos": Vector2(2450, 260), "period": 2.8,
			"mk": _mk_orb, "af": _af_orb},
		{"label": "珊瑚潮", "pos": Vector2(2450, 580), "period": 5.5,
			"mk": _mk_tide, "af": _af_tide},
		{"label": "敌人击毁", "pos": Vector2(cols[1], 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_4.tscn"),
			"af": _af_enemy},
	]})

	# 第五章 破晓云廊（桥式地块：箱梁+排架柱，海面固定线 860）
	pages.append({"id": "w5", "title": "五章 · 破晓云廊", "sky": Color("3f3560"),
			"far": "res://assets/world_5/env_dawn_far.svg",
			"band": "res://assets/world_5/env_dawn_ground_top.svg",
			"fill": "res://assets/world_5/env_dawn_ground.svg",
			"seam": Color("1f1d16"), "detail": Color("6a5a48"),
			"enemy": "res://scenes/units/enemy_5.tscn", "bridge": true, "entries": [
		{"label": "曳光矢", "pos": Vector2(2400, 380), "period": 1.2,
			"mk": _mk_scene.bind("res://scenes/weapons/dawn_bolt.tscn"),
			"af": _af_bullet.bind(1400.0)},
		{"label": "啸雷弹(定距空爆)", "pos": Vector2(500, 600), "period": 2.6,
			"mk": _mk_flak, "af": _af_flak},
		{"label": "敌人击毁", "pos": Vector2(cols[2], 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_5.tscn"),
			"af": _af_enemy},
	]})

	return pages


func _plasma_missile() -> Node:
	return PlasmaMissile.new()


func _tour() -> void:
	await get_tree().create_timer(1.2).timeout
	for i in _pages.size():
		_show_page(i)
		await get_tree().create_timer(2.8).timeout
		# 一发系特效大多 ≤0.6s，盲拍必抓进间歇期：先同步重放一轮再拍中段。
		_spawn_all()
		await get_tree().create_timer(0.1).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(SHOT_DIR + "/fx_showcase_%s.png" % _pages[i].id)
		printerr("shot ", _pages[i].id)
	get_tree().quit(0)


func _spawn_all() -> void:
	if not is_instance_valid(_page_root):
		return
	for e in _page_entries:
		_spawn(_page_root, e)
