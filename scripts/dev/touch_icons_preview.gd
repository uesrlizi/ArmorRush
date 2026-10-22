extends Node2D
## 触控图标预览（临时）：三个图标按钮 + 摇杆，引擎内真实渲染各拍一张自退。
## 桌面预览专用的 @tool 组件直摆（游戏内触控件仅移动端显示，桌面看不到）。
## godot --path . res://scenes/previews/touch_icons_preview.tscn
## 跑前后 tasklist 清残留 godot 进程（见 readability_preview.gd 同款守则）。

const SHOT_DIR := "res://autotest_shots"

@onready var _buttons: Array[TouchButton] = [%Fire, %Jump, %Melee]
@onready var _joystick: TouchJoystick = %Joystick


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_shoot()


func _shoot() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := SHOT_DIR + "/touch_icons_preview.png"
	var err := img.save_png(path)
	printerr("shot %s err=%d" % [path, err])
	get_tree().quit(0)
