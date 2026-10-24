"""The Rogue's weapons: six families, each in the five sets.

    tools/art/blender.sh tools/art/make_rogue_arms.py [family ...]
    (or Blender's Python: pip install bpy, then python tools/art/make_rogue_arms.py)

Writes assets/kaykit/weapons/rogue_<family>_<set>.gltf in the Barbarian's set
ladder (make_barbarian_arms.py). All are light, one-hand blades held along +y
with the grip at the origin, flat faces toward +-z, like KayKit's dagger:
- daggers:    a pair of plain fighting knives, cross-guard and pommel;
- chakram:    a bladed throwing ring held by its grip bar;
- rapier:     a long needle blade under a cup-and-bow guard;
- sickles:    a pair of reaping hooks, the blade curling forward;
- katars:     a pair of punch daggers, the H-frame grip across the fist;
- nightblade: a long curved single edge, black from Bloodiron, runed.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, box, spike, mark, place, export  # noqa: E402
from make_barbarian_arms import SETS, haft, jewels  # noqa: E402
from make_hero_arms import blade, guard, pommel  # noqa: E402


def daggers(k):
    s = SETS[k]
    sz = s["size"]
    haft(-0.2, 0.02, 0.032, s, k, [(-0.17, 0.17)])
    pommel(-0.22, k, s, r=0.042)
    guard(0.04, 0.2 + 0.03 * k, k, s)
    blade(0.06, (0.42 + 0.05 * k) * sz, 0.06 * sz, k, s, tip=0.3)
    jewels((0, 0.04, 0.05), k, s, 1, 0.024)


def chakram(k):
    """A ring of edge around a hole, a grip bar across it at the origin."""
    s = SETS[k]
    sz = s["size"]
    c = 0.2 * sz
    ro, ri = 0.27 * sz, 0.17 * sz
    n = 16
    outer, inner = [], []
    for i in range(n + 1):
        a = math.pi * 2 * i / n - math.pi / 2
        outer.append((ro * math.cos(a), c + ro * math.sin(a)))
        inner.append((ri * math.cos(a), c + ri * math.sin(a)))
    plate(outer + list(reversed(inner)), 0.02, s["metal"], list(range(1, n + 1)), s["edge"])
    box((0, 0.0, 0), (0.05, 0.05, 0.05), s["wrap"])
    lathe([(-0.06, 0.03), (-0.04, 0.035), (0.04, 0.035), (0.06, 0.03)], s["wrap"], sides=6)
    # Teeth round the rim: more and longer up the ladder.
    teeth = 4 + 2 * k
    for i in range(teeth):
        a = math.pi * 2 * (i + 0.5) / teeth - math.pi / 2
        b = (ro * 0.95 * math.cos(a), c + ro * 0.95 * math.sin(a), 0)
        t = ((ro + 0.06 + 0.012 * k) * math.cos(a + 0.25), c + (ro + 0.06 + 0.012 * k) * math.sin(a + 0.25), 0)
        spike(b, 0.03, t, s["edge"], sides=3)
    if k >= 2:
        for sx in (-1, 1):
            gem((sx * (ri + ro) / 2, c, 0.025), 0.025, 0.03, 0.015, sw="red" if k == 3 else ("white" if k == 4 else s["trim"]))


def rapier(k):
    s = SETS[k]
    sz = s["size"]
    haft(-0.24, 0.04, 0.03, s, k, [(-0.21, 0.22)])
    pommel(-0.27, k, s, r=0.045)
    # The cup over the hand, then the quillons.
    lathe([(0.02, 0.03), (0.05, 0.1 + 0.01 * k), (0.07, 0.11 + 0.01 * k), (0.08, 0.03)], s["trim"] if k else s["metal"], sides=8)
    box((0, 0.08, 0), (0.3 + 0.04 * k, 0.03, 0.03), s["trim"] if k else s["metal"])
    if k >= 1:
        # A knuckle bow down to the pommel.
        m = mark()
        plate([(0.12, 0.06), (0.15, 0.06), (0.1, -0.26), (0.07, -0.26)], 0.012, s["trim"])
        place(m)
    w = 0.03 * sz
    pts = [(-w, 0.08), (w, 0.08), (w * 0.6, 0.08 + 0.95 * sz), (0, 0.08 + (1.05 + 0.06 * k) * sz), (-w * 0.6, 0.08 + 0.95 * sz)]
    plate(pts, 0.016, s["metal"], [1, 2, 3], s["edge"])
    jewels((0, 0.06, 0.1), k, s, 1, 0.022)


def _hook(top, r, k, s, half=0.022):
    """A sickle blade: an arc from the haft top curling forward (+x) and down."""
    n = 9
    outer, inner = [], []
    cx, cy = r * 0.85, top
    for i in range(n + 1):
        a = math.pi * (0.95 - 0.95 * i / n)  # from the haft side over the top
        ro = r
        ri = r * (0.62 + 0.3 * i / n)
        outer.append((cx + ro * math.cos(a), cy + ro * math.sin(a)))
        inner.append((cx + ri * math.cos(a), cy + ri * math.sin(a) * 0.9))
    pts = outer + list(reversed(inner))
    plate(pts, half, s["metal"], list(range(n + 1, 2 * n + 2)), s["edge"])


def sickles(k):
    s = SETS[k]
    sz = s["size"]
    top = 0.36
    haft(-0.18, top, 0.03, s, k, [(-0.15, 0.2)])
    lathe([(top - 0.02, 0.04), (top + 0.03, 0.04)], s["trim"], sides=6)
    _hook(top, 0.24 * sz, k, s)
    if k >= 3:
        spike((0.0, top, 0), 0.03, (-0.16 - 0.02 * k, top - 0.02, 0), s["edge"], sides=3)
    jewels((0, top, 0.045), k, s, 1, 0.022)


def katars(k):
    """Punch daggers: the fist closes on a crossbar at the origin, two side
    bars run up the forearm-less frame to the blade's broad base."""
    s = SETS[k]
    sz = s["size"]
    box((0, 0.0, 0), (0.15, 0.035, 0.035), s["wrap"])
    for sx in (-1, 1):
        box((sx * 0.09, 0.03, 0), (0.03, 0.22, 0.04), s["trim"] if k else s["metal"])
    box((0, 0.15, 0), (0.22, 0.04, 0.06), s["trim"] if k else s["metal"])
    w = (0.09 + 0.008 * k) * sz
    pts = [(-w, 0.17), (w, 0.17), (w * 0.5, 0.17 + 0.32 * sz), (0, 0.17 + (0.48 + 0.05 * k) * sz), (-w * 0.5, 0.17 + 0.32 * sz)]
    plate(pts, 0.026, s["metal"], [1, 2, 3, 4], s["edge"])
    if k >= 2:
        plate([(-w * 0.2, 0.19), (w * 0.2, 0.19), (0, 0.17 + 0.36 * sz)], 0.032, s["trim"] if k == 2 else "black")
    if k >= 4:
        for sx in (-1, 1):
            spike((sx * 0.1, 0.15, 0), 0.025, (sx * 0.2, 0.3, 0), "gold", sides=3)
    jewels((0, 0.15, 0.04), k, s, 1, 0.022)


