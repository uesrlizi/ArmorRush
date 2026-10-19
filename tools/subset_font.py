# -*- coding: utf-8 -*-
"""生成 UI 中文打包字体（思源黑体子集）。

游戏界面中文一律走 assets/fonts/ui_cjk.ttf（scripts/ui_font.gd 统一取用）。
SystemFont 在 Web 导出里拿不到系统字体（浏览器沙箱），中文会全是豆腐块，
所以字体必须打进游戏。子集只含"代码/播报/场景文本里出现过的字符"——
新增界面文案后重跑本脚本即可（纯本地，秒级，无网络）：

    py -3 tools/subset_font.py

底料 tools/ref_fonts/NotoSansSC-Regular.otf（SIL OFL 协议，可自由分发），
不入库（.gitignore），丢了重下：
    https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCAN_DIRS = ["scripts", "data", "scenes"]
SRC_FONT = ROOT / "tools" / "ref_fonts" / "NotoSansSC-Regular.otf"
OUT_FONT = ROOT / "assets" / "fonts" / "ui_cjk.ttf"
# 兜底字符：常用中文标点 + 全角 ASCII，防止文案微调（换个标点）就缺字。
EXTRA = "、。！？，：；【】（）《》""''…—～·０１２３４５６７８９ＡＢＣ"

def collect_chars() -> str:
    chars = set(EXTRA) | {chr(c) for c in range(0x20, 0x7F)}
    for d in SCAN_DIRS:
        for p in (ROOT / d).rglob("*"):
            if p.is_file() and p.suffix in (".gd", ".json", ".tscn"):
                chars |= set(p.read_text(encoding="utf-8", errors="ignore"))
    return "".join(sorted(chars))

def main() -> None:
    if not SRC_FONT.exists():
        sys.exit(f"底料字体缺失：{SRC_FONT}（见文件头注释的下载地址）")
    text = collect_chars()
    glyph_file = SRC_FONT.with_suffix(".glyphs.txt")
    glyph_file.write_text(text, encoding="utf-8")
    OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        sys.executable, "-m", "fontTools.subset", str(SRC_FONT),
        f"--text-file={glyph_file}", f"--output-file={OUT_FONT}",
        "--desubroutinize", "--drop-tables+=DSIG",
    ], check=True)
    # 验收：子集必须覆盖全部收集字符，缺一个都是隐患。
    from fontTools.ttLib import TTFont
    cmap = TTFont(str(OUT_FONT)).getBestCmap()
    missing = [c for c in text if ord(c) not in cmap and c not in "\n\r\t"]
    kb = OUT_FONT.stat().st_size / 1024
    print(f"ui_cjk.ttf: {kb:.0f} KB, chars={len(set(text))}, missing={missing}")
    if missing:
        sys.exit("子集缺字！检查底料字体或 EXTRA 表")
    glyph_file.unlink()

if __name__ == "__main__":
    main()
