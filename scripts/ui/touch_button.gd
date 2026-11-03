@tool
class_name TouchButton
extends Control
## 圆形触控按钮：按住期间把动作压进 Input（jump 要按住=推进，melee 取按下瞬间）。
## 优先级靠输入系统原生机制：认领触摸时 set_input_as_handled()，
## 排在后面的控件见 is_input_handled() 就放弃。
## （开火全自动后，射击键与铺满屏幕的"空白处开火"区已移除，2026-11-03。）
## @tool：编辑器里也画按钮方便摆位；输入/动作逻辑在编辑器中一律跳过。

@export var action := "jump"
@export var label := "":
	set(v):
		label = v
		queue_redraw()
## 图标（设置后取代文字标签绘制；240 画布 SVG 按 120 显示 = 2px/单位密度档）
@export var icon: Texture2D:
	set(v):
		icon = v
		queue_redraw()
@export var icon_size := 120.0:
	set(v):
		icon_size = v
		queue_redraw()
@export var radius := 90.0:
	set(v):
		radius = v
		queue_redraw()
@export var base_color := Color(0.1, 0.13, 0.17, 0.25):
	set(v):
		base_color = v
		queue_redraw()
@export var pressed_color := Color(1.0, 0.58, 0.18, 0.45):
	set(v):
		pressed_color = v
		queue_redraw()
@export var font_size := 30:
	set(v):
		font_size = v
		queue_redraw()
## 按下时手机震动毫秒数（仅 Android/iOS 生效，0 关闭）
@export var haptic_ms := 20

var _pressed_id := -1
var _last_press_pos := Vector2.ZERO # 按住指按下时的视口坐标（跨关交接认领用）
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 中文按钮文字用打包的思源黑体子集（见 ui_font.gd）。
	_font = UIFont.cjk()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	var pos := get_global_transform().affine_inverse() * touch.position
	if touch.pressed:
		var viewport := get_viewport()
		if _pressed_id == -1 and not viewport.is_input_handled() and _hit(pos):
			_pressed_id = touch.index
			_last_press_pos = touch.position
			viewport.set_input_as_handled()
			Input.action_press(action, 1.0)
			if haptic_ms > 0 and (OS.has_feature("android") or OS.has_feature("ios")):
				Input.vibrate_handheld(haptic_ms)
			queue_redraw()
	elif touch.index == _pressed_id:
		_release()


func _exit_tree() -> void:
	# 章末黑场交接时指还按着：暂存给 RunState，新场景的同款按钮原地认领——
	# 按住跨关不脱手（死亡路径先经 release() 清了认领，这里自然是空的）。
	if _pressed_id != -1 and not Engine.is_editor_hint():
		RunState.stash_touch_hold(action, _pressed_id, _last_press_pos)
	_release()


## 章末交接认领（TouchControls._ready 分发）：接住上一关离场时还按着的那根指，
## 只认领不压回动作——跳/斩是边沿型动作，认领时 action_press 的边沿可能落在
## 玩家首个物理帧里（实测场景装载发生在物理步内）→ 落地即跳/即斩；键盘按住
## 空格/S 跨关同样不会自动触发（要新边沿），语义一致。玩家落地后想跳/斩
## 抬手重按一下即可（新按下=新认领=新边沿）。
func adopt_hold(holds: Array[Dictionary]) -> void:
	if Engine.is_editor_hint() or _pressed_id != -1:
		return
	for hold in holds:
		if hold.action != action:
			continue
		var pos: Vector2 = get_global_transform().affine_inverse() \
				* (hold.position as Vector2)
		if _hit(pos):
			_pressed_id = hold.index
			_last_press_pos = hold.position as Vector2
			queue_redraw()
			break


func _hit(pos: Vector2) -> bool:
	return pos.distance_to(center()) <= radius


func center() -> Vector2:
	return size * 0.5


## 阵亡时由 TouchControls 调用：清掉残留的按住状态与动作（别带进下一局）。
func release() -> void:
	_release()


func _release() -> void:
	if _pressed_id == -1:
		return # 没认领过触摸就绝不动动作状态（见摇杆同款注释：别清掉物理按键的按住态）
	_pressed_id = -1
	Input.action_release(action)
	queue_redraw()


func _draw() -> void:
	var c := center()
	var pressed := _pressed_id != -1
	draw_circle(c, radius, pressed_color if pressed else base_color)
	draw_arc(c, radius, 0.0, TAU, 48,
			(pressed_color if pressed else base_color).lightened(0.15), 3.0, true)
	if icon != null:
		# 按下微缩+提亮，给指尖一个"吃进去了"的回弹；平时降一档透明度融进底色。
		var s := icon_size * (0.94 if pressed else 1.0)
		draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)),
				false, Color(1.0, 1.0, 1.0, 1.0 if pressed else 0.92))
	elif not label.is_empty():
		var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(_font, c - Vector2(text_size.x * 0.5, -text_size.y * 0.35),
				label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
				Color(0.92, 0.9, 0.82, 0.85))
