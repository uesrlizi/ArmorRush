class_name BossBar
extends Control
## BOSS 顶部血条（HUD 空间，平涂无底板）：实心段 + 掉血虚影段，
## 语汇与世界空间 OverheadBar 一致（同色同虚影算法）。

var fill_color := Color(1.0, 0.32, 0.25) # 填充色：血条=阵营红，冲击条=黄（构造时取 Balance）
var ratio := 1.0

var _ghost := 1.0


func _init() -> void:
	fill_color = Balance.HP_BAR_ENEMY_COLOR # autoload 在 _init 里取值，解析期不依赖


func set_ratio(r: float) -> void:
	ratio = clampf(r, 0.0, 1.0)
	if ratio > _ghost:
		_ghost = ratio
	queue_redraw()


func reset() -> void:
	ratio = 1.0
	_ghost = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if ratio < _ghost:
		_ghost = lerpf(_ghost, ratio,
				1.0 - exp(-Balance.HP_BAR_GHOST_DAMP * delta))
		queue_redraw()


func _draw() -> void:
	var w := size.x
	if ratio < _ghost:
		draw_rect(Rect2(w * ratio, 0.0, w * (_ghost - ratio), size.y),
				Balance.HP_BAR_GHOST_COLOR)
	if ratio > 0.0:
		draw_rect(Rect2(0.0, 0.0, w * ratio, size.y), fill_color)
