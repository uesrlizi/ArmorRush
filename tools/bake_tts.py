#!/usr/bin/env python3
"""通讯语音离线烘焙：读 data/comms.json，按说话人音色合成到 assets/vo/。

- 台词 id 即文件名（assets/vo/<id>.mp3/.wav），Godot 导入后由 comms.gd 按同 id 加载。
- 另合成电台 squelch 开合音效（_squelch_open/_close.wav，纯标准库合成）。
- 增量：已存在的文件跳过，改了台词重跑只补缺；--force 全量重烘。
- 后端：
    edge  = edge-tts 微软神经声（质量首选；偶发 403 限流，串行+退避）
    piper = 本地神经声（离线，需先下好音色模型到 tools/piper_voices/，
            下载源 hf-mirror.com/rhasspy/piper-voices，见 README）
  产物 mp3（edge）/ wav（piper）；comms.gd 按 mp3 优先、wav 兜底，
  edge 恢复后 `--backend edge --force` 出 mp3 即自动顶替。

用法：
    python tools/bake_tts.py                          # 烘全部缺的（edge）
    python tools/bake_tts.py --backend piper          # 本地 piper
    python tools/bake_tts.py --force                  # 全量重烘
    python tools/bake_tts.py --only id1,id2           # 只烘指定台词
    python tools/bake_tts.py --list                   # 列出台词与音色
"""

import argparse
import asyncio
import json
import math
import random
import struct
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "data" / "comms.json"
VO_DIR = ROOT / "assets" / "vo"
VOICES_DIR = Path(__file__).resolve().parent / "piper_voices"

SPEAKER_DEFAULTS = {"voice": "en-US-AriaNeural", "rate": "+0%", "pitch": "+0Hz"}
PIPER_DEFAULTS = {"voice": "en_US-lessac-high", "length_scale": 1.0}
RETRIES = 6
CONCURRENCY = 1  # edge 并发会触发服务端 403 限流，串行+退避最稳


