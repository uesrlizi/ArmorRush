class_name GroundBlast
extends Node2D
## 落地爆炸：球状伤害检测——引爆帧结算一次（爆心=撞地点，圆心距玩家
## 碰撞中心 ≤ 半径+玩家半宽宽限即命中）。视觉=FlashBurst 贴图爆闪
## （颜色/尺寸/时长是它的导出参数，编辑器可调），本体只管判定。

var damage := 20
var radius := 110.0
var linger := 0.25

# 玩家判定宽限（比碰撞盒半宽略宽：手感从宽，宁可"擦边也算躲过"也不反向）
const PLAYER_RADIUS := 26.0

const FLASH_BURST := preload("res://scenes/flash_burst.tscn")

var _judged := false


func _init() -> void:
	linger = Balance.HEAVY_BLAST_LINGER # autoload 在 _init 里取值，解析期不依赖


func _ready() -> void:
	# 爆闪（视觉）：橙红染色，大小随伤害半径
	var flash := FLASH_BURST.instantiate() as Node2D
	flash.modulate = Color(1.0, 0.5, 0.25)
	flash.scale = Vector2.ONE * (radius / 48.0)
	add_child(flash) # 先定位再入树：tween 在 _ready 起跑，晚定位会闪在原点
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not _judged:
		_judged = true
		_judge()
	linger -= delta
	if linger <= 0.0:
		queue_free()


func _judge() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	if global_position.distance_to(player.global_position) <= radius + PLAYER_RADIUS:
		player.take_damage(damage)
