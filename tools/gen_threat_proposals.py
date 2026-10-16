# -*- coding: utf-8 -*-
"""威胁警告音提案工场（AC6 式两声滴滴）：生成多版本候选 + 试听页。

【已退役留档】选型结果：A 标准款音色 × 双声，已定稿为 gen_sfx.py 的
threat_warn()（声 90ms、声间静 250ms=循环节奏，尾静 250ms），接线
elite_mortar 齐射预警 / boss 弹雨预警。本脚本不再维护。
已知 bug（退役时未修）：make_warn 每对只生成一声——当年提案页里听到的
"单对/双对"实为对应声数的循环听感，定稿以 gen_sfx.py 为准。

跑法：  py -3 tools/gen_threat_proposals.py
产物：  assets/sfx_proposals/threat_<版号>_<名>.wav
试听：  本地起 py -3 -m http.server 8931 后开 design/proposals/threat_listen.html
        （内嵌浏览器 file:// 拦本地音频；页面相对路径以页面目录算，别改错层级）

背景参考（搜索到的定性信息，无精确频率）：AC6 的警告音是 RWR（雷达警告
接收器）风格——"beep"=锁定、"chirp"=导弹锁定，功能是"大当量来袭弹，快躲"。
本工场按设计空间铺版本：波形（方波/失谐蜂鸣/加谐波）、音高（850–2200Hz）、
节奏（单对/双对/四连发）、走向（同高/微降）。定稿后把选中配方搬进
gen_sfx.py 正式清单（本脚本即退役）。
"""

import cmath
import math
import random
import struct
import wave
import zlib
from pathlib import Path

SR = 44100
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sfx_proposals"
MASTER_PEAK = 0.9


def square_wave(f, n, detune_hz=0.0, h2=0.0):
    """有限项方波（奇次 1,3,5,7，幅度 1/k）——比 sign() 柔和一点不失蜂鸣感。
    detune_hz 给出则叠加失谐第二振荡（拍频=机械蜂鸣质感）。h2 为二次谐波量
    （偶次让低频款更"喇叭"）。"""
    out = []
    ph1 = ph2 = 0.0
    for i in range(n):
        ph1 += 2.0 * math.pi * f / SR
        v = sum(math.sin(k * ph1) / k for k in (1, 3, 5, 7))
        v *= 4.0 / math.pi
        if detune_hz > 0.0:
            ph2 += 2.0 * math.pi * (f + detune_hz) / SR
            v += sum(math.sin(k * ph2) / k for k in (1, 3, 5, 7)) * 4.0 / math.pi
            v *= 0.5
        if h2 > 0.0:
            v += h2 * math.sin(2.0 * ph1)
        out.append(v)
    return out


def make_warn(f, tone_ms, gap_ms, pairs, detune_hz=0.0, h2=0.0,
              f_second=None, pair_rest_ms=200.0):
    """两声滴滴骨架：每对 = 声(tone_ms) + 间隔(gap_ms) + 声；
    多对时对间停 pair_rest_ms。f_second 给出则第二声变调（微降/微升）。"""
    tones = []
    rest = int(pair_rest_ms / 1000.0 * SR)
    for p in range(pairs):
        tone = int(tone_ms / 1000.0 * SR)
        gap = int(gap_ms / 1000.0 * SR)
        f2 = f if f_second is None else f_second
        tones.append((tone, f))
        tones.append((gap, 0))  # 间隔
        if p < pairs - 1:
            tones.append((rest, 0))
        f = f2  # 第二对起用第二声频率（微降款的单对也走 f_second）
        f_second = None
    total = sum(n for n, _ in tones)
    out = [0.0] * (total + int(0.12 * SR))  # 尾部留 120ms 衰减空间
    at = 0
    for n, fq in tones:
        if fq > 0.0:
            piece = square_wave(fq, n, detune_hz, h2)
            fade = int(0.005 * SR)  # 5ms 边缘消咔哒
            for i in range(min(fade, n)):
                w = i / fade
                piece[i] *= w
                piece[-1 - i] *= w
            for i, s in enumerate(piece):
                out[at + i] += s
        at += n
    peak = max(abs(min(out)), abs(max(out)), 1e-9)
    return [s * (MASTER_PEAK / peak) for s in out]


VERSIONS = [
    ("threat_a_classic", "标准款：1.5kHz 方波，90ms/隔130ms 单对",
     dict(f=1500.0, tone_ms=90, gap_ms=130, pairs=1)),
    ("threat_b_beat", "蜂鸣款：失谐双振荡（7Hz 拍频）= 机械蜂鸣器质感",
     dict(f=1500.0, tone_ms=90, gap_ms=130, pairs=1, detune_hz=7.0)),
    ("threat_c_urgent", "急促款：2.2kHz 短声快隔（65/85ms），高威胁感",
     dict(f=2200.0, tone_ms=65, gap_ms=85, pairs=1)),
    ("threat_d_heavy", "低沉款：850Hz+二次谐波（喇叭感），重型威胁",
     dict(f=850.0, tone_ms=110, gap_ms=150, pairs=1, h2=0.5)),
    ("threat_e_drop", "降调款：两声 1500→1280Hz，威胁确认的落定感",
     dict(f=1500.0, f_second=1280.0, tone_ms=90, gap_ms=130, pairs=1)),
    ("threat_f_double", "双对款：哔哔-停-哔哔（蜂鸣配方），测循环听感",
     dict(f=1500.0, tone_ms=90, gap_ms=130, pairs=2, detune_hz=7.0)),
    ("threat_g_burst", "连发款：1.8kHz 四连发（55/70ms），导弹来袭 RWR",
     dict(f=1800.0, tone_ms=55, gap_ms=70, pairs=4)),
]


def write_wav(path, x):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in x:
            s = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(round(s * 32767.0)))
        w.writeframes(bytes(frames))


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"提案输出到 {OUT_DIR}")
    for name, desc, kw in VERSIONS:
        random.seed(zlib.crc32(name.encode("utf-8")))  # 提案同种子纪律
        x = make_warn(**kw)
        write_wav(OUT_DIR / f"{name}.wav", x)
        print(f"  {name}.wav  {len(x)/SR:.2f}s  {desc}")
    print("完成。试听：design/proposals/threat_listen.html")


if __name__ == "__main__":
    main()
