# -*- coding: utf-8 -*-
"""音库感知响度画像：键位 dB 的取舍依据，别拿峰值当响度。

背景（2026-10-16 失衡音三轮调响的教训）：全库峰值归一 0.92 之下，瞬态声
（敲击：峰高 RMS 低）与持续声（钟鸣：RMS 高）在同一个键位 dB 上感知响度
差好几 dB——提案页归一峰值听不出，进实战混音才炸出来。本工具给每支 wav
出 时长/峰顶 dBFS/感知响度（20ms 短窗 RMS 取 95 分位，首尾静音自然门掉）/
crest（峰顶-响度差，瞬态度）。换装、定档位、怀疑"这键怎么不响"时先跑它；
两支文件要听成一样响，键位 dB 之差 = 表里响度列之差。

跑法：  py -3 tools/profile_sfx.py [wav目录，默认 assets/sfx]
依赖：  pip install soundfile numpy
"""
import math
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
WIN = 882           # 20ms 短窗
HOP = 441           # 半窗滑动
Q = 0.95            # 短窗 RMS 分位：读"最响的那些时刻"


def loudness_dbfs(x):
    xa = np.asarray(x, dtype=np.float64)
    if len(xa) < WIN:
        peak = float(np.abs(xa).max()) if len(xa) else 0.0
        return 20.0 * math.log10(max(peak / math.sqrt(2.0), 1e-9))
    idx = np.arange(0, len(xa) - WIN + 1, HOP)
    frames = np.stack([xa[i:i + WIN] for i in idx])
    rms = np.sqrt((frames * frames).mean(axis=1))
    return 20.0 * math.log10(max(float(np.quantile(rms, Q)), 1e-9))


def main():
    d = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parent.parent / "assets" / "sfx"
    rows = []
    for p in sorted(d.glob("*.wav")):
        x, sr = sf.read(str(p))
        if x.ndim > 1:
            x = x.mean(axis=1)
        peak = 20.0 * math.log10(max(float(np.abs(x).max()), 1e-9))
        loud = loudness_dbfs(x)
        rows.append((p.name, len(x) / sr, peak, loud, peak - loud))
    rows.sort(key=lambda r: -r[3])
    print(f"感知响度画像（短窗RMS p95）：{d}")
    print(f"  {'文件':30s} {'时长s':>6s} {'峰顶dBFS':>8s} {'响度dBFS':>8s} {'crest':>6s}")
    for name, dur, peak, loud, crest in rows:
        print(f"  {name:30s} {dur:6.2f} {peak:8.1f} {loud:8.1f} {crest:6.1f}")


if __name__ == "__main__":
    main()
