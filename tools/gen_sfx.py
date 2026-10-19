# -*- coding: utf-8 -*-
"""2D_AC 音效管线：实录转换（CC0 Kenney/qubodup，tools/ref_sfx/）+ 定向合成垫。

跑法：  py -3 tools/gen_sfx.py          （秒级出全库；实录源不变则字节级可复现）
产物：  assets/sfx/<name>.wav           （16-bit PCM / 44100 Hz / 单声道）

方法论（实装教训，别回退）：纯合成模拟物理声（枪/金属/挥砍/脚步）被耳朵判为
"失真、出戏"——实录自带物理源的调制组织，同样的带宽实录不会假。合成只保留
两类被认可的性质：纯噪声能量（爆炸/循环床，无音高性）与电子源（UI sting）。
结构约定：实录给"源质感"（瞬态/共鸣体），合成只给"质量垫"（无音高低频 thump）
与空间（早期反射）。变体 = 换源文件或变调重采。

纪律：
- 合成部分的随机性按文件名 crc32 定种子，字节不变可复调。
- 母带链固定：HP 38Hz → LP 10.5kHz → 峰值归一；循环音滤波绕环 3 圈收敛。
- 新音效 = 转换清单加一行（或新配方函数）。
- 依赖：pip install soundfile numpy（实录 ogg/flac 解码）。
"""

import math
import random
import struct
import wave
import zlib
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sfx"
REF_DIR = Path(__file__).resolve().parent / "ref_sfx"
MASTER_PEAK = 0.92


# ---- 滤波与噪声基元 -------------------------------------------------------

def lowpass(x, fc):
    a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
    y = 0.0
    out = []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, fc):
    lp = lowpass(x, fc)
    return [s - l for s, l in zip(x, lp)]


def sweep_lowpass(x, fc_from, fc_to):
    n = len(x)
    out = []
    y = 0.0
    for i, s in enumerate(x):
        t = i / max(n - 1, 1)
        fc = fc_from + (fc_to - fc_from) * t
        a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
        y += a * (s - y)
        out.append(y)
    return out


def bandpass(x, fc, q=2.0):
    return highpass(lowpass(x, fc * q), fc / q)


def brown_noise(n, leak=0.996):
    y = 0.0
    out = []
    for _ in range(n):
        y = (y + (random.random() * 2.0 - 1.0) * 0.12) * leak
        out.append(y)
    return out


def white_noise(n):
    return [random.random() * 2.0 - 1.0 for _ in range(n)]


# ---- 合成基元 ------------------------------------------------------------

def env(n, attack_s, tau):
    a_n = max(int(attack_s * SR), 1)
    out = []
    for i in range(n):
        if i < a_n:
            out.append(i / a_n)
        else:
            t = (i - a_n) / SR
            out.append(math.exp(-t / tau))
    return out


def thump(f_from, f_to, dur, tau, amp=1.0):
    """无音高感的低频质量垫（正弦下扫只承担"重量"，源质感交给实录层）。"""
    n = int(dur * SR)
    out = []
    phase = 0.0
    e = env(n, 0.004, tau)
    for i in range(n):
        t = i / max(n - 1, 1)
        f = f_from + (f_to - f_from) * t
        phase += 2.0 * math.pi * f / SR
        out.append(amp * math.sin(phase) * e[i])
    return out


def resonate(excitation, f, tau):
    """二阶谐振器：激励信号进来，输出该频率的 ringing——持续激励的短衰减
    谐振就是"被刮的金属板在鸣"，金属感与塑料感的分界。输出按峰值归一。"""
    r = math.exp(-1.0 / (tau * SR))
    w = 2.0 * math.pi * f / SR
    b1 = 2.0 * r * math.cos(w)
    b2 = -r * r
    y1 = y2 = 0.0
    out = []
    for s in excitation:
        y = s + b1 * y1 + b2 * y2
        y2, y1 = y1, y
        out.append(y)
    peak = max(abs(min(out)), abs(max(out)), 1e-9)
    return [s / peak for s in out]


def crack(dur_s=0.003, amp=1.0, hp=2000.0):
    n = int(dur_s * SR)
    x = highpass(white_noise(n), hp)
    e = env(n, 0.0005, dur_s * 0.45)
    return [amp * s * e[i] for i, s in enumerate(x)]


