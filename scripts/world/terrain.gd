class_name Terrain
extends Node2D
## 高低不平的地块生成器（种子化纯函数 + 小窗口缓存，双向、往返一致）：
## 一个"段"= 连续 TERRAIN_RUN_MIN..RUN_MAX 块同高。段的长度与高度档都由
## (每局随机种子, 段索引) 的整数哈希直接得出——纯函数，与生成顺序无关；
## 段起点按 start(s+1) = start(s) + len(s) 递推。因此任何地块被清除后，
## 从缓存窗口边缘按种子迭代即可精确重建，双向走回都一致。
## 缓存只保留镜头附近一小段段起点，走远即忘，内存不随路程增长。

## 地块皮肤按章走：默认=第一章锈雨废都（破碎沥青路面），
## 第二章主场景在检查器里换成精炼所钢板/混凝土带。
## 纹理规格（拆地块 v2，2026-10-21）：
##   band_texture = 640x66，左右各一个 320 宽变体拼花（A/B），按块序号奇偶取半幅；
##     纹理内烘焙：顶缘亮线(0..2.5)/走道带花(2.5..56)/立面 AO 渐隐(56..66)/块间竖缝；
##   fill_texture = 16x256 立面渐变（face_hi→face_lo）+ 烘焙层理横线，
##     被 sprite 拉伸到 320x(700-66)。
@export var band_texture: Texture2D = preload("res://assets/world_1/env_rust_ground_top.svg")
@export var fill_texture: Texture2D = preload("res://assets/world_1/env_rust_ground_fill.svg")
## 块间缝与立面细节（露头钢筋/冰脉）颜色按章配（ch2/3/4 场景里覆盖）
@export var seam_color := Color("1f1d16")
@export var detail_color := Color("6a5a48")
## ---- 桥式模式（可选，world_5 用）----
## bridge_girder_texture 非空即启用：每块画 箱梁+排架柱（挡位选贴图）+剪刀撑，
## 不再画 fill 立面/露头横杆/块间缝（块间接缝烘在箱梁贴图两端）。
## 排架柱选挡：需要长度 = bridge_sea_y − 柱顶，取贴图数组里高度最接近且
## 不短于它的那张（柱底统一钉在海面固定线上=「海面固定、柱随地形换挡」）。
## 云海本体是场景里的独立固定条（GroundStrip，scroll=1 钉屏幕），不归块管。
@export var bridge_girder_texture: Texture2D
@export var bridge_brace_texture: Texture2D
@export var bridge_column_textures: Array[Texture2D] = []
@export var bridge_column_xs: PackedFloat32Array = PackedFloat32Array([48.0, 244.0])
@export var bridge_sea_y := 860.0 # 海面固定线（世界 y）：柱脚目标深度
const BAND_HEIGHT := 66.0    # 表面带 56 + 立面 AO 渐隐 10（都烘在纹理里）
const FILL_DEPTH := 700.0    # 顶面向下的填充深度（覆盖最低档到画面外）
const SEG_CACHE_MARGIN := 96 # 段起点缓存保留镜头两侧多少段，超出即忘

var _chunks := {}    # 块索引 -> StaticBody2D
var _seg_start := {} # 段索引 -> 该段首块的块索引（缓存窗口，可按种子重建）
var _seed := 0
var _primed := false


func _ready() -> void:
	add_to_group("terrain") # 重击武器（导弹落点解算）按组查找地表高度


func _physics_process(_delta: float) -> void:
	if not _primed:
		_seed = randi() # 每局随机一次；一局内一切由它确定性推出
		_seg_start[0] = 0
		_primed = true
	_update()


func _update() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var w := BalanceGlobal.TERRAIN_CHUNK_WIDTH
	var half_w := get_viewport_rect().size.x * 0.5
	var center := cam.get_screen_center_position().x
	var lo := floori((center - half_w - w) / w)
	var hi := floori((center + half_w + w) / w)

	# 双向补块：缺哪块补哪块，高度由种子纯函数决定
	for i in range(lo, hi + 1):
		if not _chunks.has(i):
			_spawn_chunk(i)

	# 清除视野外（两侧都清；高度是纯函数，走回来会原样重建）
	for i in _chunks.keys():
		if i < lo or i > hi:
			_chunks[i].queue_free()
			_chunks.erase(i)


