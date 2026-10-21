extends Node
## 全局黑屏转场（autoload 名：Fade）——黑屏必须活在场景树顶层、跨重载存在：
## 场景内的转场层会随旧场景一起卸载，reload 的空档帧只剩 clear color，
## 屏幕会闪亮一帧（踩过）。任何场景借本层做"渐黑 → 停 → 切 → 渐亮"。
## 渐亮由切完场景的一方（新场景 _ready）调 reveal() 接棒。

const FADE_OUT_TIME := 0.5   # 渐黑时长（秒）：完整渐变
const FADE_HOLD_TIME := 0.25 # 全黑停留（秒）：黑透后略等一拍再切
const FADE_IN_TIME := 0.5    # 渐亮时长（秒）
const COLOR := Color(0.05, 0.05, 0.06)

var _rect: ColorRect
var _busy := false # 转场进行中：挡掉黑屏窗口内的连点/连按（重复转场会闪）


func _ready() -> void:
	# 结算定格（树暂停）时转场也要能走完。
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_rect = ColorRect.new()
	_rect.color = COLOR
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_rect.visible = false
	layer.add_child(_rect)


## 前半程：渐黑 → 全黑停留 → covered 回调（在这里切场景/重载）。
## covered 之后本层黑屏保持全盖，空档帧不会露出 clear color。
func transition(on_covered: Callable) -> void:
	if _busy:
		return
	_busy = true
	_rect.visible = true
	_rect.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, FADE_OUT_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_interval(FADE_HOLD_TIME)
	tw.tween_callback(func() -> void:
		on_covered.call()
		_busy = false
	)


## 后半程：从全黑渐亮（首启开机与重开回来同路，新场景 _ready 调）。
func reveal() -> void:
	_rect.visible = true
	_rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 0.0, FADE_IN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _rect.visible = false)