def crackle(count, dur, amp=0.5):
    n = int(dur * SR)
    out = [0.0] * n
    for _ in range(count):
        at = int(random.random() * (n - 400))
        a = amp * (0.3 + random.random() * 0.7)
        piece = crack(0.001 + random.random() * 0.002, a, 1500.0)
        for i, s in enumerate(piece):
            if at + i < n:
                out[at + i] += s
    return out


def mix_at(base, piece, at_s, gain=1.0):
    at = int(at_s * SR)
    need = at + len(piece)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, s in enumerate(piece):
        base[at + i] += s * gain
    return base


def add_space(x, delay_s, gain, lp=2500.0):
    """早期反射：主信号延迟+低通折回一道。全干声=录音棚假，
    带一击空间回声=真（户外废都的命中/落地要有"场地感"）。"""
    d = int(delay_s * SR)
    ref = lowpass(x, lp)
    for i, s in enumerate(ref):
        if d + i < len(x):
            x[d + i] += s * gain
    return x


# ---- 实录加载 ------------------------------------------------------------

def load_ref(fname, pitch=1.0, keep_s=None):
    """读实录（ogg/flac）→ 单声道 → 静音修剪（留 5ms 起手余量）→ 变调重采
    → 4ms 边缘淡化。pitch<1 拉长降调（变重：机甲 vs 人脚的换算就是它）。"""
    x, sr = sf.read(str(REF_DIR / fname))
    if x.ndim > 1:
        x = x.mean(axis=1)
    if sr != SR:
        raise ValueError(f"{fname}: sample rate {sr} != {SR}")
    peak = max(abs(s) for s in x) or 1.0
    idx = [i for i, s in enumerate(x) if abs(s) > 0.02 * peak]
    pad = int(0.005 * SR)
    a = max(0, idx[0] - pad)
    b = min(len(x), idx[-1] + pad)
    x = x[a:b]
    if pitch != 1.0:
        n = int(len(x) / pitch)
        x = [x[min(len(x) - 1, int(i * pitch))] for i in range(n)]
    if keep_s is not None:  # 只取开头（做"上膛咔"之类的一瞬）
        x = x[: int(keep_s * SR)]
    f = int(0.004 * SR)
    for i in range(min(f, len(x))):
        w = i / f
        x[i] *= w
        x[-1 - i] *= w
    return list(x)


# ---- 母带与落盘 -----------------------------------------------------------

def normalize(x, peak=1.0):
    m = max(abs(min(x)), abs(max(x)), 1e-9)
    return [s * (peak / m) for s in x]


def master(x, loop=False):
    """HP 38Hz → LP 10.5kHz → 归一。loop=True：IIR 状态绕环 3 圈收敛取中段，
    否则滤波冷启动会在循环点造成低频跳变（踩过：接缝 8 倍于正常步进）。"""
    if loop:
        triple = x * 3
        triple = highpass(triple, 38.0)
        triple = lowpass(triple, 10500.0)
        n = len(x)
        return normalize(triple[n:2 * n], MASTER_PEAK)
    x = highpass(x, 38.0)
    x = lowpass(x, 10500.0)
    return normalize(x, MASTER_PEAK)


def seamless_loop(x, fade_s):
    """无缝循环：延长段交叉替换头部 fade 帧——循环点(尾→头)落在原始信号
    自然连续处。周期成分须先 snap 频率/整周期，随机成分靠交叉兜底。"""
    f = int(fade_s * SR)
    n = len(x) - f
    if n <= 0 or f <= 0:
        return x
    out = list(x)
    for i in range(f):
        w = i / f
        out[i] = x[n + i] * (1.0 - w) + x[i] * w
    return out[:n]


def write_wav(name, x):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in x:
            s = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(round(s * 32767.0)))
        w.writeframes(bytes(frames))
    print(f"  {name}.wav  {len(x) / SR:.2f}s")


def render(name, fn, *args, loop=False, **kwargs):
    """清单入口：合成配方用（文件名 crc32 定种子）。"""
    random.seed(zlib.crc32(name.encode("utf-8")))
    x = fn(*args, **kwargs)
    write_wav(name, master(x, loop=loop))


def convert(name, fn, *args, **kwargs):
    """清单入口：实录转换用（同一种子纪律，保证合成垫部分可复现）。"""
    render(name, fn, *args, **kwargs)


