#!/usr/bin/env python3
"""分块并行下载器：多连接 Range 分块，专治单连接限速的镜像/加速器。

用法：python chunked_download.py <url> <输出文件> [块数]
"""
import concurrent.futures as cf
import sys
import time
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 (download-tool)"}


def head_total(url: str) -> int:
    req = urllib.request.Request(url, headers={**UA, "Range": "bytes=0-0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        cr = r.headers.get("Content-Range")  # bytes 0-0/TOTAL
        if cr and "/" in cr:
            return int(cr.split("/")[-1])
        return int(r.headers.get("Content-Length", 0))


def fetch_chunk(url: str, start: int, end: int, path: str) -> int:
    for attempt in range(20):
        try:
            got = path.stat().st_size if path.exists() else 0
            want = end - start + 1
            if got >= want:
                return got
            req = urllib.request.Request(
                url, headers={**UA, "Range": f"bytes={start + got}-{end}"})
            with urllib.request.urlopen(req, timeout=60) as r, open(path, "ab") as f:
                while True:
                    buf = r.read(65536)
                    if not buf:
                        break
                    f.write(buf)
            got = path.stat().st_size
            if got >= want:
                return got
        except Exception:
            time.sleep(min(2.0 * (attempt + 1), 15.0))
    raise RuntimeError(f"chunk {start}-{end} failed after retries")


def download(url: str, out: str, chunks: int = 8) -> None:
    from pathlib import Path
    total = head_total(url)
    if total <= 0:
        raise RuntimeError("拿不到文件总大小（服务端不支持 Range？）")
    print(f"total {total/1e6:.1f} MB, {chunks} chunks", flush=True)
    tmpdir = Path(out + ".parts")
    tmpdir.mkdir(exist_ok=True)
    bounds = [(i * total // chunks, (i + 1) * total // chunks - 1)
              for i in range(chunks)]
    t0 = time.time()
    with cf.ThreadPoolExecutor(chunks) as pool:
        futs = [pool.submit(fetch_chunk, url, s, e, tmpdir / f"part{i}")
                for i, (s, e) in enumerate(bounds)]
        for f in futs:
            f.result()
    with open(out, "wb") as w:
        for i in range(chunks):
            with open(tmpdir / f"part{i}", "rb") as r:
                while True:
                    buf = r.read(1 << 20)
                    if not buf:
                        break
                    w.write(buf)
    for i in range(chunks):
        (tmpdir / f"part{i}").unlink()
    tmpdir.rmdir()
    import os
    got = os.path.getsize(out)
    dt = time.time() - t0
    print(f"done {got} bytes in {dt:.0f}s ({got/1e6/dt:.2f} MB/s)", flush=True)
    if got != total:
        raise RuntimeError(f"大小不符 {got} != {total}")


if __name__ == "__main__":
    download(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 8)