def load_data() -> dict:
    with open(DATA_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def speaker_tts_params(data: dict, speaker_id: str) -> dict:
    spk = data.get("speakers", {}).get(speaker_id, {})
    return {key: spk.get(key, SPEAKER_DEFAULTS[key]) for key in SPEAKER_DEFAULTS}


def speaker_piper_params(data: dict, speaker_id: str) -> dict:
    spk = data.get("speakers", {}).get(speaker_id, {})
    merged = dict(PIPER_DEFAULTS)
    merged.update(spk.get("piper", {}))
    return merged


def ensure_squelch(force: bool) -> None:
    VO_DIR.mkdir(parents=True, exist_ok=True)
    if force or not (VO_DIR / "_squelch_open.wav").exists():
        write_squelch(VO_DIR / "_squelch_open.wav", 0.12, close=False)
    if force or not (VO_DIR / "_squelch_close.wav").exists():
        write_squelch(VO_DIR / "_squelch_close.wav", 0.08, close=True)
    if force or not (VO_DIR / "_static_bed.wav").exists():
        write_static_bed(VO_DIR / "_static_bed.wav", 2.0)


def write_static_bed(path: Path, duration: float) -> None:
    """合成常驻静噪底床（频道开着的沙沙声）：带通白噪，尾部与头部交叉淡接保证循环无缝。"""
    fs = 44100
    fade = int(fs * 0.05)
    n = int(fs * duration)
    rng = random.Random(11)
    f0, q = 1200.0, 0.55
    w0 = 2.0 * math.pi * f0 / fs
    alpha = math.sin(w0) / (2.0 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1.0 + alpha, -2.0 * math.cos(w0), 1.0 - alpha
    b0, b1, b2 = b0 / a0, b1 / a0, b2 / a0
    a1, a2 = a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    total = n + fade
    raw = []
    for _ in range(total):
        x = rng.uniform(-1.0, 1.0)
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x1, x2 = x, x1
        y1, y2 = y, y1
        raw.append(y * 2.6)
    out = raw[:n]
    for i in range(fade):  # 循环接缝：渲染续段叠进头部，接缝处信号自然连续
        w = i / fade
        out[i] = out[i] * w + raw[n + i] * (1.0 - w)
    frames = [int(max(-1.0, min(1.0, s)) * 32767 * 0.5) for s in out]
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(fs)
        w.writeframes(struct.pack("<%dh" % len(frames), *frames))


async def bake_line_edge(sem: asyncio.Semaphore, line_id: str, spec: dict, data: dict,
                         force: bool) -> str:
    text = spec.get("tts", spec.get("text", ""))
    if not text:
        return f"skip  {line_id} (no text)"
    out = VO_DIR / f"{line_id}.mp3"
    if out.exists() and not force:
        return f"skip  {line_id} (exists)"
    tts = speaker_tts_params(data, spec.get("speaker", "SYSTEM"))
    import edge_tts
    async with sem:
        for attempt in range(1, RETRIES + 1):
            try:
                comm = edge_tts.Communicate(
                    text, tts["voice"], rate=tts["rate"], pitch=tts["pitch"])
                await comm.save(str(out))
                return f"baked {line_id} [edge/{tts['voice']}]"
            except Exception as exc:  # 网络/服务端偶发，退避重试
                out.unlink(missing_ok=True)  # save() 失败也会留下 0 字节残文件
                if attempt == RETRIES:
                    return f"FAIL  {line_id}: {str(exc)[:140]}"
                await asyncio.sleep(3.0 * attempt)
    return f"FAIL  {line_id}"


def bake_line_piper(line_id: str, spec: dict, data: dict, force: bool) -> str:
    text = spec.get("tts", spec.get("text", ""))
    if not text:
        return f"skip  {line_id} (no text)"
    out = VO_DIR / f"{line_id}.wav"
    if out.exists() and not force:
        return f"skip  {line_id} (exists)"
    tts = speaker_piper_params(data, spec.get("speaker", "SYSTEM"))
    model = VOICES_DIR / f"{tts['voice']}.onnx"
    if not model.exists():
        return f"FAIL  {line_id}: 缺音色模型 {model}（下载见 README 的 piper 节）"
    proc = subprocess.run(
        [sys.executable, "-m", "piper", "-m", str(model), "-f", str(out),
         "--length-scale", str(tts.get("length_scale", 1.0)),
         "--speaker", str(tts.get("speaker_id", 0)),
         "--noise-scale", str(tts.get("noise_scale", 0.667)),
         "--sentence-silence", str(tts.get("sentence_silence", 0.15))],
        input=text, capture_output=True, text=True, timeout=120, encoding="utf-8")
    if proc.returncode != 0 or not out.exists() or out.stat().st_size == 0:
        out.unlink(missing_ok=True)
        detail = ((proc.stderr or "") + " " + (proc.stdout or "")).strip()
        return f"FAIL  {line_id} (rc={proc.returncode}): {detail[:160]}"
    return f"baked {line_id} [piper/{tts['voice']}]"


def write_squelch(path: Path, duration: float, close: bool) -> None:
    """合成电台 squelch：带通白噪 + 包络。开=快攻慢尾，合=立即起、快衰。"""
    fs = 44100
    n = int(fs * duration)
    rng = random.Random(7)
    f0, q = 1750.0, 1.1
    w0 = 2.0 * math.pi * f0 / fs
    alpha = math.sin(w0) / (2.0 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1.0 + alpha, -2.0 * math.cos(w0), 1.0 - alpha
    b0, b1, b2 = b0 / a0, b1 / a0, b2 / a0
    a1, a2 = a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    frames = []
    for i in range(n):
        x = rng.uniform(-1.0, 1.0)
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x1, x2 = x, x1
        y1, y2 = y, y1
        t = i / fs
        if close:
            env = math.exp(-t / 0.030)
        else:
            env = (1.0 - math.exp(-t / 0.003)) * math.exp(-t / 0.045)
        s = max(-1.0, min(1.0, y * env * 3.2))
        frames.append(int(s * 32767 * 0.55))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(fs)
        w.writeframes(struct.pack("<%dh" % len(frames), *frames))


def report(results: list) -> None:
    failed = [r for r in results if r.startswith("FAIL")]
    for r in results:
        print(r)
    print(f"\n{len(results) - len(failed)} ok, {len(failed)} failed -> {VO_DIR}")
    if failed:
        sys.exit(1)


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=["edge", "piper"], default="edge",
                        help="edge=微软神经声（首选，需网络）；piper=本地离线")
    parser.add_argument("--force", action="store_true", help="重烘已存在的文件")
    parser.add_argument("--only", default="", help="只烘指定 id（逗号分隔）")
    parser.add_argument("--list", action="store_true", help="列出台词与音色，不合成")
    args = parser.parse_args()

    data = load_data()
    lines: dict = data.get("lines", {})

    if args.list:
        for line_id, spec in lines.items():
            tts = speaker_tts_params(data, spec.get("speaker", "SYSTEM"))
            piper = speaker_piper_params(data, spec.get("speaker", "SYSTEM"))
            print(f"{line_id:20s} {spec.get('speaker', '?'):8s} "
                  f"edge={tts['voice']:20s} piper={piper['voice']}")
        return

    ensure_squelch(args.force)
    only = {s.strip() for s in args.only.split(",") if s.strip()}

    if args.backend == "piper":
        results = []
        for line_id, spec in lines.items():
            if only and line_id not in only:
                continue
            results.append(bake_line_piper(line_id, spec, data, args.force))
        report(results)
        return

    try:
        import edge_tts
    except ImportError:
        sys.exit("edge-tts 未安装：pip install edge-tts（或用 --backend piper 本地离线）")

    sem = asyncio.Semaphore(CONCURRENCY)
    tasks = []
    for line_id, spec in lines.items():
        if only and line_id not in only:
            continue
        tasks.append(asyncio.create_task(
            bake_line_edge(sem, line_id, spec, data, args.force)))
    report(await asyncio.gather(*tasks))


if __name__ == "__main__":
    asyncio.run(main())
