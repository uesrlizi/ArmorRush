# -*- coding: utf-8 -*-
"""列出 ref_sfx 全部实录素材的画像：时长/峰值/谱质心/过零率。
选型依据：时长/质心/亮度画像匹配用途性格（挥砍要亮、钝击要暗、脚步居中）。"""
import soundfile as sf
import numpy as np
from pathlib import Path

REF = Path(__file__).resolve().parent / "ref_sfx"

def profile(path):
    x, sr = sf.read(str(path))
    if x.ndim > 1:
        x = x.mean(axis=1)
    n = len(x) / sr
    if len(x) < 64:
        return None
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    total = spec.sum() or 1.0
    centroid = (spec * freqs).sum() / total  # 谱质心：亮暗
    rms = float(np.sqrt((x ** 2).mean()))
    peak = float(np.abs(x).max())
    return n, centroid, rms, peak

rows = []
for p in sorted(REF.iterdir()):
    if p.suffix not in (".ogg", ".flac"):
        continue
    r = profile(p)
    if r:
        rows.append((p.name, *r))

print(f"{'文件':40s} {'时长s':>6s} {'质心Hz':>8s} {'RMS':>7s} {'峰':>6s}")
for name, n, c, rms, peak in rows:
    print(f"{name:40s} {n:6.2f} {c:8.0f} {rms:7.3f} {peak:6.2f}")
