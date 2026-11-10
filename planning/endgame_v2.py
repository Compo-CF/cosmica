"""Cosmica endgame model v2 (Nov 2026, for 4.0): the v1 player, in log10 space, so
it can run past Double's 1e308 and show what removing the ceiling does.

Same economy and player as endgame_v1.py, with the knobs 3.4.1 shipped:
Wonder levels x100, Furnace x9 / Prism x16 cost growth, fragments past 1e9 shards
^0.45, spark fragment bonus 1 + 0.25*sqrt(sparks), Cosmos Goal 1e(36+4n).
Every quantity is held as log10(x) (-inf = 0). Purchases that v1 made one level
at a time are solved in closed form (levels can reach the hundreds of thousands).

Run:  python endgame_v2.py [cap|nocap|both] [days]
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pace_v2 as p

L10 = math.log10
NEG = float("-inf")

def lsum(a, b):
    if a == NEG: return b
    if b == NEG: return a
    hi, lo = max(a, b), min(a, b)
    return hi + L10(1 + 10 ** (lo - hi)) if hi - lo < 300 else hi

def lsub(a, b):
    """log10(10^a - 10^b), a >= b; -inf when they cancel."""
    if b == NEG: return a
    if b >= a: return NEG
    d = b - a
    return a + L10(1 - 10 ** d) if d > -300 else a

def l1p(c, lx):
    """log10(1 + c * 10^lx)."""
    return lsum(0.0, (L10(c) + lx) if lx != NEG else NEG)

def run_lL(lM, seconds):
    """log10 lifetime one run reaches with permanent multiplier 10^lM in `seconds`."""
    if lM >= 20:
        return L10(6.1e15) + L10(lM) + lM + L10(seconds)
    return L10(max(p.run_for(10 ** lM, seconds), 1.0))

WONDERS = {  # id -> (cosmos required, level-1 cost, max level or 0)
    "chronosphere": (1, 5e3, 0), "nexus_lattice": (2, 2e4, 0), "voidkeeper": (4, 1e5, 0),
    "multiverse_engine": (7, 5e5, 0), "absolute_aperture": (10, 2.5e6, 0),
    "time_lens": (12, 2.5e7, 1), "event_horizon": (15, 1e8, 1), "stellar_forge": (20, 1e10, 0),
}
RANKS = {"focus": (3 * 1.6**11, 1.10, "prod"), "harvest": (2 * 1.6**11, 1.10, "prod"),
         "chronal": (5 * 1.7**7, 1.15, "prod"), "big_bang": (5 * 1.8**5, 1.10, "yield"),
         "tap_mastery": (3 * 1.6**7, 1.25, "tap")}
VOID = {"seed": (2.0, 2.0, 5), "furnace": (3.0, 9.0, 0), "prism": (5.0, 16.0, 0)}
WONDER_GROWTH = 100.0

def wonder_gain(k, l, W):
    """Multiplier the next level adds (>1 means worth buying)."""
    if k in ("stellar_forge", "multiverse_engine"): return 2.0
    if k == "voidkeeper": return (1.5 + 0.5 * l) / (1 + 0.5 * l)
    if k == "nexus_lattice": return (3 + 2 * l) / (1 + 2 * l) if W["event_horizon"] else 1.0
    if k == "absolute_aperture": return (1.25 + 0.25 * l) / (1 + 0.25 * l)
    return 2.0 if l == 0 else 1.0

def levels_affordable(level, lcost1, lgrowth, lbudget, frac_of):
    """Highest level reachable from `level` where buying level l costs
    10^(lcost1 + l*lgrowth) and must stay under frac_of(l) * budget. Returns
    (new level, log10 total spent). Monotone, so binary search."""
    def ok(l):
        f = frac_of(l)
        return f > 0 and lcost1 + l * lgrowth < L10(f) + lbudget
    if lbudget == NEG or not ok(level): return level, NEG
    lo, hi = level, level + 1
    while ok(hi) and hi < 10**9: lo, hi = hi, hi * 2 + 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if ok(mid): lo = mid
        else: hi = mid
    top = lo                      # levels level..top are bought
    g = 10 ** lgrowth
    tail = L10(g / (g - 1)) if g > 1 else L10(top - level + 1)
    return top + 1, lcost1 + top * lgrowth + tail

def simulate(run_h=1.0, active=True, days=90, cap=None, verbose=False, marks=(7, 14, 30, 60, 90)):
    lS = NEG; life_S = 0.0; lF = NEG; lV = NEG; n = 0; mv = 0
    W = {k: 0 for k in WONDERS}; void = {k: 0 for k in VOID}
    absolute = False; best = NEG; bbs = 0; t = 0.0
    first = {}; trace = {}; next_mark = list(marks)

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

    def fragments(lshards):
        if lshards == NEG or lshards < 6: return NEG
        return L10(50) + (0.5 * (lshards - 6) if lshards <= 9 else 1.5 + 0.45 * (lshards - 9))

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
        T = run_h * 3600
        lL = run_lL(lM, T)
        if cap is not None and lL > cap:   # the old ceiling: the run stops when it hits it
            T = max(60.0, T * 10 ** (cap - lL)); lL = cap
        lfloor = L10((1e10, 1e11)[bbs]) if n == 0 and bbs < 2 else 12.0
        if lL < lfloor:
            tf, _ = p.run_time(10 ** lM, target=10 ** lfloor, limit_days=60)
            T, lL = (tf or 60 * 86400), lfloor
        bbs += 1; t += T
        best = max(best, lL)
        if lL >= 36: absolute = True
        for name, thr in (("1e100", 100), ("1e300", 300), ("1.8e308 (Omniverse door)", 308.25), ("1e1000", 1000)):
            if lL >= thr and name not in first: first[name] = t / 86400
        while next_mark and t >= next_mark[0] * 86400:
            trace[next_mark.pop(0)] = (lL, n, mv)
        lgain = L10(150) + 0.5 * (lL - 12) + lY
        if n == 0 and life_S < 6000:
            g = 10 ** lgain; room = 6000 - life_S
            g = g * 3 if g * 3 <= room else room + (g - room / 3)
            lgain = L10(g)
        lS = lsum(lleft, lgain); life_S = min(life_S + 10 ** min(lgain, 300), 1e300)
        # ---- True Cosmos ----
        goal = 36 + 4 * n
        if cap is not None: goal = min(cap, goal)
        goal_ok = n == 0 or best >= goal
        lfm = (L10(1 + 0.25 * W["absolute_aperture"]) + l1p(0.25, 0.5 * lV if lV != NEG else NEG)
               + void["prism"] * L10(2))
        lfr = fragments(lS)
        if absolute and goal_ok and lfr != NEG and lfr + lfm >= max(lF, L10(50)):
            lS = buy_wonders(lS)
            lfr = fragments(lS)
            if lfr != NEG:
                lF = lsum(lF, lfr + lfm); n += 1
                lS = lS + L10(0.1 * min(void["seed"], 5)) if void["seed"] else NEG
                best = NEG
                if n == 20 and "cosmos 20" not in first: first["cosmos 20"] = t / 86400
                lv = L10(5) + 0.5 * (lF - 3) if lF != NEG and lF >= 3 else NEG
                if n >= 10 and lv != NEG and lv >= max(lV, L10(2)):
                    lV = lsum(lV, lv); mv += 1; lF = NEG; lS = NEG
                    for key, (c1, g, mx) in VOID.items():
                        new, spent = levels_affordable(void[key], L10(c1), L10(g), lV, lambda l: 0.5)
                        if mx: new = min(new, mx)
                        if new > void[key]:
                            void[key] = new; lV = lsub(lV, spent)
                if verbose and n % 10 == 0:
                    print(f"  day {t/86400:6.2f} cosmos {n:4d} mv {mv:3d} run 1e{lL:,.0f} M 1e{lM:,.0f} "
                          f"F 1e{lF:,.0f} V 1e{lV:,.1f} forge {W['stellar_forge']} furnace {void['furnace']}")
    return first, trace, n, mv

def report(label, **kw):
    first, trace, n, mv = simulate(**kw)
    print(f"--- {label}: {n} cosmoi, {mv} collapses by day {kw.get('days', 90)}")
    for k in ("1e100", "1e300", "1.8e308 (Omniverse door)", "1e1000", "cosmos 20"):
        print(f"    {k:28s} {('day %.1f' % first[k]) if k in first else '-'}")
    for d, (lL, nn, m) in sorted(trace.items()):
        print(f"    day {d:3d}: best run ~1e{lL:,.0f}, cosmos {nn}, collapses {m}")

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "both"
    days = int(sys.argv[2]) if len(sys.argv) > 2 else 90
    for who, active, h in (("active (1h runs + taps)", True, 1.0), ("idle (8h runs)", False, 8.0)):
        if mode in ("cap", "both"):
            report(f"{who}, 1e300 ceiling (3.4.1 live)", run_h=h, active=active, days=days, cap=300.0)
        if mode in ("nocap", "both"):
            report(f"{who}, no ceiling", run_h=h, active=active, days=days, cap=None)
