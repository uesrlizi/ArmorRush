class_name BalanceMods
## 轻肉鸽装备调参：槽位/成员定义正本——BOSS 概率爆装备（design/run_loop.md §4）。
## 只在这里改数值与颜色，场景和脚本不保存副本（同 balance/ 拆分惯例）；
## 槽位/成员的查表与换算在 RunState（mods_* 段），本文件保持纯数据。
## 加槽先加通道（槽位上限=可辨通道数）；加成员=在本表加一项，别处零改动。
## 成员字段：
##   slot   —— 所属槽位（SLOTS 之一）
##   label  —— 结算拾取清单用的名字（战斗内零文字，只上结算）
##   tint   —— 成员色：掉落小件的 tint = 到手后通道的预告色（颜色即预告）
##   stats  —— 数值账（StringName -> float），消费点经 RunState.mod_stat 读；
##             键全游戏唯一（按域命名），Balance* 里的同名常量=无装备默认值
##   blade/flame/ring —— 通道负载（刃光四色/焰三层色/护盾环色），可选
## 机动红线（不进池）：跳跃初速、最大上升速度；容量=黄线（±0.3s 内）；
## 枪曳光色相留黄色族（敌我共弹语言）；刃光保两段相对色差；突进速度不动。
# ---- 通道常量（成员共用的表现/弹道参数） ----
const TWIN_TRACER_GAP := 14.0        # 双曳光两发的垂向错距（px，同道齐射读法）
const POD_BULLET_SPEED_SCALE := 0.8  # 肩炮弹速 = 主枪弹速 ×此系数（副炮读得出是另一门）
const POD_BULLET_SCALE := 0.6        # 肩炮弹体缩放（复用主枪弹场景，小一号=副炮）
const POD_BULLET_IMPACT := 2.0       # 肩炮弹冲击值（主枪 8：副炮不抢近战打失衡的主位）
const POD_SCATTER_DEG := 12.0        # 霰副炮多发的相邻散角（度）
const POD_FIRE_SFX_STRENGTH := 0.6   # 肩炮开火声强度（主枪全档；副炮压低不刷屏）
const SHIELD_RING_ALPHA_MIN := 0.45  # 护盾环残盾时的不透明度（满盾 1.0：盾量即亮度）
# ---- 槽位（同槽位不爆：掉落时从未持有槽掷） ----
const SLOTS: Array[StringName] = [
	&"gun",      # 枪（机炮）—— 曳光亮/粗/道数
	&"blade",    # 刀 —— 刃光整套转色+形
	&"back",     # 背部推进 —— 主焰色（只碰回气侧）
	&"leg",      # 腿部推进器 —— 姿控焰色（腰/腿两套焰件一起 tint）
	&"armor",    # 装甲 —— 头顶血条加宽
	&"shield",   # 护盾 —— 机体外缘平涂环（2026-11-08 定案：一次性吸收，转场满血回充）
	&"shoulder", # 肩部武器 —— 背挂副炮+第二弹道（同日定案入池）
]
const MEMBERS := {
	&"gun_whitehot": {
		"slot": &"gun", "label": "白热", "tint": Color(1.0, 0.93, 0.72),
		"stats": {&"fire_cooldown": 0.18},
	},
	&"gun_piercing": {
		"slot": &"gun", "label": "穿甲", "tint": Color(1.0, 0.83, 0.24),
		"stats": {&"bullet_impact": 11.0, &"bullet_knockback_scale": 1.4},
	},
	&"gun_twin": {
		"slot": &"gun", "label": "双曳光", "tint": Color(1.0, 0.72, 0.18),
		"stats": {&"bullet_damage": 3.0, &"bullet_impact": 4.0},
	},
	&"blade_crimson": {
		"slot": &"blade", "label": "绯红", "tint": Color(1.0, 0.31, 0.44),
		"stats": {&"melee_damage_1": 19.0, &"melee_damage_2": 29.0},
		"blade": {
			"core1": Color(1.0, 0.89, 0.92), "outer1": Color(1.0, 0.23, 0.36),
			"core2": Color(1.0, 0.82, 0.85), "outer2": Color(0.85, 0.12, 0.27),
		},
	},
	&"blade_gild": {
		"slot": &"blade", "label": "鎏金", "tint": Color(1.0, 0.81, 0.30),
		"stats": {&"melee_combo_window": 0.95, &"melee_recover_2": 0.5},
		"blade": {
			"core1": Color(1.0, 0.95, 0.81), "outer1": Color(1.0, 0.81, 0.30),
			"core2": Color(1.0, 0.91, 0.68), "outer2": Color(0.91, 0.63, 0.12),
		},
	},
	&"blade_shade": {
		"slot": &"blade", "label": "疾影", "tint": Color(0.62, 0.85, 1.0),
		"stats": {
			&"melee_windup_time": 0.16, &"melee_windup_combo_time": 0.04,
			&"melee_recover_1": 0.16, &"melee_recover_2": 0.48,
		},
		"blade": {
			"core1": Color(0.93, 0.97, 1.0), "outer1": Color(0.50, 0.82, 1.0),
			"core2": Color(0.86, 0.94, 1.0), "outer2": Color(0.30, 0.62, 0.85),
		},
	},
	&"back_cyan": {
		"slot": &"back", "label": "青焰", "tint": Color(0.35, 0.92, 0.85),
		"stats": {&"boost_regen_per_sec": 2.5},
		"flame": [Color(0.10, 0.85, 0.78), Color(0.45, 0.95, 0.88), Color(0.85, 1.0, 0.97)],
	},
	&"back_deuterium": {
		"slot": &"back", "label": "重氢白焰", "tint": Color(0.88, 0.93, 1.0),
		"stats": {&"boost_capacity": 2.8},
		"flame": [Color(0.82, 0.88, 1.0), Color(0.92, 0.95, 1.0), Color(1.0, 1.0, 1.0)],
	},
	&"leg_violet": {
		"slot": &"leg", "label": "紫焰", "tint": Color(0.72, 0.47, 0.96),
		"stats": {&"boost_regen_delay_air": 0.15},
		"flame": [Color(0.63, 0.36, 0.94), Color(0.78, 0.59, 1.0), Color(0.95, 0.89, 1.0)],
	},
	&"armor_plate": {
		"slot": &"armor", "label": "装甲板", "tint": Color(0.56, 0.72, 0.80),
		"stats": {&"max_hp_bonus": 25.0, &"hp_bar_width": 84.0},
	},
	&"shield_phase": {
		"slot": &"shield", "label": "相位盾", "tint": Color(0.49, 0.91, 0.78),
		"stats": {&"shield_capacity": 30.0},
		"ring": Color(0.49, 0.91, 0.78),
	},
	&"shield_composite": {
		"slot": &"shield", "label": "复合盾", "tint": Color(0.42, 0.68, 0.98),
		"stats": {&"shield_capacity": 22.0, &"shield_guard_time": 0.4},
		"ring": Color(0.42, 0.68, 0.98),
	},
	&"shoulder_tracer": {
		"slot": &"shoulder", "label": "曳光副炮", "tint": Color(1.0, 0.9, 0.35),
		"stats": {&"pod_cooldown": 0.45, &"pod_damage": 3.0},
	},
	&"shoulder_scatter": {
		"slot": &"shoulder", "label": "霰副炮", "tint": Color(1.0, 0.8, 0.42),
		"stats": {&"pod_cooldown": 0.6, &"pod_damage": 2.0, &"pod_shots": 2.0},
	},
}
