"""Cosmica pacing model v2 (Oct 2026): where does the climb to Absolute slow down?

Mirrors the live numbers in GameContent.swift / Tier.swift / PrestigeCalculator:
16 generators, 3 per-generator upgrades + 2 globals, 12 tiers, shards =
150*sqrt(L/1e12) per Big Bang, +2% earnings per unspent shard.

The player is idle and buys greedily by payback time (what auto-buy and a
sensible active player both approximate). No taps, events or ad boosts.

  run_time(M, target)   seconds for one run to reach `target` lifetime ✦,
                        given a permanent multiplier M (shards, tree, etc.)

Findings, 22 Oct 2026 (idle player, Big Bang every 8h, holds for Absolute
once a single run reaches it within 2 days; no taps/events/boosts, so real
players are somewhat faster):
  * Past ~1e30 a run saturates: generator costs outrun income, so production
    is just M x constant and every further x10 of lifetime takes x10 the time.
    Shards come from sqrt(lifetime) and add to the balance, so shard growth
    per run decays (16-24%/run near the end). That is the "days of AFK".
  * 3.2: tree maxed day 7.3, breakpoint 1.3d, second slog 5.0d -> first
    Absolute day 13.6. Matches the Candeloro1 review shape exactly.
  * 3.3 Stellar ranks (x4 cost growth): production x115 at 1e13 shards while
    keeping ~70% of them; second slog 5.0d -> 0.3d, first Absolute day 8.7.
    Gentler ranks (1.05/1.08) still give 0.6d: the fix is robust.
  * The early slog (0 -> 5,000 shards, ~7 days here) is now most of the
    journey. 3x shards until the tree is affordable -> first Absolute day 4.3.
  * BUILT in 3.3 as Kindling (x3 until 6,000 lifetime shards, first cosmos,
    only the part under the cap tripled): tree day 7.3 -> 3.0, Absolute 8.7 -> 4.3.
Run:  python pace_v2.py single | journey | ranks | kindling
"""
import math, sys

G = [(10,0.1,1.07),(100,1,1.08),(1200,8,1.09),(15000,47,1.10),(2e5,260,1.11),(3e6,1400,1.12),
     (5e7,7800,1.13),(8e8,44000,1.14),(1.2e10,260000,1.15),(2e11,1.6e6,1.15),(3e12,1e7,1.16),
     (5e13,6.5e7,1.17),(8e14,5e8,1.17),(1.5e16,4e9,1.18),(3e17,3e10,1.18),(6e18,2.5e11,1.19)]
UPS = [(2,25,10),(2,200,25),(3,5000,50)]           # (multiplier, cost factor, unlock at)
GLOBALS = [(1e9,1.5),(1e15,2.0)]
TIERS = [(0,1.0),(1e5,1.25),(1e8,1.6),(1e11,2.0),(1e14,2.75),(1e17,4.0),(1e20,6.0),
         (1e23,8.5),(1e26,12.0),(1e29,18.0),(1e32,28.0),(1e36,45.0)]

def tier(L):
    m = 1.0
    for t, mult in TIERS:
        if L >= t: m = mult
    return m

