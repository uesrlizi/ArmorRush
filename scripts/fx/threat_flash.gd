class_name ThreatFlash
extends Node2D
## 威胁预警闪光（粒子版）：出招前在枪口"闪一下"——红色高亮光晕 + 细线警示
## 十字 + 细实线环。固定时长、与攻击类型/出招节拍无关，只负责把视线钉到
## 威胁源头。语义是提醒不是反馈：亮起即峰值、驻留可读、末段快收（不爆完
## 即衰、不蓄力渐亮、不拖长尾）。视觉全在场景的 GPUParticles2D 层（贴图/scale 曲线/色带/
## 时长都在检查器里直接手调）；本脚本只管**预警统一入口 warn()（闪光+警告音
## 同拍，调用方只调这一个）**、总开关与枪口钉位（top_level + 亚步补间，
## MuzzleFlash 同配方），不碰任何视觉参数。

static var warnings_enabled := true # Main 内容开关转发：关=不演出，出招节拍不变

@export var flash_time := 0.6 # 闪光固定总时长（秒，兜底收尾；各层粒子寿命 ≤ 此值）

var _t := -1.0 # >=0 = 播放中
var _m_prev := Vector2.ZERO # 上一物理步的枪口世界位（亚步补间用，见 _process）
var _m_curr := Vector2.ZERO

@onready var _layers: Array[GPUParticles2D] = [$Flare, $Cross, $Ring]


func _init() -> void:
	# 脱离枪臂变换树：臂的翻转/俯仰不再把它带歪。物理插值下若自身仍参与插值，
	# 脚本写入的 60Hz 台阶位会被引擎当补间目标，粒子在量化位之间游移
	# （MuzzleFlash 同坑）；关掉后渲染即所写。
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false


func _ready() -> void:
	_m_curr = _muzzle_pos()
	_m_prev = _m_curr
	# top_level 的本体位默认在世界原点：入树同帧就 warn()（首个 _process 前）会在
	# 原点闪一帧，入树即钉到枪口（MuzzleFlash 同款）。
	global_position = _m_curr


## 预警统一入口：枪口闪光 + 警告音同拍出（调用方只调这一个，别自己拼）。
## 总开关关闭时整条预警静默（闪光与警告音都不出），出招节拍不变。
func warn() -> void:
	if not warnings_enabled:
		return
	flash()
	Sfx.play(&"threat_warn")


## 在枪口闪一下（纯视觉底层，warn() 内部走这里；重复调用=原地重闪）。
func flash() -> void:
	if not warnings_enabled:
		return
	_t = 0.0
	visible = true
	for layer in _layers:
		layer.restart()
		layer.emitting = true


## 池化复用/死亡清理：掐掉正在演出的闪光。
func reset() -> void:
	_t = -1.0
	visible = false
	for layer in _layers:
		layer.emitting = false


func _muzzle_pos() -> Vector2:
	var muzzle := get_parent() as Node2D
	return muzzle.global_position if muzzle != null else global_position


func _physics_process(_delta: float) -> void:
	# 树序父先子后：此刻读到的 global_position 已含本物理步的移动/俯仰/悬浮。
	_m_prev = _m_curr
	_m_curr = _muzzle_pos()


func _process(delta: float) -> void:
	# muzzle.global_position 是 60Hz 台阶值（插值只在渲染端，2D 无可读插值位），
	# 按渲染帧所处的步内比例在前后两步间补间，贴回连续的枪口位。
	global_position = _m_prev.lerp(_m_curr, Engine.get_physics_interpolation_fraction())
	if _t < 0.0:
		return
	_t += delta
	if _t >= flash_time: # 各层粒子此时已各自寿终，这里只收尾隐藏
		reset()
