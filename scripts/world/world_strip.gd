class_name WorldStrip
extends Sprite2D
## 无限横向平铺条（地面 / 远景专用）。
## 用 region + 纹理重复实现平铺，纹理在世界中的相位 = scroll_scale × 镜头位移：
##   scroll_scale = 0    → 固定在世界坐标（地面），随镜头滚动
##   scroll_scale = 0.85 → 以 15% 镜头速度相对屏幕漂移（远山视差）
##   scroll_scale = 1    → 钉死在屏幕上（背景板）
## region 尺寸必须等于纹理原尺寸（重复采样在纵轴同样生效，高度多了会纵向重复）。

@export var scroll_scale := 0.0
@export var tile_width := 256.0


func _ready() -> void:
	# 本类每渲染帧向镜头钉位（与 Camera2D / MuzzleFlash 同配方，必须关插值）：
	# 插值开着时，相位回绕瞬间的 +tile_width 整段跳变会被当成待补间运动，
	# 摊到后续渲染帧上滑半程——高刷屏上表现为背景花纹偶发一帧错位闪烁。
	# 关掉后写入当帧即所见，跳变恰为一整个花纹周期，像素级无缝。
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position().x
	var phase := fposmod((scroll_scale - 1.0) * center, tile_width)
	global_position.x = center + phase