def nightblade(k):
    """A long curved single edge: the back straight, the edge bellying out
    toward the tip; black with a pale edge from Bloodiron, runed at Gravelight."""
    s = SETS[k]
    sz = s["size"]
    haft(-0.3, 0.05, 0.034, s, k, [(-0.27, 0.28)])
    pommel(-0.32, k, s)
    guard(0.07, 0.22 + 0.03 * k, k, s)
    L = (0.95 + 0.06 * k) * sz
    n = 8
    back, edge = [], []
    for i in range(n + 1):
        t = i / n
        y = 0.09 + L * t
        bend = 0.1 * sz * t * t
        back.append((-0.03 * sz - bend, y))
        edge.append((0.075 * sz * (1 - t * t) + 0.02 - bend, y))
    pts = [back[0]] + list(edge[:-1]) + [back[-1]] + list(reversed(back[1:-1]))
    body = "black" if k >= 3 else s["metal"]
    plate(pts, 0.026, body, list(range(1, n + 1)), s["edge"] if k >= 1 else s["metal"])
    if k >= 4:
        for i in range(4):
            y = 0.25 + i * L * 0.18
            for f in (1, -1):
                gem((-0.005, y, 0.028 * f), 0.018, 0.03, 0.012, sw="white", facing=f)
    jewels((0, 0.07, 0.05), k, s, 1, 0.026)


FAMILIES = {"daggers": daggers, "chakram": chakram, "rapier": rapier, "sickles": sickles, "katars": katars, "nightblade": nightblade}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name, build in FAMILIES.items():
        if argv and name not in argv:
            continue
        for k in range(len(SETS)):
            K.reset()
            build(k)
            export("rogue_%s_%d" % (name, k), ROOT + "/assets/kaykit/weapons/rogue_%s_%d.gltf" % (name, k))
