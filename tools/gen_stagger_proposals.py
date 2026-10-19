# -*- coding: utf-8 -*-
"""失衡（STAGGER）音提案工场：AC6 式"敲钢板"基准 + 设计空间铺版本。

跑法：  py -3 tools/gen_stagger_proposals.py
产物：  assets/sfx_proposals/stagger_<版号>_<名>.wav
试听：  本地起 py -3 -m http.server 8931 后开 design/proposals/stagger_listen.html
        （内嵌浏览器 file:// 拦本地音频；页面相对路径以页面目录算）

背景：AC6 失衡确立音是一记大金属撞击——"抡锤敲钢板"：亮瞬态+板鸣+下坠感。
本作只有敌方会失衡（enemy.gd _enter_stagger，视觉=歪一下回正，BOSS 继承），
这声音是"近战爆发窗开启"的确认音。复用 gen_sfx.py 基元与母带链（实录为底
+合成垫纪律不重述，thump 只做质量垫、电子源只做标记层）。全部归一到同一
峰值，页面只比音色与层数。定稿后把选中配方搬进 gen_sfx.py 正式清单。

变调分层设想（接线时用）：杂兵 ×1.05 / 精英 ×1.0 / BOSS ×0.72——
同一配方换算机体体量，页面里 A/B 款带 BOSS 变调示例可听。
"""

import math
import random
import struct
import wave
import zlib
from pathlib import Path

import numpy as np

import gen_sfx as g

SR = g.SR
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sfx_proposals"


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


def tape_bend(x, rate_from, rate_to):
    """磁带降速：回放速率从 rate_from 线性滑到 rate_to——板鸣尾巴连续往下掉，
    读"结构受压垮下去"。起点速率=1 时头部瞬态忠实，无需接缝。"""
    xa = np.asarray(x)
    avg = 0.5 * (rate_from + rate_to)
    n_out = int(len(xa) / avg)
    t = np.linspace(0.0, 1.0, n_out, endpoint=False)
    rate = rate_from + (rate_to - rate_from) * t
    pos = np.cumsum(rate)
    j = pos.astype(np.int64)
    frac = pos - j
    out = xa[j] * (1.0 - frac) + xa[np.minimum(j + 1, len(xa) - 1)] * frac
    return list(out[j < len(xa) - 1])


def make_a(pitch=1.0):
    """A 敲钢板基准款（AC6 直击）：厚板实录降调 + 低频质量垫 + 早期反射。"""
    out = [0.0] * int(0.7 * SR)
    g.mix_at(out, g.load_ref("impactPlate_heavy_004.ogg", 0.8 * pitch), 0.0, 1.0)
    g.mix_at(out, g.thump(120.0 * pitch, 50.0, 0.12, 0.09), 0.0, 0.5)
    out = g.add_space(out, 0.05, 0.15)
    return g.normalize(out)


def make_b(pitch=1.0):
    """B 坍塌双层款：主击 + 110ms 后次级碰撞与垮落噪声尾——机体塌下去的叙事。"""
    out = [0.0] * int(1.0 * SR)
    g.mix_at(out, g.load_ref("impactPlate_heavy_004.ogg", 0.8 * pitch), 0.0, 1.0)
    g.mix_at(out, g.thump(120.0 * pitch, 50.0, 0.12, 0.09), 0.0, 0.5)
    g.mix_at(out, g.load_ref("impactMetal_medium_002.ogg", 0.6 * pitch), 0.11, 0.45)
    n = int(0.45 * SR)
    slump = g.sweep_lowpass(g.brown_noise(n), 800.0, 100.0)
    g.mix_at(out, [slump[i] * math.exp(-i / SR / 0.13) * 0.6 for i in range(n)], 0.12)
    out = g.add_space(out, 0.05, 0.15)
    return g.normalize(out)


def make_c(pitch=1.0):
    """C 降调扭曲款：板鸣尾连续掉速（磁带降速 1.0→0.62）——结构受压下坠。"""
    out = [0.0] * int(1.0 * SR)
    plate = g.load_ref("impactPlate_heavy_000.ogg", 0.82 * pitch)
    g.mix_at(out, tape_bend(plate, 1.0, 0.62), 0.0, 1.0)
    g.mix_at(out, g.thump(120.0 * pitch, 55.0, 0.12, 0.09), 0.0, 0.5)
    out = g.add_space(out, 0.05, 0.15)
    return g.normalize(out)


def make_d(pitch=1.0):
    """D 钟振款：脆短击 + 工业钟长鸣——持续标识，穿透枪声与已有短命中音。"""
    out = [0.0] * int(1.25 * SR)
    g.mix_at(out, g.load_ref("impactPlate_heavy_001.ogg", 0.9 * pitch, keep_s=0.18), 0.0, 0.9)
    g.mix_at(out, g.load_ref("impactBell_heavy_000.ogg", 0.85 * pitch, keep_s=1.2), 0.0, 0.55)
    g.mix_at(out, g.thump(110.0 * pitch, 50.0, 0.12, 0.09), 0.0, 0.45)
    out = g.add_space(out, 0.05, 0.15)
    return g.normalize(out)


