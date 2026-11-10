"""Cosmica 4.0 Omniverse model (Nov 2026). endgame_v2's player, plus the layer above
the Multiverse, to tune dilation + Echoes before writing any Swift.

Rules being tested (all knobs in `Omni`):
  * Dilation: past 1.8e308, each order of magnitude of the production multiplier
    counts at d (d0 = 0.5). Above ~0.65 the runaway comes back (endgame_v2 sweep),
    so the Echo node that raises d stops short of that.
  * The Omniverse door opens the first time one run passes 1.8e308.
  * Omniverse collapse pays Echoes = floor(10^((log10 bestRun - 308.25) / scale)),
    resets shards, fragments, sparks, Void Wonders and the Cosmos Goal ladder
    (cosmoi counted since the last collapse). Cosmic Wonders and the lifetime
    cosmos count (unlocks) are kept.
  * Echoes: unspent ones multiply production x(1 + E) AFTER dilation, and buy
    "Thin the Veil" levels (+step to d each, cost c0 * growth^k).
  The player collapses the Omniverse when it would at least double their Echoes.

Run:  python omniverse_v1.py [days]
"""
import math, sys
from endgame_v2 import (L10, NEG, lsum, lsub, l1p, run_lL, WONDERS, RANKS, VOID,
                        WONDER_GROWTH, wonder_gain, levels_affordable, p)

DOOR = L10(1.8) + 308

class Omni:
    def __init__(self, **kw):
        self.d0 = 0.5
        self.veil_step = 0.01
        self.veil_max = 12            # d tops out at d0 + 12*0.01 = 0.62
        self.veil_c0, self.veil_growth = 5.0, 3.0
        self.echo_scale = 100.0       # +1 order of magnitude of Echoes per 100 orders of run
        self.echo_mult = True
        self.reset_goal = True
        self.__dict__.update(kw)

