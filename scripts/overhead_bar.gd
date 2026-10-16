class_name OverheadBar
extends Node2D
## 头顶血条/气槽：世界空间，挂在玩家与敌人本体下的空节点，每帧重绘。
## 玩家 = 血条 + 气槽双条横排头顶（常显）；敌人 = 单血条，受损后才显示
## （满血不挂牌，免得跑酷画面里一串满条；开关见 Balance.HP_BAR_DAMAGED_ONLY）。
## 掉血虚影 = 插值型：虚影右缘以指数阻尼连续趋近当前血量，无停顿；
## 回血/池化重置（比例回升）时瞬移归位，不倒放。
## 全部可调参数在 Balance 的 HP_BAR_* 段（用户直接手调 Balance）。

var _ghost := 1.0 # 虚影右缘（血量比例 0..1，≥当前血量比例）


func _process(delta: float) -> void:
	var ratio := _hp_ratio()
	if ratio > _ghost:
		_ghost = ratio # 回满/回血/池化重置：瞬移，不倒放虚影
	elif ratio < _ghost:
		# 指数阻尼插值：先快后慢地缩到当前血量，帧率无关。
		_ghost = lerpf(_ghost, ratio, 1.0 - exp(-Balance.HP_BAR_GHOST_DAMP * delta))
	queue_redraw()


func _draw() -> void:
	var player := get_parent() as Player
	if player != null:
		_draw_player(player)
		return
	var enemy := get_parent() as Enemy
	if enemy != null:
		_draw_enemy(enemy)


func _hp_ratio() -> float:
	var player := get_parent() as Player
	if player != null:
		return clampf(float(player.hp) / float(player.max_hp), 0.0, 1.0)
	var enemy := get_parent() as Enemy
	if enemy != null:
		return enemy.hp_ratio()
	return _ghost


func _draw_player(player: Player) -> void:
	# 启动页待机空场不挂牌（modulate 淡入由 Player.play_ignition 管）。
	if player.is_dead() or not player.input_enabled:
		return
	var w := Balance.HP_BAR_PLAYER_WIDTH
	var y := Balance.HP_BAR_PLAYER_OFFSET_Y
	_bar(-w * 0.5, y, w, Balance.HP_BAR_HEIGHT, clampf(float(player.hp) / float(player.max_hp), 0.0, 1.0),
			Balance.HP_BAR_PLAYER_COLOR)
	_bar(-w * 0.5, y + Balance.HP_BAR_HEIGHT + Balance.BOOST_BAR_GAP, w, Balance.BOOST_BAR_HEIGHT,
			clampf(player.boost / Balance.BOOST_CAPACITY, 0.0, 1.0), Balance.HP_BAR_BOOST_COLOR,
			false) # 气槽不掉血，无虚影


func _draw_enemy(enemy: Enemy) -> void:
	if Balance.HP_BAR_DAMAGED_ONLY and not enemy.is_damaged():
		return
	var w := clampf(enemy.body_size.x * 0.9,
			Balance.HP_BAR_ENEMY_WIDTH_MIN, Balance.HP_BAR_ENEMY_WIDTH_MAX)
	var y := -enemy.body_size.y * 0.5 - Balance.HP_BAR_ENEMY_MARGIN_Y
	_bar(-w * 0.5, y, w, Balance.HP_BAR_HEIGHT, enemy.hp_ratio(), Balance.HP_BAR_ENEMY_COLOR)


## 平涂血条（无底板）：实心段 + 掉血虚影段（从当前血量到虚影右缘）。
## 锚点为条左上角。
func _bar(x: float, y: float, w: float, h: float, ratio: float, fill: Color, ghost := true) -> void:
	if ghost and _ghost > ratio:
		draw_rect(Rect2(x + w * ratio, y, w * (_ghost - ratio), h), Balance.HP_BAR_GHOST_COLOR)
	draw_rect(Rect2(x, y, w * ratio, h), fill)