# ---- 保留的合成配方（纯噪声能量/电子源——被认可的合成性质） -----------------

def boom_enemy(scale=1.0):
    dur = 0.95 * scale
    n = int(dur * SR)
    fire = sweep_lowpass(brown_noise(n), 1400.0 / scale, 120.0)
    e = env(n, 0.006, 0.26 * scale)
    out = [fire[i] * e[i] for i in range(n)]
    phase = 0.0
    for i in range(n):
        phase += 2.0 * math.pi * 45.0 / SR
        out[i] += 0.5 * math.sin(phase) * math.exp(-i / SR / 0.35)
    for i, s in enumerate(crackle(int(9 * scale), dur * 0.55, amp=0.5)):
        out[i] += s
    return normalize(out)


def boom_player():
    dur = 1.35
    n = int(dur * SR)
    fire = sweep_lowpass(brown_noise(n), 1000.0, 80.0)
    e = env(n, 0.008, 0.42)
    out = [fire[i] * e[i] for i in range(n)]
    phase = 0.0
    for i in range(n):
        phase += 2.0 * math.pi * 38.0 / SR
        out[i] += 0.55 * math.sin(phase) * math.exp(-i / SR / 0.5)
    for i, s in enumerate(crackle(14, dur * 0.6, amp=0.55)):
        out[i] += s
    for _ in range(3):
        at = 0.25 + random.random() * 0.7
        debris_f = 180.0 + random.random() * 260.0
        debris = [0.0] * int(0.2 * SR)
        for i in range(len(debris)):
            t = i / SR
            debris[i] = (math.sin(2 * math.pi * debris_f * t) * math.exp(-t / 0.1)
                         + 0.4 * math.sin(2 * math.pi * (900 + random.random() * 700) * t)
                         * math.exp(-t / 0.05))
        mix_at(out, debris, at, 0.2)
    return normalize(out)


def thrust_loop():
    """推进循环 1.6s：棕噪体 + 谐波列（52.5Hz 基，snap 循环整分频）+ 高频嘶。"""
    loop_s = 1.6
    tail_s = 0.15
    n = int((loop_s + tail_s) * SR)
    body = lowpass(brown_noise(n), 750.0)
    out = [s * 0.6 for s in body]
    base = 84 * (1.0 / loop_s)  # 52.5 Hz
    for k, amp in [(1, 0.30), (2, 0.16), (3, 0.08)]:
        f = base * k
        ph = random.random() * 2.0 * math.pi
        trem_cycles = 3.0 * k
        for i in range(n):
            trem = 1.0 + 0.10 * math.sin(2.0 * math.pi * trem_cycles * i / SR / loop_s)
            out[i] += amp * math.sin(2.0 * math.pi * f * i / SR + ph) * trem
    hiss = highpass(white_noise(n), 3500.0)
    for i in range(n):
        out[i] += hiss[i] * 0.07
    return seamless_loop(normalize(out), tail_s)


def amb_rust():
    """锈雨废都环境床 7.0s：细雨颗粒 + 呼吸风（LFO 整周期）+ 55Hz 工业低嗡。"""
    loop_s = 7.0
    tail_s = 0.4
    n = int((loop_s + tail_s) * SR)
    out = [0.0] * n
    rain = highpass(white_noise(n), 1200.0)
    for i in range(n):
        out[i] += rain[i] * 0.10
    for _ in range(150):
        at = int(random.random() * (n - 200))
        drop = crack(0.001 + random.random() * 0.002,
                     0.10 + random.random() * 0.16, 2500.0)
        for i, s in enumerate(drop):
            if at + i < n:
                out[at + i] += s
    wind = lowpass(brown_noise(n), 400.0)
    for i in range(n):
        lfo = 0.6 + 0.4 * math.sin(2.0 * math.pi * 3.0 * i / SR / loop_s)
        out[i] += wind[i] * 0.55 * lfo
    for k, amp in [(1, 0.045), (2, 0.02)]:
        ph = random.random() * 2.0 * math.pi
        for i in range(n):
            out[i] += amp * math.sin(2.0 * math.pi * 55.0 * k * i / SR + ph)
    return seamless_loop(normalize(out), tail_s)