def simulate(o, run_h=1.0, active=True, days=180, marks=(7, 14, 30, 60, 90, 120, 180), verbose=False):
    lS = NEG; life_S = 0.0; lF = NEG; lV = NEG; n = 0; n_omni = 0; mv = 0
    W = {k: 0 for k in WONDERS}; void = {k: 0 for k in VOID}
    absolute = False; best = NEG; bbs = 0; t = 0.0
    lE = NEG; veil = 0; omni = 0; door_day = None
    trace = {}; next_mark = list(marks); omni_days = []

    def buy_wonders(lleft):
        for _ in range(3):
            for k, (req, c1, mx) in WONDERS.items():
                if n < req or (mx and W[k] >= mx): continue
                if k == "multiverse_engine" and not active: continue
                def frac(l, k=k):
                    g = wonder_gain(k, l, W)
                    return 1 - 1 / g if g > 1 else 0
                new, spent = levels_affordable(W[k], L10(c1), L10(WONDER_GROWTH), lleft, frac)
                if mx: new = min(new, mx)
                if new > W[k]:
                    W[k] = new; lleft = lsub(lleft, spent)
        return lleft

    def fragments(ls):
        if ls == NEG or ls < 6: return NEG
        return L10(50) + (0.5 * (ls - 6) if ls <= 9 else 1.5 + 0.45 * (ls - 9))

    while t < days * 86400:
        has_tree = life_S >= 5000 or n > 0
        lS = buy_wonders(lS)
        lleft = lS; lprod = 0.0; lyld = 0.0; ltap = 0.0
        if has_tree:
            for node, (c0, m, kind) in RANKS.items():
                if kind == "tap" and not active: continue
                r, spent = levels_affordable(0, L10(c0) + L10(4.0), L10(4.0), lleft, lambda l, m=m: 1 - 1 / m)
                lleft = lsub(lleft, spent)
                if kind == "prod": lprod += r * L10(m)
                elif kind == "yield": lyld += r * L10(m)
                else: ltap += r * L10(m)
        P = 11.4 if has_tree else 1.0
        lY = L10(1.9 if has_tree else 1.0) + lyld + L10(1 + 0.5 * W["voidkeeper"]) + void["furnace"] * L10(2)
        levents = L10(1 + 2 * W["nexus_lattice"]) if W["event_horizon"] else 0.0
        lM = (l1p(0.02, lleft) + L10(P) + lprod + l1p(0.05, lF) + l1p(2.5, lV)
              + W["stellar_forge"] * L10(2) + levents)
        if active and has_tree:
            lM += l1p(0.1, L10(3) + ltap + W["multiverse_engine"] * L10(2))
        # ---- dilation, then Echoes on top ----
        d = o.d0 + o.veil_step * veil
        if lM > DOOR: lM = DOOR + d * (lM - DOOR)
        if o.echo_mult and lE != NEG: lM += l1p(1.0, lE)
        T = run_h * 3600
        lL = run_lL(lM, T)
        lfloor = L10((1e10, 1e11)[bbs]) if n == 0 and bbs < 2 else 12.0
        if lL < lfloor:
            tf, _ = p.run_time(10 ** lM, target=10 ** lfloor, limit_days=60)
            T, lL = (tf or 60 * 86400), lfloor
        bbs += 1; t += T
        best = max(best, lL)
        if lL >= 36: absolute = True
        if lL >= DOOR and door_day is None: door_day = t / 86400
        while next_mark and t >= next_mark[0] * 86400:
            trace[next_mark.pop(0)] = (lL, n, omni, veil, lE)
        lgain = L10(150) + 0.5 * (lL - 12) + lY
        if n == 0 and life_S < 6000:
            g = 10 ** lgain; room = 6000 - life_S
            g = g * 3 if g * 3 <= room else room + (g - room / 3)
            lgain = L10(g)
        lS = lsum(lleft, lgain); life_S = min(life_S + 10 ** min(lgain, 300), 1e300)

        # ---- Omniverse collapse ----
        if door_day is not None and best >= DOOR:
            egain = math.floor(10 ** ((best - DOOR) / o.echo_scale))
            held = 10 ** lE if lE != NEG else 0
            if egain >= max(1, held):
                lE = L10(held + egain); omni += 1; omni_days.append(t / 86400)
                lS = NEG; lF = NEG; lV = NEG; void = {k: 0 for k in VOID}; best = NEG
                if o.reset_goal: n_omni = 0
                while veil < o.veil_max:
                    c = o.veil_c0 * o.veil_growth ** veil
                    if c > 0.5 * 10 ** lE: break
                    lE = L10(10 ** lE - c); veil += 1
                if verbose:
                    print(f"  day {t/86400:6.2f} OMNIVERSE #{omni}: +{egain} echoes, held 1e{lE:.1f}, veil {veil} (d={o.d0 + o.veil_step*veil:.2f}), cosmoi {n}")
                continue

        # ---- True Cosmos ----
        goal = 36 + 4 * n_omni
        goal_ok = n_omni == 0 or best >= goal
        lfm = (L10(1 + 0.25 * W["absolute_aperture"]) + l1p(0.25, 0.5 * lV if lV != NEG else NEG)
               + void["prism"] * L10(2))
        lfr = fragments(lS)
        if absolute and goal_ok and lfr != NEG and lfr + lfm >= max(lF, L10(50)):
            lS = buy_wonders(lS)
            lfr = fragments(lS)
            if lfr != NEG:
                lF = lsum(lF, lfr + lfm); n += 1; n_omni += 1
                lS = lS + L10(0.1 * min(void["seed"], 5)) if void["seed"] else NEG
                best = NEG
                lv = L10(5) + 0.5 * (lF - 3) if lF != NEG and lF >= 3 else NEG
                if n >= 10 and lv != NEG and lv >= max(lV, L10(2)):
                    lV = lsum(lV, lv); mv += 1; lF = NEG; lS = NEG
                    for key, (c1, g, mx) in VOID.items():
                        new, spent = levels_affordable(void[key], L10(c1), L10(g), lV, lambda l: 0.5)
                        if mx: new = min(new, mx)
                        if new > void[key]:
                            void[key] = new; lV = lsub(lV, spent)
    return door_day, trace, omni_days, n

def report(label, o, **kw):
    door, trace, omni_days, n = simulate(o, **kw)
    gaps = [b - a for a, b in zip(omni_days, omni_days[1:])]
    print(f"--- {label}: door day {door:.1f}" if door else f"--- {label}: door never", end="")
    print(f", {len(omni_days)} Omniverse collapses" + (f" (first day {omni_days[0]:.1f}, median gap {sorted(gaps)[len(gaps)//2]:.1f}d)" if gaps else ""))
    for dday, (lL, nn, om, veil, lE) in sorted(trace.items()):
        print(f"    day {dday:3d}: run ~1e{lL:,.0f}  cosmoi {nn}  omniverses {om}  veil {veil}  echoes 1e{lE:.1f}")

if __name__ == "__main__":
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 180
    for who, active, h in (("active", True, 1.0), ("idle", False, 8.0)):
        report(f"{who}, proposal", Omni(), run_h=h, active=active, days=days)
