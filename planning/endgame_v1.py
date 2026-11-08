"""Cosmica endgame model v1 (Nov 2026): how fast does a player reach the 1e300 ceiling?

Trigger: 5-star review on 3.4.0 (Thenungod, UK, 2026-11-06): "with a low num cap of
e300 it is quite easily to get to a point where you cycle prestiges for free extra
magnitudes of click damage etc in literal minutes ... after a couple of days there
is simply nothing left to do after spamming 20 cosmic resets to gain all 8 pillars."

Run economy (from pace_v2.run_for, calibrated 2026-11-08): above a permanent
multiplier of ~1e20 a run is saturated and earns L ~= 6.1e15 * log10(M) * M * seconds.
So a run touches the 1e300 ceiling once M ~ 1e278.

Everything else mirrors the Swift: shards 150*sqrt(L/1e12) x yield, +2%/unspent
shard, tree ranks (x4 cost), the 8 Cosmic Wonders with levels (x10 cost), True
Cosmos 50*sqrt(S/1e6) fragments (+5% each), Multiverse 5*sqrt(F/1e3) sparks
(+250% each), Null Seed / Spark Furnace / Fragment Prism.

Player: Big Bangs every `run_h` hours (or as soon as a run touches the ceiling,
min 1 minute), spends shards on whatever pays (rank/Wonder level while its cost
< (1 - 1/gain) x shards held), True Cosmos when it at least doubles fragments,
collapses when it at least doubles sparks. The "active" player also taps 1/s on
average, which is worth 0.1 x tapMult seconds of production per second.

Run:  python endgame_v1.py [live|fix] [idle|active]
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pace_v2 as p

CAP = 1e300
_cache = {}

def run_L(M, seconds):
    """Lifetime one run reaches with permanent multiplier M in `seconds` (capped)."""
    if M >= 1e20:
        return min(CAP, 6.1e15 * math.log10(M) * M * seconds)
    key = (round(math.log10(max(M, 1)), 1), round(seconds))
    if key not in _cache:
        _cache[key] = p.run_for(10 ** key[0], seconds)
    return min(CAP, _cache[key])

def seconds_to_cap(M):
    if M < 1e20: return None
    return CAP / (6.1e15 * math.log10(M) * M)

# Cosmic Wonders: id -> (cosmos required, level-1 cost, max level or 0)
WONDERS = {
    "chronosphere": (1, 5e3, 0), "nexus_lattice": (2, 2e4, 0), "voidkeeper": (4, 1e5, 0),
    "multiverse_engine": (7, 5e5, 0), "absolute_aperture": (10, 2.5e6, 0),
    "time_lens": (12, 2.5e7, 1), "event_horizon": (15, 1e8, 1), "stellar_forge": (20, 1e10, 0),
}
RANKS = {  # node: (last regular cost, rank multiplier, kind)
    "focus": (3 * 1.6**11, 1.10, "prod"), "harvest": (2 * 1.6**11, 1.10, "prod"),
    "chronal": (5 * 1.7**7, 1.15, "prod"), "big_bang": (5 * 1.8**5, 1.10, "yield"),
    "tap_mastery": (3 * 1.6**7, 1.25, "tap"),
}

class Rules:
    """The tunable knobs. Defaults = 3.4.0 as shipped."""
    def __init__(self, **kw):
        self.wonder_growth = 10.0       # each Wonder level costs this x the last
        self.forge_per_level = 2.0      # Stellar Forge: x2 per level (multiplicative)
        self.engine_per_level = 2.0     # Multiverse Engine: x2 taps per level
        self.forge_additive = False     # True -> 1 + (forge_per_level-1)*level
        self.engine_additive = False
        self.tap_rank = 1.25
        self.tap_cap = float('inf')
        self.spark_frag_sqrt = False   # True -> fragments x (1 + 0.25*sqrt(sparks)) instead of linear
        self.furnace_growth, self.prism_growth = 3.0, 4.0     # most a tap's multipliers may add up to
        self.cosmos_goal = None         # fn(cosmos n) -> lifetime one run must reach in this cosmos
        # Past these knees each layer's payout grows with this exponent instead of 0.5.
        self.shard_knee, self.shard_exp = 1e300, 0.5
        self.frag_knee, self.frag_exp = 1e300, 0.5
        self.spark_knee, self.spark_exp = 1e300, 0.5
        self.__dict__.update(kw)

    def forge(self, l):
        return 1 + (self.forge_per_level - 1) * l if self.forge_additive else self.forge_per_level ** min(l, 1000)
    def engine(self, l):
        return 1 + (self.engine_per_level - 1) * l if self.engine_additive else self.engine_per_level ** min(l, 1000)

    @staticmethod
    def _curve(x, base, scale, knee, exp):
        """scale * sqrt(x/base) up to `knee`, then continuing with exponent `exp`."""
        if x <= knee: return scale * math.sqrt(x / base)
        return scale * math.sqrt(knee / base) * (x / knee) ** exp
    def shards(self, L): return self._curve(L, 1e12, 150, self.shard_knee, self.shard_exp)
    def frags(self, S):  return self._curve(S, 1e6, 50, self.frag_knee, self.frag_exp) if S >= 1e6 else 0.0
    def sparks(self, F): return self._curve(F, 1e3, 5, self.spark_knee, self.spark_exp) if F >= 1e3 else 0.0

def simulate(rules, run_h=1.0, active=True, days=60, verbose=False):
    S = 0.0; life_S = 0.0; F = 0.0; V = 0.0; n = 0; mv = 0
    W = {k: 0 for k in WONDERS}; void = {"seed": 0, "furnace": 0, "prism": 0}
    absolute = False; best_this_cosmos = 0.0; bbs = 0; ranks_paid = 0.0
    t = 0.0; first = {}

    def buy_wonders(left):
        bought = True
        while bought:
            bought = False
            for k, (req, c1, mx) in WONDERS.items():
                if n < req or (mx and W[k] >= mx) or W[k] >= 2000: continue
                if k == "multiverse_engine" and not active: continue
                c = c1 * rules.wonder_growth ** W[k]
                l = W[k]
                gain = {"stellar_forge": rules.forge(l + 1) / rules.forge(l),
                        "multiverse_engine": rules.engine(l + 1) / rules.engine(l),
                        "voidkeeper": (1.5 + 0.5 * l) / (1 + 0.5 * l),
                        "nexus_lattice": (3 + 2 * l) / (1 + 2 * l) if W["event_horizon"] else 1.0,
                        "absolute_aperture": (1.25 + 0.25 * l) / (1 + 0.25 * l),
                        }.get(k, 2.0 if l == 0 else 1.0)
                if gain > 1 and c < (1 - 1 / gain) * left:
                    left -= c; W[k] += 1; bought = True
        return left

    while t < days * 86400:
        has_tree = life_S >= 5000 or n > 0
        # ---- spend shards: Wonders (permanent) first, then tree ranks (lost on True Cosmos) ----
        S = buy_wonders(S)
        left = S; prod = 1.0; yld = 1.0; tapm = 1.0
        if has_tree:
            for node, (c0, m, kind) in RANKS.items():
                if kind == "tap":
                    if not active: continue
                    m = rules.tap_rank
                r = 0
                while left > 0 and r < 3000:
                    c = c0 * 4.0 ** (r + 1)
                    if c >= (1 - 1 / m) * left: break
                    left -= c; r += 1
                if kind == "prod": prod *= m ** r
                elif kind == "yield": yld *= m ** r
                else: tapm *= m ** r
        # ---- run ----
        P = 11.4 if has_tree else 1.0
        Y = (1.9 if has_tree else 1.0) * yld * (1 + 0.5 * W["voidkeeper"]) * 2.0 ** min(void["furnace"], 1000)
        events = (1 + 2 * W["nexus_lattice"]) if W["event_horizon"] else 1.0
        M = ((1 + 0.02 * left) * P * prod * (1 + 0.05 * F) * (1 + 2.5 * V)
             * rules.forge(W["stellar_forge"]) * events)
        tap_mult = (1 + 0.25 * 8) * tapm * rules.engine(W["multiverse_engine"]) if active and has_tree else 1.0
        tap_mult = min(tap_mult, rules.tap_cap)
        if active: M *= (1 + 0.1 * tap_mult)
        T = run_h * 3600
        stc = seconds_to_cap(M)
        if stc is not None and stc < T:
            T = max(60.0, stc)
        L = run_L(M, T)
        floor = (1e10, 1e11)[bbs] if n == 0 and bbs < 2 else 1e12
        if L < floor:   # keep going until Big Bang unlocks (the game doesn't let you reset for nothing)
            tf, _ = p.run_time(M, target=floor, limit_days=60)
            T, L = (tf or 60 * 86400), floor
        bbs += 1
        t += T
        best_this_cosmos = max(best_this_cosmos, L)
        if L >= 1e36: absolute = True
        if L >= CAP and "cap" not in first: first["cap"] = t / 86400
        gainS = rules.shards(L) * Y if L >= floor else 0.0
        if n == 0 and life_S < 6000:  # Kindling
            room = 6000 - life_S
            gainS = gainS * 3 if gainS * 3 <= room else room + (gainS - room / 3)
        S = left + gainS; life_S += gainS
        # ---- True Cosmos ----
        goal_ok = rules.cosmos_goal is None or best_this_cosmos >= rules.cosmos_goal(n)
        fmult = (1 + 0.25 * W["absolute_aperture"]) * (1 + 0.25 * (math.sqrt(V) if rules.spark_frag_sqrt else V)) * 2.0 ** min(void["prism"], 1000)
        if absolute and goal_ok and rules.frags(S) * fmult >= max(F, 50):
            S = buy_wonders(S)                       # permanent: worth buying before the reset
            fgain = rules.frags(S) * fmult
            F += fgain; n += 1
            S = S * 0.1 * min(void["seed"], 5); best_this_cosmos = 0.0
            if all(W[k] > 0 for k in WONDERS) and "all wonders" not in first:
                first["all wonders"] = t / 86400
            if n == 20 and "cosmos 20" not in first: first["cosmos 20"] = t / 86400
            # ---- Multiverse ----
            vgain = rules.sparks(F)
            if n >= 10 and vgain >= max(V, 2):
                V += vgain; mv += 1; F = 0; S = 0
                for key, (c1, g, mx) in {"seed": (2.0, 2.0, 5), "furnace": (3.0, rules.furnace_growth, 0), "prism": (5.0, rules.prism_growth, 0)}.items():
                    while (not mx or void[key] < mx) and void[key] < 900:
                        c = c1 * g ** float(void[key])
                        if c >= 0.5 * V: break
                        V -= c; void[key] += 1
            if verbose:
                print(f"  day {t/86400:6.2f}  cosmos {n:3d}  multiverse {mv:2d}  run L={L:.1e}  M={M:.1e} "
                      f"F={F:.1e} V={V:.1e} forge={W['stellar_forge']} engine={W['multiverse_engine']}")
    return first, n, mv

def report(name, rules, **kw):
    first, n, mv = simulate(rules, **kw)
    def d(x): return f"day {x:.1f}" if x is not None else "not by day 60"
    print(f"  {name:44s} ceiling {d(first.get('cap')):>14}   cosmos 20 {d(first.get('cosmos 20')):>14}"
          f"   ({n} cosmoi, {mv} collapses by day 60)")

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "live"
    who = sys.argv[2] if len(sys.argv) > 2 else "active"
    if mode == "live":
        active = who == "active"
        simulate(Rules(), run_h=1.0 if active else 8.0, active=active, verbose=True, days=30)
    else:
        for player, a, h in (("active", True, 1.0), ("idle", False, 8.0)):
            print(f"--- {player} ---")
            report("3.4.0 live", Rules(), active=a, run_h=h)
