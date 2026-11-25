# -*- coding: utf-8 -*-
"""敌方推进件公共素材：火箭推进焰（灰度，modulate 染色）。
产物 assets/common/thruster_flame.svg；各 BOSS 的推进接线见
_更改日志_BOSS形态.md 02/05~08 节。ThorVG 硬约束：无 filter/pattern/use/text/
transform（plain rect/polygon 可用）。

**悬浮推进定案（2026-11-11 八轮，用户拍板）**：全表 BOSS 悬浮=火箭焰，喷口
朝下（哨兵）或朝运动方向（截击机仅冲撞期点火）。螺旋桨/风扇装饰件三连败
废弃不留档（05 像特效→06 画的什么玩意→07 侧视不成立+丑）；下洗粒子同轮否决
（全局空间粒子随载体移动读成拖尾；若将来做气流类粒子必须 local_coords=true，
教训在 fx-method 记忆）。焰形=玩家机甲 ThrusterFlame 同款标准：三层等腰锥、
**平根贴喷口、向尾收尖、无根尖**（根带尖=「火焰往回扎进喷口」），无马赫环。
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..")))
from generate_proposals import Svg, f  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "common"))


def save(s, name, comment):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(s.w)} {f(s.h)}" '
           f'width="{f(s.w)}" height="{f(s.h)}">\n<!-- {comment.strip()} -->\n<defs>\n'
           + "\n".join(s.defs) + "\n</defs>\n" + "\n".join(s.body) + "\n</svg>\n")
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fp:
        fp.write(svg)
    print(name)


def thruster_flame():
    """推进焰 40x64，焰朝 +Y，喷口=画布顶平根 y6（宽 15）。玩家机甲
    ThrusterFlame._draw_cone 同款三层等腰锥比例（外/中/芯=1/0.79/0.52 长，
    逐层收窄），平根无根尖、无马赫环。灰度实色，颜色全交节点 modulate 染；
    EnemyThrusterFlame 脚本驱动闪燃+速度拉长。焰根=节点上方 (32-6)=26×scale。"""
    s = Svg(40, 64)
    # 外层锥（半宽 7.5，长 52）
    s.poly([(12.5, 6), (27.5, 6), (20, 58)], "#9a9a9a", 0.5)
    # 中层锥（半宽 4.8，长 41）
    s.poly([(15.2, 6), (24.8, 6), (20, 47)], "#c6c6c6", 0.68)
    # 白热芯（半宽 2.6，长 27）
    s.poly([(17.4, 6), (22.6, 6), (20, 33)], "#f2f2f2", 0.95)
    return s


if __name__ == "__main__":
    save(thruster_flame(), "thruster_flame.svg",
         "敌方推进焰 40x64，焰朝 +Y，喷口=顶平根 y6；三层等腰锥（玩家焰标准，"
         "平根无根尖无马赫环）；颜色=节点 modulate 染；EnemyThrusterFlame"
         "（scripts/units/enemy_thruster_flame.gd）驱动闪燃+速度拉长+enabled 开关。")
