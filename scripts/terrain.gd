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
@export var band_texture: Texture2D = preload("res://assets/env_rust_ground_top.svg")
@export var fill_texture: Texture2D = preload("res://assets/env_rust_ground_fill.svg")
const BAND_HEIGHT := 56.0    # 表面带高度（256 宽纹理横向平铺，块间相位对齐）
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
	var w := Balance.TERRAIN_CHUNK_WIDTH
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
	var w := Balance.TERRAIN_CHUNK_WIDTH
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
	chunk.add_child(_make_fill_sprite())

	add_child(chunk)
	_chunks[i] = chunk


# ---- 段的纯函数：长度与高度档只取决于 (种子, 段索引) ----
## 段 0 与段 -1 固定为同高长平地（启动页：机甲在原点空场待命，
## 画面里脚下不许有高低差——向西也铺一小段，镜头左缘不出台阶）；
## 之后照常随机。
func _seg_len(s: int) -> int:
	if s == 0:
		return Balance.TERRAIN_INTRO_SEG_LEN
	if s == -1:
		return Balance.TERRAIN_INTRO_WEST_SEG_LEN
	var span := Balance.TERRAIN_RUN_MAX - Balance.TERRAIN_RUN_MIN + 1
	return Balance.TERRAIN_RUN_MIN + _hash(s, 1) % span


func _seg_tier(s: int) -> int:
	if s == 0 or s == -1:
		return Balance.TERRAIN_INTRO_SEG_TIER
	return _hash(s, 2) % Balance.TERRAIN_TIER_COUNT


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
	return Balance.TERRAIN_TIER_BASE_Y - tier * Balance.TERRAIN_TIER_STEP


## 表面带：按纹理原宽 256 平铺，相位取块的世界 x 取模，块间花纹连续
func _make_band_sprite(i: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = band_texture
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.centered = false
	s.region_enabled = true
	var w := Balance.TERRAIN_CHUNK_WIDTH
	s.region_rect = Rect2(fposmod(i * w, 256.0), 0.0, w, BAND_HEIGHT)
	return s


## 填充：竖向渐变纹理拉伸到整块深度
func _make_fill_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = fill_texture
	s.centered = false
	s.position = Vector2(0, BAND_HEIGHT)
	s.scale = Vector2(Balance.TERRAIN_CHUNK_WIDTH / 16.0, (FILL_DEPTH - BAND_HEIGHT) / 256.0)
	return s


## 指定 x 处的地表高度。段数据是纯函数，未生成的远处也能精确算出，
## 刷敌人/脚手架永远贴合将来的地表。
func surface_y_at(x: float) -> float:
	var i := floori(x / Balance.TERRAIN_CHUNK_WIDTH)
	if _chunks.has(i):
		return _chunks[i].get_meta("top")
	return _tier_y(_seg_tier(_seg_of_chunk(i)))
