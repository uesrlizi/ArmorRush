class_name LegIK
extends Node2D
## 机甲双腿两骨 IK（骨架拆件：大腿/小腿/脚掌，轴点账正本在 tools/split_player_legs.py）。
## 挂在 Visuals/LegRig（必须恒等变换：本节点局部系 = Visuals 局部系）。
## 目标：贴地滑行时身体下沉（Visuals.position.y，player.gd 写）、双腿屈膝、
## 脚掌钉在地面；直立与浮空回手绘站姿。
##
## 增量制：美术件自带手绘静止姿态（=最高位），骨节点 rotation 写的是「相对
## 静止姿态」的偏移量；crouch=0 时解算结果与手绘姿态一致（场景里骨默认
## rotation=0 = 编辑器所见即手绘站姿）。静止倾角作为常量收藏在这里。
##
## 关节轴点 = 场景节点，编辑器里可拖调，骨长按节点实际位置现算（拖完即生效）：
##   大腿骨长 L1 = Hip*/Knee*.position.length()
##   小腿骨长 L2 = Hip*/Knee*/Ankle*.position.length()
## 脚掌（Foot*）位置由锚点驱动：FootAnchor* 挂在 Visuals 下（跟着镜像换边），
## x 读锚点本地坐标；y 补回 Visuals 下蹲量 —— 锚点本地坐标恒定，脚掌世界钉地。

@export var bend_sign := 1.0 # 膝弯朝向（画布 +1=机头侧；美术膝盖朝前，翻转由 Visuals 镜像承担）

# 踝关节在脚掌锚点正上方的固定偏移（局部单位；画布 (0,-7.4)×0.5833333）。
const ANKLE_UP := Vector2(0.0, -4.3167)
# 手绘静止姿态角（度）：轴点账算出，改轴点后须用生成器重算这两行。
const THIGH_REST_DEG := -9.9262
const KNEE_REL_REST_DEG := 27.8687
# 脚掌对齐常量：Foot*.position = 脚掌锚点位 − 本值（静止时恰好 = 0）。
const SOLE_ALIGN := {
	"Far": Vector2(-11.55, 30.275),
	"Near": Vector2(-6.265, 30.275),
}

@onready var _visuals: Node2D = get_parent()
var _legs: Array[Dictionary] = []


func _ready() -> void:
	assert(position == Vector2.ZERO and rotation == 0.0,
			"LegRig 必须恒等挂在 Visuals 下（局部系=Visuals 局部系）")
	for side: String in ["Far", "Near"]:
		var thigh: Node2D = get_node("Hip" + side)
		var knee: Node2D = thigh.get_node("Knee" + side)
		_legs.append({
			"thigh": thigh,
			"knee": knee,
			"ankle": knee.get_node("Ankle" + side),
			"foot": get_node("Foot" + side),
			"anchor": get_node("../FootAnchor" + side), # 锚点挂 Visuals 下（LegRig 的兄弟）
			"sole_align": SOLE_ALIGN[side],
		})


func _physics_process(_delta: float) -> void:
	var crouch := _visuals.position.y
	for leg: Dictionary in _legs:
		var thigh: Node2D = leg.thigh
		var knee: Node2D = leg.knee
		var l1: float = knee.position.length()
		var l2: float = (leg.ankle as Marker2D).position.length()
		# 脚掌目标（Visuals 局部系）：x=锚点本地坐标（镜像免算）；y 补回下蹲量。
		var anchor: Marker2D = leg.anchor
		var sole := Vector2(anchor.position.x, anchor.position.y - crouch)
		var ankle_t := sole + ANKLE_UP
		var hip := thigh.position
		var to_ankle := ankle_t - hip
		var raw := to_ankle.length()
		if raw < 0.001:
			continue
		# 够不到=伸直（最高位）；过折=夹住。滑行下蹲只会让 d 从静止值变小。
		var d := clampf(raw, absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
		var u := to_ankle / raw
		var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
		var perp := Vector2(u.y, -u.x) * bend_sign
		var knee_pos := hip + u * a + perp * h
		# 绝对角（骨静止朝向=画布 +y 向下）→ 减静止角得增量写入。
		var thigh_abs := (knee_pos - hip).angle() - PI / 2.0
		var shin_abs := (ankle_t - knee_pos).angle() - PI / 2.0
		thigh.rotation = thigh_abs - deg_to_rad(THIGH_REST_DEG)
		knee.rotation = (shin_abs - thigh_abs) - deg_to_rad(KNEE_REL_REST_DEG)
		(leg.foot as Sprite2D).position = sole - (leg.sole_align as Vector2)