def run_time(M, target=1e36, limit_days=400, start_stardust=0.0):
    n = [0]*16; up = [[False]*3 for _ in G]; gl = [False, False]
    s = start_stardust; L = 0.0; t = 0.0
    marks = {}
    while t < limit_days*86400:
        gmul = math.prod(m for (c, m), b in zip(GLOBALS, gl) if b)
        umul = [math.prod(UPS[k][0] for k in range(3) if up[i][k]) for i in range(16)]
        mult = tier(L) * M * gmul
        rate = sum(G[i][1]*umul[i]*n[i] for i in range(16)) * mult
        # buy greedily by payback until nothing affordable improves things
        for _ in range(4000):
            best = None
            for i, (bc, br, g) in enumerate(G):
                c = bc * g**n[i]
                if c <= s:
                    pb = c / (br*umul[i]*mult)
                    if best is None or pb < best[0]: best = (pb, 'g', i, c)
                for k, (m, cf, ua) in enumerate(UPS):
                    if not up[i][k] and n[i] >= ua and bc*cf <= s:
                        d = br*umul[i]*n[i]*(m-1)*mult
                        if d > 0 and (best is None or bc*cf/d < best[0]): best = (bc*cf/d, 'u', (i, k), bc*cf)
            for j, (c, m) in enumerate(GLOBALS):
                if not gl[j] and c <= s and rate > 0:
                    pb = c / (rate*(m-1))
                    if best is None or pb < best[0]: best = (pb, 'G', j, c)
            if best is None: break
            _, kind, idx, c = best; s -= c
            if kind == 'g': n[idx] += 1
            elif kind == 'u': up[idx[0]][idx[1]] = True
            else: gl[idx] = True
            gmul = math.prod(m for (cc, m), b in zip(GLOBALS, gl) if b)
            umul = [math.prod(UPS[k][0] for k in range(3) if up[i][k]) for i in range(16)]
            mult = tier(L) * M * gmul
            rate = sum(G[i][1]*umul[i]*n[i] for i in range(16)) * mult
        if rate <= 0:                      # fresh run: one free telescope's worth of taps
            rate = 1.0
        dt = max(1.0, min(3600.0, t * 0.002))
        gain = rate * dt
        s += gain; L += gain; t += dt
        for p in range(10, 37):
            if 10**p not in marks and L >= 10**p: marks[10**p] = t
        if L >= target:
            global LAST_L; LAST_L = L
            return t, marks
    LAST_L = L
    return None, marks

LAST_L = 0.0

def fmt(sec):
    if sec is None: return ">limit"
    d = sec/86400
    return f"{d:.1f}d" if d >= 1 else (f"{sec/3600:.1f}h" if sec >= 3600 else f"{sec/60:.0f}m")

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "single"
    # Permanent multiplier from a maxed Cosmic Tree + all original achievements
    # (focus 1.96 x harvest 2.2 x cluster 1.96 x achievements 1.35 ~= 11.4).
    P = 11.4
    if mode == "single":
        print("Time for ONE run to reach Absolute (1e36), by unspent shards held (tree maxed):")
        for S in [1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13, 1e14]:
            M = (1 + 0.02*S) * P
            t, marks = run_time(M)
            share = {p: marks.get(10**p) for p in (24, 30, 33, 36)}
            print(f"  S={S:8.0e}  M={M:9.2e}  ->1e36 in {fmt(t):>8}   "
                  f"1e24 at {fmt(share[24])}, 1e30 at {fmt(share[30])}, 1e33 at {fmt(share[33])}")

def run_for(M, seconds, target=1e300):
    """Lifetime ✦ one run reaches in `seconds` (stops early at `target`)."""
    run_time(M, target=target, limit_days=seconds/86400)
    return LAST_L

def journey(absolute=1e36, exponent=0.5, run_hours=8, hold_days=2.0, P_tree=11.4, max_runs=400):
    """Idle player: Big Bang every `run_hours`; hold for Absolute once one run gets
    there within `hold_days`. Returns (days to Absolute, runs, shards at the end)."""
    S, days = 0.0, 0.0
    for r in range(max_runs):
        P = P_tree if S >= 5000 else 1.0
        Y = 1.9 if S >= 5000 else 1.0            # Big Bang Yield node maxed with the tree
        M = (1 + 0.02*S) * P
        t, _ = run_time(M, target=absolute, limit_days=hold_days)
        if t is not None:
            return days + t/86400, r + 1, S
        L = run_for(M, run_hours*3600)
        S += 150 * (L/1e12)**exponent * Y
        days += run_hours/24
    return None, max_runs, S

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "journey":
    for label, kw in [("live: Absolute 1e36, sqrt shards", {}),
                      ("Absolute at 1e35 (1000x step like every other tier)", {"absolute": 1e35}),
                      ("shards L^0.55", {"exponent": 0.55}),
                      ("both", {"absolute": 1e35, "exponent": 0.55})]:
        d, runs, S = journey(**kw)
        print(f"  {label:55s} first Absolute in {('%.1f days' % d) if d else '>limit':>10}  ({runs} runs, {S:.1e} shards)")


