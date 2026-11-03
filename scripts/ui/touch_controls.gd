class_name TouchControls
extends CanvasLayer
## 触控层总控：
## 1) 结算面板出现后（Main 调 arm_restart 开闸）点按屏幕任意处或按任意键/手柄键
##    重开（400ms 防抖，防止死亡瞬间误触；只受理一次）。结算后世界不冻结，
##    不再靠树暂停判定游戏结束；
## 2) 阵亡瞬间释放摇杆/按钮残留输入（按住型动作带进下一局会自己推进），触控件渐隐停用。
## 本节点 process_mode=ALWAYS；子控件保持 PAUSABLE。

signal restart_requested

## 结算面板出现后多少毫秒内的点按无效
const RESTART_DEBOUNCE_MS := 400
## 桌面临时调触控布局时改成 true（正常发布不用动，仅影响本层子控件的显隐）
const FORCE_TOUCH_VISIBLE := false

var _combat_on := false # 启动页待机时触控件藏着，进战斗才点亮
var _restart_armed := false # 结算面板已出：受理重开输入
var _armed_at_ms := 0


func _ready() -> void:
	_apply_touch_visibility(false) # 启动页待机先藏，进战斗 fade_in_controls 依次点亮
	_adopt_touch_holds()


## 章末黑场交接：上一关离场时还按着的触控指（RunState 暂存）由本层分发、
## 同款控件原地认领——按住跨关不脱手，移动/推进连续（见 virtual_joystick.gd /
## touch_button.gd 的 adopt_hold）。死亡重开路径离场前已 release() 清认领，
## 暂存自然为空；桌面无触摸也不产生暂存，此处空转。
func _adopt_touch_holds() -> void:
	if Engine.is_editor_hint():
		return
	var holds := RunState.take_touch_holds()
	if holds.is_empty():
		return
	for child in get_children():
		if child.has_method("adopt_hold"):
			child.call("adopt_hold", holds)


## 触控输入件只在移动端显示；桌面只保留结算后的任意键/点屏重开。
func _apply_touch_visibility(interactive: bool) -> void:
	var show_touch := FORCE_TOUCH_VISIBLE or Platforms.is_mobile()
	for child in get_children():
		if child.has_method("release"): # 摇杆 + 按钮
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


## 死亡演出：先放掉残留按住，再把触控 UI 整体渐隐并停用——机体失控，操控件跟着熄掉；
## 渐隐落定必须 visible=false + DISABLED 双保险：隐藏的控件仍收 _input，活着的
## 触控件会先认领触摸、把"点屏重开"吃掉（当年全屏开火区实测踩过，该区已移除）。
func fade_out_controls() -> void:
	if not _combat_on:
		return
	_combat_on = false
	for child in get_children():
		if child.has_method("release"):
			child.call("release")
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


## 结算面板出现（Main 调）：开始受理重开输入，防抖从此刻起算。
func arm_restart() -> void:
	_restart_armed = true
	_armed_at_ms = Time.get_ticks_msec()


## 结算后点屏/任意键/鼠标/手柄键重开，同权同防抖；只受理一次（转场黑屏期间
## 再按不重复触发）。未开闸时一律不管（战斗输入走各自的动作映射）。
func _input(event: InputEvent) -> void:
	if not _restart_armed or Time.get_ticks_msec() - _armed_at_ms < RESTART_DEBOUNCE_MS:
		return
	var touch := event as InputEventScreenTouch
	if (touch != null and touch.pressed) or _is_any_press(event):
		_restart_armed = false
		restart_requested.emit()


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
