class_name EnemyThrusterFlame
extends Sprite2D
## 敌方推进焰（BOSS/精英通用）：贴图=assets/common/thruster_flame.svg（灰度平根
## 锥焰，焰朝 +Y），颜色由节点 modulate 染（各章自己的焰色），本脚本只负责
## 「像在烧」：多频正弦闪燃（慢呼吸×快颤，同 EyeGlow 配方）+ 随机体速度沿焰向
## 拉长。**原点=焰根（喷口）**：Sprite2D 必须 centered=false + offset=(-20,-6)
## （贴图 40×64，喷口=画布 (20,6)）——拉伸/摆动都从喷口长出来，枢轴在中心
## =提速时焰根从喷口里拔出来（玩家 ThrusterFlame 的 _draw 原点就在喷口，
## 同一账）。平射喷口节点转 ±90°，焰绕喷口摆。别再从 BOSS 脚本写本节点的
## modulate/scale，会跟脚本打架。boost（0..1）留给俯冲/冲刺等增推读法。

const STRETCH_MAX := 1.9      # 满速焰长倍数
const STRETCH_SPEED := 520.0  # 拉长参考速度 px/s

## 外部点火开关（默认开）。「平时熄火」的载体在场景里置 false（截击机：
## 仅俯冲突袭喷火——前摇即开、拉起即关）。BOSS 脚本只准写这个开关和
## boost，modulate/scale 仍归本脚本。
@export var enabled := true:
	set(value):
		enabled = value
		visible = value

## 外部增推（如截击机俯冲）：0=巡航，1=满增推（额外拉长+提亮）。
var boost := 0.0

var _phase := randf() * TAU
var _base_scale := Vector2.ONE


func _ready() -> void:
	_base_scale = scale


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var t := Time.get_ticks_msec() / 1000.0
	# 慢呼吸 × 电气颤：纯静态亮度一眼假（同 EyeGlow/玩家焰配方）
	var flick := 0.86 + 0.14 * sin(t * 9.0 + _phase)
	flick *= 1.0 + 0.07 * sin(t * 37.0 + _phase * 1.6) + 0.05 * sin(t * 61.0 + 0.7)
	var speed := _body_speed()
	var stretch := 1.0 + (STRETCH_MAX - 1.0) * clampf(speed / STRETCH_SPEED, 0.0, 1.0)
	stretch += boost * 0.8
	scale = _base_scale * Vector2(1.0 + 0.05 * sin(t * 21.0 + _phase), flick * stretch)
	self_modulate.a = clampf(0.55 + 0.30 * flick + 0.15 * boost, 0.0, 1.0)


func _body_speed() -> float:
	var n: Node = get_parent()
	while n != null and not n is CharacterBody2D:
		n = n.get_parent()
	if n is CharacterBody2D:
		return n.velocity.length()
	return 0.0
