class_name FlashBurst
extends Node2D
## 一次性爆闪（贴图素材版）：入树即播——快速放大 + 淡出，完事自灭。
## 用于失衡爆闪、落地爆炸闪光等"一闪"语汇；颜色走 modulate（调用方/场景里调），
## 尺寸/时长/缩放曲线都是导出参数，编辑器直接调。先定位再入树（同爆炸粒子规矩）。

const FLASH_TEXTURE := preload("res://assets/common/fx_flash.svg")

@export var duration := 0.22    # 闪的时长（秒）
@export var start_scale := 0.5  # 起始缩放
@export var end_scale := 1.7    # 结束缩放（放大扩散）
@export var size_scale := 1.0   # 整体尺寸倍率（爆径耦合：GroundBlast 传 radius/48）
@export var flash_color := Color(1.0, 0.92, 0.8) # 起始染色（衰减到白）

var _add_material: CanvasItemMaterial = CanvasItemMaterial.new()


func _init() -> void:
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _add_material


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FLASH_TEXTURE
	add_child(sprite)
	var tw := create_tween()
	tw.set_parallel(true)
	# 尺寸倍率并进补间两端（小→大）：入树前预置 scale 的做法会被 .from
	# 覆盖，且大爆径下第一帧画的是全尺寸盘=闪出一帧大圈（踩过）。
	tw.tween_property(self, "scale",
			Vector2.ONE * end_scale * size_scale, duration) \
			.from(Vector2.ONE * start_scale * size_scale) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate", Color.WHITE, duration).from(flash_color)
	tw.chain().tween_property(self, "modulate:a", 0.0, duration * 0.5)
	tw.chain().tween_callback(queue_free)
