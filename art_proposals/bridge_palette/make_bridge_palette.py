# -*- coding: utf-8 -*-
"""高架桥配色提案：P0 基线图上精确替换桥 4 色 + 柱描边，出前后对比与局部放大。

改动逻辑（明度阶梯重排，玩家 L50 ↔ 雾后中景楼 L107 之间单调排开）：
  柱体   #3d3a32 L58 → #645d4c L93  （用户方向：柱变淡；柱是跑桥下必叠的竖条）
  下暗缘 #37352d L53 → #453f35 L64  （不再与玩家 L50 撞）
  板身   #46433a L67 → #504b40 L75  （微提）
  上亮缘 #5a574b L87 → 不动          （工作正常）
  新增：柱 1.5px #3d3a32 描边（老柱色复用作描边，把 L93 柱体从 L107 雾后楼里勾出来）
"""
import pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "autotest_shots" / "readability_p0.png"
OUT = ROOT / "art_proposals" / "bridge_palette"

REPLACE = {
    (0x3D, 0x3A, 0x32): (0x64, 0x5D, 0x4C),  # 柱体
    (0x37, 0x35, 0x2D): (0x45, 0x3F, 0x35),  # 下暗缘
    (0x46, 0x43, 0x3A): (0x50, 0x4B, 0x40),  # 板身
}
PIER_OLD = (0x3D, 0x3A, 0x32)  # 描边色复用老柱色
PIER_NEW = (0x64, 0x5D, 0x4C)
MIST = (0xCA, 0xBB, 0x8E)  # mid.svg 内置雾色：柱区实测是「柱色→雾色」混合线（t 0~0.15），
# 实装 AerialFog 后柱仍会被雾按同方式洗，按混合线映射 = 预演实装观感
TOL = 3   # 桥面平涂替换用精确匹配
TOL_PIER = 30  # 柱检测用宽域（覆盖混合线）


def close(c, ref, tol=TOL):
    return all(abs(a - b) <= tol for a, b in zip(c, ref))


def mix_t(c):
    """像素在 3d3a32→cabb8e 混合线上的参数 t，残差过大返回 None。"""
    d = tuple(ci - pi for ci, pi in zip(MIST, PIER_OLD))
    n2 = sum(v * v for v in d)
    t = sum((ci - pi) * di for ci, pi, di in zip(c, PIER_OLD, d)) / n2
    if not (0.0 <= t <= 0.30):
        return None
    recon = tuple(pi + t * di for pi, di in zip(PIER_OLD, d))
    if sum((a - b) ** 2 for a, b in zip(c, recon)) > 40:
        return None
    return t


