class_name CoralTide
extends Node2D
## 珊瑚潮（第四章 BOSS「鮟鱇」舰腹放电舱的危险件）：**固定绝对高度的涌浪墙**
## ——不管地面，浪墙钉在平衡表给的高度带 [BAND_TOP, BAND_BOTTOM]（纵跨 120，
## 盖住三档地块站立带中心 634/570/506），只沿 x 恒速涌向玩家，台阶零瞬移。
## 反制=推进升空**飞越**（纯跳 apex 只在最高档擦得过，低档必须飞）；浮空
## 脚手架高台=合法掩体；后撤跑 600>涌速 520 甩得开，射程到点哑熄（无伤）
## ——等待永远合法。灼烧一次即溃散（浪墙不是驻留区）。
## 伤害=玩家中心到浪墙竖直段（x, TOP..BOTTOM）的距离 ≤ RADIUS+宽限。
## 视觉=纯特效（v2.5 全平涂：coral_tide_fx 四层平涂盘发射器[墙体/浪冠/泡沫/
## 前缘飞沫]，平涂堆密度出能量感，柔光底已随渐变一起砍掉）：group
## "coral_tides" 供自测探针计数。预警在发射器上（ThreatFlash，见调用方）。
## 数值全在 Balance.CORAL_TIDE_*。

const TIDE_FX := preload("res://scenes/fx/coral_tide_fx.tscn")

var damage := Balance.CORAL_TIDE_DAMAGE
var speed := Balance.CORAL_TIDE_SPEED
var travel_max := Balance.CORAL_TIDE_RANGE

var _dir := -1.0 # 涌动方向（−1=朝左，向玩家一侧）
var _travel := 0.0
var _t := 0.0
var _fade := 1.0
var _fx: Node2D
var _emitters: Array[GPUParticles2D] = []


func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _ready() -> void:
	add_to_group("coral_tides")
	_fx = TIDE_FX.instantiate() as Node2D
	add_child(_fx)
	for c in _fx.get_children():
		if c is GPUParticles2D:
			var p := c as GPUParticles2D
			p.emitting = false # launch() 定位后开（先入树后定位：粒子别喷在原点）
			_emitters.append(p)


## 先入树再调本方法：from=出潮点（只取 x；y 钉绝对高度带中心），
## direction 带符号（负=朝左涌）。浪墙特效原生前缘朝 -X：行进反向时整层镜像
##（前缘永远迎着玩家，墙体/泡沫拖在后侧）。
func launch(_terrain: Terrain, from: Vector2, direction: float) -> void:
	_dir = signf(direction) if direction != 0.0 else -1.0
	_fx.scale.x = -1.0 if _dir > 0.0 else 1.0
	var band_center := (Balance.CORAL_TIDE_BAND_TOP \
			+ Balance.CORAL_TIDE_BAND_BOTTOM) * 0.5
	global_position = Vector2(from.x, band_center)
	reset_physics_interpolation() # 先入树后定位：不拖补间残影
	for e in _emitters:
		e.emitting = true


func _physics_process(delta: float) -> void:
	_t += delta
	if _fade < 1.0: # 溃散中：断发射器+短淡出（存量粒子自然燃尽），无伤
		_fade -= delta * 4.0
		modulate.a = clampf(_fade, 0.0, 1.0)
		if _fade <= 0.0:
			queue_free()
		return
	global_position.x += speed * delta * _dir # 只涌 x：高度带恒定，台阶零瞬移
	_travel += speed * delta
	if _travel >= travel_max:
		_fade = 0.99 # 到点哑熄：无伤淡出（等待是合法反制）
		for e in _emitters:
			e.emitting = false
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.is_dead():
		var a := Vector2(global_position.x, Balance.CORAL_TIDE_BAND_TOP)
		var b := Vector2(global_position.x, Balance.CORAL_TIDE_BAND_BOTTOM)
		var dist := Geometry2D.get_closest_point_to_segment(
				player.global_position, a, b).distance_to(player.global_position)
		if dist <= Balance.CORAL_TIDE_RADIUS + 26.0:
			player.take_damage(damage)
			_fade = 0.99 # 灼烧一次即溃散：威胁解除（同"雷爆即完"的账）
			for e in _emitters:
				e.emitting = false
