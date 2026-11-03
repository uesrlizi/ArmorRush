class_name BossBar
extends Control
## BOSS 顶部血条（HUD 空间，平涂无底板）：实心段 + 掉血虚影段，
## 语汇与世界空间 OverheadBar 一致（同色同虚影算法）。
## 冲击条（失衡条）用法：center_fill=true 从中心向两边填充，且两层赋值翻转——
## fill(白)=实值（真实冲击，瞬时），ghost(黄)=虚值（指数跟随值）仍压在上层：
## 升程黄没追上时白尖端从两端露头，衰减/排程黄瞬时跟住线性实值边（匀速读数）。

var fill_color := Color(1.0, 0.32, 0.25) # 填充色：血条=阵营红，冲击条=白（构造时取 BalanceGlobal）
var ghost_color := Color(1.0, 1.0, 1.0)  # 虚影色：血条=满白，冲击条=黄（构造时取 BalanceGlobal）
var center_fill := false                 # true=从中心向两边填充+赋值翻转（失衡条），false=左锚定（血条）
var ratio := 1.0

var _ghost := 1.0


func _init() -> void:
	fill_color = BalanceGlobal.HP_BAR_ENEMY_COLOR # autoload 在 _init 里取值，解析期不依赖
	ghost_color = BalanceGlobal.HP_BAR_GHOST_COLOR


func set_ratio(r: float) -> void:
	ratio = clampf(r, 0.0, 1.0)
	# 经典虚影瞬时抬升（掉血虚影只滞后在下落向）；翻转模式（失衡条）的跟随
	# 全走 _process：升程要看出"虚值追实值"，不能在这里瞬跳
	if not center_fill and ratio > _ghost:
		_ghost = ratio
	queue_redraw()


func reset(v := 1.0) -> void:
	ratio = v
	_ghost = v
	queue_redraw()


func _process(delta: float) -> void:
	if center_fill:
		# 虚值(黄)是双向跟随器：升程指数追（追不上→白实值尖端领先），
		# 降程瞬时贴住（衰减/失衡排空的可视边=线性实值，匀速）
		if ratio > _ghost:
			_ghost = lerpf(_ghost, ratio,
					1.0 - exp(-BalanceGlobal.HP_BAR_GHOST_DAMP * delta))
		else:
			_ghost = ratio
		queue_redraw()
	elif ratio < _ghost:
		_ghost = lerpf(_ghost, ratio,
				1.0 - exp(-BalanceGlobal.HP_BAR_GHOST_DAMP * delta))
		queue_redraw()


func _draw() -> void:
	var w := size.x
	if center_fill:
		# 白=实值(0→ratio)先画在下，黄=虚值(0→_ghost)压在上层
		if ratio > 0.0:
			draw_rect(Rect2(w * (1.0 - ratio) * 0.5, 0.0, w * ratio, size.y), fill_color)
		if _ghost > 0.0:
			draw_rect(Rect2(w * (1.0 - _ghost) * 0.5, 0.0, w * _ghost, size.y), ghost_color)
		return
	if ratio < _ghost:
		draw_rect(Rect2(w * ratio, 0.0, w * (_ghost - ratio), size.y), ghost_color)
	if ratio > 0.0:
		draw_rect(Rect2(0.0, 0.0, w * ratio, size.y), fill_color)