def slide_loop():
    """地面滑行循环 4.0s：金属刮擦（对齐滑行火花视觉）。
    三层：宽带高频锐刮（1.3–5.2kHz，砂砾感）+ 两路甲板板鸣（二阶谐振器持续
    激励——"金属 vs 塑料"的分界就是被刮的板在鸣）+ 低频隆隆（重量）。
    幅度起伏用非周期的慢随机漂移——正弦 LFO 的规则脉动会让循环"一段一段"
    （踩过）；不放事件性脉冲——循环里固定位置的咔同样暴露周期。"""
    loop_s = 4.0
    tail_s = 0.25
    n = int((loop_s + tail_s) * SR)
    scrape = highpass(lowpass(white_noise(n), 4300.0), 1050.0)
    ring_hi = resonate(scrape, 2500.0, 0.005)  # 甲板板鸣：持续激励的短衰减谐振
    ring_lo = resonate(scrape, 1350.0, 0.004)
    rumble = lowpass(brown_noise(n), 130.0)
    drift = normalize(lowpass(brown_noise(n), 1.2), 1.0) # 亚 2Hz 无规则起伏
    out = [0.0] * n
    for i in range(n):
        mod = 0.82 + 0.18 * drift[i] # 大部分时段 ±5% 微起伏，偶发更深
        out[i] = (scrape[i] * 0.38 + ring_hi[i] * 0.24 + ring_lo[i] * 0.17) * mod \
                + rumble[i] * 0.34
    return seamless_loop(normalize(out), tail_s)


def ui_gameover():
    """结算 sting：下行双音（A2→E2）。电子源，合成不失真。"""
    dur = 1.1
    out = [0.0] * int(dur * SR)

    def tone(f, at_s, len_s):
        at = int(at_s * SR)
        n = int(len_s * SR)
        for i in range(n):
            t = i / SR
            attack = min(t / 0.02, 1.0)
            release = math.exp(-t / 0.22)
            v = (math.sin(2 * math.pi * f * t)
                 + 0.4 * math.sin(4 * math.pi * f * t)
                 + 0.18 * math.sin(6 * math.pi * f * t))
            if at + i < len(out):
                out[at + i] += v * attack * release * 0.5

    tone(110.0, 0.0, 0.34)
    tone(82.41, 0.16, 0.6)
    return normalize(out)


# ---- 实录转换配方 ---------------------------------------------------------

def fcs_tick(amp=0.3):
    """FCS 中弹警报 tick（电子源）：基频+三次谐波短促方波感。"""
    tick_n = int(0.035 * SR)
    out = []
    for i in range(tick_n):
        e = math.exp(-i / SR / 0.012)
        ph = 2.0 * math.pi * 3150.0 * i / SR
        out.append((math.sin(ph) + 0.35 * math.sin(3 * ph)) * e * amp)
    return out


def fire_player(bright=1.0):
    """机炮：实录金属后坐咔（源质感）+ 无音高噪声体（爆炸同族）+ 硝烟尾。"""
    body_dur = 0.3
    n = int(body_dur * SR)
    out = [0.0] * n
    mix_at(out, load_ref("impactMetal_heavy_002.ogg", 1.3 * bright), 0.0, 0.95)
    body = sweep_lowpass(brown_noise(n), 1600.0 * bright, 250.0)
    e = env(n, 0.003, 0.07)
    for i in range(n):
        out[i] += body[i] * e[i] * 0.9
    tail = lowpass(brown_noise(n), 700.0)
    e2 = env(n, 0.005, 0.12)
    for i in range(n):
        out[i] += tail[i] * e2[i] * 0.3
    out = add_space(out, 0.045, 0.15)
    return normalize(out)


def fire_enemy(tone=1.0):
    """敌方炮塔：更钝的后坐 + 更深更长的噪声体。"""
    body_dur = 0.42
    n = int(body_dur * SR)
    out = [0.0] * n
    mix_at(out, load_ref("impactMetal_medium_001.ogg", 0.9 * tone), 0.0, 0.9)
    body = sweep_lowpass(brown_noise(n), 1100.0 * tone, 140.0)
    e = env(n, 0.004, 0.11)
    for i in range(n):
        out[i] += body[i] * e[i] * 0.95
    tail = lowpass(brown_noise(n), 500.0)
    e2 = env(n, 0.006, 0.2)
    for i in range(n):
        out[i] += tail[i] * e2[i] * 0.4
    out = add_space(out, 0.06, 0.2)
    return normalize(out)