# v3.3 Stellar ranks. A rational player buys a rank while its gain beats the
# passive bonus the spent shards were giving: rank cost c, holdings S, rank
# multiplier m -> worth it while m * (1 - c/S) > 1, i.e. c < (1 - 1/m) * S.
RANK_NODES = {  # node: (last regular cost, rank multiplier, what it multiplies)
    "focus":    (3 * 1.6**11, 1.10, "prod"),
    "harvest":  (2 * 1.6**11, 1.10, "prod"),
    "chronal":  (5 * 1.7**7,  1.15, "prod"),   # the cluster late production comes from
    "big_bang": (5 * 1.8**5,  1.10, "yield"),
}

def ranks_for(S, cost_growth=4.0, rank_mults=None):
    """(production multiplier, shard-yield multiplier, shards left) after buying ranks."""
    prod, yld, left = 1.0, 1.0, S
    for node, (c0, m, kind) in RANK_NODES.items():
        m = (rank_mults or {}).get(node, m)
        r = 0
        while True:
            c = c0 * cost_growth**(r + 1)
            if left <= 0 or c >= (1 - 1/m) * left: break
            left -= c; r += 1
        if kind == "prod": prod *= m**r
        else: yld *= m**r
    return prod, yld, left

def journey_ranks(absolute=1e36, run_hours=8, hold_days=2.0, P_tree=11.4, max_runs=400, **rk):
    S, days = 0.0, 0.0
    for r in range(max_runs):
        P = P_tree if S >= 5000 else 1.0
        Y = 1.9 if S >= 5000 else 1.0
        prod, yld, left = ranks_for(S, **rk) if S >= 5000 else (1.0, 1.0, S)
        M = (1 + 0.02*left) * P * prod
        t, _ = run_time(M, target=absolute, limit_days=hold_days)
        if t is not None:
            return days + t/86400, r + 1, S
        L = run_for(M, run_hours*3600)
        S += 150 * (L/1e12)**0.5 * Y * yld
        days += run_hours/24
    return None, max_runs, S

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "ranks":
    for S in [1e5, 1e8, 1e11, 1e13, 1e14]:
        prod, yld, left = ranks_for(S)
        print(f"  S={S:.0e}: ranks give production x{prod:,.0f}, shard yield x{yld:.1f}, "
              f"{left/S*100:.0f}% of shards kept -> net x{prod*(1+0.02*left)/(1+0.02*S):,.0f}")
    for label, kw in [("3.2 (no ranks)", None), ("3.3 ranks as built (x4 cost)", {}),
                      ("ranks, x6 cost", {"cost_growth": 6.0}), ("ranks, x8 cost", {"cost_growth": 8.0})]:
        d, runs, S = (journey() if kw is None else journey_ranks(**kw))
        print(f"  {label:32s} first Absolute in {('%.1f days' % d) if d else '>limit':>10} ({runs} runs, {S:.1e} shards)")


# v3.3 Kindling: Big Bangs pay x3 until 6,000 lifetime shards (first cosmos).
# Only the part under the cap is tripled (mirrors PrestigeCalculator.kindled).
KINDLING_CAP = 6000.0

def kindled(shards, lifetime):
    if lifetime >= KINDLING_CAP: return shards
    room = KINDLING_CAP - lifetime
    return shards*3 if shards*3 <= room else room + (shards - room/3)

def journey_kindling(absolute=1e36, run_hours=8, hold_days=2.0, P_tree=11.4, max_runs=400,
                     kindling=True, tree_at=5000):
    S, days, tree_day = 0.0, 0.0, None
    for r in range(max_runs):
        has_tree = S >= tree_at
        if has_tree and tree_day is None: tree_day = days
        P = P_tree if has_tree else 1.0
        Y = 1.9 if has_tree else 1.0
        prod, yld, left = ranks_for(S) if has_tree else (1.0, 1.0, S)
        M = (1 + 0.02*left) * P * prod
        t, _ = run_time(M, target=absolute, limit_days=hold_days)
        if t is not None:
            return days + t/86400, r + 1, tree_day
        L = run_for(M, run_hours*3600)
        gain = 150 * (L/1e12)**0.5 * Y * yld
        S += kindled(gain, S) if kindling else gain
        days += run_hours/24
    return None, max_runs, tree_day

if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "kindling":
    for label, k in [("3.3 ranks, no Kindling", False), ("3.3 ranks + Kindling x3 to 6,000", True)]:
        d, runs, tree = journey_kindling(kindling=k)
        print(f"  {label:36s} tree affordable day {tree:.1f}, first Absolute day {d:.1f} ({runs} runs)")
