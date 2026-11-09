class_name ExplosionBurst
extends Node2D
## 击毁爆炸：白闪 → 橙红火球 + 扩散冲击环（本体绘制，加法混合），
## 叠火焰/烟尘/碎片三层粒子（火焰加法发亮，烟尘碎片普通混合压得住底色）。
## 一次性自灭；由 Enemy 在击毁瞬间生成，不随本体回池消失。

const FLASH_TIME := 0.12
const FIREBALL_TIME := 0.3
const RING_TIME := 0.38
const LIFETIME := 0.95
const INK_SAMPLE_MAX := 64 # 墨迹面积取样：贴图缩到长边 ≤64px 再数不透明像素（接近就行）

## 承接半径（局部 px，未乘节点缩放）：这次爆炸要接走的本体的**面积折算半径**
## （面积承接：πr²≈本体墨迹面积，接近就行——不取包围框/外接圆，design/worlds.md §4c）。
## 实现=白闪起跳半径放大（r0=max(9, cover)），不另加白盘叠层（两层白=过亮，踩过）。
## 0=模板原样（杂兵击毁就是 0：原版爆炸本身接得住）。
@export var cover_radius := 0.0

static var _ink_cache := {} # 贴图 → 不透明像素占比（每张贴图只数一次）

var _life := 0.0


## 面积折算承接半径：πr²=面积 → r=√(面积/π)。
static func area_cover_radius(area_px: float) -> float:
	return sqrt(maxf(area_px, 0.0) / PI)


## 精灵墨迹面积（世界 px²，含缩放）：显示矩形 × 贴图不透明像素占比——透明边和
## 画布留白不算（画布矩形面积会把玩家整机算到 ~3.7 万 px²，实际墨迹约其 1/5）。
static func sprite_area(sprite: Sprite2D) -> float:
	if sprite == null or sprite.texture == null:
		return 0.0
	var s := sprite.get_rect().size
	var g := (sprite.global_scale if sprite.is_inside_tree() else sprite.scale).abs()
	return s.x * g.x * s.y * g.y * _ink_ratio(sprite.texture)


static func _ink_ratio(tex: Texture2D) -> float:
	if _ink_cache.has(tex):
		return _ink_cache[tex]
	var ratio := 1.0
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var k := maxf(1.0, float(maxi(img.get_width(), img.get_height())) / INK_SAMPLE_MAX)
		img.resize(maxi(1, roundi(img.get_width() / k)), maxi(1, roundi(img.get_height() / k)))
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		ratio = float(opaque) / float(img.get_width() * img.get_height())
	_ink_cache[tex] = ratio
	return ratio


## 子树里所有可见精灵的面积和（多件拼装的单位：机体/枪臂/腿/挂舱……）。
static func tree_sprite_area(root: Node) -> float:
	var area := 0.0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is CanvasItem and not (cur as CanvasItem).visible:
			continue
		if cur is Sprite2D:
			area += sprite_area(cur as Sprite2D)
		for c in cur.get_children():
			stack.append(c)
	return area


func _ready() -> void:
	$Fire.emitting = true
	$Smoke.emitting = true
	$Debris.emitting = true


func _process(delta: float) -> void:
	_life += delta
	queue_redraw()
	if _life >= LIFETIME:
		queue_free()


func _draw() -> void:
	var flash_p := _life / FLASH_TIME
	if flash_p < 1.0:
		# 白闪：瞬间吞掉机体轮廓的第一帧；cover_radius>0 时起跳半径直接放大到
		# 面积折算半径（只放大这一层，不加层），且按二次曲线快收——大半径线性淡出
		# 会在后半程停成一张平灰盘（终爆实测 3~4 帧）。cover=0 时与模板逐帧一致。
		var eased := 1.0 - pow(1.0 - flash_p, 2.0)
		var r0 := maxf(9.0, cover_radius)
		var fade := 1.0 - flash_p
		if cover_radius > 0.0:
			fade *= fade
		draw_circle(Vector2.ZERO, lerpf(r0, maxf(30.0, r0 * 1.5), eased),
				Color(1.0, 1.0, 0.95, 0.95 * fade))
	var fire_p := _life / FIREBALL_TIME
	if fire_p < 1.0:
		# 火球：橙色外壳外扩，黄白核心收拢。
		var eased := 1.0 - pow(1.0 - fire_p, 1.8)
		draw_circle(Vector2.ZERO, lerpf(10.0, 38.0, eased),
				Color(1.0, 0.55, 0.12, 0.8 * (1.0 - fire_p)))
		draw_circle(Vector2.ZERO, lerpf(6.0, 19.0, eased),
				Color(1.0, 0.9, 0.5, 0.9 * (1.0 - fire_p)))
	var ring_p := _life / RING_TIME
	if ring_p < 1.0:
		var eased := 1.0 - pow(1.0 - ring_p, 2.4)
		draw_arc(Vector2.ZERO, lerpf(12.0, 80.0, eased), 0.0, TAU, 48,
				Color(1.0, 0.85, 0.55, 0.55 * (1.0 - ring_p)),
				3.0 * (1.0 - ring_p) + 0.6, true)
