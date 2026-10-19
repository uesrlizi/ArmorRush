class_name TouchControls
extends CanvasLayer
## 触控层总控：
## 1) 游戏结束（树暂停）后点按屏幕任意处重开（400ms 防抖，防止死亡瞬间误触）；
## 2) 暂停瞬间释放摇杆/按钮残留输入并关掉自动前进（按着摇杆死掉不能卡动作）；
## 3) 双击"右"开启自动前进——键盘双击 D/→，触控双击摇杆轨道右半；
##    之后任何移动操作（A/D/←/→ 键、摇杆按下）立即关闭。
## 本节点 process_mode=ALWAYS，暂停时仍能收输入；子控件保持 PAUSABLE。

signal restart_requested

## 游戏结束后多少毫秒内的点按无效
const RESTART_DEBOUNCE_MS := 400
## 判定双击的两次"右"间隔上限（毫秒）
const DOUBLE_TAP_MS := 280

var _paused_at_ms := 0
## 桌面临时调触控布局时改成 true（正常发布不用动，仅影响本层子控件的显隐）
const FORCE_TOUCH_VISIBLE := false

var _was_paused := false
var _auto_forward := false
var _combat_on := false # 启动页待机时触控件藏着，进战斗才点亮
var _last_right_tap_ms := -999999999 # 上一次"右"手势（键盘或摇杆）的时刻

@onready var _joystick: TouchJoystick = $Joystick
@onready var _auto_label: Label = $AutoLabel


func _ready() -> void:
	_joystick.move_started.connect(_on_move_started)
	_joystick.tapped.connect(_on_joystick_tapped)
	# 中文标签用打包的思源黑体子集（见 ui_font.gd）。
	_auto_label.add_theme_font_override("font", UIFont.cjk())
	_auto_label.visible = false
	_apply_touch_visibility(false) # 启动页待机先藏，进战斗 fade_in_controls 依次点亮


## 触控输入件只在移动端显示；桌面保留键盘双击自动前进、点屏重开与自动前进标签。
func _apply_touch_visibility(interactive: bool) -> void:
	var show_touch := FORCE_TOUCH_VISIBLE or Platforms.is_mobile()
	for child in get_children():
		if child.has_method("release"): # 摇杆 + 按钮（AutoLabel 没有此方法，不参与）
			child.visible = show_touch and interactive
			# 不参与输入时彻底停掉回调（隐藏的 Control 仍会收 _input）。
			child.process_mode = Node.PROCESS_MODE_INHERIT \
					if (show_touch and interactive) else Node.PROCESS_MODE_DISABLED


## 进战斗：触控件恢复可交互并依次渐显（桌面无触控件，只翻标记）。
func fade_in_controls() -> void:
	if _combat_on:
		return
	_combat_on = true
	_apply_touch_visibility(true)
	if not (FORCE_TOUCH_VISIBLE or Platforms.is_mobile()):
		return
	var delay := 0.0
	for child in get_children():
		if not child.has_method("release"):
			continue
		child.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(child, "modulate:a", 1.0, 0.35) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += 0.07


## 死亡演出：触控 UI 整体渐隐并停用——机体失控，操控件跟着熄掉；
## 全屏开火区若还活着会先认领触摸，把"点屏重开"吃掉（实测踩过），
## 渐隐落定必须 visible=false + DISABLED 双保险。
func fade_out_controls() -> void:
	if not _combat_on:
		return
	_combat_on = false
	if not (FORCE_TOUCH_VISIBLE or Platforms.is_mobile()):
		return
	var tw := create_tween().set_parallel(true)
	for child in get_children():
		if not child.has_method("release"):
			continue
		tw.tween_property(child, "modulate:a", 0.0, 0.3) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_retire_touch_controls)


## 渐隐落定：隐藏的 Control 仍会收 _input，须禁用处理才彻底闭嘴。
func _retire_touch_controls() -> void:
	for child in get_children():
		if child.has_method("release"):
			child.visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused and not _was_paused:
		_paused_at_ms = Time.get_ticks_msec()
		for child in get_children():
			if child.has_method("release"):
				child.call("release")
		_set_auto(false)
	_was_paused = paused
	# 自动前进：每帧重申动作（真实按键的释放会把整个动作状态清掉）。
	if _auto_forward and not paused:
		Input.action_press("move_right", 1.0)


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and get_tree().paused \
				and Time.get_ticks_msec() - _paused_at_ms >= RESTART_DEBOUNCE_MS:
			restart_requested.emit()
		return
	# 游戏结束（树暂停）后任意键/鼠标/手柄键重开，与点屏同权（防抖同源）；
	# 暂停期间不走双击右等战斗输入。
	if get_tree().paused:
		if Time.get_ticks_msec() - _paused_at_ms >= RESTART_DEBOUNCE_MS \
				and _is_any_press(event):
			restart_requested.emit()
		return
	# 键盘侧的双击右与关自动（触控侧走摇杆信号）。
	var key := event as InputEventKey
	if key != null and key.pressed and not key.is_echo():
		var pk := key.physical_keycode
		var is_right := pk == KEY_D or pk == KEY_RIGHT
		var is_move := is_right or pk == KEY_A or pk == KEY_LEFT
		if is_move:
			if _auto_forward:
				_set_auto(false) # 任何移动操作先关自动
				_last_right_tap_ms = -999999999 # 关自动的这次按下不参与双击
			elif is_right:
				var now := Time.get_ticks_msec()
				if now - _last_right_tap_ms <= DOUBLE_TAP_MS:
					_last_right_tap_ms = -999999999
					_set_auto(true)
				else:
					_last_right_tap_ms = now


func _exit_tree() -> void:
	if _auto_forward:
		Input.action_release("move_right")


## 结算画面的"任意键重开"判定：键盘/鼠标/手柄键任一按下（与启动页同语义）。
func _is_any_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.is_echo()
	var mb := event as InputEventMouseButton
	if mb != null:
		return mb.pressed
	var pad := event as InputEventJoypadButton
	if pad != null:
		return pad.pressed
	return false


func _on_move_started() -> void:
	# 同步信号，先于摇杆压轴执行：关掉自动前进（释放 move_right）再让摇杆接管。
	if _auto_forward:
		_set_auto(false)
		_last_right_tap_ms = -999999999


func _on_joystick_tapped(direction: float) -> void:
	if direction <= 0.0:
		_last_right_tap_ms = -999999999 # 只有连续两次"右"才算
		return
	if _auto_forward:
		return
	var now := Time.get_ticks_msec()
	if now - _last_right_tap_ms <= DOUBLE_TAP_MS:
		_last_right_tap_ms = -999999999
		_set_auto(true)
	else:
		_last_right_tap_ms = now


func _set_auto(on: bool) -> void:
	_auto_forward = on
	_auto_label.visible = on
	if not on:
		Input.action_release("move_right")