def melee_hit(tone=1.0):
    """近战命中：实录金属重击双层（脆击+厚板余振）+ 低频质量垫，与顿帧同拍。"""
    out = [0.0] * int(0.42 * SR)
    mix_at(out, load_ref("impactMetal_heavy_000.ogg" if tone >= 1.0
                         else "impactMetal_heavy_003.ogg", tone), 0.0, 1.0)
    mix_at(out, load_ref("impactPlate_heavy_001.ogg" if tone >= 1.0
                         else "impactPlate_heavy_003.ogg", tone * 0.95), 0.0, 0.55)
    mix_at(out, thump(150.0, 65.0, 0.09, 0.06), 0.0, 0.4)
    out = add_space(out, 0.06, 0.18)
    return normalize(out)


def hit_enemy(tone=1.0):
    """敌受击：薄铁皮实录（Tin 族），变体靠换源+微变调。"""
    fname = "impactTin_medium_000.ogg" if tone >= 1.0 else "impactTin_medium_003.ogg"
    return normalize(load_ref(fname, tone))


def hit_deflect():
    """盾板弹开：亮钢板 + 80ms 后二次弹跳轻触。"""
    out = [0.0] * int(0.36 * SR)
    mix_at(out, load_ref("impactPlate_medium_001.ogg"), 0.0, 1.0)
    mix_at(out, load_ref("impactMetal_light_004.ogg", 1.2), 0.08, 0.3)
    return normalize(out)


def hit_player():
    """玩家受击：实录暗重钝击（乘员受冲击）+ FCS 警报 tick（电子源）。"""
    out = [0.0] * int(0.42 * SR)
    mix_at(out, load_ref("impactPunch_heavy_002.ogg"), 0.0, 1.0)
    mix_at(out, fcs_tick(), 0.06)
    out = add_space(out, 0.05, 0.12)
    return normalize(out)


def hit_world():
    """弹着地形：短闷体实录 + 棕噪尘尾。轻量高节流。"""
    out = [0.0] * int(0.22 * SR)
    mix_at(out, load_ref("impactSoft_medium_000.ogg"), 0.0, 1.0)
    n = int(0.1 * SR)
    dust = lowpass(brown_noise(n), 300.0)
    e = env(n, 0.002, 0.04)
    for i in range(n):
        out[i] += dust[i] * e[i] * 0.35
    return normalize(out)


def stagger(pitch=1.0):
    """失衡确立（AC6 式 STAGGER，终稿=B 坍塌双层款换回，+4dB 顶格增益复验）：
    厚板主击（降调+质量垫）+ 110ms 次级碰撞 + 垮落尾——近战爆发窗开启确认音。
    三轮史：B(-5 实测被枪炮掩蔽) → D 钟振(换装救掩蔽) → B 换回（+4 顶格
    增益+0.15s 延迟——掩蔽要因是响度不足，顶格后复验）。变调分层：
    杂兵 1.05 / 精英 1.0 / BOSS 0.72（清单三行）。
    感知响度注意：B 是瞬态型（crest 高），同峰值下比钟振款听着轻——
    换装前后跑 tools/profile_sfx.py 对齐键位，别拿峰值当响度。"""
    out = [0.0] * int(1.0 * SR)
    mix_at(out, load_ref("impactPlate_heavy_004.ogg", 0.8 * pitch), 0.0, 1.0)
    mix_at(out, thump(120.0 * pitch, 50.0, 0.12, 0.09), 0.0, 0.5)
    mix_at(out, load_ref("impactMetal_medium_002.ogg", 0.6 * pitch), 0.11, 0.45)
    n = int(0.45 * SR)
    slump = sweep_lowpass(brown_noise(n), 800.0, 100.0)
    mix_at(out, [slump[i] * math.exp(-i / SR / 0.13) * 0.6 for i in range(n)], 0.12)
    out = add_space(out, 0.05, 0.15)
    return normalize(out)


def melee_windup():
    """起手蓄势：中性轻击实录削短——只给"上膛"一瞬的质感。"""
    return normalize(load_ref("impactGeneric_light_001.ogg", 1.1, keep_s=0.1))


