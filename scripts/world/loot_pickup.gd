class_name LootPickup
extends Node2D
## 装备芯片（design/run_loop.md §4）：BOSS 终爆那一拍从爆点弹出的掉落件。
## 对角双切深色方牌 + 槽位图标 ×成员色（形状=哪类零件、颜色=哪个成员，颜色即预告），
## 全程直立不翻滚（图标要可读）。一条连续弧：朝玩家定速斜抛 → 后程渐混吸附到身上
## ——实际必捡（禁「躲弹漏捡」双随机叠加），玩家跑动也照收，往前迎上去收得更快。
## 授予=RunState.equip + Player.apply_mod（通道当场换色=公告）+ HUD 拾取播报
## （图标飞入左上装备栏+「成员名 效果」行）+ 物品音 + 成员色爆闪。
## 转场兜底：Main 在抽关/通关结算前调 collect_in_flight() 把在途件就地授予
## ——掉落一次都不许丢。由 Main 以 .new() 生成（纯代码构建，同 SlagPool 惯例），
## 不池化（授予即灭）。玩家死亡时不授予也不追人（本局已结束）。
## 授予时芯片出残影原地快淡：转场兜底授予时芯片可能离玩家很远，授予闪光在玩家
## 身上接不住它（消失承接规范 design/worlds.md §4c）。

const CHIP_TEXTURE := preload("res://assets/common/loot_chip.svg")
const CHIP_SCALE := 0.46   # 芯片框缩放（贴图 128 画布 → 逻辑 59：底板 43、白边 50，约机体高 0.8）
const GLYPH_SIZE := 33.0   # 芯片上槽位图标边长（逻辑 px；底板 43 的 3/4，四周留边）
const POP_IN_TIME := 0.24 # 芯片亮相回弹（出生一拍）

var member := &"" # 装备成员 id（setup 赋值）

var _launched := false   # 已出手（首物理帧按玩家位置解斜抛初速）
var _granted := false
var _t := 0.0            # 出膛后累计时（渐混权重按飞行时长归一）
var _flight_t := 1.0     # 本次斜抛时长（出手时解算）
var _vel := Vector2.ZERO # 当前合速度（抛体段=初速+重力积分，追踪段=直指玩家）
var _glyph: Sprite2D


## 纯代码构建：先 setup 再入树（同子弹 setup/launch 惯例）。
func setup(member_id: StringName, at: Vector2) -> void:
	member = member_id
	position = at


func _ready() -> void:
	add_to_group("loot_pickups") # 转场兜底按组就地授予
	var chip := Sprite2D.new()
	chip.texture = CHIP_TEXTURE
	chip.scale = Vector2.ONE * CHIP_SCALE
	chip.self_modulate = BalanceMods.MEMBERS[member]["tint"]
	add_child(chip)
	_glyph = Sprite2D.new()
	_glyph.texture = LootIcons.glyph_of(member)
	_glyph.scale = Vector2.ONE * GLYPH_SIZE / float(_glyph.texture.get_width())
	_glyph.self_modulate = BalanceMods.MEMBERS[member]["tint"]
	add_child(_glyph)
	# 亮相回弹一拍（出生即满屏弹跳读法不成立：芯片是小牌，弹跳=二次弹出误读）。
	scale = Vector2.ONE * 0.35
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.12, POP_IN_TIME * 0.55) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, POP_IN_TIME * 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reset_physics_interpolation() # 先定位再入树/入树即定位都要清插值基点，出膛不拖残影


func _physics_process(delta: float) -> void:
	if _granted:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.is_dead():
		return # 本局已结束：不追人不授予，随场景卸载消失（mods 会清，无所谓）
	if not _launched:
		_launch(player)
	_t += delta
	# 混合权重：0.45T 前纯抛体，0.45T→0.9T smoothstep 渐混，之后纯追踪。
	var w := clampf((_t - _flight_t * BalanceGlobal.LOOT_HOME_AT)
			/ (_flight_t * (BalanceGlobal.LOOT_HOME_FULL - BalanceGlobal.LOOT_HOME_AT)), 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	var ballistic := _vel + Vector2(0.0, BalanceGlobal.LOOT_SHOT_GRAVITY * delta)
	var to := player.global_position - global_position
	var speed := clampf(ballistic.length(),
			BalanceGlobal.LOOT_HOME_MIN_SPEED, BalanceGlobal.LOOT_HOME_MAX_SPEED)
	_vel = ballistic.lerp(to.normalized() * speed, w)
	position += _vel * delta
	if global_position.distance_to(player.global_position) <= BalanceGlobal.LOOT_GRAB_RANGE:
		_grant(player)


## 斜抛解：T=BASE+距离/PER 截到 [MIN,MAX]（近距也留够起飞读感、远距不拖节奏）；
## 水平初速=带号距离/T（朝玩家），竖直初速解自 dy = vy·T + ½gT²（T 秒后到玩家当时
## 高度），再钳到弧顶上限——钳过就不强求精确落点，后半程的追踪会接住；轨迹仍是
## 一记朝玩家的抛物线。全程直立（rotation 恒 0，图标可读）。
func _launch(player: Player) -> void:
	_launched = true
	var to := player.global_position - global_position
	_flight_t = clampf(BalanceGlobal.LOOT_FLIGHT_BASE + maxf(absf(to.x), 40.0) / BalanceGlobal.LOOT_FLIGHT_PER,
			BalanceGlobal.LOOT_FLIGHT_MIN, BalanceGlobal.LOOT_FLIGHT_MAX)
	var g := BalanceGlobal.LOOT_SHOT_GRAVITY
	var vy := (to.y - 0.5 * g * _flight_t * _flight_t) / _flight_t
	vy = clampf(vy, -BalanceGlobal.LOOT_SHOT_LIFT_MAX, BalanceGlobal.LOOT_SHOT_LIFT_MAX * 0.6)
	_vel = Vector2(to.x / _flight_t, vy)


## 生效瞬间：装备入表 + 玩家侧通道当场换色/换形（视觉即公告）+ 物品音 + 授予闪光
## + HUD 拾取播报（同一枚图标飞进左上装备栏）。
func _grant(player: Player) -> void:
	if _granted:
		return
	_granted = true
	RunState.equip(member)
	player.apply_mod(member)
	Sfx.play(&"pickup")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("announce_loot"):
		hud.announce_loot(member, get_global_transform_with_canvas().origin)
	_spawn_grant_flash(player)
	# 芯片出残影原地快淡：转场兜底授予时芯片可能离玩家很远，授予闪光在
	# 玩家身上接不住它（消失承接规范 design/worlds.md §4c）
	VanishGhost.spawn_tree(self)
	queue_free()


## 授予闪光：玩家身上一记成员色爆闪（FlashBurst，颜色即公告的最后一拍）。
func _spawn_grant_flash(player: Player) -> void:
	var container := get_tree().get_first_node_in_group("projectile_container")
	if container == null:
		return
	var flash := FlashBurst.new()
	flash.flash_color = BalanceMods.MEMBERS[member]["tint"]
	flash.size_scale = 1.4
	flash.position = player.global_position
	container.add_child(flash)


## 转场兜底（Main 在抽关/通关结算前调）：把场上所有在途件就地授予——
## 掉落不许因为转场时序而丢（禁「躲弹漏捡」之后的第二种丢失）。
static func collect_in_flight() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("loot_pickups"):
		var pickup := node as LootPickup
		if pickup != null and not pickup._granted:
			var player := tree.get_first_node_in_group("player") as Player
			if player != null and not player.is_dead():
				pickup._grant(player)
