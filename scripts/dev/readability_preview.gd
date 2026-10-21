extends Node2D
## 可读性提案对比（临时）：同一画面跑 4 个方案各截一张，自退。
## 方案 P0 现状基线 / P1 雾层推远中景 / P2 角色轮廓光+落影 / P3 = P1+P2+中景橙让位。
## godot --path . res://scenes/previews/readability_preview.tscn
## 注意：窗口进程紧邻重启可能卡首帧，跑前后都 taskkill 残留 godot 进程。

const FOG_COLOR := Color(0.702, 0.663, 0.498) # 天色 #b3a97f（与清屏色同源）
const RIM_COLOR := Color(1.0, 0.89, 0.70, 0.95)
const SHOT_DIR := "res://autotest_shots"

var _main: Node2D
var _fog: Sprite2D
var _rim_shader: Shader
var _overlay_nodes: Array[Node] = []
var _mid_default: Texture2D
var _mid_soft: Texture2D


func _ready() -> void:
	_rim_shader = load("res://art_proposals/readability/outline_rim.gdshader")
	_mid_default = load("res://assets/world_1/env_rust_mid.svg")
	_mid_soft = load("res://assets/world_1/env_rust_mid_soft.svg")
	_main = load("res://scenes/world/world_1.tscn").instantiate()
	add_child(_main)
	(_main.get_node("HUD") as CanvasLayer).visible = false
	_stage_scene()
	for i in 60:
		await get_tree().process_frame # 相机 smoothing 收敛
	for plan in 4:
		_apply(plan)
		for i in 8:
			await get_tree().process_frame
		await _shot("readability_p%d.png" % plan)
	print("[readability_preview] all saved")
	get_tree().quit()


## 摆一张有代表性的战斗画面：三块断桥 + 桥上敌人 + 地面敌人 + 方块箱 + 平台箱。
func _stage_scene() -> void:
	var spawner: Spawner = _main.get_node("Spawner")
	for dx in [500.0, 1100.0, 1700.0]:
		spawner._spawn(spawner.scaffold_scene, false, 200.0 + dx)
	spawner._spawn(spawner.platform_scene, false, 950.0)
	spawner._spawn(spawner.obstacle_scene, false, 620.0)
	spawner.debug_spawn_enemy(1180.0) # 贴地
	spawner.debug_spawn_enemy(1900.0) # x 落在桥 1540~2260 → 站桥面


## 方案切换：先清上一种叠加，再按位上效果。
func _apply(plan: int) -> void:
	_clear_overlays()
	var mid := _main.get_node("MidStrip") as Sprite2D
	mid.texture = _mid_default
	if plan == 1 or plan == 3:
		_add_fog()
	if plan == 2 or plan == 3:
		_add_rims_and_shadows()
		if plan == 3:
			mid.texture = _mid_soft


## P1/P3：天色雾层，插在 MidStrip 之后、BridgePiers 之前——只洗远景+中景，前景保持锐利。
## 近地雾浓、天顶淡（雨雾沉底），垂直渐变。
func _add_fog() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(FOG_COLOR, 0.28), Color(FOG_COLOR, 0.45), Color(FOG_COLOR, 0.58),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 64
	tex.height = 256
	_fog = Sprite2D.new()
	_fog.texture = tex
	_fog.centered = false
	_fog.position = Vector2(-3000, -40)
	_fog.scale = Vector2(7000.0 / 64.0, 1340.0 / 256.0)
	_main.add_child(_fog)
	_main.move_child(_fog, 2) # HillsStrip=0, MidStrip=1 → 雾插在 2


## P2/P3：给玩家与敌人所有贴图件加轮廓光副本 + 脚下接触落影。
## 落影/轮廓光挂进角色的 Visuals 镜像层（没有才退回根节点）——挂在根上
## 会在角色换边时留在原地，不跟贴图走。
func _add_rims_and_shadows() -> void:
	var rigs: Array[Node2D] = [_main.get_node("Player") as Node2D]
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e != null:
			rigs.append(e)
	for rig in rigs:
		var host: Node2D = rig.get_node_or_null("Visuals") as Node2D
		if host == null:
			host = rig
		_add_shadow(host, rig.name)
		for sprite in _find_sprites(host):
			_add_rim_copy(host, sprite, rig.name)


func _find_sprites(rig: Node2D) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	var stack: Array[Node] = [rig]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Sprite2D:
			found.append(n)
		for c in n.get_children():
			stack.append(c)
	return found


func _add_rim_copy(host: Node2D, sprite: Sprite2D, rig_name: String) -> void:
	var rim := Sprite2D.new()
	rim.texture = sprite.texture
	rim.centered = sprite.centered
	rim.offset = sprite.offset
	rim.flip_h = sprite.flip_h
	rim.scale = sprite.scale
	rim.position = sprite.position
	var mat := ShaderMaterial.new()
	mat.shader = _rim_shader
	mat.set_shader_parameter("rim_color", RIM_COLOR)
	# 玩家贴图经 0.6 缩放屏显，描边放宽补回；敌人 1:1 用默认宽。
	mat.set_shader_parameter("width_px", 3.4 if rig_name == "Player" else 2.2)
	rim.material = mat
	host.add_child(rim)
	host.move_child(rim, 1) # index0 是落影 → 影子最底、轮廓光次之、本体部件最上
	_overlay_nodes.append(rim)


func _add_shadow(host: Node2D, rig_name: String) -> void:
	var pts := PackedVector2Array()
	var rx := 26.0 if rig_name == "Player" else 30.0
	var ry := 5.0
	var foot_y := 32.0 if rig_name == "Player" else 26.0
	for i in 20:
		var ang := TAU * float(i) / 20.0
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(0.10, 0.09, 0.06, 0.30)
	poly.position = Vector2(0, foot_y)
	rig.add_child(poly)
	rig.move_child(poly, 0)
	_overlay_nodes.append(poly)


func _clear_overlays() -> void:
	for n in _overlay_nodes:
		n.queue_free()
	_overlay_nodes.clear()
	if _fog != null:
		_fog.queue_free()
		_fog = null


func _shot(fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := SHOT_DIR + "/" + fname
	img.save_png(ProjectSettings.globalize_path(path))
	print("[readability_preview] saved ", path)
