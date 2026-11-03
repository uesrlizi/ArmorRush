class_name SeaSurge
extends Node2D
## 涌浪（第七章 BOSS「沉锚」技能B·深弹涌浪的危险件本体）：**固定绝对高度带
## 漫桥**——不管地面、零地形跟随（珊瑚潮同类合法件，贴地跟随类禁令不适用）。
## 事件链：深弹入水闷爆（DepthCharge 演）→ 涌起预告（浪冠从屏底缓升，
## SWELL）→ 漫桥（水面升到 FLOOD_Y，RISE）→ 驻留（HOLD）→ 退去（RECEDE）。
## 惩罚账=BalanceWorld7.SEA_SURGE 段注释：p1 只淹最低档（脚底 664 > 620），p2 淹到
## 二档（600 > 584）——纯跳脚底 597 在 p1 够在 p2 不够=「跳不过去就飞」；
## 浮空脚手架/断桥顶=合法掩体。一次涌浪至多结算一次（脚底=碰撞中心+24）。
## 视觉=fx_sea_surge 条带（3200×400，浪冠在纹理顶缘）：每帧钉镜头 x（scroll=0
## 语义=与地面同速的世界锚定相位），顶缘钉在当前水面 y；水体普通混合（遮桥
## 面读实体感）。group "sea_surges" 供自测探针计数。数值全在 BalanceWorld7.SEA_SURGE_*。

const SURGE_TEXTURE := preload("res://assets/world_7/fx_sea_surge.svg")

enum Phase { WAIT, SWELL, RISE, HOLD, RECEDE }

var damage := BalanceWorld7.SEA_SURGE_DAMAGE
var flood_y := BalanceWorld7.SEA_SURGE_FLOOD_Y
var lead := 0.0 # 出舱→闷爆的等待时长（涌浪在此之后才开始涨）

var _phase := Phase.WAIT
var _t := 0.0
var _water_y := 1020.0 # 起始水面（屏下：镜头中心 450+屏半高 540=990 之下）
var _hit := false
var _sprite: Sprite2D
var _tile := 3200.0


## 先入树再调本方法。
func launch() -> void:
	reset_physics_interpolation()


func _ready() -> void:
	add_to_group("sea_surges")
	_sprite = Sprite2D.new()
	_sprite.texture = SURGE_TEXTURE
	_sprite.centered = false
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0.0, 0.0, 9600.0, 400.0) # 视口 2400 + tile 3200×2 余量
	_sprite.position = Vector2(0.0, _water_y)
	_sprite.modulate.a = 0.0
	add_child(_sprite)
	_pin_x()


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.WAIT:
			if _t >= lead:
				_phase = Phase.SWELL
				_t = 0.0
				_water_y = BalanceWorld7.SEA_SURGE_SEA_Y + 60.0 # 浪冠先探出屏底
				Sfx.play(&"hit_world") # 占位：涨潮涌动暂用环境撞击声
		Phase.SWELL:
			var k := clampf(_t / BalanceWorld7.SEA_SURGE_SWELL, 0.0, 1.0)
			_water_y = lerpf(BalanceWorld7.SEA_SURGE_SEA_Y + 60.0,
					BalanceWorld7.SEA_SURGE_SEA_Y + 20.0, k)
			_sprite.modulate.a = k
			if _t >= BalanceWorld7.SEA_SURGE_SWELL:
				_phase = Phase.RISE
				_t = 0.0
		Phase.RISE:
			var k := clampf(_t / BalanceWorld7.SEA_SURGE_RISE, 0.0, 1.0)
			_water_y = lerpf(BalanceWorld7.SEA_SURGE_SEA_Y + 20.0, flood_y, k)
			_judge()
			if _t >= BalanceWorld7.SEA_SURGE_RISE:
				_phase = Phase.HOLD
				_t = 0.0
		Phase.HOLD:
			_judge()
			if _t >= BalanceWorld7.SEA_SURGE_HOLD:
				_phase = Phase.RECEDE
				_t = 0.0
		Phase.RECEDE:
			var k := clampf(_t / BalanceWorld7.SEA_SURGE_RECEDE, 0.0, 1.0)
			_water_y = lerpf(flood_y, BalanceWorld7.SEA_SURGE_SEA_Y + 120.0, k)
			_sprite.modulate.a = 1.0 - k
			if k >= 1.0:
				queue_free()
				return
	_sprite.position.y = _water_y
	_pin_x()


## 漫桥判定：脚底（碰撞中心+24）在水面之下=被淹（一次涌浪至多一次）。
func _judge() -> void:
	if _hit:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	if player.global_position.y + 24.0 > _water_y:
		_hit = true
		player.take_damage(damage)
		player.add_shake(BalancePlayer.PLAYER_DAMAGE_SHAKE_STRENGTH)


## 世界锚定相位钉位（WorldStrip scroll=0 语义）：水体与地面同速滚动，
## 不随镜头滑。相机缺省（预览台）退化为屏幕居中。
func _pin_x() -> void:
	var cam := get_viewport().get_camera_2d()
	var center := cam.get_screen_center_position().x if cam != null \
			else get_viewport_rect().size.x * 0.5
	var phase := fposmod(-center, _tile)
	_sprite.position.x = center + phase - 4800.0 # 9600 宽区域中心=镜头：[center−4800, center+4800]
