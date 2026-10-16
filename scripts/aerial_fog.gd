class_name AerialFog
extends Sprite2D
## 天色雾层(P1 可读性提案实装):插在 MidStrip 与 BridgePiers 之间,只洗远景+中景,
## 前景(桥墩/地块/箱子/角色)画在本层之上,保持锐利。
## 底边不做几何对齐:雾的浓度在地面线附近达到最大后向下一路保持,
## 层延伸到画面外,可见底边由起伏的地块轮廓自然"剪"出,高低地形都贴合。
## 雾是大气,不随世界滚动:每帧只对齐镜头中心 x(镜头 y 本就锁死)。

const COLOR := Color(0.702, 0.663, 0.498) # 天色 #b3a97f(与清屏色同源)
const TOP_Y := -600.0                     # 雾层覆盖世界 y -600..2000
const HEIGHT := 2600.0
const WIDTH := 2600.0                     # 视口 2400 + 镜头平滑/震动余量
# 渐变控制点 (进度, alpha);进度 = (世界y - TOP_Y) / HEIGHT。
# 世界 y: -600→0.0 / 300→0.346 / 600→0.462(地面线 664 前已到峰值) / 2000→1.0
const STOPS: Array[Vector2] = [
	Vector2(0.0, 0.10), Vector2(0.35, 0.42), Vector2(0.47, 0.52), Vector2(1.0, 0.52),
]


func _ready() -> void:
	var grad := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in STOPS:
		offsets.append(stop.x)
		colors.append(Color(COLOR, stop.y))
	grad.offsets = offsets
	grad.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 64
	tex.height = 256
	texture = tex
	centered = false
	scale = Vector2(WIDTH / 64.0, HEIGHT / 256.0)
	global_position = Vector2(global_position.x, TOP_Y)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		global_position.x = cam.get_screen_center_position().x - WIDTH * 0.5
