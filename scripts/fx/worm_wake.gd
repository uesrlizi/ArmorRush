class_name WormWake
extends Node2D
## 冰钻潜行航迹（贴地表随头走的常驻件）：冰下黑影 + 雪脊 + 喷雪（雪粒/雪粉两层），节点原点
## 钉在头正上方的地表线上。视觉全在本场景（检查器手调），脚本只管：
##   set_wake(level, vel_x)——level 0..1=读数强度（潜得越深越淡，0=没信号），
##   vel_x 决定雪脊陡面朝向与喷雪后倾方向（运动方向的反面）。
## 粒子 local_coords=true：航迹是跟着头走的，留原地会读成拖尾。

const RIDGE_SCALE := 1.7 # 雪脊放大（贴图 200x60 对 920 长的蠕虫太小，实机打回）

var _mound_shown := true # 雪脊+黑影=「潜行在地下」的读法；身体露在外面时（犁雪线）只留喷雪

@onready var _shadow: Sprite2D = $Shadow
@onready var _ridge: Sprite2D = $Ridge
@onready var _spray: GPUParticles2D = $Spray
@onready var _grains: GPUParticles2D = $Grains
@onready var _emitters: Array[GPUParticles2D] = [$Spray, $Grains]


func _ready() -> void:
	# 运行时要改喷向：材质按实例复制，别动到场景里的共享正本
	for e in _emitters:
		e.process_material = e.process_material.duplicate()
	_shadow.visible = _mound_shown
	_ridge.visible = _mound_shown
	set_wake(0.0, 0.0)


## 入树前调：false=只留喷雪层（冰钻横冲的犁雪线、破土口沿身体喷雪都用它）。
func set_show_mound(on: bool) -> void:
	_mound_shown = on


func set_wake(level: float, vel_x: float) -> void:
	level = clampf(level, 0.0, 1.0)
	visible = level > 0.02
	if not visible:
		for e in _emitters:
			if e.emitting:
				e.emitting = false
		return
	if _mound_shown:
		_shadow.modulate.a = level * 0.55
		_ridge.modulate.a = minf(1.0, level * 1.5)
		_ridge.scale = Vector2(RIDGE_SCALE, RIDGE_SCALE * lerpf(0.45, 1.0, level))
		_ridge.flip_h = vel_x > 0.0 # 陡面领头（往右跑陡面朝右）
	var ratio := clampf(level, 0.15, 1.0)
	var dir := Vector3(-0.6 * signf(vel_x), -1.0, 0.0)
	for e in _emitters:
		if not e.emitting:
			e.emitting = true
		e.amount_ratio = ratio
		(e.process_material as ParticleProcessMaterial).direction = dir
