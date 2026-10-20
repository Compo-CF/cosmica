"""Render Cosmica 3.2's synthesized sounds to WAV for listening (mirrors Synth in SoundManager.swift)."""
import numpy as np, wave, os, sys
SR = 44100
OUT = sys.argv[1]

def pluck(f, length, decay, amp, harmonics=((2, .25), (3, .08))):
    t = np.arange(int(length*SR))/SR
    env = np.minimum(1, t/0.002)*np.exp(-t/decay)
    s = np.sin(2*np.pi*f*t)
    for m, a in harmonics: s += a*np.sin(2*np.pi*f*m*t)*np.exp(-t/(decay*.5))
    return amp*env*s

def bell(f, amp): return pluck(f, .8, .25, amp, ((2.76, .35), (5.4, .12)))

def mix(length, parts):
    out = np.zeros(int(length*SR))
    for start, s in parts:
        o = int(start*SR); n = min(len(s), len(out)-o)
        if n > 0: out[o:o+n] += s[:n]
    return out

def arpeggio(notes, step, amp):
    return mix((len(notes)-1)*step+.45, [(i*step, pluck(f, .45, .16, amp)) for i, f in enumerate(notes)])

def sweep(f0, f1, length, amp):
    n = int(length*SR); x = np.arange(n)/n
    phase = np.cumsum(2*np.pi*f0*(f1/f0)**x/SR)
    return amp*np.sin(np.pi*x)*np.sin(phase)

def bigbang():
    n = int(2.4*SR); t = np.arange(n)/SR
    phase = np.cumsum(2*np.pi*(32+90*np.exp(-t/.35))/SR)
    boom = .55*np.minimum(1, t/.01)*np.exp(-t/.7)*np.sin(phase)
    rng = np.random.default_rng(1); white = rng.uniform(-1, 1, n); lp = np.zeros(n); v = 0
    for i in range(n): v += .03*(white[i]-v); lp[i] = v
    out = boom + 1.6*np.minimum(1, t/.02)*np.exp(-t/.45)*lp
    sh = mix(1.6, [(0, bell(1046.5, .05)), (.08, bell(1567.98, .05)), (.16, bell(2093, .04))])
    o = int(.35*SR); out[o:o+len(sh)] += sh[:n-o]
    return out

effects = {
 "tap": np.concatenate([np.concatenate([pluck(f, .35, .11, .2), np.zeros(int(.05*SR))]) for f in [1046.5,1174.66,1318.51,1567.98,1760,2093]]),
 "purchase": mix(.16, [(0, pluck(1318.51, .12, .03, .16)), (.035, pluck(1975.53, .12, .03, .12))]),
 "upgrade": arpeggio([523.25, 659.26, 783.99, 1046.5], .07, .16),
 "dailyClaim": arpeggio([659.26, 783.99, 1046.5, 1318.51, 1567.98], .06, .15),
 "skillUnlock": arpeggio([783.99, 1174.66], .09, .18),
 "specialize": arpeggio([523.25, 783.99, 1046.5], .09, .16),
 "shardGrant": mix(.95, [(0, bell(1567.98, .1)), (.06, bell(2349.32, .08)), (.12, bell(3135.96, .06))]),
 "eventStart": mix(.9, [(0, sweep(440, 880, .45, .12)), (.38, pluck(1760, .5, .15, .12))]),
 "eventEnd": sweep(880, 440, .45, .1),
 "error": mix(.3, [(0, pluck(220, .12, .05, .2, ((3, .3),))), (.12, pluck(207.65, .15, .06, .2, ((3, .3),)))]),
 "bigBang": bigbang(),
}

def music():
    loop = 32.0; n = int(loop*SR); t = np.arange(n)/SR
    snap = lambda f: round(f*loop)/loop
    chords = [[146.83,220,329.63,369.99,554.37],[123.47,185,293.66,440,554.37],[98,146.83,369.99,493.88,554.37],[110,164.81,246.94,369.99,659.26]]
    chords = [[snap(f) for f in c] for c in chords]
    slot = loop/4; hw = slot*.75; s = np.zeros(n)
    for k, c in enumerate(chords):
        d = np.abs(t-(k*slot+slot/2)); d = np.minimum(d, loop-d)
        w = np.where(d < hw, .5*(1+np.cos(np.pi*d/hw)), 0)
        for v, f in enumerate(c):
            br = 1+.18*np.sin(2*np.pi*t*(v+2)/loop)
            s += w*br*.045*(np.sin(2*np.pi*f*t)+.12*np.sin(4*np.pi*f*t))
    for f in [snap(73.42), snap(110)]: s += .05*np.sin(2*np.pi*f*t)
    notes = [587.33,659.26,739.99,880,987.77,1174.66]
    times = [(1.5,3),(4.2,1),(7,5),(10.6,2),(13.1,0),(16.8,4),(19.5,2),(22.9,5),(25.4,1),(28.7,3),(30.9,0)]
    for start, k in times:
        dt = t-start; dt = np.where(dt < 0, dt+loop, dt); f = notes[k]
        env = np.where(dt < 7, np.minimum(1, dt/.01)*np.exp(-dt/1.4), 0)
        s += .035*env*(np.sin(2*np.pi*f*dt)+.25*np.sin(4*np.pi*f*dt))
    return s*(.32/np.abs(s).max())

def write(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name+".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype(np.int16).tobytes())

for k, v in effects.items():
    print(f"{k:12s} peak {np.abs(v).max():.3f}"); write("sfx-"+k, v)
m = music()
print("music seam", abs(m[-1]-m[0]), "max step", np.abs(np.diff(m)).max())
write("music-loop-32s", m)
write("music-3x-to-hear-the-seam", np.tile(m, 3))
