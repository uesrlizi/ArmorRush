class_name EyeGlow
extends Node2D
## AC6 式敌机独眼横向拉丝：挂在敌人 Sprite2D 下的常驻节点，眼位由场景按
## 「原生朝左」姿态摆放（整体缩放也摆在节点上，绘制恒按单位尺寸）。
## 加色混合三层——红色放射晕 + 长拉丝 + 白热芯线，亮度按双正弦微脉动
## （同推进焰配方，去静态贴片感）。
## 拉丝永远水平（变形宽银幕镜头的横向眩光感）：Sprite2D.flip_h 只镜像贴图、
## 不镜像子节点，本节点每帧对照父级朝向翻转自身 x，敌人脚本零改动。
## 顶点渐变条带按项目纪律走 canvas_item_add_triangle_array 显式索引，
## 不走 draw_polygon 的耳切三角化。

const EYE_RED := Color(1.0, 0.32, 0.25) # 与素材独眼 #ff5140 同族
const HOT_CORE := Color(1.0, 0.85, 0.7)

const GLOW_RADIUS := 9.0   # 放射晕半径（已含两层衰减）
const STREAK_HALF := 22.0  # 拉丝半长
const STREAK_HALF_H := 1.6 # 拉丝半厚
const CORE_HALF := 10.0    # 白热芯半长

var _phase := randf() * TAU
var _home_x := 0.0 # 场景摆下的眼位 x（原生朝左基准，镜像绕它翻符号）


func _ready() -> void:
	_home_x = position.x
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(_delta: float) -> void:
	var sprite := get_parent() as Sprite2D
	if sprite != null:
		position.x = -_home_x if sprite.flip_h else _home_x
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# 慢呼吸 × 电气颤：待机扫描感，纯静态亮度一眼假
	var pulse := 0.85 + 0.15 * sin(t * 2.4 + _phase)
	pulse *= 1.0 + 0.08 * sin(t * 43.0 + _phase * 1.7) + 0.05 * sin(t * 71.0 + 0.9)
	_draw_radial_glow(GLOW_RADIUS, Color(EYE_RED, 0.42 * pulse))
	_draw_lens_streak(STREAK_HALF, STREAK_HALF_H, Color(EYE_RED, 0.6 * pulse))
	_draw_lens_streak(CORE_HALF, STREAK_HALF_H * 0.55, Color(HOT_CORE, pulse))


## 横向拉丝：六边形透镜面，中段等亮、两端收到零。
func _draw_lens_streak(half_len: float, half_h: float, c: Color) -> void:
	var mid := half_len * 0.4
	var points := PackedVector2Array([
		Vector2(-half_len, 0.0), Vector2(-mid, -half_h),
		Vector2(mid, -half_h), Vector2(half_len, 0.0),
		Vector2(mid, half_h), Vector2(-mid, half_h),
	])
	var tip := Color(c.r, c.g, c.b, 0.0)
	var colors := PackedColorArray([tip, c, c, tip, c, c])
	# 六边形从顶点 5（左下）扇形展开；canvas 三角不剔除背面，绕序随意
	var indices := PackedInt32Array([5, 0, 1, 5, 1, 2, 5, 2, 3, 5, 3, 4])
	RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), indices, points, colors)


## 放射晕：内外两圈扇形（内圈全亮、外圈收零），叠出近似指数衰减。
func _draw_radial_glow(radius: float, c: Color) -> void:
	_draw_glow_fan(radius * 0.5, c)
	_draw_glow_fan(radius, Color(c.r, c.g, c.b, c.a * 0.45))


func _draw_glow_fan(radius: float, c: Color) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var colors := PackedColorArray([c])
	var rim := Color(c.r, c.g, c.b, 0.0)
	var indices := PackedInt32Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		points.append(Vector2(cos(a), sin(a)) * radius)
		colors.append(rim)
		indices.append_array([0, 1 + i, 1 + (i + 1) % 12])
	RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), indices, points, colors)
