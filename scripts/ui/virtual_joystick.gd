@tool
class_name TouchJoystick
extends Control
## 左下角固定位置的单轴虚拟摇杆：底座（横向圆角矩形轨道）钉死不动，
## 只看手指当前按下的位置相对轨道中心的左右侧决定方向，输入归一化为 ±1，
## 不看拖动量。通过 Input.action_press 映射到 move_left / move_right。
## @tool：编辑器里也画轨道方便摆位；输入/动作逻辑在编辑器中一律跳过。

const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const DEADZONE_PX := 12.0

## 轨道（横向圆角矩形）尺寸
@export var track_size := Vector2(440.0, 140.0):
	set(v):
		track_size = v
		queue_redraw()
@export var knob_radius := 52.0:
	set(v):
		knob_radius = v
		queue_redraw()
## 轨道中心在控件内边距（从左/下边缘往里缩）
@export var edge_margin := 80.0:
	set(v):
		edge_margin = v
		queue_redraw()
## 手指落在轨道矩形外扩这么多像素内也算按中摇杆
@export var grab_margin := 70.0
## 底座颜色
@export var track_color := Color(0.1, 0.13, 0.17, 0.25):
	set(v):
		track_color = v
		queue_redraw()
@export var knob_color := Color(0.85, 0.82, 0.72, 0.55):
	set(v):
		knob_color = v
		queue_redraw()

var _touch_id := -1
var _last_touch_pos := Vector2.ZERO # 按住指的最后视口坐标（跨关交接认领用）
var _knob_dx := 0.0 # 圆钮相对轨道中心的横向偏移（表现用）


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func center() -> Vector2:
	return Vector2(track_size.x * 0.5 + edge_margin,
			size.y - track_size.y * 0.5 - edge_margin)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		var pos := _to_local(touch.position)
		if touch.pressed:
			var viewport := get_viewport()
			if _touch_id == -1 and not viewport.is_input_handled() \
					and _grab_area().has_point(pos):
				_touch_id = touch.index
				_last_touch_pos = touch.position
				viewport.set_input_as_handled()
				_apply_axis(pos.x - center().x) # 按下即按位置定方向，不等拖动
				queue_redraw()
		elif touch.index == _touch_id:
			_release()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _touch_id:
		_last_touch_pos = drag.position
		_apply_axis(_to_local(drag.position).x - center().x)


func _exit_tree() -> void:
	# 章末黑场交接时指还按着：把（动作名/索引/最后坐标）暂存给 RunState，
	# 新场景的摇杆原地认领——移动跨关不脱手（死亡路径先经 release() 清了
	# 认领，这里自然是空的）。编辑器布局预览不参与。
	if _touch_id != -1 and not Engine.is_editor_hint():
		RunState.stash_touch_hold("move", _touch_id, _last_touch_pos)
	_release()


## 章末交接认领（TouchControls._ready 分发）：接住上一关离场时还按着的那根指
## （共享触控场景=坐标一一对应），按原位重判方向并压回动作。认领产生的按下
## 边沿落在场景装载帧，玩家首个物理帧读不到 just_pressed（帧号已过），
## 不会误发边沿动作；移动是按住型，压回即续走。
func adopt_hold(holds: Array[Dictionary]) -> void:
	if Engine.is_editor_hint() or _touch_id != -1:
		return
	for hold in holds:
		if hold.action != "move":
			continue
		var pos := _to_local(hold.position as Vector2)
		if _grab_area().has_point(pos):
			_touch_id = hold.index
			_last_touch_pos = hold.position as Vector2
			_apply_axis(pos.x - center().x)
			break


func _grab_area() -> Rect2:
	return Rect2(center() - track_size * 0.5 - Vector2(grab_margin, grab_margin),
			track_size + Vector2(grab_margin, grab_margin) * 2.0)


## Control 没有 to_local，用自身全局变换的逆把视口坐标转成本地坐标。
func _to_local(viewport_pos: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * viewport_pos


## dx：手指相对固定轨道中心的横向偏移，正=右。只要方向不要长度：过死区即满量。
func _apply_axis(dx: float) -> void:
	var travel := track_size.x * 0.5 - knob_radius
	if absf(dx) <= DEADZONE_PX:
		Input.action_release(MOVE_LEFT)
		Input.action_release(MOVE_RIGHT)
		_knob_dx = 0.0
	elif dx > 0.0:
		Input.action_release(MOVE_LEFT)
		Input.action_press(MOVE_RIGHT, 1.0)
		_knob_dx = travel
	else:
		Input.action_release(MOVE_RIGHT)
		Input.action_press(MOVE_LEFT, 1.0)
		_knob_dx = -travel
	queue_redraw()


## 阵亡时由 TouchControls 调用：清掉残留的按住状态与动作（别带进下一局）。
func release() -> void:
	_release()


func _release() -> void:
	if _touch_id == -1:
		return # 没认领过触摸就绝不动动作状态：桌面按住的键盘/手柄键是物理态，
		       # 离场时无条件 release 会把"按住的 D"拦腰清掉，且物理键不会再产生
		       # 按下边沿（echo 不算）——只能松开重按，跨关衔接断掉的元凶
	_touch_id = -1
	_knob_dx = 0.0
	# 编辑器 --import 上下文没有项目 InputMap（布局恢复会实例化再销毁本节点），
	# 没有该动作时静默跳过。
	if InputMap.has_action(MOVE_LEFT):
		Input.action_release(MOVE_LEFT)
		Input.action_release(MOVE_RIGHT)
	queue_redraw()


func _draw() -> void:
	var c := center()
	var track := StyleBoxFlat.new()
	track.bg_color = track_color
	track.set_corner_radius_all(int(track_size.y * 0.5))
	track.set_border_width_all(3)
	track.border_color = track_color.lightened(0.1)
	track.draw(get_canvas_item(), Rect2(c - track_size * 0.5, track_size))
	draw_circle(c + Vector2(_knob_dx, 0.0), knob_radius, knob_color)
	# 轨道两端 ‹ › 方向提示（解释"按这里=左右移动"）；圆钮行程到不了端头，不互抢。
	var hint := knob_color
	hint.a = 0.45
	for side: float in [-1.0, 1.0]:
		var x: float = c.x + side * (track_size.x * 0.5 - 34.0)
		draw_polyline(PackedVector2Array([
			Vector2(x, c.y - 15.0), Vector2(x + side * 9.0, c.y), Vector2(x, c.y + 15.0),
		]), hint, 7.0, true)
