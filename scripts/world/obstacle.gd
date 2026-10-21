class_name Obstacle
extends ScrollObject
## 障碍物：实体碰撞由子节点 StaticBody2D 提供（层 6 Obstacle）。
## 普通障碍真的能顶住玩家；子场景可用 one_way_collision 做只挡上方的平台（断桥）。
## 对子弹则是掩体之外的透明物：子弹不与障碍层碰撞。
## 加入 "obstacles" 组，供刷怪时做重叠检测（敌人刷到障碍上方）。

const PIER_LENGTH := 1600.0 # 桥墩超长、下端插到地块之下，由地形绘制层盖住

@export var floating := false        # 空中平台：出生在 float_top_* 决定的空中带
@export var float_top_min := 320.0   # 顶面允许的最低高度（世界 y）
@export var float_top_max := 420.0   # 顶面允许的最高高度（世界 y）
@export var pier_xs: PackedFloat32Array = PackedFloat32Array() # 桥墩局部 x（空 = 无墩）
@export var pier_half_width := 10.0
@export var pier_color := Color("3d3a32") # 桥墩用色按章走（默认=第一章锈雨废都）

var _piers: Array[Node] = [] # 画在 BridgePiers 层的桥墩节点（本对象回收时一并清掉）


func _ready() -> void:
	despawned.connect(func(_obj: ScrollObject) -> void: _clear_piers())
	super()


func on_spawned() -> void:
	super()
	despawn_margin = Balance.OBSTACLE_DESPAWN_MARGIN # 宽体平台：出画面后再留半屏余量
	add_to_group("obstacles")
	_rebuild_piers()


## 断桥桥墩：一根超长矩形插到地面之下，画在主场景 BridgePiers 层
## （层级在中景之后、地块之前，下端被地块绘制盖住，视觉即"立在地面上"）。
## 不需要按地表算高度，池化复用每次重建即可。
func _rebuild_piers() -> void:
	_clear_piers()
	if pier_xs.is_empty():
		return
	var layer := get_tree().get_first_node_in_group("bridge_piers") as Node2D
	if layer == null:
		return
	var deck_bottom := global_position.y + body_size.y * 0.5
	for px in pier_xs:
		var pier := Polygon2D.new()
		var hw := pier_half_width
		pier.polygon = PackedVector2Array([
			# 顶边向上叠进桥面背后 8px：抗锯齿缝隙，重叠部分被桥面盖住
			Vector2(-hw, -8.0), Vector2(hw, -8.0), Vector2(hw, PIER_LENGTH), Vector2(-hw, PIER_LENGTH),
		])
		pier.color = pier_color
		pier.position = Vector2(global_position.x + px, deck_bottom)
		layer.add_child(pier)
		_piers.append(pier)


func _clear_piers() -> void:
	for pier in _piers:
		pier.free() # 纯视觉节点，立即清掉，复用不留残影
	_piers.clear()
