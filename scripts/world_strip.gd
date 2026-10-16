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


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position().x
	var phase := fposmod((scroll_scale - 1.0) * center, tile_width)
	global_position.x = center + phase
