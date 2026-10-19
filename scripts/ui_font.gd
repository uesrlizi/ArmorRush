class_name UIFont
## UI 中文打包字体：思源黑体子集（tools/subset_font.py 生成，285KB，SIL OFL 可分发）。
## 为什么必须打包：Web 导出在浏览器沙箱里拿不到系统字体，SystemFont 按名
## 找微软雅黑会全部落空；内置默认字体又没有 CJK 字形——中文全是豆腐块。
## 子集只含工程文本（scripts/data/scenes）出现过的字符：改了界面文案或播报
## 台词后要重跑 `py -3 tools/subset_font.py`，缺的字在 Web 端没有兜底。

const FONT_PATH := "res://assets/fonts/ui_cjk.ttf"

static var _font: Font


static func cjk() -> Font:
	if _font == null:
		var packed: FontFile = load(FONT_PATH)
		# 系统字体挂 fallback：桌面端撞到子集外的字仍能兜底显示；
		# Web 端拿不到系统字体，这条 fallback 无效——以重跑子集脚本为准。
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray([
			"Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Arial",
		])
		packed.fallbacks = [sys]
		_font = packed
	return _font
