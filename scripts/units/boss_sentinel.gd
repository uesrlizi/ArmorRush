class_name BossSentinel
extends PursuitBoss
## 第三章 BOSS v3·强袭悬空机甲「哨兵」（雪原警戒点守卫）：追击框架能力层——
## 「电浆封锁」。从零设计的敌机甲（白鲸飞艇整体废弃，见 提案_v3_哨兵重设计.md）：
## 宽肩双 Pod（四联电浆垂发）+ 单臂电浆重炮 + 腰部布雷撒布舱 + 反关节悬垂腿
## + 背包双喷口悬浮。碰撞体 260×180（高度与 ch1 直升机同档，宽度放开）。
##   电浆弹雨（技能A）：肩部 4 垂发仓口（画布 x71/87/151/167，=轮发数 1:1，
##     phase2 +2 回绕）逐孔出膛 PlasmaMissile——HeavyMissile 纯视觉换皮（追踪/
##     爆炸语法同 ch1 弹雨：上抛+载机速度继承、滑行 0.2s 开机、比例导引追脚底、
##     3s 锁死扎地）——惩罚贴地驻停；
##   浮雷封锁（技能B）：**一次性齐撒**——预警 0.5s 后全数同帧出舱（3 枚/二阶段
##     4 枚各奔承诺带不同落点，空中读成"一把撒开的雷幕"），与臼炮逐孔梯次读法
##     彻底分家；落点=按玩家速度外推的前方承诺带（间距 280 有缝），惩罚犹豫/
##     跳跃，蓄能窗内冲过免费（几何账见提案_v2 §2）；
##   电浆枪直射（普攻）：右臂重炮真瞄玩家短点放——弹=plasma_bolt.tscn
##     （bullet.gd 纯换皮：冰蓝矢形贴图，速度/伤害复用 BOSS_SWEEP_*，直瞄无
##     预判语法不变），无重击警告（真瞄即预警）。
## 走位/贴脸窗/二阶段/失衡全在 PursuitBoss 框架；_tick_visual=背包双喷口推进焰
## 琥珀脉动（机甲无旋翼，错相呼吸给"悬浮的活"感）。数值全在 BalanceWorld3.SENTINEL_*
## /PLASMA_MINE_*。

const ST_RAIN_WARN := 3
const ST_RAIN_FIRE := 4
const ST_MINE_WARN := 5
const ST_MINE_FIRE := 6
const ST_DIRECT := 7

const PLASMA_BOLT := preload("res://scenes/weapons/plasma_bolt.tscn")

var _rain_launched := 0
var _launch_t := 0.0
var _direct_shoot_t := 0.0

@onready var _rain_warn: ThreatFlash = $Visuals/MissileWarn/ThreatFlash
@onready var _bay_port: Node2D = $Visuals/BayPort
@onready var _bay_warn: ThreatFlash = $Visuals/BayPort/ThreatFlash
@onready var _bay_flash: MuzzleFlash = $Visuals/BayPort/Flash
@onready var _warn: ThreatFlash = $Visuals/ArmPivot/Muzzle/ThreatFlash # 直瞄枪口（不预警，但池化复用要兜底重置）
@onready var _thrusters: Array[Sprite2D] = [
	$Visuals/Thruster1 as Sprite2D,
	$Visuals/Thruster2 as Sprite2D,
]


## 血条上方显示的机体名。
func _display_name() -> String:
	return "哨兵"


func _species_max_hp() -> int:
	return BalanceWorld3.SENTINEL_MAX_HP


func _hover_anchor_y() -> float:
	return BalanceWorld3.SENTINEL_HOVER_Y # 绝对锚：机体 280..460，对最高台阶 536 净空 76px


func on_spawned() -> void:
	super()
	_rain_launched = 0


## 背包双喷口推进焰：琥珀错相呼吸（机甲无旋翼；失衡/死亡演出期间也照烧——
## 悬浮没熄火）。
func _tick_visual(delta: float) -> void:
	for i in _thrusters.size():
		var t := _thrusters[i] as Sprite2D
		t.modulate.a = 0.55 + 0.25 * sin(_bob_t * 13.0 + i * 2.1)
		t.scale = Vector2.ONE * (0.9 + 0.15 * sin(_bob_t * 9.0 + i * 1.7))


## ---- 技能 A：电浆弹雨 ----

func _begin_skill_a() -> void:
	_bstate = ST_RAIN_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_rain_warn.warn() # 预警统一入口：肩部 Pod 闪光 + 警告音（炮口留给直射）


## RAIN 式出膛节拍：蓄力结束首发即出，逐孔轮发（4 仓=一轮 1:1，二阶段 +2 回绕）。
## 垂发姿态：近乎竖直、朝玩家一侧微倾——弹体姿态沿它不动，动量继承机体速度
## （_vel）；拱顶与追踪由导弹自理（同 ch1 弹雨账）。
func _launch_ticker(delta: float) -> void:
	if _rain_launched >= _rain_count():
		return
	_launch_t -= delta
	if _launch_t > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var ports := _visuals.get_node("MissilePorts").get_children()
	var from := (ports[_rain_launched % ports.size()] as Node2D).global_position
	var lean := signf(player.global_position.x - from.x)
	var dir := (Vector2.UP + Vector2(0.28 * lean, 0.0)).normalized()
	dir = dir.rotated(deg_to_rad(randf_range(-BalanceCombat.HEAVY_MISSILE_SPREAD_DEG,
			BalanceCombat.HEAVY_MISSILE_SPREAD_DEG)))
	var missile := PlasmaMissile.new()
	missile.damage = BalanceWorld3.SENTINEL_RAIN_DAMAGE
	missile.blast_radius = BalanceWorld3.SENTINEL_RAIN_BLAST_RADIUS
	container.add_child(missile)
	missile.launch(terrain, from, dir, true, _vel)
	_rain_launched += 1
	_launch_t = BalanceWorld3.SENTINEL_RAIN_STAGGER
	Sfx.play(&"fire_enemy") # 占位发射声（暂用敌枪声，电浆音效后续单独配方）


