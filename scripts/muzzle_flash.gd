class_name MuzzleFlash
extends Node2D
## 枪口焰（粒子版）：开火瞬间在枪口"炸"一下——主焰泪滴 + 白热芯 + 火花，
## 0.12s 一次性自灭。常驻节点（挂 Player/Enemy 的 Muzzle 下），开火方调用
## fire(射向角)：节点整体转向射向，主焰贴图长轴即弹道。
## top_level 脱离臂节点的镜像/俯仰（焰形永远按全局射向、不被镜像剪切）；
## 激活期由本脚本亚步补间钉枪口（ThreatFlash 同配方，物理插值坑见记忆）。
## 视觉全在场景的 GPUParticles2D 层（贴图/曲线/色带检查器手调），脚本只管
## 触发与钉位。

const ACTIVE_TIME := 0.12 # 兜底收尾（各层粒子寿命 ≤ 此值）

var _t := ACTIVE_TIME # 初始即"已熄灭"态
var _m_prev := Vector2.ZERO # 上一物理步的枪口世界位（亚步补间用，见 _process）
var _m_curr := Vector2.ZERO

@onready var _layers: Array[GPUParticles2D] = [$Flame, $Cross, $Core]


func _init() -> void:
	# 脱离臂变换树：镜像/俯仰不带歪焰形。物理插值下若自身仍参与插值，脚本
	# 写入的 60Hz 台阶位会被引擎当补间目标，焰在量化位间游移（MuzzleFlash
	# 老病）；关掉后渲染即所写。
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false


func _ready() -> void:
	_m_curr = _muzzle_pos()
	_m_prev = _m_curr


func _muzzle_pos() -> Vector2:
	var muzzle := get_parent() as Node2D
	return muzzle.global_position if muzzle != null else global_position


func _physics_process(_delta: float) -> void:
	# 树序父先子后：此刻读到的 global_position 已含本物理步的移动/俯仰/悬浮。
	_m_prev = _m_curr
	_m_curr = _muzzle_pos()


func fire(direction_rad: float) -> void:
	global_rotation = direction_rad
	_t = 0.0
	visible = true
	for layer in _layers:
		layer.restart()
		layer.emitting = true


func _process(delta: float) -> void:
	# muzzle.global_position 是 60Hz 台阶值（插值只在渲染端），按步内比例在
	# 前后两步间补间，贴回与渲染端一致的连续枪口位。
	global_position = _m_prev.lerp(_m_curr, Engine.get_physics_interpolation_fraction())
	if _t >= ACTIVE_TIME:
		return
	_t += delta
	if _t >= ACTIVE_TIME:
		visible = false # 各层粒子已按寿命燃尽，这里只收尾隐藏