def find_pier_boxes(img):
    """两阶段定位：完全精确色（==，连 TOL=3 都不行——地块底部暗填充渐变恰在
    柱色 ±3 内会连成整幅）列内计数 ≥30 找柱心列，聚组后 y 取组内极值，
    自动涵盖被雾洗的柱段。组宽 8~44 过滤桥面混色横条假阳性。"""
    w, h = img.size
    px = img.load()
    cols = {}
    for x in range(0, w, 2):
        ys = [y for y in range(h) if px[x, y][:3] == PIER_OLD]
        if len(ys) >= 30:
            cols[x] = (min(ys), max(ys))
    boxes = []
    xs = sorted(cols)
    group = []
    for x in xs:
        if group and x - group[-1] <= 4:
            group.append(x)
        else:
            if group:
                boxes.append(group)
            group = [x]
    if group:
        boxes.append(group)
    out = []
    for g in boxes:
        if not (8 <= g[-1] - g[0] + 2 <= 44):
            continue
        y0 = min(cols[x][0] for x in g)
        y1 = max(cols[x][1] for x in g)
        out.append((g[0], y0, g[-1], y1))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    base = Image.open(SRC).convert("RGB")
    piers = find_pier_boxes(base)
    print("pier boxes:", piers)

    replaced = base.copy()
    px = replaced.load()
    w, h = replaced.size
    # 桥面行定位：板身 #46433a 的行直方图（桥面条带宽 480px/块，行计数远高于偶发像素）。
    # 下暗缘 #37352d 与地块暗条纹同色，全图替换会误伤地块——桥面色只在桥面行内替换。
    deck_rows = set()
    for y in range(h):
        n = sum(1 for x in range(0, w, 2) if px[x, y][:3] == (0x46, 0x43, 0x3A))
        if n >= 100:
            deck_rows.update(range(max(0, y - 2), min(h, y + 3)))
    # 桥面平涂替换（仅桥面行）
    for y in deck_rows:
        for x in range(w):
            c = px[x, y][:3]
            for src, dst in REPLACE.items():
                if close(c, src):
                    px[x, y] = dst
                    break
    # 柱区按混合线映射：被雾洗 t 的老柱色 → 被雾洗 t 的新柱色
    for (x0, y0, x1, y1) in piers:
        for y in range(max(0, y0), min(h, y1 + 1)):
            for x in range(max(0, x0 - 2), min(w, x1 + 3)):
                t = mix_t(px[x, y][:3])
                if t is not None:
                    px[x, y] = tuple(round(pi + t * (mi - pi)) for pi, mi in zip(PIER_NEW, MIST))

    # 柱描边：替换后的柱 bbox 外扩 2px 画老柱色线框（顶边与桥下暗缘重合，无碍）
    draw = ImageDraw.Draw(replaced)
    for (x0, y0, x1, y1) in piers:
        draw.rectangle([x0 - 2, y0 - 1, x1 + 2, y1 + 2], outline=PIER_OLD, width=2)
    # 箱子叠在柱前（ScrollObjects 后画），描边矩形会画穿——把箱子色像素从原图拷回
    CRATE = [(0x7A, 0x55, 0x27), (0x6F, 0x4D, 0x22), (0xB9, 0x8A, 0x4E),
             (0xA2, 0x74, 0x3F), (0xA1, 0x88, 0x7F)]
    pb = replaced.load()
    ob = base.load()
    for y in range(h):
        for x in range(w):
            if any(ob[x, y][:3] == c for c in CRATE):
                pb[x, y] = ob[x, y]

    replaced.save(OUT / "bridge_after.png")

    # ---- 前后对照 + 局部放大（规整网格：上排全图前后，下排 pier/enemy 局部前后）----
    def zoom(im, box, f=2):
        crop = im.crop(box)
        return crop.resize((crop.width * f, crop.height * f), Image.NEAREST)

    px_, py_, _, _ = piers[len(piers) // 2]
    zb = (max(0, px_ - 70), max(0, py_ - 40), min(base.width, px_ + 70), min(base.height, py_ + 100))

    # 敌人叠桥局部（红色定位）
    ex = None
    px0 = base.load()
    for y in range(0, base.height, 2):
        for x in range(0, base.width, 2):
            if close(px0[x, y][:3], (0xFF, 0x51, 0x40), 40):
                ex = (x, y)
                break
        if ex:
            break
    ze = None
    if ex:
        ze = (max(0, ex[0] - 110), max(0, ex[1] - 70),
              min(base.width, ex[0] + 110), min(base.height, ex[1] + 90))

    CW, CH, LBL = 780, 352, 22
    CW2 = (CW * 2 + 8) // 2 - 4
    grid = Image.new("RGB", (CW * 2 + 8, LBL + CH + 8 + LBL + CH + 8), (12, 12, 12))
    d = ImageDraw.Draw(grid)
    cells = [
        (base.resize((CW, CH)), "BEFORE  current colors"),
        (replaced.resize((CW, CH)), "AFTER  pier 58->93 + outline / lower edge 53->64 / body 67->75"),
        (zoom(base, zb).resize((CW2, CH)), "BEFORE pier close-up"),
        (zoom(replaced, zb).resize((CW2, CH)), "AFTER pier close-up"),
    ]
    if ze:
        cells += [
            (zoom(base, ze).resize((CW2, CH)), "BEFORE enemy on deck"),
            (zoom(replaced, ze).resize((CW2, CH)), "AFTER enemy on deck"),
        ]
    row2 = LBL + CH + 8 + LBL
    pos = [(0, LBL), (CW + 8, LBL), (0, row2), (CW2 + 8, row2),
           (CW2 * 2 + 16, row2), (CW2 * 3 + 24, row2)]
    for i, (im, cap) in enumerate(cells[:6]):
        x, y = pos[i]
        grid.paste(im, (x, y))
        d.rectangle([x, y - LBL, x + CW2, y], fill=(24, 24, 22))
        d.text((x + 8, y - LBL + 5), cap, fill=(235, 230, 214))
    grid.save(OUT / "bridge_compare.png")
    print("saved", OUT / "bridge_after.png", OUT / "bridge_compare.png")


if __name__ == "__main__":
    main()
