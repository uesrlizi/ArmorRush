# 第十章威胁几何实算（§0 口径：世界 y 朝下，g=地表，h=g-y，玩家 40x60 中心=g-30）
# 运行：python -I threat_calc_ch10.py   —— 只算账，不改任何工程文件
import math

RUN, ACC, JV, GU, GD = 600.0, 1800.0, -450.0, 1200.0, 800.0
B_ACC, B_MAX = 1000.0, 320.0
DT = 1 / 240

def player_sim(script, T, x0=0.0, v0=0.0, g=600.0):
    """script(t, state)->(dir, jump_pressed, boost_held). 返回 [(t,x,feet_y)]"""
    x, vx, y, vy, air = x0, v0, g, 0.0, False
    out, t = [], 0.0
    while t <= T + 1e-9:
        d, jp, bh = script(t)
        tgt = RUN * d
        vx += max(-ACC * DT, min(ACC * DT, tgt - vx))
        if jp and not air:
            vy, air = JV, True
        if air:
            if bh and vy > -B_MAX:
                vy = max(-B_MAX, vy - B_ACC * DT) if vy > -B_MAX else vy
                vy += 0 if vy <= -B_MAX else 0
            elif not bh or vy < -B_MAX:
                vy += (GU if vy < 0 else GD) * DT
            if bh and vy < -B_MAX:   # 起跳初速 -450 先被重力拉回到 -320
                vy += GU * DT
            y += vy * DT
            if y >= g:
                y, vy, air = g, 0.0, False
        x += vx * DT
        out.append((t, x, y))
        t += DT
    return out

def jump_table():
    tr = player_sim(lambda t: (0, t < 0.01, False), 1.2)
    apex = max(600 - y for _, _, y in tr)
    win = [t for t, _, y in tr if 600 - y >= 48]
    print(f"纯跳 apex={apex:.1f}  h>=48 窗 {win[0]:.3f}-{win[-1]:.3f}")
    trb = player_sim(lambda t: (0, t < 0.01, True), 1.2)
    for H in (48, 108, 220, 252):
        tt = next((t for t, _, y in trb if 600 - y >= H), None)
        print(f"按住推进 脚底到 h={H}: t={tt:.3f}")

# ---------- 硫焰井口 SulfurVent ----------
VENT_W, VENT_H = 64.0, 220.0
ON, OFF = 0.45, 0.75
def vent_on(t, first_on, pulses=3):
    for m in range(pulses):
        a = first_on + m * (ON + OFF)
        if a <= t < a + ON:
            return True
    return False

