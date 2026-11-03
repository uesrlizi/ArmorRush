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
		t.bridge_girder_texture = load(p.get("bridge_girder",
				"res://assets/world_5/env_dawn_girder.svg") as String)
		t.bridge_brace_texture = load(p.get("bridge_brace",
				"res://assets/world_5/env_dawn_brace.svg") as String)
		var cols: Array[Texture2D] = [
			load(p.get("bridge_column_1",
					"res://assets/world_5/env_dawn_column_1.svg") as String),
			load(p.get("bridge_column_2",
					"res://assets/world_5/env_dawn_column_2.svg") as String),
			load(p.get("bridge_column_3",
					"res://assets/world_5/env_dawn_column_3.svg") as String),
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


func _mk_tex(path: String) -> Node:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	return sp


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


## 斗轮抛石：bullet.gd 抛体语法——按 BOSS 档重力解初速，落到左前方 1300px 的地表
## （弧线全程在页内可见；实际 BOSS 逐石扇开，预览只看一枚的弧与落地迸溅）。
func _af_lob(n: Node, pos: Vector2) -> void:
	var m = n
	var tx := pos.x - 1300.0
	var v: Vector2 = Bullet.solve_lob_velocity(pos, Vector2(tx, _terrain.surface_y_at(tx)),
			BalanceWorld6.REDWHEEL_LOB_GRAVITY, 1.0)
	m.lob_gravity = BalanceWorld6.REDWHEEL_LOB_GRAVITY
	m.speed = v.length()
	m.setup(v.normalized(), Vector2.ZERO)


## 钓灯爆闪：径向 N 矢同帧齐放（BOSS 档 ANGLER_FLASH_*，一矢朝左=朝玩家）+
## 灯头珊瑚爆蕗压 power——包装 Node2D 当"钓灯口"，矢与绽放都挂它名下。
func _af_flash(n: Node, _pos: Vector2) -> void:
	var count := BalanceWorld4.ANGLER_FLASH_COUNT
	for i in count:
		var b = (load("res://scenes/weapons/coral_bolt.tscn") as PackedScene).instantiate()
		n.add_child(b)
		b.speed = BalanceWorld4.ANGLER_FLASH_SPEED
		b.setup(Vector2.LEFT.rotated(TAU * float(i) / float(count)), Vector2.ZERO)
	var bloom := (load("res://scenes/fx/coral_burst.tscn") as PackedScene).instantiate() as CoralBurst
	bloom.power = 0.6
	n.add_child(bloom)


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


# ---- 六章 赤沙矿区（电网闸/凿岩装药全链按真实参数播放）----

func _mk_fence() -> Node:
	# BOSS 档参数（ElitePiler 共用同一危险件，只差数值）
	var f := ArcFence.new()
	f.half_width = BalanceWorld6.REDWHEEL_FENCE_HALF
	f.top_height = BalanceWorld6.REDWHEEL_FENCE_TOP
	f.warmup_time = BalanceWorld6.REDWHEEL_FENCE_WARMUP
	f.lifetime = BalanceWorld6.REDWHEEL_FENCE_LIFE
	f.stake_flight = BalanceWorld6.REDWHEEL_STAKE_FLIGHT
	return f


func _af_fence(n: Node, pos: Vector2) -> void:
	# 出膛点≈BOSS 背甲炮架口高度；落带中心偏右半 lead（读全周期）
	(n as ArcFence).launch(_terrain, pos + Vector2(-140, -360), pos.x + 60.0)


func _mk_charge() -> Node:
	var c := DrillCharge.new()
	c.blast_radius = BalanceWorld6.REDWHEEL_CHARGE_RADIUS
	c.flight_time = BalanceWorld6.REDWHEEL_CHARGE_FLIGHT
	c.fuse_time = BalanceWorld6.REDWHEEL_CHARGE_FUSE
	return c


func _af_charge(n: Node, pos: Vector2, tx: float) -> void:
	(n as DrillCharge).launch(_terrain, pos,
			Vector2(tx, _terrain.surface_y_at(tx)), BalanceWorld6.REDWHEEL_CHARGE_FLIGHT)


func _af_corridor(n: Node, pos: Vector2) -> void:
	# 三连梯次装药落同一条带（间距>爆球直径=走廊读法；实际 BOSS 有
	# 0.18s 出膛梯次，预览同时出膛读落点分布）
	for i in 3:
		var tx := pos.x + 620.0 + (float(i) - 1.0) * BalanceWorld6.REDWHEEL_CHARGE_SPACING
		var c := DrillCharge.new()
		c.blast_radius = BalanceWorld6.REDWHEEL_CHARGE_RADIUS
		c.flight_time = BalanceWorld6.REDWHEEL_CHARGE_FLIGHT
		c.fuse_time = BalanceWorld6.REDWHEEL_CHARGE_FUSE
		n.add_child(c)
		c.launch(_terrain, pos, Vector2(tx, _terrain.surface_y_at(tx)),
				BalanceWorld6.REDWHEEL_CHARGE_FLIGHT)


func _af_curtain(n: Node, _pos: Vector2) -> void:
	var p := (n as GPUParticles2D)
	var mat := p.process_material as ParticleProcessMaterial
	mat = mat.duplicate() # 场景资源正本不写回
	mat.emission_box_extents.y = 110.0
	p.process_material = mat


func _af_enemy(n: Node, _pos: Vector2) -> void:
	var m = n
	m.on_spawned()
	get_tree().create_timer(0.9).timeout.connect(_kill.bind(m))


# ---- 七章 溺海都会（跳弹/深弹涌浪全链按真实参数播放）----

func _mk_skip() -> Node:
	# BOSS 档参数（EliteShore 共用同一弹种，只差数值）
	var s := SkipShell.new()
	s.damage = BalanceWorld7.ANCHOR_SKIP_DAMAGE
	s.blast_radius = BalanceWorld7.ANCHOR_SKIP_BLAST_RADIUS
	return s


func _af_skip(n: Node, pos: Vector2) -> void:
	# 平抛鱼雷（v2）：出膛=水平向左（向条目一侧，不瞄人），重力拉浅弧触
	# 甲板开跳——出膛点在条目右侧稍高处（≈船体下管发射位）
	(n as SkipShell).launch(_terrain, pos + Vector2(900.0, -160.0), -1.0)


func _mk_charge7() -> Node:
	return DepthCharge.new()


func _af_charge7(n: Node, pos: Vector2) -> void:
	# 艉侧抛出落海（海面线 860 在桥面之下=坠入桥后海面的真实读法）
	(n as DepthCharge).launch(pos + Vector2(300.0, -240.0), -1.0)


func _mk_surge() -> Node:
	var s := SeaSurge.new()
	s.flood_y = BalanceWorld7.SEA_SURGE_FLOOD_Y
	s.lead = 0.5
	return s


func _af_surge(n: Node, _pos: Vector2) -> void:
	# 涌浪水体按镜头钉位：条目位移必须归零（节点自定位，pos 只当出生触发器）
	(n as SeaSurge).position = Vector2.ZERO
	(n as SeaSurge).launch()


func _af_splash(n: Node, _pos: Vector2) -> void:
	var tw := (n as Sprite2D).create_tween()
	tw.set_parallel(true)
	n.scale = Vector2.ONE * 0.7
	tw.tween_property(n, "scale", Vector2.ONE * 1.8, 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(n, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(n.queue_free)


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
		{"label": "排炮重弹(普攻·慢速熔渣大弹)", "pos": Vector2(2400, 300), "period": 2.0,
			"mk": _mk_scene.bind("res://scenes/weapons/slag_slug.tscn"),
			"af": _af_bullet.bind(BalanceWorld2.BARGE_SLUG_SPEED)},
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
		{"label": "钓灯爆闪(普攻·径向慢矢齐放)", "pos": Vector2(1900, 360), "period": 2.4,
			"mk": Node2D.new, "af": _af_flash},
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
		{"label": "空爆爆裂(白金)", "pos": Vector2(1300, 420), "period": 1.6,
			"mk": _mk_scene.bind("res://scenes/fx/dawn_burst.tscn")},
		{"label": "敌人击毁", "pos": Vector2(cols[2], 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_5.tscn"),
			"af": _af_enemy},
	]})

	# 第六章 赤沙矿区（白热沙天亮=亮底章：电=蓝紫白对比读法、爆=红砂岩屑；
	# 电网闸按 BOSS 档参数走完整周期：落桩迸花→充能光斑渐急→立幕驻留电花→哑熄）
	pages.append({"id": "w6", "title": "六章 · 赤沙矿区", "sky": Color(0.722, 0.816, 0.863),
			"far": "res://assets/world_6/env_red_far.svg",
			"band": "res://assets/world_6/env_red_ground_top.svg",
			"fill": "res://assets/world_6/env_red_ground_fill.svg",
			"seam": Color(0.353, 0.141, 0.086), "detail": Color(0.851, 0.549, 0.369),
			"enemy": "res://scenes/units/enemy_6.tscn", "entries": [
		{"label": "电网闸(落桩→蓄能→立幕)", "pos": Vector2(300, 560), "period": 4.6,
			"mk": _mk_fence, "af": _af_fence},
		{"label": "电幕驻留电花", "pos": Vector2(820, 430), "period": 0.0,
			"mk": _mk_scene.bind("res://scenes/fx/arc_curtain_fx.tscn"),
			"af": _af_curtain},
		{"label": "触电迸溅", "pos": Vector2(1150, 500), "period": 1.4,
			"mk": _mk_scene.bind("res://scenes/fx/arc_spark_burst.tscn")},
		{"label": "装药走廊(三连)", "pos": Vector2(700, 240), "period": 3.6,
			"mk": Node2D.new, "af": _af_corridor},
		{"label": "凿岩装药(拖尾→钉地→起爆)", "pos": Vector2(1450, 320), "period": 2.8,
			"mk": _mk_charge, "af": _af_charge.bind(1900.0)},
		{"label": "敌人击毁", "pos": Vector2(1700, 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_6.tscn"),
			"af": _af_enemy},
		{"label": "凿孔落定尘", "pos": Vector2(620, 648), "period": 1.4,
			"mk": _mk_scene.bind("res://scenes/fx/drill_plant_dust.tscn")},
		{"label": "起爆爆裂(红砂)", "pos": Vector2(2250, 600), "period": 1.6,
			"mk": _mk_scene.bind("res://scenes/fx/red_burst.tscn")},
		{"label": "斗轮抛石(普攻·抛体弧→落地迸溅)", "pos": Vector2(2300, 300), "period": 1.8,
			"mk": _mk_scene.bind("res://scenes/weapons/red_lob.tscn"),
			"af": _af_lob},
	]})

	# 第七章 溺海都会（青绿海光高调=亮底章：暗壳弹体+白沫/青白涌浪语汇；
	# 跳弹按 BOSS 档参数走完整链：抛→三跳溅花→末跳球爆；涌浪走全事件链：
	# 浪冠从屏底探出→漫桥→驻留→退去；深弹坠海落点在桥面之下=桥后海面读法）
	pages.append({"id": "w7", "title": "七章 · 溺海都会", "sky": Color(0.369, 0.541, 0.561),
			"far": "res://assets/world_7/env_sea_far.svg",
			"band": "res://assets/world_7/env_sea_ground_top.svg",
			"fill": "res://assets/world_7/env_sea_ground.svg",
			"seam": Color(0.114, 0.157, 0.137), "detail": Color(0.478, 0.353, 0.235),
			"enemy": "res://scenes/units/enemy_7.tscn", "bridge": true,
			"bridge_girder": "res://assets/world_7/env_sea_girder.svg",
			"bridge_brace": "res://assets/world_7/env_sea_brace.svg",
			"bridge_column_1": "res://assets/world_7/env_sea_column_1.svg",
			"bridge_column_2": "res://assets/world_7/env_sea_column_2.svg",
			"bridge_column_3": "res://assets/world_7/env_sea_column_3.svg",
			"entries": [
		{"label": "跳弹(抛→三跳→末爆)", "pos": Vector2(560, 480), "period": 4.0,
			"mk": _mk_skip, "af": _af_skip},
		{"label": "白沫溅花(落点读出件)", "pos": Vector2(1150, 600), "period": 1.4,
			"mk": _mk_tex.bind("res://assets/world_7/fx_sea_splash.svg"),
			"af": _af_splash},
		{"label": "舰炮曳光(直射)", "pos": Vector2(2300, 360), "period": 1.3,
			"mk": _mk_scene.bind("res://scenes/weapons/sea_bolt.tscn"),
			"af": _af_bullet.bind(1000.0)},
		{"label": "深弹(坠海→水花→闷爆)", "pos": Vector2(1900, 430), "period": 2.6,
			"mk": _mk_charge7, "af": _af_charge7},
		{"label": "涌浪漫桥(全链)", "pos": Vector2(1200, 300), "period": 4.4,
			"mk": _mk_surge, "af": _af_surge},
		{"label": "水下闷爆晕", "pos": Vector2(1750, 640), "period": 1.6,
			"mk": _mk_tex.bind("res://assets/world_7/fx_sea_bloom.svg")},
		{"label": "敌人击毁", "pos": Vector2(cols[4], 596), "period": 3.0,
			"mk": _mk_enemy.bind("res://scenes/units/enemy_7.tscn"),
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
