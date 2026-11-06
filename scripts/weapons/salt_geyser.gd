class_name SaltGeyser
extends Node2D
## 间歇泉（第八章核心危险件：精英「喷井」预教/BOSS「盐磨」泉幕的本体）：
## 三段读法——**地裂（mark 预警）→ 喷发（瞬时汽柱）→ 收柱（淡出自灭）**。
## mark=静止落点零地形跟随（装药/锚桩同族，贴地跟随禁令不受累）；汽柱=静止
## 竖直件（出现即静止，寿命到点自灭）。
## 惩罚账=BalanceWorld8.SALT_GEYSER 段注释：**离=唯一反制**（0.7s 预警窗内
## 跑出 mark）；**跳≠过**（柱高 360 = 纯跳 67 的 5.4 倍——柱 AABB 判定，
## 玩家中心在柱宽内且低于柱顶即吃，一次喷发至多一次）；穿缝=免；等全灭跑过
## 空场=免。视觉：mark=fx_salt_mark（地裂环纹+盐田粉蓄能环渐急+预漏白汽，
## DrillCharge 灯晕手法）；汽柱=fx_salt_column（顶在纹理 y=0，节点把顶钉在
## 地表−360，普通混合=墙的实体遮挡感）。group "salt_geysers" 供自测探针计数
## （重击谓词并入本件：mark 落地即计入威胁）。
## 数值全在 BalanceWorld8.SALT_GEYSER_*；由 SaltDart 落地生成（.new() 纯代码
## 自建视觉惯例）。

const MARK_TEXTURE := preload("res://assets/world_8/fx_salt_mark.svg")
const COLUMN_TEXTURE := preload("res://assets/world_8/fx_salt_column.svg")
const GLINT_TEXTURE := preload("res://assets/world_8/fx_salt_glint.svg")

enum Phase { MARK, ERUPT, CLOSE }

var damage := BalanceWorld8.SALT_GEYSER_DAMAGE

var _phase := Phase.MARK
var _t := 0.0
var _hit := false
var _mark: Sprite2D
var _glint: Sprite2D
var _column: Sprite2D


func _ready() -> void:
	add_to_group("salt_geysers")
	_mark = Sprite2D.new()
	_mark.texture = MARK_TEXTURE
	_mark.position = Vector2(0.0, -8.0) # 环纹贴地读法（椭圆扁环中心在地表上缘）
	_mark.modulate.a = 0.0
	add_child(_mark)
	var addmat := CanvasItemMaterial.new()
	addmat.blend_mode = 1
	_glint = Sprite2D.new()
	_glint.texture = GLINT_TEXTURE
	_glint.material = addmat
	_glint.position = Vector2(0.0, -8.0)
	_glint.scale = Vector2.ONE * 0.6
	add_child(_glint) # 蓄能粉晕盖在环上（加色，渐急主读出层之一）
	_column = Sprite2D.new()
	_column.texture = COLUMN_TEXTURE
	_column.position = Vector2(0.0, -BalanceWorld8.SALT_GEYSER_HEIGHT * 0.5) # 顶钉地表−360
	_column.visible = false
	add_child(_column)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.MARK:
			# 预漏白汽+蓄能环渐急（「何时喷」的剩余时间信息层，装药灯晕手法）
			var urgency := clampf(_t / BalanceWorld8.SALT_GEYSER_WARN, 0.0, 1.0)
			_mark.modulate.a = 0.55 + 0.45 * sin(_t * (8.0 + 26.0 * urgency))
			_glint.modulate.a = urgency * (0.35 + 0.4 * sin(_t * (10.0 + 30.0 * urgency)))
			_glint.scale = Vector2.ONE * (0.5 + 0.7 * urgency)
			if _t >= BalanceWorld8.SALT_GEYSER_WARN:
				_erupt()
		Phase.ERUPT:
			_judge()
			if _t >= BalanceWorld8.SALT_GEYSER_ERUPT:
				_phase = Phase.CLOSE
				_t = 0.0
		Phase.CLOSE:
			var k := clampf(_t / BalanceWorld8.SALT_GEYSER_CLOSE, 0.0, 1.0)
			_column.modulate.a = 1.0 - k
			_mark.modulate.a = 1.0 - k
			_glint.modulate.a = 0.0
			if k >= 1.0:
				queue_free()


## 喷发：汽柱瞬起（补间 0.08s 冲到全高=「瞬时」读法）+ 泉眼粉晕全亮 +
## 爆响。柱体静止竖直，寿命 0.55s。
func _erupt() -> void:
	_phase = Phase.ERUPT
	_t = 0.0
	_column.visible = true
	_column.modulate.a = 1.0
	_column.scale = Vector2(0.7, 0.12)
	var tw := _column.create_tween()
	tw.set_parallel(true)
	tw.tween_property(_column, "scale", Vector2.ONE, 0.08) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_glint.modulate.a = 1.0
	_glint.scale = Vector2.ONE * 1.4
	Sfx.play(&"boom_enemy") # 占位：汽柱喷发暂用敌爆声，地热配方后配


## 柱 AABB 判定：玩家中心 |dx| ≤ 柱半宽+宽限 且中心低于柱顶（地表−360）
## ——跳≠过（纯跳 67、柱寿内推进 ~176 都够不到柱顶 360）。
func _judge() -> void:
	if _hit:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	if absf(player.global_position.x - global_position.x) \
			> BalanceWorld8.SALT_GEYSER_WIDTH * 0.5 + GroundBlast.PLAYER_RADIUS:
		return
	if player.global_position.y < global_position.y - BalanceWorld8.SALT_GEYSER_HEIGHT:
		return
	_hit = true
	player.take_damage(damage)
	player.add_shake(BalancePlayer.PLAYER_DAMAGE_SHAKE_STRENGTH)
