class_name LootIcons
## 轻肉鸽装备的图形件登记（design/run_loop.md §4）：掉落芯片框 + 6 槽槽位图标。
## 世界掉落件（LootPickup）与 HUD 拾取栏/飞入图标共用同一套贴图——同一枚图标
## 从 BOSS 爆点飞到机体、再飞进左上拾取栏，玩家认的是同一个东西。
## 贴图由 tools/gen_loot_art.py 生成（白=受 tint：芯片与拾取栏里都染成员色）；
## 缩到 0.3~0.5 显示，导入开 mipmap、节点一律 FILTER 用 LINEAR_WITH_MIPMAPS。
## 加槽=生成器加一枚图标 + 这里加一行。

const CHIP := preload("res://assets/common/loot_chip.svg")
const GLYPHS := {
	&"gun": preload("res://assets/common/loot_glyph_gun.svg"),
	&"blade": preload("res://assets/common/loot_glyph_blade.svg"),
	&"boost": preload("res://assets/common/loot_glyph_boost.svg"),
	&"armor": preload("res://assets/common/loot_glyph_armor.svg"),
	&"shield": preload("res://assets/common/loot_glyph_shield.svg"),
	&"shoulder": preload("res://assets/common/loot_glyph_shoulder.svg"),
}


## 槽位图标（未登记的槽返回 null：调用方按「没有图标」降级，不炸）。
static func glyph(slot: StringName) -> Texture2D:
	return GLYPHS.get(slot)


## 成员所属槽位的图标。
static func glyph_of(member: StringName) -> Texture2D:
	return glyph(BalanceMods.MEMBERS[member]["slot"])