def threat_warn(gap_s=0.15):
    """AC6 式威胁警告（提案 A 定稿）：1.5kHz 方波双声——声 90ms、声间静
    gap_s、尾静同 gap_s，循环触发时四声均匀。间隔 250→200→150，150 定稿。
    保命提示档：预警确立瞬间（充能光晕起点）播，威胁持续由再次触发承担。"""
    def beep(n):
        ph = 0.0
        piece = []
        for i in range(n):
            ph += 2.0 * math.pi * 1500.0 / SR
            piece.append(sum(math.sin(k * ph) / k for k in (1, 3, 5, 7)) * 4.0 / math.pi)
        fade = int(0.005 * SR)
        for i in range(fade):
            w = i / fade
            piece[i] *= w
            piece[-1 - i] *= w
        return piece

    tone_n = int(0.09 * SR)
    quiet_n = int(gap_s * SR)
    out = [0.0] * (tone_n * 2 + quiet_n * 2)
    for at in (0, tone_n + quiet_n):
        for i, s in enumerate(beep(tone_n)):
            out[at + i] += s
    return normalize(out, MASTER_PEAK)


def melee_slash(down=True, sweep=1.0):
    """挥砍：实录挥风直接采用（选择依据：时长/亮度画像），降调给重刃质量。
    下劈用中暗素材、上挑用带弧素材；变体换源。"""
    if down:
        fname = "swosh-01.flac" if sweep >= 1.0 else "swosh-06.flac"
        return normalize(load_ref(fname, 0.85 * sweep))
    fname = "swosh-08.flac" if sweep >= 1.0 else "swosh-26.flac"
    return normalize(load_ref(fname, 0.9 * sweep))


# ---- 清单（新文件一律加在末尾） -------------------------------------------

def main():
    print(f"生成到 {OUT_DIR}")
    # 实录转换：枪 / 挥砍 / 命中 / 受击 / 落地 / 脚步
    convert("fire_player_a", fire_player)
    convert("fire_player_b", fire_player, bright=1.12)
    convert("fire_player_c", fire_player, bright=0.9)
    convert("fire_enemy_a", fire_enemy)
    convert("fire_enemy_b", fire_enemy, tone=0.92)
    convert("melee_slash1_a", melee_slash, down=True)
    convert("melee_slash1_b", melee_slash, down=True, sweep=0.9)
    convert("melee_slash2_a", melee_slash, down=False)
    convert("melee_slash2_b", melee_slash, down=False, sweep=1.1)
    convert("melee_hit_a", melee_hit)
    convert("melee_hit_b", melee_hit, tone=0.95)
    convert("melee_windup", melee_windup)
    convert("hit_enemy_a", hit_enemy)
    convert("hit_enemy_b", hit_enemy, tone=0.95)
    convert("hit_deflect", hit_deflect)
    convert("hit_player", hit_player)
    convert("hit_world", hit_world)
    # 保留合成：纯噪声能量 / 电子源
    render("boom_enemy_a", boom_enemy)
    render("boom_enemy_b", boom_enemy, scale=1.12)
    render("boom_player", boom_player)
    render("thrust_loop", thrust_loop, loop=True)
    render("slide_loop", slide_loop, loop=True)
    render("ui_gameover", ui_gameover)
    render("threat_warn", threat_warn, gap_s=0.15)
    render("amb_rust_loop", amb_rust, loop=True)
    # 失衡确立（D 钟振款换装）：三键同配方变调分层，不走随机变体。
    # sfx.gd 以 +4dB 增益播（用户定稿，全库唯一正增益键）——文件母带后按
    # 4dB 预留峰顶余量，回放恰好满幅；直接 0.92 母带叠正增益会在钟的
    # 攻击瞬态上削波出破音。想再响只能压 RMS（压缩/加层），不能再加增益。
    for key, kw in (("stagger", {"pitch": 1.05}),
                    ("stagger_elite", {}),
                    ("stagger_boss", {"pitch": 0.72})):
        random.seed(zlib.crc32(key.encode("utf-8")))
        x = master(stagger(**kw))
        write_wav(key, [s * 10.0 ** (-4.0 / 20.0) for s in x])
    print("完成。")


if __name__ == "__main__":
    main()