def vent_hits(tr, vents):
    """vents=[(x, first_on)] 返回命中列表（每口井每脉冲至多一次）"""
    hits = set()
    for t, x, y in tr:
        for i, (vx, fo) in enumerate(vents):
            if abs(x - vx) <= VENT_W / 2 + 20 and (600 - y) < VENT_H and vent_on(t, fo):
                pulse = int((t - fo) // (ON + OFF))
                hits.add((i, pulse))
    return sorted(hits)

def run_full(t):
    return (1, False, False)

def elite_cases():
    xv = 0 + min(max(600 * 2.4, 240), 1440)
    print(f"\n[精英] 满速落位 xv={xv}，首喷 2.3")
    print(" 满速盲冲:", vent_hits(player_sim(run_full, 6, v0=600), [(xv, 2.3)]))
    # 刹停：中心 <= xv-52 停住，等首喷熄(2.75)再走
    stop_c = xv - 72   # 判定半宽 52 + 余量 20
    brake_at = (stop_c - 100) / 600
    def brake(t):
        if t < brake_at: return (1, False, False)
        if t < 2.75: return (0, False, False)
        return (1, False, False)
    tr = player_sim(brake, 6, v0=600)
    print(f" 刹停等熄 起刹 t={brake_at:.3f}:", vent_hits(tr, [(xv, 2.3)]),
          f" 停点={[x for t,x,y in tr if abs(t-2.6)<DT/2][0]:.0f}")
    # 推进飞越：t_j 起跳并按住
    for tj in (1.55, 1.65):
        tr = player_sim(lambda t, tj=tj: (1, abs(t - tj) < DT, t >= tj and t < tj + 1.2), 6, v0=600)
        print(f" 推进飞越 起跳 t={tj}:", vent_hits(tr, [(xv, 2.3)]))
    tr = player_sim(lambda t: (1, abs(t - 2.0) < DT, False), 6, v0=600)
    print(" 纯跳过(2.0 起跳):", vent_hits(tr, [(xv, 2.3)]))

def boss_a_cases(n=3):
    v1 = 1440
    vents = [(v1 + 360 * k, 2.3 + 0.6 * k) for k in range(n)]
    print(f"\n[BOSS A] n={n} vents={vents}")
    print(" 满速盲冲:", vent_hits(player_sim(run_full, 8, v0=600), vents))
    brake_at = (v1 - 72 - 100) / 600
    def wave(t):
        if t < brake_at: return (1, False, False)
        if t < 2.75: return (0, False, False)
        return (1, False, False)
    print(f" 刹停首井→2.75 起步一口气绿波:", vent_hits(player_sim(wave, 8, v0=600), vents))
    for go in (2.75, 2.9, 3.0, 3.05, 3.1, 3.2):
        def w2(t, go=go):
            if t < brake_at: return (1, False, False)
            if t < go: return (0, False, False)
            return (1, False, False)
        print(f"   起步 t={go}:", vent_hits(player_sim(w2, 8, v0=600), vents))
    print(" 站桩(px=0, 井在 240/600/960):", vent_hits(player_sim(lambda t: (0, False, False), 8),
          [(240 + 360 * k, 2.3 + 0.6 * k) for k in range(n)]))

# ---------- 硫云爆燃 B：固定绝对带 ----------
def band_case(name, script, g_of_x, band, x_rng, ign=1.8, burn=0.6, front_v=2500.0, ign_x=None, v0=600, T=3):
    top, bot = band
    tr = []
    x, vx, y, vy, air, t = 0.0, v0, None, 0.0, False, 0.0
    tr = player_sim(script, T, v0=v0, g=600)
    hit = False
    for t, x, fy in tr:
        g = g_of_x(x)
        feet = g - (600 - fy)
        head = feet - 60
        front = (t - ign) * front_v
        if ign <= t < ign + burn and x_rng[0] - 20 <= x <= x_rng[1] + 20:
            if x >= x_rng[1] - front:  # 火锋自右端（BOSS 侧）向左推
                if head < bot and feet > top:
                    hit = True
    print(f" {name}: {'吃' if hit else '免'}")

def boss_b_cases():
    L = min(max(600 * 1.0, 0), 600)          # 落位 lead：clamp(vx·1.0, 0, 600)
    rng = (0 + L, 1000 + L)
    print(f"\n[BOSS B] 带 y∈[428,512]，满速横向 {rng}（站桩 [0,1000]），点燃 1.8，火锋自右端向左 2500px/s，燃 0.6")
    for g in (536, 600, 664):
        band_case(f"满速 tier g={g} 贴地", run_full, lambda x, g=g: g, (428, 512), rng, ign_x=None)
        band_case(f"满速 tier g={g} 1.7 起跳", lambda t: (1, abs(t - 1.7) < DT, False),
                  lambda x, g=g: g, (428, 512), rng, ign_x=None)
    brake = (rng[0] - 40 - 100) / 600   # 停点 ≤ 带左端−40
    band_case(f"g=536 起刹 t={brake:.2f}", lambda t: (1 if t < brake else 0, False, False),
              lambda x: 536, (428, 512), rng, ign_x=None)
    band_case("g=536 站桩(带 [0,1000])", lambda t: (0, False, False), lambda x: 536, (428, 512), (0, 1000), v0=0)
    band_case(f"g=536 起刹晚 0.1 (t={brake+0.1:.2f})", lambda t: (1 if t < brake + 0.1 else 0, False, False),
              lambda x: 536, (428, 512), rng)
    print(" 站立/起跳头顶 y：", {g: (g - 60, g - 60 - 84.4) for g in (536, 600, 664)})

# ---------- 普攻 硫焰扫掠：竖直扇，7 团穿过出手瞬间玩家 x 的 h=210..0 ----------
SW_H = [210, 175, 140, 105, 70, 35, 0]
def sweep(x_p, g, bx, order, ny=424.0, gap=0.07, delay=0.12, sp=850.0):
    nz = (bx - 146, ny)
    hs = SW_H if order == "down" else SW_H[::-1]
    out = []
    for k, h in enumerate(hs):
        dx, dy = x_p - nz[0], (g - h) - nz[1]
        L = math.hypot(dx, dy)
        out.append((delay + gap * k, nz, (dx / L * sp, dy / L * sp), h))
    return out

def sweep_hits(tr, shots, g, R=14.0):
    hits = set()
    for t, x, fy in tr:
        for i, (t0, nz, v, _) in enumerate(shots):
            if t >= t0:
                bx_, by_ = nz[0] + v[0] * (t - t0), nz[1] + v[1] * (t - t0)
                if by_ > g:   # 触地即爆（同地表）
                    continue
                if abs(bx_ - x) <= 20 + R and fy - 60 - R <= by_ <= fy + R:
                    hits.add(i)
    return sorted(hits)

def sweep_cases():
    g = 600
    print("\n[普攻 扫掠] 喷嘴世界 (bx-146, 424)，7 团 h=210..0，梯次 0.07，速度 850，团半径 14")
    s0 = sweep(0, g, 1400, "down")
    print(" 站桩时各团过 x_p 时刻:", [round(t0 + abs(nz[0]) / abs(v[0]), 2) for t0, nz, v, _ in s0])
    print(" 扇角跨度(度):", round(math.degrees(math.atan2(210, 1254)), 1))
    for order in ("down", "up"):
        for bx, v0, lbl, sc in [
            (1400, 0, "站桩", lambda t: (0, False, False)),
            (1400, 0, "0.35 反应后向BOSS反向撤", lambda t: (-1 if t > 0.35 else 0, False, False)),
            (1400, 0, "0.35 反应后向BOSS前冲", lambda t: (1 if t > 0.35 else 0, False, False)),
            (1400, 0, "原地纯跳 1.3", lambda t: (0, abs(t - 1.3) < DT, False)),
            (1400, 0, "原地纯跳 1.55", lambda t: (0, abs(t - 1.55) < DT, False)),
            (900, 600, "满速保持(BOSS 滞后 +900)", run_full),
            (900, 600, "满速→出手即刹", lambda t: (0, False, False)),
        ]:
            tr = player_sim(sc, 4, v0=v0)
            xs = [x for t, x, _ in tr if t <= 2.1]  # 末团过身前
            disp = max(xs) - min(xs)
            print(f" {order:4} {lbl}: 命中团 {sweep_hits(tr, sweep(0, g, bx, order), g)}  位移量={disp:.0f}px")

if __name__ == "__main__":
    jump_table()
    elite_cases()
    boss_a_cases(3)
    boss_a_cases(4)
    boss_b_cases()
    sweep_cases()


# ---------- R8 精英双喷节拍：单口 2 喷（2.3 喷 / 2.75–3.5 息 / 3.5 喷 / 3.95 熄） ----------
def vent_hits2(tr, xv, first=2.3, pulses=2):
    hits = set()
    for t, x, y in tr:
        if abs(x - xv) <= VENT_W / 2 + 20 and (600 - y) < VENT_H and vent_on(t, first, pulses):
            hits.add(int((t - first) // (ON + OFF)))
    return sorted(hits)

def elite_r8_cases():
    xv = 1440.0
    print("\n[R8 精英双喷] xv=px+1440，喷 [2.3,2.75] 息 [2.75,3.5] 喷 [3.5,3.95]")
    print(" 满速盲冲(px=0 起跑 600):", vent_hits2(player_sim(run_full, 5, v0=600), xv))
    for tc, lbl in ((3.125, "息窗中点满速穿"), (3.725, "第二喷中点满速穿"), (2.6, "第一喷中满速穿")):
        x0 = xv - 600 * tc
        tr = player_sim(run_full, 5, x0=x0, v0=600)
        print(f" {lbl}(中心过井 t={tc}, 起点 px{x0:+.0f}):", vent_hits2(tr, xv),
              f" 占井时段 [{tc-52/600:.3f},{tc+52/600:.3f}]")

# ---------- R9 普攻逐发 16px 采样校平 ----------
def sweep_legalize(x_p, g_of_x, nozzle, h_list, step=16.0, lift_deg=6.0, max_lift=2):
    res = []
    for h in h_list:
        tx, ty = x_p, g_of_x(x_p) - h
        ang = math.atan2(ty - nozzle[1], tx - nozzle[0])
        out = "哑火"
        for k in range(max_lift + 1):
            a = ang + math.radians(lift_deg) * k  # 抬角：射向 -X 时 atan2≈π-θ，加角=减小下俯
            # 射向 -X：角度 ~π-；抬角 = 下俯量减小
            dx, dy = math.cos(a), math.sin(a)
            ok, s = True, 0.0
            while True:
                px_, py_ = nozzle[0] + dx * s, nozzle[1] + dy * s
                if px_ < x_p:  # 过玩家出手 x 即停止采样
                    break
                if py_ > g_of_x(px_):
                    ok = False
                    break
                s += step
            if ok:
                out = f"抬{k}次"
                break
        res.append((h, out))
    return res

def r9_cases():
    # tier0 玩家；玩家前方 +200..+520 一块 tier2(536) 台阶；其余 tier0
    g_of_x = lambda x: 536.0 if 200 <= x < 520 else 664.0
    noz = (1254.0, 424.0)
    print("\n[R9 校平] tier0 玩家 px=0，台阶 tier2 [+200,+520]，喷嘴 (1254,424)")
    # 注：atan2 对 -X 射向给出 ~(π-θ)，抬角=向 +y 小的方向，修正符号
    for h, out in sweep_legalize(0, g_of_x, noz, SW_H):
        print(f"  h={h}: {out}")

if __name__ == "__main__":
    elite_r8_cases()
    r9_cases()


# ---------- 实装期补跑（终审 R7/R8/R16）----------
# B 技燃烧区模型（实装 sulfur_cloud.gd 同口径）：t∈[1.8,2.4] 内，燃烧区 = [max(锋, xL), xR]，
# 锋 = xR − 2500·(t−1.8)；玩家 AABB（半宽 20、高 60）与燃烧区 x 相交且身体 y 区间与带 [428,512] 相交 → 吃。
def cloud_hit(tr, g, xL, xR, ign=1.8, burn=0.6, v=2500.0):
    for t, x, fy in tr:
        if not (ign <= t <= ign + burn):
            continue
        front = max(xR - v * (t - ign), xL)
        feet = g - (600 - fy)
        head = feet - 60
        if x + 20 >= front and x - 20 <= xR and head < 512 and feet > 428:
            return True
    return False

def r8_thrust_cases():
    print("\n[R8 B 推进飞越] 满速 vx=600，带 [px+600, px+1600]，起跳 tj、按住推进 1.2s")
    for g in (536, 600):
        last_ok = None
        row = []
        for i in range(12, 19):
            tj = i / 10
            sc = lambda t, tj=tj: (1, abs(t - tj) < DT / 2 + 1e-9, tj <= t <= tj + 1.2)
            hit = cloud_hit(player_sim(sc, 3, v0=600), g, 600, 1600)
            row.append(f"{tj:.1f}:{'吃' if hit else '免'}")
            if not hit:
                last_ok = tj
        print(f"  tier g={g}: " + " ".join(row) + f"  → 最晚免伤起跳 {last_ok}")

def r16_gate(vx):
    lead = min(max(vx * 1.0, 0), 600)
    xr = lead + 1000
    ts = (xr + 4500) / (vx + 2500)
    return lead, xr, ts, (vx * ts - 20, vx * 2.4 + 20)

def r16_cases():
    print("\n[R16 受罚区间闸] I=[px+vx·t*−20, px+vx·2.4+20]，t*=(xRrel+4500)/(vx+2500)")
    for vx in (600, 300, 0):
        lead, xr, ts, I = r16_gate(vx)
        print(f"  vx={vx}: 带 [{lead:.0f},{xr:.0f}] t*={ts:.3f} I=[{I[0]:.0f},{I[1]:.0f}]")
    # 注入 tier2 位于 [600,920]（满速）：与 I=[1161,1460] 交集 0 → 不派 B
    lead, xr, ts, I = r16_gate(600)
    seg = (600, 920)
    inter = max(0.0, min(seg[1], I[1]) - max(seg[0], I[0]))
    print(f"  满速 tier2 段 {seg}: 与 I 交集 {inter:.0f} → {'派 B' if inter >= 40 else '改派 A'}")
    seg = (1120, 1440)
    inter = max(0.0, min(seg[1], I[1]) - max(seg[0], I[0]))
    w = max(0.0, min(seg[1], xr) - max(seg[0], lead))
    print(f"  满速 tier2 段 {seg}: 带内宽 {w:.0f}(≥320) 与 I 交集 {inter:.0f}(≥40) → {'派 B' if inter >= 40 and w >= 320 else '改派 A'}")
    # 该段上满速贴地：玩家在 [1120,1440] 时 tier2，其余 tier1
    g_of = lambda x: 536 if 1120 <= x < 1440 else 600
    tr = player_sim(run_full, 3, v0=600)
    hit = False
    for t, x, fy in tr:
        if 1.8 <= t <= 2.4:
            front = max(1600 - 2500 * (t - 1.8), 600)
            g = g_of(x)
            if x + 20 >= front and x - 20 <= 1600 and g - 60 < 512 and g > 428:
                hit = True
    print(f"  该地形满速贴地：{'吃 12' if hit else '免'}")

def r7_backstep_cases():
    print("\n[R7 扫掠后撤扫描] 站桩 px=0，0.35s 反应后向 BOSS 反向撤 d px 后停（每 50px）")
    for order in ("down", "up"):
        first_ok = None
        for d in range(0, 1001, 50):
            sc = lambda t, d=d: (-1 if t > 0.35 else 0, False, False)
            tr = player_sim(sc, 4, v0=0)
            tr2, stopped, base = [], False, None
            # 撤满 d 后刹停：重算——用逐帧剪裁法近似（位移到 d 后位置钉住）
            for t, x, fy in tr:
                tr2.append((t, max(x, -d), fy))
            hits = sweep_hits(tr2, sweep(0, 600, 1400, order), 600)
            if not hits and first_ok is None:
                first_ok = d
        print(f"  {order}: 最小免伤后撤位移 = {first_ok}px")

if __name__ == "__main__":
    r8_thrust_cases()
    r16_cases()
    r7_backstep_cases()