def make_e(pitch=1.0):
    """E 电子确认款：主击 + 下行双音 blip——爆发窗开启的 UI 级标记。
    电子源是认可的合成性质；音色与 fcs_tick（3.1kHz 单声）、threat_warn
    （1.5kHz 方波双声）都拉开距离。"""
    out = [0.0] * int(0.8 * SR)
    g.mix_at(out, g.load_ref("impactPlate_heavy_004.ogg", 0.8 * pitch), 0.0, 1.0)
    g.mix_at(out, g.thump(120.0 * pitch, 50.0, 0.12, 0.09), 0.0, 0.5)

    def blip(f0, f1, n):
        piece = []
        ph = 0.0
        for i in range(n):
            t = i / max(n - 1, 1)
            ph += 2.0 * math.pi * (f0 + (f1 - f0) * t) / SR
            e = math.exp(-i / SR / 0.03) * min(i / (0.004 * SR), 1.0)
            piece.append((math.sin(ph) + 0.3 * math.sin(2.0 * ph)) * e)
        return piece

    g.mix_at(out, blip(1320.0, 880.0, int(0.06 * SR)), 0.045, 0.32)
    out = g.add_space(out, 0.05, 0.15)
    return g.normalize(out)


def make_f(pitch=1.0):
    """F 重锤闷击款：钝击为主体 + 亮板瞬态点缀——质量位移感，弱 clang。"""
    out = [0.0] * int(0.9 * SR)
    g.mix_at(out, g.load_ref("impactPunch_heavy_000.ogg", 0.85 * pitch), 0.0, 1.0)
    g.mix_at(out, g.load_ref("impactPlate_heavy_001.ogg", 1.05 * pitch, keep_s=0.12), 0.0, 0.5)
    g.mix_at(out, g.thump(100.0 * pitch, 45.0, 0.16, 0.11), 0.0, 0.6)
    out = g.add_space(out, 0.05, 0.15)
    return g.normalize(out)


def make_b_second(pitch=1.0):
    """拆件试听：B 的第二层单独渲染——次级碰撞 + 垮落噪声尾。
    层内配比与 B 一致（碰撞 0.45 / 噪声尾 0.6，噪声比碰撞晚 10ms），
    在 B 里整体垫在主击后 110ms；单独听时归一峰值。头部加 5ms 起坡
    防孤立播放时的起始咔哒（B 里这层被主击瞬态盖住，无此问题）。"""
    out = [0.0] * int(0.6 * SR)
    g.mix_at(out, g.load_ref("impactMetal_medium_002.ogg", 0.6 * pitch), 0.0, 0.45)
    n = int(0.45 * SR)
    slump = g.sweep_lowpass(g.brown_noise(n), 800.0, 100.0)
    g.mix_at(out, [slump[i]
                   * math.exp(-i / SR / 0.13)
                   * min(i / (0.005 * SR), 1.0)
                   * 0.6 for i in range(n)], 0.01)
    return g.normalize(out)


def make_d_slump(pitch=1.0):
    """组合试听：D 钟振主体 + B 的第二层（110ms 次级碰撞+垮落尾）——
    钟鸣当穿透标识，垮落补"塌下去"的叙事。层配比与 B/D 原样不动。"""
    out = [0.0] * int(1.4 * SR)
    g.mix_at(out, g.load_ref("impactPlate_heavy_001.ogg", 0.9 * pitch, keep_s=0.18), 0.0, 0.9)
    g.mix_at(out, g.load_ref("impactBell_heavy_000.ogg", 0.85 * pitch, keep_s=1.2), 0.0, 0.55)
    g.mix_at(out, g.thump(110.0 * pitch, 50.0, 0.12, 0.09), 0.0, 0.45)
    g.mix_at(out, g.load_ref("impactMetal_medium_002.ogg", 0.6 * pitch), 0.11, 0.45)
    n = int(0.45 * SR)
    slump = g.sweep_lowpass(g.brown_noise(n), 800.0, 100.0)
    g.mix_at(out, [slump[i] * math.exp(-i / SR / 0.13) * 0.6 for i in range(n)], 0.12)
    out = g.add_space(out, 0.05, 0.15)
    return g.normalize(out)


VERSIONS = [
    ("stagger_a_plate", "A 敲钢板基准款：厚板实录降调+质量垫——AC6 直击", make_a, {}),
    ("stagger_b_slump", "B 坍塌双层款：主击+110ms 次级碰撞与垮落尾", make_b, {}),
    ("stagger_b_second", "拆件：B 的第二层单独听（次级碰撞+垮落尾）", make_b_second, {}),
    ("stagger_c_sag",   "C 降调扭曲款：板鸣尾连续掉速——结构受压下坠", make_c, {}),
    ("stagger_d_bell",  "D 钟振款：脆短击+工业钟长鸣——穿透性持续标识", make_d, {}),
    ("stagger_e_sting", "E 电子确认款：主击+下行双音 blip——窗开启标记", make_e, {}),
    ("stagger_f_mass",  "F 重锤闷击款：钝击主体+亮板点缀——质量感，弱 clang", make_f, {}),
    ("stagger_d_slump", "组合试听：D 钟振 + B 的垮落层", make_d_slump, {}),
    ("stagger_a_boss",  "BOSS 变调示例：A 款整体 ×0.72（分层用，非独立提案）", make_a, {"pitch": 0.72}),
    ("stagger_b_boss",  "BOSS 变调示例：B 款整体 ×0.72", make_b, {"pitch": 0.72}),
]


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"提案输出到 {OUT_DIR}")
    for name, desc, fn, kw in VERSIONS:
        random.seed(zlib.crc32(name.encode("utf-8")))  # 提案同种子纪律
        x = g.master(fn(**kw))
        write_wav(OUT_DIR / f"{name}.wav", x)
        print(f"  {name}.wav  {len(x) / SR:.2f}s  {desc}")
    print("完成。试听：design/proposals/stagger_listen.html")


if __name__ == "__main__":
    main()