## ---- 技能 B：浮雷封锁（一次性齐撒） ----

func _begin_skill_b() -> void:
	_bstate = ST_MINE_WARN
	_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
	_bay_warn.warn() # 预警统一入口：布雷舱闪光 + 警告音


## 齐撒：基点同一瞬间读定（按玩家速度外推承诺带），全数同帧出舱——带内按序位
## 铺开，各自抛送入位。空中是"一把撒开的雷幕"，与臼炮的逐孔哨节拍彻底分家。
func _dispense_salvo() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var terrain := get_tree().get_first_node_in_group("terrain") as Terrain
	var container := get_tree().get_first_node_in_group("projectile_container")
	if player == null or terrain == null or container == null:
		return
	var base := PlasmaMine.fence_base_x(player, BalanceWorld3.SENTINEL_MINE_FLIGHT,
			BalanceWorld3.SENTINEL_MINE_LEAD_MIN, BalanceWorld3.SENTINEL_MINE_LEAD_MAX)
	for i in _mine_count():
		var x := base + i * BalanceWorld3.PLASMA_MINE_FENCE_SPACING
		var target := Vector2(x, terrain.surface_y_at(x)
				- BalanceWorld3.PLASMA_MINE_HOVER_CLEAR)
		var mine := PlasmaMine.new()
		container.add_child(mine)
		mine.launch(terrain, _bay_port.global_position, target,
				BalanceWorld3.SENTINEL_MINE_FLIGHT)
		Sfx.play(&"fire_enemy") # 占位发射声（暂用敌枪声，布雷音效后续单独配方）
	_bay_flash.fire(deg_to_rad(90.0)) # 出舱焰朝下（腰部开口往下撒）


## ---- 普攻：电浆枪直射 ----

func _begin_direct() -> void:
	_bstate = ST_DIRECT
	_bt = BalanceCombat.BOSS_DIRECT_DURATION
	_direct_shoot_t = 0.0 # 首发即出


## ---- 主循环 ----

func _tick_attack(delta: float) -> void:
	if _bstate == ST_RECOVER:
		super(delta)
		return
	match _bstate:
		ST_RAIN_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_RAIN_FIRE
				_rain_launched = 0
				_launch_t = 0.0
				_bt = BalanceCombat.HEAVY_MISSILE_TRACK_MAX + 0.8 # 全部出膛+追踪窗口
		ST_RAIN_FIRE:
			_launch_ticker(delta)
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld3.SENTINEL_RAIN_RECOVER)
		ST_MINE_WARN:
			_bt -= delta
			if _bt <= 0.0:
				_bstate = ST_MINE_FIRE
				_dispense_salvo()
				_bt = BalanceWorld3.SENTINEL_MINE_FLIGHT + 0.35 # 抛送+入位窗口
		ST_MINE_FIRE:
			_bt -= delta
			if _bt <= 0.0:
				_enter_recover(BalanceWorld3.SENTINEL_MINE_RECOVER)
		ST_DIRECT:
			_bt -= delta
			_direct_shoot_t -= delta
			if _direct_shoot_t <= 0.0:
				var player := get_tree().get_first_node_in_group("player") as Player
				if player != null:
					_fire_direct_shot(_muzzle.global_position.direction_to(
							player.global_position))
				_direct_shoot_t = BalanceCombat.BOSS_SWEEP_FIRE_INTERVAL
			if _bt <= 0.0:
				_enter_recover(BalanceCombat.BOSS_DIRECT_RECOVER)


## 直瞄单发：电浆矢弹真从炮口出膛、朝玩家当前位置（无预判）；弹是 bullet.gd
## 纯换皮（速度/伤害复用 BOSS_SWEEP_*），命中迸溅染冰蓝。
func _fire_direct_shot(dir: Vector2) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var b := PLASMA_BOLT.instantiate() as Bullet
	b.speed = BalanceCombat.BOSS_SWEEP_SPEED
	b.damage = BalanceCombat.BOSS_SWEEP_DAMAGE
	b.impact_tint = Color(0.5, 0.8, 1.0)
	b.setup(dir, Vector2.ZERO)
	container.add_child(b)
	b.global_position = _muzzle.global_position
	b.reset_physics_interpolation()
	_muzzle_flash.fire(dir.angle())
	Sfx.play(&"fire_enemy")


## 压招期间断掉的预警，回距重走完整程——预警只认发射器，压掉的半截不算数。
func _rewarn_after_hold() -> void:
	match _bstate:
		ST_RAIN_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_rain_warn.warn()
		ST_MINE_WARN:
			_bt = BalanceCombat.HEAVY_GUN_WARN_TIME
			_bay_warn.warn()
		_:
			pass


func _reset_warnings() -> void:
	_rain_warn.reset()
	_bay_warn.reset()
	_warn.reset()


## ---- 二阶段数值 ----

func _rain_count() -> int:
	return BalanceWorld3.SENTINEL_RAIN_COUNT + (BalanceWorld3.SENTINEL_PHASE2_RAIN_BONUS if _phase2 else 0)


func _mine_count() -> int:
	return BalanceWorld3.SENTINEL_MINE_COUNT + (BalanceWorld3.SENTINEL_PHASE2_MINE_BONUS if _phase2 else 0)
