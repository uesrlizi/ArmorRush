class_name TitleScreen
extends CanvasLayer
## 启动页提示层（小恐龙式待机）：机甲站桩空场，本层只挂一行开始提示。
## 分设备文案：移动端=触屏，桌面=点击屏幕或任意键。确认后淡出上浮并自毁。
## 判定走 _input 原始事件（键盘/鼠标/手柄/触摸任意一个），与游戏动作映射解耦。

signal accepted

const ARM_DELAY_MS := 400   # 进场景后多少 ms 内忽略输入（防残留按住的手指/按键误触）
const ENTER_TIME := 0.5     # 提示入场淡入时长（秒）
const EXIT_TIME := 0.25     # 确认后退场时长（秒）
const BREATHE_PERIOD := 1.5 # 呼吸闪烁周期（秒）
const BREATHE_MIN := 0.45   # 呼吸 alpha 下限
const EXIT_RISE := 14.0     # 退场上浮量（px）

@onready var _prompt: Label = $Root/Prompt

var _clock := 0.0
var _armed_at := 0
var _done := false
var _base_y := 0.0


func _ready() -> void:
	# 中文提示用系统字体兜底（内置默认字体没有 CJK 字形），同 hud.gd。
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial",
	])
	_prompt.add_theme_font_override("font", font)
	_prompt.text = "触摸屏幕开始" if OS.has_feature("mobile") else "点击屏幕或按任意键开始"
	_prompt.modulate.a = 0.0
	_base_y = _prompt.position.y
	_armed_at = Time.get_ticks_msec() + ARM_DELAY_MS


func _process(delta: float) -> void:
	_clock += delta
	if not _done:
		# 入场淡入 × 呼吸：呼吸从谷底起相（sin -90°），与 0 起步的入场平滑衔接。
		var enter := clampf(_clock / ENTER_TIME, 0.0, 1.0)
		var breathe := BREATHE_MIN + (1.0 - BREATHE_MIN) \
				* (0.5 + 0.5 * sin(_clock * TAU / BREATHE_PERIOD - PI * 0.5))
		_prompt.modulate.a = enter * breathe
	else:
		var p := clampf(_clock / EXIT_TIME, 0.0, 1.0)
		_prompt.modulate.a = 1.0 - p
		_prompt.position.y = _base_y - EXIT_RISE * p
		if p >= 1.0:
			queue_free()


## 进战斗时由 Main 调（含重开跳过启动页的路径）。
func dismiss() -> void:
	if _done:
		return
	_done = true
	_clock = 0.0


func _input(event: InputEvent) -> void:
	if _done or Time.get_ticks_msec() < _armed_at:
		return
	if _is_accept(event):
		dismiss()
		accepted.emit()


func _is_accept(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.is_echo()
	var mb := event as InputEventMouseButton
	if mb != null:
		return mb.pressed
	var touch := event as InputEventScreenTouch
	if touch != null:
		return touch.pressed
	var pad := event as InputEventJoypadButton
	if pad != null:
		return pad.pressed
	return false