func _spawn_chunk(i: int) -> void:
	var w := BalanceGlobal.TERRAIN_CHUNK_WIDTH
	var top := _tier_y(_seg_tier(_seg_of_chunk(i)))
	var chunk := StaticBody2D.new()
	chunk.collision_layer = 1
	chunk.collision_mask = 0
	chunk.position = Vector2(i * w, top)
	chunk.set_meta("top", top)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, FILL_DEPTH)
	shape.shape = rect
	shape.position = Vector2(w * 0.5, FILL_DEPTH * 0.5)
	chunk.add_child(shape)

	chunk.add_child(_make_band_sprite(i))
	if _bridge_mode():
		_add_bridge_parts(chunk, i, top)
	else:
		chunk.add_child(_make_fill_sprite())
		_add_chunk_decor(chunk, i)

	add_child(chunk)
	_chunks[i] = chunk


func _bridge_mode() -> bool:
	return bridge_girder_texture != null and not bridge_column_textures.is_empty()


## 桥式件（块的局部坐标）：箱梁整幅宽 + 剪刀撑挂两柱之间梁下 + 排架柱
## ×2 按挡位选贴图（柱底统一钉在 bridge_sea_y），柱身按 (块序+柱序) 奇偶
## 镜像微错，破一破等距柱列的复制感。
func _add_bridge_parts(chunk: StaticBody2D, i: int, top: float) -> void:
	var girder := Sprite2D.new()
	girder.texture = bridge_girder_texture
	girder.centered = false
	girder.position = Vector2(0.0, BAND_HEIGHT)
	chunk.add_child(girder)
	var girder_bottom := BAND_HEIGHT + bridge_girder_texture.get_size().y
	if bridge_brace_texture != null:
		var brace := Sprite2D.new()
		brace.texture = bridge_brace_texture
		brace.centered = false
		brace.position = Vector2(76.0, girder_bottom - 8.0)
		chunk.add_child(brace)
	var columns := bridge_column_textures.duplicate()
	columns.sort_custom(func(a: Texture2D, b: Texture2D) -> bool:
		return a.get_size().y < b.get_size().y)
	for j in bridge_column_xs.size():
		var need := bridge_sea_y - (top + girder_bottom)
		var tex: Texture2D = columns[columns.size() - 1] # 比最长挡还深时兜底最长柱
		for t: Texture2D in columns:
			if t.get_size().y >= need:
				tex = t
				break
		var col := Sprite2D.new()
		col.texture = tex
		col.centered = false
		col.flip_h = (i + j) & 1 == 1
		# 柱底钉在 bridge_sea_y（世界线）：子节点坐标是块的局部系，须减块顶
		col.position = Vector2(bridge_column_xs[j] - tex.get_size().x * 0.5,
				bridge_sea_y - top - tex.get_size().y)
		chunk.add_child(col)


# ---- 段的纯函数：长度与高度档只取决于 (种子, 段索引) ----
## 段 0 与段 -1 固定为同高长平地（启动页：机甲在原点空场待命，
## 画面里脚下不许有高低差——向西也铺一小段，镜头左缘不出台阶）；
## 之后照常随机。
func _seg_len(s: int) -> int:
	if s == 0:
		return BalanceGlobal.TERRAIN_INTRO_SEG_LEN
	if s == -1:
		return BalanceGlobal.TERRAIN_INTRO_WEST_SEG_LEN
	var span := BalanceGlobal.TERRAIN_RUN_MAX - BalanceGlobal.TERRAIN_RUN_MIN + 1
	return BalanceGlobal.TERRAIN_RUN_MIN + _hash(s, 1) % span


func _seg_tier(s: int) -> int:
	if s == 0 or s == -1:
		return BalanceGlobal.TERRAIN_INTRO_SEG_TIER
	return _hash(s, 2) % BalanceGlobal.TERRAIN_TIER_COUNT


func _hash(s: int, salt: int) -> int:
	var h := s * 374761393 + salt * 668265263 + _seed
	h = (h ^ (h >> 13)) * 1274126177
	h ^= h >> 16
	return absi(h)


# ---- 段起点：按递推 start(s+1) = start(s) + len(s) 缓存/重建 ----
func _seg_start_of(s: int) -> int:
	if _seg_start.has(s):
		return _seg_start[s]
	# 从最近的已缓存段向 s 迭代（每步一段，代价随距离摊薄）
	var nearest := 0
	var best := INF
	for k in _seg_start.keys():
		var d := absi(k - s)
		if d < best:
			best = d
			nearest = k
	var v: int = _seg_start[nearest]
	var dir := 1 if s > nearest else -1
	var cur := nearest
	while cur != s:
		var nxt := cur + dir
		if dir > 0:
			v += _seg_len(cur)
		else:
			v -= _seg_len(nxt)
		_seg_start[nxt] = v
		cur = nxt
	return _seg_start[s]


