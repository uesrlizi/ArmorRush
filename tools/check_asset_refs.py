# -*- coding: utf-8 -*-
"""资源引用完整性校验（纯 Python，不占引擎、编辑器在线也能跑）。
用法：python tools/check_asset_refs.py
场景：任何改名/迁移/分层类改动之后、进引擎流水线之前跑一遍——
tscn/gd 里所有 res://assets|scenes|scripts|data 引用必须落在磁盘上；
顺带列出 assets 下未被引用的 svg（存档/预留件，仅备案不判失败）。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAN_DIRS = ["scenes", "scripts", "tests"]
# 目录型引用（不带文件名，存在性按目录判）
DIR_REFS_PREFIX = ("res://assets/sfx", "res://assets/vo", "res://data/")
# 输出路径（预览/自测截图的写盘目标，允许尚不存在）
OUTPUT_PREFIX = ("res://autotest_shots/",)


def main():
    refs = {}
    for scan in SCAN_DIRS:
        base = os.path.join(ROOT, scan)
        if not os.path.isdir(base):
            continue
        for dirpath, _, files in os.walk(base):
            for f in files:
                if not f.endswith((".tscn", ".gd")):
                    continue
                p = os.path.join(dirpath, f)
                text = open(p, encoding="utf-8").read()
                for m in re.findall(r"res://[A-Za-z0-9_/\.\-]+", text):
                    refs.setdefault(m, []).append(os.path.relpath(p, ROOT))

    bad = []
    for r, users in sorted(refs.items()):
        if r.startswith(DIR_REFS_PREFIX) or r.startswith(OUTPUT_PREFIX):
            continue
        rel = r[len("res://"):]
        if rel.endswith(".import"):
            rel = rel[: -len(".import")]
        if not os.path.exists(os.path.join(ROOT, rel)):
            bad.append((r, users[:2]))

    if bad:
        print(f"FAIL: {len(bad)} 条断链引用")
        for r, users in bad:
            print("  BROKEN:", r, "<-", ", ".join(users))
        sys.exit(1)

    # 备案：未被任何场景/脚本引用的 svg
    referenced = set(refs.keys())
    orphans = []
    assets = os.path.join(ROOT, "assets")
    for dirpath, _, files in os.walk(assets):
        for f in files:
            if not f.endswith(".svg"):
                continue
            p = "res://" + os.path.relpath(os.path.join(dirpath, f), ROOT).replace("\\", "/")
            if p not in referenced:
                orphans.append(p)

    print(f"OK: {len(refs)} 条 res:// 引用全部落在磁盘上；未引用 svg {len(orphans)} 个（备案）")
    for o in sorted(orphans):
        print("  orphan:", o)


if __name__ == "__main__":
    main()
