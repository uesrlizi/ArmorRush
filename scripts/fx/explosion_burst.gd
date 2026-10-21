class_name ExplosionBurst
extends Node2D
## 击毁爆炸：白闪 → 橙红火球 + 扩散冲击环（本体绘制，加法混合），
## 叠火焰/烟尘/碎片三层粒子（火焰加法发亮，烟尘碎片普通混合压得住底色）。
## 一次性自灭；由 Enemy 在击毁瞬间生成，不随本体回池消失。

const FLASH_TIME := 0.12
const FIREBALL_TIME := 0.3
const RING_TIME := 0.38
const LIFETIME := 0.95

var _life := 0.0


func _ready() -> void:
	$Fire.emitting = true
	$Smoke.emitting = true
	$Debris.emitting = true


func _process(delta: float) -> void:
	_life += delta
	queue_redraw()
	if _life >= LIFETIME:
		queue_free()


func _draw() -> void:
	var flash_p := _life / FLASH_TIME
	if flash_p < 1.0:
		# 白闪：瞬间吞掉机体轮廓的第一帧。
		var eased := 1.0 - pow(1.0 - flash_p, 2.0)
		draw_circle(Vector2.ZERO, lerpf(9.0, 30.0, eased),
				Color(1.0, 1.0, 0.95, 0.95 * (1.0 - flash_p)))
	var fire_p := _life / FIREBALL_TIME
	if fire_p < 1.0:
		# 火球：橙色外壳外扩，黄白核心收拢。
		var eased := 1.0 - pow(1.0 - fire_p, 1.8)
		draw_circle(Vector2.ZERO, lerpf(10.0, 38.0, eased),
				Color(1.0, 0.55, 0.12, 0.8 * (1.0 - fire_p)))
		draw_circle(Vector2.ZERO, lerpf(6.0, 19.0, eased),
				Color(1.0, 0.9, 0.5, 0.9 * (1.0 - fire_p)))
	var ring_p := _life / RING_TIME
	if ring_p < 1.0:
		var eased := 1.0 - pow(1.0 - ring_p, 2.4)
		draw_arc(Vector2.ZERO, lerpf(12.0, 80.0, eased), 0.0, TAU, 48,
				Color(1.0, 0.85, 0.55, 0.55 * (1.0 - ring_p)),
				3.0 * (1.0 - ring_p) + 0.6, true)
