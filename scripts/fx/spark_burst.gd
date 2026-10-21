class_name SparkBurst
extends Node2D
## 近战命中火花：白色闪芯 + 扩散冲击环 + 粒子迸射，一次性自灭。
## 由 Player 在命中点生成；喷发方向沿用挥刀朝向（生成方设置本节点 rotation/scale）。

const LIFETIME := 0.5
const RING_TIME := 0.22

var _life := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	$Sparks.emitting = true


func _process(delta: float) -> void:
	_life += delta
	queue_redraw()
	if _life >= LIFETIME:
		queue_free()


func _draw() -> void:
	var p := _life / RING_TIME
	if p >= 1.0:
		return
	var eased := 1.0 - pow(1.0 - p, 2.5)
	draw_arc(Vector2.ZERO, lerpf(8.0, 46.0, eased), 0.0, TAU, 40,
			Color(1.0, 1.0, 1.0, 0.7 * (1.0 - p)), 3.0 * (1.0 - p) + 0.5, true)
	draw_circle(Vector2.ZERO, 12.0 * (1.0 - p), Color(1.0, 1.0, 1.0, 0.85 * (1.0 - p)))
