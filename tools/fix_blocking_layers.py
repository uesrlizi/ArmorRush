# 批量修复单位场景阻挡：根节点 layer 4→68（并入 EnemyBody 层），删除 BlockingBody 幽灵子体。
# 背景：AnimatableBody2D 挂在 move_and_slide 驱动的父级下物理服务器变换不同步
# （godotengine/godot#58269），阻挡从未生效。改用根本体阻挡。
# 用法：python -I tools/fix_blocking_layers.py
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KINDS = ["enemy", "enemy_drone", "enemy_shield", "elite"]
CHAPTERS = 7


def patch(text: str, path: Path) -> str:
    # 1) 根节点 collision_layer 4 → 68（本类场景里 4 只出现在根节点行）
    n_layer = text.count("collision_layer = 4\n")
    if n_layer != 1:
        sys.exit(f"{path.name}: 预期恰 1 处根 collision_layer=4，实际 {n_layer}，人工处理")
    text = text.replace("collision_layer = 4\n", "collision_layer = 68\n")

    # 2) 删 BlockingBody 子树：节点头 + 所有 parent="BlockingBody" 的子节点，
    #    直到第一个非其子级的节点头（其子节点头也以 [node 开头，不能见 [node 就停）
    m = re.search(r'\[node name="BlockingBody"[^\n]*\n', text)
    if not m:
        sys.exit(f"{path.name}: 未找到 BlockingBody 节点，人工处理")
    start = m.start()
    end = len(text)
    for nm in re.finditer(r'^\[node ([^\]\n]*)\]', text[m.end():], re.M):
        if 'parent="BlockingBody"' in nm.group(1):
            continue
        end = m.end() + nm.start()
        break
    block = text[start:end]

    # 切除 [start, end) 后，块前原有空行恰好充当分隔行，无需补删
    text = text[:start] + text[end:]

    # 3) 删块内引用且无其他引用的 sub_resource
    for sid in re.findall(r'SubResource\("([^"]+)"\)', block):
        rest = text
        if f'SubResource("{sid}")' not in rest:
            sm = re.search(rf'\[sub_resource type="[^"]+" id="{sid}"\]\n(?:[^\[]*\n)?', text)
            if sm:
                text = text[:sm.start()] + text[sm.end():]

    # 4) load_steps 重算（存在才管）：ext + sub + 1
    def count(tag):
        return len(re.findall(rf'^\[{tag} ', text, re.M))
    total = count("ext_resource") + count("sub_resource") + 1
    text = re.sub(r'load_steps=\d+', f'load_steps={total}', text, count=1)
    return text


def main():
    changed = 0
    for i in range(1, CHAPTERS + 1):
        for kind in KINDS:
            p = ROOT / "scenes" / "units" / f"{kind}_{i}.tscn"
            old = p.read_text(encoding="utf-8")
            new = patch(old, p)
            if new != old:
                p.write_text(new, encoding="utf-8", newline="\n")
                changed += 1
                print(f"patched {p.name}")
    print(f"done, {changed} files")


if __name__ == "__main__":
    main()
