class_name ImpactBurst
extends Node2D
## 子弹命中迸溅：白热闪芯 + 扩散小环 + 沿回溅方向的火花锥，一次性自灭。
## 由 Bullet 在命中点生成；本节点 +X 朝飞溅方向（通常为弹道反向），
## tint 供弹种染色（玩家弹暖金、敌弹红）。

const FLASH_TIME := 0.08
const RING_TIME := 0.18
const LIFETIME := 0.32

var _tint := Color(1.0, 0.92, 0.6)
var _life := 0.0

@onready var _sparks: CPUParticles2D = $Sparks


## 兼容先进树再 setup 两种调用顺序；splash_dir 传弹道反向。
func setup(splash_dir: Vector2, tint: Color) -> void:
	_tint = tint
	if splash_dir.length_squared() > 0.0001:
		rotation = splash_dir.angle()
	if is_inside_tree():
		_apply_tint()


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_apply_tint()
	$Sparks.emitting = true


func _apply_tint() -> void:
	_sparks.color = _tint


func _process(delta: float) -> void:
	_life += delta
	queue_redraw()
	if _life >= LIFETIME:
		queue_free()


func _draw() -> void:
	var flash_p := _life / FLASH_TIME
	if flash_p < 1.0:
		# 闪芯：快胀快灭的白热圆点，染一点弹种色。
		draw_circle(Vector2.ZERO, 1.5 + 5.5 * flash_p,
				Color(_tint.lerp(Color.WHITE, 0.7), 0.95 * (1.0 - flash_p)))
	var ring_p := _life / RING_TIME
	if ring_p < 1.0:
		var eased := 1.0 - pow(1.0 - ring_p, 2.2)
		draw_arc(Vector2.ZERO, lerpf(2.0, 15.0, eased), 0.0, TAU, 24,
				Color(_tint, 0.6 * (1.0 - ring_p)), 2.0 * (1.0 - ring_p) + 0.5, true)
