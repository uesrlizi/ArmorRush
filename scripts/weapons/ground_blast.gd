class_name GroundBlast
extends Node2D
## 落地爆炸：球状伤害检测——引爆帧结算一次（爆心=撞地点，圆心距玩家
## 碰撞中心 ≤ 半径+玩家半宽宽限即命中）。视觉=FlashBurst 贴图爆闪
## （颜色/尺寸/时长是它的导出参数，编辑器可调），本体只管判定。

var damage := 20
var radius := 110.0
var linger := 0.25
# 爆区闪光染色（FlashBurst 的 modulate）：默认橙红=现役三处（导弹/臼炮/击毁补爆）
# 不变；电浆系爆（PlasmaMissile/PlasmaMine）染冰蓝。只管视觉，伤害判定同源。
var flash_color := Color(1.0, 0.5, 0.25, 0.6)
# 平涂爆闪开关：珊瑚系爆蕗的爆区闪由 coral_burst 的 Bloom 粒子层接管
#（这张硬边大盘放大后和粒子群读成两回事），调用方置 false。
var show_flash := true

# 玩家判定宽限（比碰撞盒半宽略宽：手感从宽，宁可"擦边也算躲过"也不反向）
const PLAYER_RADIUS := 26.0

const FLASH_BURST := preload("res://scenes/fx/flash_burst.tscn")

var _judged := false
var _flash: FlashBurst # 爆闪子节点：它自己播完淡出才自清，本体等它（见 _physics_process）


func _init() -> void:
	linger = BalanceCombat.HEAVY_BLAST_LINGER # autoload 在 _init 里取值，解析期不依赖


func _ready() -> void:
	if show_flash:
		# 爆闪（视觉）：flash_color 染色垫在爆炸本体下面当爆区光晕（层级由引爆处
		# 入树序保证，见 heavy_missile._detonate），alpha 压低防罩住特效；大小随
		# 伤害半径（size_scale 走 FlashBurst 补间两端——预置 scale 会被补间覆盖，
		# 且大爆径首帧闪出全尺寸大圈，踩过）
		var flash := FLASH_BURST.instantiate() as FlashBurst
		flash.modulate = flash_color
		flash.size_scale = radius / 48.0
		add_child(flash) # 先定位再入树：tween 在 _ready 起跑，晚定位会闪在原点
		_flash = flash
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not _judged:
		_judged = true
		_judge()
	linger -= delta
	# 爆闪挂在本节点下：本体先清会把正在淡出的闪光连根砍掉（linger 0.25s 砍在
	# 0.33s 闪光的七成亮度、最大尺寸处=「爆炸到一半忽然消失」）。linger 只当
	# 驻留下限，闪光自清后再走。
	if linger <= 0.0 and not is_instance_valid(_flash):
		queue_free()


func _judge() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	if global_position.distance_to(player.global_position) <= radius + PLAYER_RADIUS:
		player.take_damage(damage)
