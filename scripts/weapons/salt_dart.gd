class_name SaltDart
extends Node2D
## 裂地镖（第八章间歇泉的运载弹：精英「喷井」钻尖/BOSS「盐磨」腹口出膛）：
## 真实枪口律的落地件——泉的 mark 由镖落地生成（ch6 装药同构：弹落点=mark）。
## 弹体小 16x8 **快速一闪即落**（读法归地面标记本身，提案 §1）——平飞速度档
## 出膛、真弹道浅弧落地，落地即生成 SaltGeyser（地裂环纹→汽柱的完整生命周期
## 归间歇泉件）。镖本体无伤、无驻留、落定即退场；落点=调用方解算（精英=玩家
## 当时脚下无 lead；BOSS 泉幕=玩家当时位置前后铺开）。
## group "salt_darts" 供自测探针计数。数值全在 BalanceWorld8.SALT_DART_*。

const DART_TEXTURE := preload("res://assets/world_8/fx_salt_dart.svg")
const GLINT_TEXTURE := preload("res://assets/world_8/fx_salt_glint.svg")

const MAX_LIFETIME := 3.0 # 兜底寿钟（正常按落地结算）

var _vel := Vector2.ZERO
var _terrain: Terrain
var _t := 0.0
var _planted := false


## 先入树再调本方法。target 必须贴地（调用方按 surface_y_at 解算）。
func launch(terrain: Terrain, from: Vector2, target: Vector2) -> void:
	_terrain = terrain
	global_position = from
	var flight := clampf(absf(target.x - from.x) / BalanceWorld8.SALT_DART_SPEED,
			BalanceWorld8.SALT_DART_FLIGHT_MIN, BalanceWorld8.SALT_DART_FLIGHT_MAX)
	var d := target - from
	var g := BalanceCombat.MORTAR_GRAVITY
	_vel = Vector2(d.x / flight, d.y / flight - 0.5 * g * flight)
	rotation = _vel.angle()
	reset_physics_interpolation() # 先入树后定位：不拖补间残影


## 出膛初速方向（调用方挂出膛焰用——真实枪口律：焰向=弹向）。
func initial_dir() -> Vector2:
	return _vel.normalized() if _vel.length_squared() > 0.0001 else Vector2.RIGHT


func _ready() -> void:
	add_to_group("salt_darts")
	var sprite := Sprite2D.new()
	sprite.texture = DART_TEXTURE
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if _planted:
		return
	_t += delta
	if _t >= MAX_LIFETIME:
		queue_free()
		return
	_vel.y += BalanceCombat.MORTAR_GRAVITY * delta
	global_position += _vel * delta
	rotation = _vel.angle()
	var surface := _terrain.surface_y_at(global_position.x) \
			if _terrain != null else global_position.y
	if _vel.y > 0.0 and global_position.y >= surface:
		_plant(surface)


## 落地：生成间歇泉（mark 预警在落点本身）+ 落点光斑一闪（触地读出件），
## 镖本体退场。
func _plant(surface: float) -> void:
	_planted = true
	var at := Vector2(global_position.x, surface)
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var geyser := SaltGeyser.new()
		container.add_child(geyser)
		geyser.global_position = at
		geyser.reset_physics_interpolation()
		var glint := Sprite2D.new()
		glint.texture = GLINT_TEXTURE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glint.material = mat
		container.add_child(glint)
		glint.global_position = at + Vector2(0.0, -6.0)
		glint.reset_physics_interpolation()
		var tw := glint.create_tween()
		tw.set_parallel(true)
		glint.scale = Vector2.ONE * 0.5
		tw.tween_property(glint, "scale", Vector2.ONE * 1.6, 0.3) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(glint, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(glint.queue_free)
	Sfx.play(&"hit_world") # 占位：地裂暂用环境撞击声
	queue_free()
