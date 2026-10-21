@tool
class_name TouchButton
extends Control
## 圆形触控按钮：按住期间把动作压进 Input（fire/jump 要按住，melee 取按下瞬间）。
## use_full_rect=true 时命中区变成整个控件矩形、不绘制圆底——用作铺满屏幕的
## "空白处开火"区（放在触控层的第一个子节点 = 输入优先级最低）。
## 优先级靠输入系统原生机制：认领触摸时 set_input_as_handled()，
## 排在后面的控件（含全屏火区）见 is_input_handled() 就放弃。
## @tool：编辑器里也画按钮方便摆位；输入/动作逻辑在编辑器中一律跳过。

@export var action := "fire"
@export var label := "FIRE":
	set(v):
		label = v
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
## 命中区=整个控件矩形，且不绘制圆底（全屏空白开火区用）
@export var use_full_rect := false:
	set(v):
		use_full_rect = v
		queue_redraw()

var _pressed_id := -1
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
			viewport.set_input_as_handled()
			Input.action_press(action, 1.0)
			if haptic_ms > 0 and (OS.has_feature("android") or OS.has_feature("ios")):
				Input.vibrate_handheld(haptic_ms)
			queue_redraw()
	elif touch.index == _pressed_id:
		_release()


func _hit(pos: Vector2) -> bool:
	if use_full_rect:
		return get_rect().has_point(pos)
	return pos.distance_to(center()) <= radius


func center() -> Vector2:
	return size * 0.5


## 暂停/重开时由 TouchControls 调用：清掉残留的按住状态与动作。
func release() -> void:
	_release()


func _release() -> void:
	_pressed_id = -1
	Input.action_release(action)
	queue_redraw()


func _draw() -> void:
	if use_full_rect:
		# 全屏火区平时隐形；编辑器里画个淡框让摆放/选中可见。
		if Engine.is_editor_hint():
			draw_rect(get_rect(), Color(1.0, 0.58, 0.18, 0.06), true)
			draw_rect(get_rect().grow(-2), Color(1.0, 0.58, 0.18, 0.35), false, 2.0)
		return
	var c := center()
	var pressed := _pressed_id != -1
	draw_circle(c, radius, pressed_color if pressed else base_color)
	draw_arc(c, radius, 0.0, TAU, 48,
			(pressed_color if pressed else base_color).lightened(0.15), 3.0, true)
	var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(_font, c - Vector2(text_size.x * 0.5, -text_size.y * 0.35),
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size,
			Color(0.92, 0.9, 0.82, 0.85))
