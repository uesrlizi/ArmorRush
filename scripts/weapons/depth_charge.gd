class_name DepthCharge
extends Node2D
## 深弹（第七章 BOSS「沉锚」技能B·深弹涌浪的起爆件）：打捞舰艉舱向艉侧
## 抛出→坠海（白沫水花=入水读出件）→定延时水下闷爆（青白晕脉冲）→
## 触发涌浪（涌浪的时机由 SeaSurge 自带 lead 驱动，弹本体只演事件链）。
## 弹体入海前走**地形后方容器**（"sea_props_container" 组节点：落在桥面
## 之后/浪沿之前=「坠入桥后海面」，不穿桥面读法）；水花/闷爆走前景弹容器。
## 三重预警之二：水花（入水）+闷爆晕（「水要来了」）；涨潮本体在 SeaSurge。
## group "depth_charges" 供自测探针计数。数值：抛速=BalanceWorld7.ANCHOR_CHARGE_TOSS，
## 引信/海面线=BalanceWorld7.DEPTH_CHARGE_FUSE/SEA_SURGE_SEA_Y。

const CHARGE_TEXTURE := preload("res://assets/world_7/fx_sea_charge.svg")
const SPLASH_TEXTURE := preload("res://assets/world_7/fx_sea_splash.svg")
const BLOOM_TEXTURE := preload("res://assets/world_7/fx_sea_bloom.svg")

enum Phase { FALL, SINK, SINK_WAIT, DONE }

var _vel := Vector2.ZERO
var _phase := Phase.FALL
var _t := 0.0
var _fuse_t := 0.0


## 先入树再调本方法。toss_dir_x 带符号：抛出水平方向（艉侧=远离玩家）。
func launch(from: Vector2, toss_dir_x: float) -> void:
	global_position = from
	_vel = Vector2(toss_dir_x * BalanceWorld7.ANCHOR_CHARGE_TOSS, -60.0)
	rotation = 0.0
	reset_physics_interpolation() # 先入树后定位：不拖补间残影


func _ready() -> void:
	add_to_group("depth_charges")
	var sprite := Sprite2D.new()
	sprite.texture = CHARGE_TEXTURE
	add_child(sprite)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.FALL:
			_vel.y += BalanceCombat.MORTAR_GRAVITY * delta
			global_position += _vel * delta
			if global_position.y >= BalanceWorld7.SEA_SURGE_SEA_Y:
				_splash_down()
		Phase.SINK:
			_t += delta
			global_position.y += 60.0 * delta # 缓沉（浪沿之下=「沉了」）
			modulate.a = clampf(1.0 - _t / 0.25, 0.0, 1.0)
			if _t >= 0.25:
				_phase = Phase.SINK_WAIT
		Phase.SINK_WAIT:
			_fuse_t += delta
			if _fuse_t >= BalanceWorld7.DEPTH_CHARGE_FUSE:
				_bloom()
		Phase.DONE:
			pass


## 入水：白沫水花（前景容器=浪沿之上的海面读法）+ 转缓沉（沉入浪沿之下）。
func _splash_down() -> void:
	_phase = Phase.SINK
	_t = 0.0
	_fuse_t = 0.0
	global_position.y = BalanceWorld7.SEA_SURGE_SEA_Y
	reset_physics_interpolation()
	_spawn_front_splash(Vector2(global_position.x, BalanceWorld7.SEA_SURGE_SEA_Y))
	Sfx.play(&"hit_world") # 占位：入水暂用环境撞击声，深弹配方后配


## 闷爆：青白晕脉冲（前景容器，ADD）+ 闷响——「水要来了」的二段预警。
func _bloom() -> void:
	_phase = Phase.DONE
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var bloom := Sprite2D.new()
		bloom.texture = BLOOM_TEXTURE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		bloom.material = mat
		container.add_child(bloom)
		bloom.global_position = Vector2(global_position.x,
				BalanceWorld7.SEA_SURGE_SEA_Y + 6.0)
		bloom.reset_physics_interpolation()
		var tw := bloom.create_tween()
		tw.set_parallel(true)
		bloom.scale = Vector2.ONE * 0.4
		tw.tween_property(bloom, "scale", Vector2.ONE * 1.5, 0.45) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(bloom, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(bloom.queue_free)
	Sfx.play(&"boom_enemy") # 占位：闷爆暂用敌爆声（水下闷感后配）
	queue_free()


func _spawn_front_splash(at: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var splash := Sprite2D.new()
	splash.texture = SPLASH_TEXTURE
	container.add_child(splash)
	splash.global_position = at + Vector2(0.0, -14.0)
	splash.reset_physics_interpolation()
	var tw := splash.create_tween()
	tw.set_parallel(true)
	splash.scale = Vector2.ONE * 0.8
	tw.tween_property(splash, "scale", Vector2.ONE * 1.5, 0.35) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(splash, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(splash.queue_free)
