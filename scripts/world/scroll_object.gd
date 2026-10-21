class_name ScrollObject
extends CharacterBody2D
## 滚动物基类：敌人、障碍等统一从它继承。
## 本质：世界是静止的，"滚动"由镜头跟随玩家实现。
## 本类只负责生命周期——出生定位、被甩到屏幕左侧外时请求回收（进对象池）。
## 用 CharacterBody2D 是给敌人让路：敌人要走动/被击退，move_and_slide 提供
## 地形碰撞与被阻挡的自然约束；障碍不调 move_and_slide，行为等同静态体。

signal despawned(obj: ScrollObject)
signal killed(points: int)

@export var score_value := 0        # 被击毁时的得分（障碍为 0）
@export var feet_offset := 40.0     # 原点到脚底的距离，出生时用来贴地
@export var despawn_margin := 200.0 # 越过屏幕左缘多少像素后回收
@export var body_size := Vector2.ZERO # 本体碰撞盒尺寸（刷怪重叠检测用）

var _despawn_requested := false


func _ready() -> void:
	add_to_group("scroll_objects")
	on_spawned()


func _physics_process(_delta: float) -> void:
	if is_past_left_edge():
		request_despawn()


## 出生 / 池化复用时的状态重置，子类必须先 super() 再写自己的逻辑。
func on_spawned() -> void:
	_despawn_requested = false


## 是否已被镜头甩到屏幕左侧之外。
## 按物件右缘（原点 + 半宽）判定：宽体障碍（如 720 宽断桥）原点过缘时
## 右半截还留在画面里，按原点回收会当着玩家的面消失。
func is_past_left_edge() -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var half_width := get_viewport_rect().size.x * 0.5
	var left_edge := cam.get_screen_center_position().x - half_width
	var right_edge := global_position.x + body_size.x * 0.5
	return right_edge < left_edge - despawn_margin


## 请求回收（Spawner 监听 despawned 信号后归还对象池）。
func request_despawn() -> void:
	if _despawn_requested:
		return
	_despawn_requested = true
	despawned.emit(self)
