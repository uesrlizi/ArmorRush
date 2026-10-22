class_name OreCart
extends Node2D
## 溜矿车（第六章 BOSS「赤轮」腹舱倾泻的危险件）：出舱坠落→贴地朝玩家恒速
## 滚行（台阶=y 朝当地地表快速归位，叮咣翻越读法）。碰撞 64×84——纯跳可过
## （apex 底 −103 vs 车顶 −84）；命中一次结算（车继续滚，不因命中停）；
## 寿命到点/滚出玩家后方射程=脱轨哑熄（无伤）——等待永远合法。
## 视觉=fx_red_cart.svg（白热顶灯=第一眼读法的主动读出件），行进反向整层
## 镜像；group "ore_carts" 供自测探针计数。数值全在 Balance.ORE_CART_*。

const CART_TEXTURE := preload("res://assets/world_6/fx_red_cart.svg")

const HALF_SIZE := Vector2(32.0, 42.0) # 碰撞半尺寸（64×84）
const DROP_GRAVITY := 2600.0           # 出舱坠落段重力（弧快读法）
const STEP_TRACK := 14.0               # 滚行段 y 归位速率（指数平滑 /s）

var damage := Balance.ORE_CART_DAMAGE
var speed := Balance.ORE_CART_SPEED
var lifetime := Balance.ORE_CART_LIFETIME

var _dir := -1.0
var _rolling := false
var _t := 0.0
var _terrain: Terrain
var _visual: Sprite2D
var _hit := false


## 先入树再调本方法。direction 带符号（−1=朝左滚向玩家一侧）。
func launch(terrain: Terrain, from: Vector2, direction: float) -> void:
	_terrain = terrain
	_dir = signf(direction) if direction != 0.0 else -1.0
	if _visual != null: # add_child 先于 launch：贴图镜像在此同步（_ready 的初值只是兜底）
		_visual.scale.x = 1.0 if _dir > 0.0 else -1.0
	global_position = from
	reset_physics_interpolation() # 先入树后定位：不拖补间残影


func _ready() -> void:
	add_to_group("ore_carts")
	_visual = Sprite2D.new()
	_visual.texture = CART_TEXTURE
	_visual.scale.x = 1.0 if _dir > 0.0 else -1.0 # 贴图原生 +X=滚向，反向镜像
	add_child(_visual)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _rolling:
		# 出舱坠落段：抛体下坠，斗沿触地即转滚行
		global_position.y += DROP_GRAVITY * delta
		var surface := _terrain.surface_y_at(global_position.x) \
				if _terrain != null else global_position.y + HALF_SIZE.y
		if global_position.y + HALF_SIZE.y >= surface:
			global_position.y = surface - HALF_SIZE.y
			_rolling = true
			reset_physics_interpolation()
		return
	# 滚行段：x 恒速，y 朝当地地表归位（台阶=快速跨上/落下）
	global_position.x += speed * delta * _dir
	var target_y := (_terrain.surface_y_at(global_position.x) \
			if _terrain != null else global_position.y + HALF_SIZE.y) - HALF_SIZE.y
	global_position.y += (target_y - global_position.y) * minf(STEP_TRACK * delta, 1.0)
	# 滚动颠簸（轻微，读「重载矿车」）
	_visual.rotation = sin(_t * 26.0) * 0.02
	_tick_damage()
	var past_player := false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		# 沿行进方向越过玩家 600px 才算滚过（×_dir 把「行进方向上的前方」
		# 归一成正值；出舱时车在玩家身后 >600 是正常起点，不能判过）。
		past_player = (global_position.x - player.global_position.x) * _dir > 600.0
	if _t >= lifetime or past_player:
		queue_free() # 脱轨哑熄（无伤淡出账：出屏即收，无驻留区）


## 命中：AABB（车盒 + 玩家半宽限）内一次结算，车继续滚（威胁不消失，
## 但同一辆车不重复吃血）。
func _tick_damage() -> void:
	if _hit:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return
	var d := player.global_position - global_position
	if absf(d.x) <= HALF_SIZE.x + 26.0 and absf(d.y) <= HALF_SIZE.y + 24.0:
		_hit = true
		player.take_damage(damage)
		player.add_shake(Balance.KILL_SHAKE_STRENGTH * 0.8)
		Sfx.play(&"boom_enemy") # 占位：撞击暂用敌爆声，矿车配方后配
