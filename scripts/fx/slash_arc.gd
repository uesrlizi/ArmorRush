class_name SlashArc
extends Node2D
## 程序化新月刀光：一道弧从起手角长到收势角，**弧长全程只增不减**；
## 亮度沿弧从刃口向尾部逐渐减弱（刃口=刚扫过=最亮，尾部=最早扫过=渐冷）；
## 整弧不透明度只在收势后的熄灭期衰减。
## 前后分层 = 同一道弧画两遍：一个裁掉上半（只画 sinθ>0 观众半侧，z 在机体身前）、
## 一个裁掉下半（z 在机体身后），两遍共享同一套包络，拼缝处亮度连续。
## 角度为挥砍平面平面角（0=正前、+90=观众侧、±180=正后），SlashRoot 统一
## y 向压扁投影成椭圆（2D 侧视的贴地横扫）。

enum Clip { NONE, LOWER, UPPER } # LOWER=只画 sinθ>0（观众半侧），UPPER=只画 sinθ<0

const SEGMENTS := 120 # 满弧细分基准（弧可达 240°，按区间占比伸缩），段距约 2° 无折角

# ---- 弧几何（起手时由 Player 写入） ----
var pivot_offset := Vector2(10, 2) # 弧心（挥砍平面圆心）相对本节点的偏移
var radius := 115.0                # 挥砍半径（压扁前）
var thickness := 30.0              # 弧带厚度（压扁前；椭圆上下端随投影变细）
var color_core := Color(0.9, 0.99, 1.0)
var color_outer := Color(0.2, 0.65, 1.0)
var depth_dim := 0.75 # 绕到机身后方（sinθ<0）那侧的亮度系数，按 sinθ 平滑过渡
var clip := Clip.NONE # 本节点裁掉哪半侧

var _from := 0.0    # 起手角（弧尾，扫掠期固定不动）
var _head := 0.0    # 刃口角（随扫掠推进，弧长只增）
var _alpha := 1.0   # 整弧不透明度（只有熄灭期衰减）
var _brightness := 1.0 # 全局亮度（起手快攻上升）


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## 喂入当前弧状态并重绘。from_deg 固定为起手角，head_deg 为刃口当前位置。
func show_arc(from_deg: float, head_deg: float, alpha: float, brightness: float = 1.0) -> void:
	_from = from_deg
	_head = head_deg
	_alpha = alpha
	_brightness = brightness
	queue_redraw()


func clear() -> void:
	if _alpha > 0.0:
		_alpha = 0.0
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var lo := minf(_from, _head)
	var hi := maxf(_from, _head)
	if hi - lo < 1.0:
		return
	# 按 sinθ 零点切分，裁掉本节点不负责的半侧（近/远两遍在零点处拼合）。
	var bounds: Array[float] = [lo, hi]
	for k in range(-2, 3):
		for base: float in [0.0, 180.0]:
			var c := base + 360.0 * k
			if c > lo + 0.5 and c < hi - 0.5:
				bounds.append(c)
	bounds.sort()
	var sweep_total := _head - _from # 带符号；弧龄参数 u 沿它归一
	for i in bounds.size() - 1:
		var a := bounds[i]
		var b := bounds[i + 1]
		if b - a < 1.0:
			continue
		var mid_sign := signf(sin(deg_to_rad((a + b) * 0.5)))
		if (clip == Clip.LOWER and mid_sign < 0.0) \
				or (clip == Clip.UPPER and mid_sign > 0.0):
			continue
		_draw_band_interval(a, b, sweep_total)
		if absf(a - _head) < 0.5 or absf(b - _head) < 0.5:
			_draw_edge(_head)


func _draw_band_interval(lo: float, hi: float, sweep_total: float) -> void:
	var steps := maxi(2, ceili(SEGMENTS * absf(hi - lo) / 240.0))
	var pts_inner := PackedVector2Array()
	var pts_core := PackedVector2Array()
	var pts_outer := PackedVector2Array()
	var cols_inner := PackedColorArray()
	var cols_core := PackedColorArray()
	var cols_outer := PackedColorArray()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a_deg := lerpf(lo, hi, t)
		# 弧龄：u=0 刃口（刚扫过，最亮）→ u=1 起手角（最早扫过，渐冷）。
		var u := clampf((_head - a_deg) / sweep_total, 0.0, 1.0)
		var bright := lerpf(0.22, 1.0, pow(1.0 - u, 1.35)) # 沿弧向尾部逐渐减弱
		var w := thickness * pow(sin(PI * u), 0.3) # 两端收尖：刃口薄、起手尖
		var a := deg_to_rad(a_deg)
		# 深度亮度：绕到机身后方（sinθ<0）侧平滑压暗，两遍共用同一曲线。
		var depth := lerpf(1.0, depth_dim, clampf(-sin(a) * 2.0, 0.0, 1.0))
		var glow := bright * _alpha * _brightness * depth
		var dir := Vector2(cos(a), sin(a))
		pts_inner.append(pivot_offset + dir * (radius - w * 0.45))
		pts_core.append(pivot_offset + dir * (radius + w * 0.1))
		pts_outer.append(pivot_offset + dir * (radius + w * 0.55))
		cols_inner.append(Color(color_outer, 0.5 * glow))
		cols_core.append(Color(color_core.lerp(Color.WHITE, 0.5), 0.95 * glow))
		cols_outer.append(Color(color_outer, 0.0))
	_draw_band(pts_inner, cols_inner, pts_core, cols_core)
	_draw_band(pts_core, cols_core, pts_outer, cols_outer)


func _draw_edge(edge_deg: float) -> void:
	var a := deg_to_rad(edge_deg)
	var depth := lerpf(1.0, depth_dim, clampf(-sin(a) * 2.0, 0.0, 1.0))
	var dir := Vector2(cos(a), sin(a))
	draw_line(
		pivot_offset + dir * (radius - thickness * 0.45),
		pivot_offset + dir * (radius + thickness * 0.55),
		Color(1.0, 1.0, 1.0, 0.9 * _alpha * _brightness * depth), 3.5, true)
	draw_circle(pivot_offset + dir * (radius + thickness * 0.1), 4.5,
			Color(1.0, 1.0, 1.0, 0.75 * _alpha * _brightness * depth))


## 弧带 = 两排顶点（a 排 + b 排）张成的四边形条带，按显式索引切成三角带提交。
## 不能用 draw_polygon 整体闭合提交：那是对整条 C 形凹多边形做耳切三角化，
## 切出的耳朵三角形横跨 a/b 两排顶点，顶点色沿长对角线拉出交替楔形——
## 就是内白外蓝之间那道锯齿波。显式条带每格四边形沿同一方向切对角线，
## 顶点色沿径向逐格线性插值（真·渐变）；相邻三角形共享边由光栅化填充
## 规则保证只着色一次，加色混合下同样无缝。
func _draw_band(pts_a: PackedVector2Array, cols_a: PackedColorArray,
		pts_b: PackedVector2Array, cols_b: PackedColorArray) -> void:
	var n := pts_a.size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append_array(pts_a)
	cols.append_array(cols_a)
	pts.append_array(pts_b)
	cols.append_array(cols_b)
	var indices := PackedInt32Array()
	for i in n - 1:
		var a0 := i
		var a1 := i + 1
		var b0 := n + i
		var b1 := n + i + 1
		indices.push_back(a0)
		indices.push_back(a1)
		indices.push_back(b0)
		indices.push_back(a1)
		indices.push_back(b1)
		indices.push_back(b0)
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), indices, pts, cols)