## 包含块索引 i 的段（迭代定位，顺带刷新缓存窗口）
func _seg_of_chunk(i: int) -> int:
	if _seg_start.is_empty():
		_seg_start[0] = 0
	var s := 0
	var best := INF
	for k in _seg_start.keys():
		var d := absi(k - i)
		if d < best:
			best = d
			s = k
	while true:
		var st := _seg_start_of(s)
		if st > i:
			s -= 1
		elif st + _seg_len(s) <= i:
			s += 1
		else:
			return s
	return s # 不可达，仅为通过返回值分析


func _tier_y(tier: int) -> float:
	return BalanceGlobal.TERRAIN_TIER_BASE_Y - tier * BalanceGlobal.TERRAIN_TIER_STEP


## 表面带：640 宽纹理的 A/B 两半，按块序号奇偶取用（接缝烘在纹里，无平铺相位）
func _make_band_sprite(i: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = band_texture
	s.centered = false
	s.region_enabled = true
	var w := BalanceGlobal.TERRAIN_CHUNK_WIDTH
	s.region_rect = Rect2(w * float(i & 1), 0.0, w, BAND_HEIGHT)
	return s


## 填充：竖向渐变纹理（含烘焙层理）拉伸到整块深度。
## 缩放按贴图实际尺寸算（默认 16x256；章可用原生分辨率贴图画桥式
## 排架柱等实体结构，见 world_5 的 env_dawn_ground_fill 320x634）。
func _make_fill_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = fill_texture
	s.centered = false
	s.position = Vector2(0, BAND_HEIGHT)
	var tex_size := fill_texture.get_size()
	s.scale = Vector2(BalanceGlobal.TERRAIN_CHUNK_WIDTH / tex_size.x,
			(FILL_DEPTH - BAND_HEIGHT) / tex_size.y)
	return s


## 块间缝：左右缘竖缝，顶点色做上密下疏 alpha 渐变（纯视觉，随块重建）
func _make_seam(x: float) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(x, BAND_HEIGHT + 4.0), Vector2(x + 1.2, BAND_HEIGHT + 4.0),
		Vector2(x + 1.2, BAND_HEIGHT + 78.0), Vector2(x, BAND_HEIGHT + 78.0),
	])
	var ca := seam_color
	ca.a = 0.5
	var cb := seam_color
	cb.a = 0.0
	p.vertex_colors = PackedColorArray([ca, ca, cb, cb])
	return p


## 立面细节：1~2 组"露头横杆+端点"（钢筋/冰脉/管线，颜色按章 @export），
## 位置由 (每局种子, 块序号) 纯函数决定——块清掉重建后原样重现
func _make_face_details(i: int) -> Node2D:
	var holder := Node2D.new()
	var count := 1 + (_hash(i, 7) % 2)
	for j in count:
		var hx := _hash(i, 8 + j)
		var rx := 60.0 + float(hx % 200)
		var ry := BAND_HEIGHT + 16.0 + float((hx / 7) % 18)
		var c := detail_color
		c.a = 0.85
		var bar := Polygon2D.new()
		bar.color = c
		bar.polygon = PackedVector2Array([
			Vector2(rx, ry), Vector2(rx + 18.0, ry),
			Vector2(rx + 18.0, ry + 2.6), Vector2(rx, ry + 2.6),
		])
		holder.add_child(bar)
		var dot := Polygon2D.new()
		dot.color = c
		dot.polygon = PackedVector2Array([
			Vector2(rx + 21.0, ry - 1.3), Vector2(rx + 23.6, ry - 1.3),
			Vector2(rx + 23.6, ry + 1.3), Vector2(rx + 21.0, ry + 1.3),
		])
		holder.add_child(dot)
	return holder


func _add_chunk_decor(chunk: StaticBody2D, i: int) -> void:
	chunk.add_child(_make_seam(0.6))
	chunk.add_child(_make_seam(BalanceGlobal.TERRAIN_CHUNK_WIDTH - 1.8))
	chunk.add_child(_make_face_details(i))


## 指定 x 处的地表高度。段数据是纯函数，未生成的远处也能精确算出，
## 刷敌人/脚手架永远贴合将来的地表。
func surface_y_at(x: float) -> float:
	var i := floori(x / BalanceGlobal.TERRAIN_CHUNK_WIDTH)
	if _chunks.has(i):
		return _chunks[i].get_meta("top")
	return _tier_y(_seg_tier(_seg_of_chunk(i)))
