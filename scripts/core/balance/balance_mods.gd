class_name BalanceMods
## 轻肉鸽装备调参：槽位/成员定义正本——BOSS 概率爆装备（design/run_loop.md §4）。
## 只在这里改数值与颜色，场景和脚本不保存副本（同 balance/ 拆分惯例）；
## 槽位/成员的查表与换算在 RunState（mods_* 段），本文件保持纯数据。
## 加槽先加通道（槽位上限=可辨通道数）；加成员=在本表加一项，别处零改动。
## 成员字段：
##   slot   —— 所属槽位（SLOTS 之一）
##   label  —— 成员名（拾取播报行与结算拾取清单共用）。命名=零件名词（像一件装备，
##             不是招式/形容词）：长短按需，两字成立就两字（同 BOSS 名「哨兵」），
##             也可以是 AC 式干说明（如「反应装甲」）；名字要能连到成员的视觉通道
##             （推进槽=推进剂种类，焰色即身份证），按名能联系功能。
##   desc   —— 效果短句（拾取播报行名字后面那半句：≤8 字、只说作用不写数字——数字待调参）
##   tint   —— 成员色：掉落芯片的边与图标色 = 到手后通道的预告色（颜色即预告；
##             芯片图标形状=槽位，见 LootIcons）
##   stats  —— 数值账（StringName -> float），消费点经 RunState.mod_stat 读；
##             键全游戏唯一（按域命名），Balance* 里的同名常量=无装备默认值
##   blade/flame/ring —— 通道负载（刃光三段色/焰三层色/护盾环色），可选
## 机动红线（不进池）：跳跃初速、最大上升速度；容量=黄线（±0.3s 内）；
## 枪曳光色相留黄色族（敌我共弹语言）；刃光保相邻段相对色差；突进速度不动。
# ---- 通道常量（成员共用的表现/弹道参数） ----
const TWIN_TRACER_GAP := 14.0        # 双联装两发的垂向错距（px，同道齐射读法）
const SHIELD_RING_ALPHA_MIN := 0.45  # 护盾环残盾时的不透明度（满盾 1.0：盾量即亮度）
const SHIELD_REFORM_TIME := 0.6      # 复层盾：碎盾后再立的时间（次数账走 shield_charges）
const MISSILE_STAGGER := 0.12        # 蜂巢齐射的发间错拍（秒，一窝蜂读法）
const MISSILE_LAUNCH_FAN := 0.30     # 蜂巢齐射相邻两发的出筒张角（弧度，向上扇开）
const RAIL_BOLT_SPEED := 3600.0      # 磁轨弹速（主枪 2400：肉眼读得出是另一门快炮）
const RAIL_AIM_TOLERANCE := 0.20     # 磁轨开火闸：炮身瞄准与目标方向的容差角（弧度）
# ---- 槽位（同槽位不爆：掉落时从未持有槽掷） ----
const SLOTS: Array[StringName] = [
	&"gun",      # 枪（机炮）—— 曳光亮/粗/道数
	&"blade",    # 刀 —— 刃光整套转色+形
	&"boost",    # 推进 —— 主焰+姿控焰两套焰件一起 tint（背推/腿推合并槽）
	&"armor",    # 装甲 —— 头顶血条加宽
	&"shield",   # 护盾 —— 机体外缘平涂环（一次性吸收，转场满血回充）
	&"shoulder", # 肩部武器 —— 越肩大件：固定支架+可动轴瞄准（导弹舱/磁轨炮）
]
const MEMBERS := {
	# ---- 枪（机炮）：曳光亮/粗/道数；成员色全在黄色族（敌我共弹语言红线） ----
	&"gun_rapid": {
		"slot": &"gun", "label": "弹链", "desc": "射速提升", "tint": Color(1.0, 0.93, 0.72),
		"stats": {&"fire_cooldown": 0.18},
	},
	&"gun_ap": {
		"slot": &"gun", "label": "穿甲弹", "desc": "冲击与击退提升", "tint": Color(1.0, 0.83, 0.24),
		"stats": {&"bullet_impact": 11.0, &"bullet_knockback_scale": 1.4},
	},
	&"gun_twin": {
		"slot": &"gun", "label": "双联装", "desc": "双发曳光", "tint": Color(1.0, 0.72, 0.18),
		"stats": {&"bullet_damage": 3.0, &"bullet_impact": 4.0},
	},
	# ---- 刀：刃光三段色（相邻段保色差；第三段只被 三连刃 唤出） ----
	&"blade_heavy": {
		"slot": &"blade", "label": "重刃", "desc": "斩击伤害提升", "tint": Color(1.0, 0.31, 0.44),
		"stats": {&"melee_damage_1": 19.0, &"melee_damage_2": 29.0},
		"blade": {
			"core1": Color(1.0, 0.89, 0.92), "outer1": Color(1.0, 0.23, 0.36),
			"core2": Color(1.0, 0.82, 0.85), "outer2": Color(0.85, 0.12, 0.27),
		},
	},
	&"blade_combo": {
		"slot": &"blade", "label": "三连刃", "desc": "三段连斩", "tint": Color(1.0, 0.81, 0.30),
		"stats": {&"melee_max_stage": 3.0, &"melee_damage_3": 38.0},
		"blade": {
			"core1": Color(1.0, 0.95, 0.81), "outer1": Color(1.0, 0.81, 0.30),
			"core2": Color(1.0, 0.91, 0.68), "outer2": Color(0.91, 0.63, 0.12),
			"core3": Color(1.0, 0.97, 0.88), "outer3": Color(0.95, 0.72, 0.16),
		},
	},
	&"blade_swift": {
		"slot": &"blade", "label": "薄刃", "desc": "出手收手加快", "tint": Color(0.62, 0.85, 1.0),
		"stats": {
			&"melee_windup_time": 0.16, &"melee_windup_combo_time": 0.04,
			&"melee_recover_1": 0.16, &"melee_recover_2": 0.48,
		},
		"blade": {
			"core1": Color(0.93, 0.97, 1.0), "outer1": Color(0.50, 0.82, 1.0),
			"core2": Color(0.86, 0.94, 1.0), "outer2": Color(0.30, 0.62, 0.85),
		},
	},
	# ---- 推进（背推+腿推合并槽）：一套成员色同时染主焰与腰/腿姿控焰——成员名=推进剂种类，
	#      焰色即身份证（青焰=液氢淡青焰 / 白蓝焰=甲烷蓝白焰 / 紫焰=离子电推焰）
	&"boost_regen": {
		"slot": &"boost", "label": "液氢", "desc": "推进回气加快", "tint": Color(0.35, 0.92, 0.85),
		"stats": {&"boost_regen_per_sec": 2.5},
		"flame": [Color(0.10, 0.85, 0.78), Color(0.45, 0.95, 0.88), Color(0.85, 1.0, 0.97)],
	},
	&"boost_tank": {
		"slot": &"boost", "label": "甲烷罐", "desc": "推进容量提升", "tint": Color(0.88, 0.93, 1.0),
		"stats": {&"boost_capacity": 2.8},
		"flame": [Color(0.82, 0.88, 1.0), Color(0.92, 0.95, 1.0), Color(1.0, 1.0, 1.0)],
	},
	&"boost_air": {
		"slot": &"boost", "label": "离子喷口", "desc": "空中回气提前", "tint": Color(0.72, 0.47, 0.96),
		"stats": {&"boost_regen_delay_air": 0.15},
		"flame": [Color(0.63, 0.36, 0.94), Color(0.78, 0.59, 1.0), Color(0.95, 0.89, 1.0)],
	},
	# ---- 装甲：上限/减伤，血条加宽 ----
	&"armor_plate": {
		"slot": &"armor", "label": "复合装甲", "desc": "耐久上限提升", "tint": Color(0.56, 0.72, 0.80),
		"stats": {&"max_hp_bonus": 25.0, &"hp_bar_width": 84.0},
	},
	&"armor_reactive": {
		"slot": &"armor", "label": "反应装甲", "desc": "受到伤害降低", "tint": Color(0.88, 0.55, 0.34),
		"stats": {&"damage_taken_scale": 0.75},
	},
	# ---- 护盾：外缘环，一次性吸收（转场回充）；复层盾=两层先后吃，次数有限 ----
	&"shield_wall": {
		"slot": &"shield", "label": "壁垒", "desc": "护盾吸收伤害", "tint": Color(0.49, 0.91, 0.78),
		"stats": {&"shield_capacity": 30.0},
		"ring": Color(0.49, 0.91, 0.78),
	},
	&"shield_reform": {
		"slot": &"shield", "label": "复层盾", "desc": "护盾可吸收两次", "tint": Color(0.42, 0.68, 0.98),
		"stats": {&"shield_capacity": 22.0, &"shield_charges": 2.0},
		"ring": Color(0.42, 0.68, 0.98),
	},
	# ---- 肩部武器：越肩大件（固定支架+可动轴）；成员身份由弹道/发数承担 ----
	&"shoulder_rack": {
		"slot": &"shoulder", "label": "蜂巢", "desc": "齐射三枚导弹", "tint": Color(1.0, 0.62, 0.30),
		"stats": {&"missile_cooldown": 2.4, &"missile_damage": 6.0,
			&"missile_impact": 3.0, &"missile_shots": 3.0},
	},
	&"shoulder_rail": {
		"slot": &"shoulder", "label": "磁轨炮", "desc": "高速磁轨弹", "tint": Color(0.95, 0.95, 0.72),
		"stats": {&"rail_cooldown": 1.3, &"rail_damage": 8.0, &"rail_impact": 16.0},
	},
}
