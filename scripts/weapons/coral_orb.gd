class_name CoralOrb
extends Node2D
## 珊瑚重弹（第四章精英「海葵」/BOSS「鮟鱇」共用重击弹）：**慢速可见的能量
## 重球**——出膛=真实炮口×lead 瞄准方向×恒速直线（弹体自读：弹速 900 慢于
## 机枪流，看得见、侧移即躲），撞地即爆蕗（coral_burst 粒群绽放+Bloom 软爆闪，
## 无残留区；GroundBlast 平涂爆闪对珊瑚系关闭，见 show_flash）。lead 瞄准在发射瞬间一次解算（lead_direction：玩家
## 速度×飞行时长，时距从决策点起算，clamp 承诺带）——相对速度即机制：
## 匀速直线跑被压在路径上，变向/急停=免。预警在发射器上（ThreatFlash，
## 见调用方）。视觉全贴图+粒子（fx 规约）：fx_coral_orb.svg+coral_embers
## 余烬尾迹。数值：速度=BalanceWorld4.CORAL_ORB_SPEED，伤害/爆径=调用方机体段。

const ORB_TEXTURE := preload("res://assets/world_4/fx_coral_orb.svg")
const EMBERS := preload("res://scenes/fx/coral_embers.tscn")
const BURST := preload("res://scenes/fx/coral_burst.tscn")

const MAX_LIFETIME := 6.0 # 兜底寿钟（正常按地形命中结算）

var damage := 10
var blast_radius := 90.0

var _speed := BalanceWorld4.CORAL_ORB_SPEED
var _dir := Vector2.LEFT
var _terrain: Terrain
var _t := 0.0
var _visual: Sprite2D
var _embers: GPUParticles2D


## lead 瞄准解算（发射瞬间调用）：预测点=玩家当前位置+速度×飞行时长
##（时长=炮口→预测点距离/弹速，一次迭代收敛），clamp 承诺带后取地表点，
## 返回炮口→落点的单位方向。
static func lead_direction(terrain: Terrain, from: Vector2, player: Player,
		speed: float, lead_back: float, lead_max: float) -> Vector2:
	var vx := clampf(player.velocity.x,
			-BalancePlayer.PLAYER_MOVE_SPEED, BalancePlayer.PLAYER_MOVE_SPEED)
	var t := from.distance_to(player.global_position) / speed
	var lead_x := player.global_position.x + vx * t
	lead_x = clampf(lead_x, player.global_position.x - lead_back,
			player.global_position.x + lead_max)
	var target := Vector2(lead_x, terrain.surface_y_at(lead_x))
	return from.direction_to(target)


func _ready() -> void:
	_visual = Sprite2D.new()
	_visual.texture = ORB_TEXTURE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_visual.material = mat
	add_child(_visual)
	_embers = EMBERS.instantiate() as GPUParticles2D
	_embers.emitting = false # launch() 定位后开（先入树后定位：粒子别喷在原点）
	add_child(_embers)


## 先入树再调本方法。
func launch(terrain: Terrain, from: Vector2, dir: Vector2) -> void:
	_terrain = terrain
	_dir = dir.normalized()
	global_position = from
	reset_physics_interpolation() # 先入树后定位：不拖补间残影
	_embers.emitting = true


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= MAX_LIFETIME:
		queue_free()
		return
	global_position += _dir * _speed * delta
	_visual.scale = Vector2.ONE * (1.0 + 0.1 * sin(_t * 14.0)) # 能量球呼吸
	if _terrain != null \
			and global_position.y >= _terrain.surface_y_at(global_position.x):
		_bloom()


## 爆蕗：粒群绽放 + 珊瑚红爆区（单次球状判定），余烬过继弹容器淡完再清。
func _bloom() -> void:
	var at := Vector2(global_position.x, _terrain.surface_y_at(global_position.x))
	var container := get_tree().get_first_node_in_group("projectile_container")
	if _embers != null:
		_embers.emitting = false
		if container != null:
			_embers.reparent(container)
			get_tree().create_timer(0.6).timeout.connect(_embers.queue_free)
	if container != null:
		var blast := GroundBlast.new()
		blast.damage = damage
		blast.radius = blast_radius
		blast.show_flash = false # 平涂大盘让位：爆区闪由 coral_burst 的 Bloom 层接管
		container.add_child(blast)
		blast.global_position = at
		blast.reset_physics_interpolation()
		var burst := BURST.instantiate() as CoralBurst
		burst.position = at
		burst.power = blast_radius / 90.0 # 爆径耦合：90 为粒子基准档
		container.add_child(burst)
	Sfx.play(&"boom_enemy") # 占位：能量爆蕗暂用敌爆声，珊瑚系配方后配
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(BalanceCombat.KILL_SHAKE_STRENGTH * 1.2)
	queue_free()
