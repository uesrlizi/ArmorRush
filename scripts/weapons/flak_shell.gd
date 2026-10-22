class_name FlakShell
extends Node2D
## 啸雷弹（第五章精英「响哨」/BOSS「断云」共用重击弹）：**定距空爆的防空
## 弹**——直线无重力飞行，出膛瞬间按「炮口→玩家当时位置」的距离解算引信
## （定距引信=真实高炮语法），到点在**发射时玩家所在点**爆出球状爆区
## （GroundBlast，空中合法；flash_color 白热金）。撞地形=提前爆（台阶立面
## 当掩体合法，不校平）。惩罚账=提案 §2：**停=吃/动=免**——与 ch4 重弹的
## lead 惩罚互为镜像（那边罚匀速跑，这边罚不跑）；悬停=吃（防空语义）。
## 读法=炮口预警（ThreatFlash，见调用方）+ 弹上引信芯越闪越急。
## 视觉全贴图（fx 规约）：fx_dawn_flak.svg，亮度脉冲由代码驱动。
## 数值：速度=Balance.FLAK_SHELL_SPEED，伤害/爆径/引信=调用方按机体段解算。

const FLAK_TEXTURE := preload("res://assets/world_5/fx_dawn_flak.svg")

const FLASH_COLOR := Color(1.0, 0.85, 0.55, 0.6) # 白热金爆区（dawn 语汇，与熔渣橙红/珊瑚红分家）
const MAX_LIFETIME := 4.0 # 兜底寿钟（正常按引信/撞地结算）

var damage := 8
var blast_radius := 90.0

var _speed := Balance.FLAK_SHELL_SPEED
var _fuse := 1.0
var _dir := Vector2.LEFT
var _terrain: Terrain
var _t := 0.0
var _detonated := false
var _visual: Sprite2D


## 先入树再调本方法。fuse=引信时长（秒）：调用方按 距离/弹速 定距（爆点=
## 发射时玩家所在点）。
func launch(terrain: Terrain, from: Vector2, dir: Vector2, fuse: float) -> void:
	_terrain = terrain
	_dir = dir.normalized()
	_fuse = maxf(fuse, 0.05)
	global_position = from
	rotation = _dir.angle()
	reset_physics_interpolation() # 先入树后定位：不拖补间残影


func _ready() -> void:
	_visual = Sprite2D.new()
	_visual.texture = FLAK_TEXTURE
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	_t += delta
	global_position += _dir * _speed * delta
	# 引信读法：越闪越急（频率随引信进度爬升；脉冲幅度加大=暗天上更抓眼）
	var urgency := clampf(_t / _fuse, 0.0, 1.0)
	_visual.modulate.a = 0.55 + 0.45 * sin(_t * (10.0 + 42.0 * urgency))
	if _terrain != null \
			and global_position.y >= _terrain.surface_y_at(global_position.x):
		_detonate(Vector2(global_position.x,
				_terrain.surface_y_at(global_position.x))) # 撞地/撞立面=早爆（掩体）
		return
	if _t >= _fuse:
		_detonate(global_position)


## 定距空爆：球状爆区（单次判定）+ 白金球闪，无驻留区。
func _detonate(at: Vector2) -> void:
	_detonated = true
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container != null:
		var blast := GroundBlast.new()
		blast.damage = damage
		blast.radius = blast_radius
		blast.flash_color = FLASH_COLOR
		container.add_child(blast)
		blast.global_position = at
		blast.reset_physics_interpolation()
	Sfx.play(&"boom_enemy") # 占位：空爆暂用敌爆声，啸雷配方后配
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.add_shake(Balance.KILL_SHAKE_STRENGTH * 0.8)
	queue_free()
