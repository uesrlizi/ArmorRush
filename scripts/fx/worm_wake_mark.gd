extends Sprite2D
## 航迹雪痕（冰钻潜行沿途留在地表的亮色扰动痕）：入树即自淡，淡完自清。
## 留在世界原地（残迹类=全局空间），不跟头走。
@export var life := 1.1


func _ready() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
