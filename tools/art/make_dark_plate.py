"""A knight in full dark plate, as one skinned model on the hero skeleton: a
mockup of the darker, fully armoured hero look (black steel, silver edges,
a closed beaked helm, a cowl, a cape and a tabard, no skin showing).

    python3 tools/art/make_dark_plate.py   (plain Python + numpy)

Writes assets/kaykit/characters/Hero_Knight_Dark.glb on the "heroic" build
of make_hero_body.py, so the baked clips play on it unchanged. Each plate is
skinned to one bone only, so it moves rigidly like forged metal and the
plates overlap at the joints instead of stretching; cloth (cape, tabard,
cowl) is blended over the bones it hangs from, so it follows the legs.
"""
import math
import os

import numpy as np

import make_hero_body as H

H.BUILD = H.BUILDS["heroic"]
# Every face here is wound outward as it is made.
H.ORIENT_SMALL = False

PLATE, TRIM, MAIL, CLOTH, BELT, HEM = "black", "steel", "steel_dark", "cloth", "leather", "rust"
# Cloth is the black swatch's dark end, so it reads matte beside the plate.
H.SWATCH["cloth"] = H.SWATCH["black"]


class Part:
    """Verts and faces of one piece; faces are turned to face `want`, and
    shaded lit from above and the front by their own normal."""

    def __init__(self):
        self.verts, self.faces = [], []

    def v(self, p):
        self.verts.append(np.array(p, float))
        return len(self.verts) - 1

    def f(self, idx, sw, want=None, t0=0.0, t1=0.45):
        pts = [self.verts[i] for i in idx]
        nrm = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        if len(idx) == 4:
            nrm = nrm + np.cross(pts[2] - pts[0], pts[3] - pts[0])
        if want is not None and nrm @ np.array(want, float) < 0:
            idx, nrm = list(reversed(idx)), -nrm
        ln = np.linalg.norm(nrm)
        nrm = nrm / ln if ln > 0 else nrm
        lit = np.clip(0.5 + 0.5 * nrm[1] * 0.8 + 0.2 * nrm[2], 0, 1)
        t = t1 - (t1 - t0) * lit
        if sw == CLOTH:
            t = 0.5 + 0.45 * t
        self.faces.append((tuple(idx), sw, tuple([t] * len(idx))))

    def to(self, m, bones, smooth=True):
        if self.faces:
            m.add(self.verts, self.faces, None, bones, smooth)


def basis(d, fwd):
    u = np.array(d, float)
    u /= np.linalg.norm(u)
    z = np.array(fwd, float) - (np.array(fwd, float) @ u) * u
    z /= np.linalg.norm(z)
    return np.cross(u, z), u, z


def ring(c, d, fwd, rx, rz, n, a0=0.0, a1=360.0, front=1.0, point=0.0, fold=0.0, folds=7, dip=0.0, jag=None):
    """Points round c across direction d; a = 0 faces `fwd`. `front` deepens
    the front half, `point` draws it to a ridge, `fold` ripples the radius
    (cloth), `dip` drops the front along -d (a scarf hanging lower in front)."""
    x, u, z = basis(d, fwd)
    closed = (a1 - a0) >= 359.9
    out = []
    for i in range(n if closed else n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        ca, sa = math.cos(a), math.sin(a)
        f = 1.0 + fold * math.sin(folds * a + 0.7)
        lz = ca * rz * (front if ca > 0 else 1.0) + point * max(ca, 0.0) ** 8
        p = np.array(c, float) + x * (rx * sa * f) + z * (lz * f)
        p = p - u * (dip * max(ca, 0.0) ** 2 + (jag[i] if jag is not None else 0.0))
        out.append(p)
    return out, closed


def _rings(pts, radii, fwd, n, **kw):
    """Rings along a polyline; per-ring keyword lists (front, point...) allowed."""
    out = []
    for k, p in enumerate(pts):
        d = np.array(pts[min(k + 1, len(pts) - 1)], float) - np.array(pts[max(k - 1, 0)], float)
        r = radii[k]
        rx, rz = (r, r) if not isinstance(r, tuple) else r
        kk = {key: (val[k] if isinstance(val, list) else val) for key, val in kw.items()}
        out.append((ring(p, d, fwd, rx, rz, n, **kk)[0], np.array(p, float), d))
    return out


def tube(m, pts, radii, sw, bones, fwd=(0, 0, 1), n=12, smooth=True, caps=(True, True), **kw):
    """A closed tube through pts; its faces look away from the axis."""
    P = Part()
    rs = _rings(pts, radii, fwd, n, **kw)
    ids = [[P.v(p) for p in r] for r, _, _ in rs]
    sws = sw if isinstance(sw, list) else [sw] * len(rs)
    for k in range(len(rs) - 1):
        c = (rs[k][1] + rs[k + 1][1]) / 2
        for i in range(n):
            j = (i + 1) % n
            q = [ids[k][i], ids[k][j], ids[k + 1][j], ids[k + 1][i]]
            mid = np.mean([P.verts[t] for t in q], axis=0)
            P.f(q, sws[min(k, len(sws) - 1)], want=mid - c)
    for k, sgn in ((0, -1), (len(rs) - 1, 1)):
        if not caps[0 if k == 0 else 1]:
            continue
        ci = P.v(np.mean([P.verts[t] for t in ids[k]], axis=0))
        for i in range(n):
            P.f([ids[k][i], ids[k][(i + 1) % n], ci], sws[0 if k == 0 else -1], want=rs[k][2] * sgn)
    P.to(m, bones, smooth)


def shell(m, pts, radii, a0, a1, sw, bones, fwd=(0, 0, 1), n=10, th=0.018, edge=None, smooth=True, inner=CLOTH, **kw):
    """Part of a tube, from angle a0 to a1, `th` thick: a plate (or a cape).
    The outside is smooth; the inside and the cut edges are flat."""
    edge = edge or sw
    O, I = Part(), Part()
    rs = _rings(pts, radii, fwd, n, a0=a0, a1=a1, **kw)
    cols = n + 1
    out_ids = [[O.v(p) for p in r] for r, _, _ in rs]
    ov = [[I.v(p) for p in r] for r, _, _ in rs]
    iv = []
    for r, c, d in rs:
        row = []
        for p in r:
            dv = p - c
            dv = dv - (dv @ (d / np.linalg.norm(d))) * (d / np.linalg.norm(d))
            row.append(I.v(p - dv / max(np.linalg.norm(dv), 1e-6) * th))
        iv.append(row)
    for k in range(len(rs) - 1):
        c = (rs[k][1] + rs[k + 1][1]) / 2
        for i in range(cols - 1):
            q = [out_ids[k][i], out_ids[k][i + 1], out_ids[k + 1][i + 1], out_ids[k + 1][i]]
            mid = np.mean([O.verts[t] for t in q], axis=0)
            O.f(q, sw, want=mid - c)
            q = [iv[k][i], iv[k][i + 1], iv[k + 1][i + 1], iv[k + 1][i]]
            mid = np.mean([I.verts[t] for t in q], axis=0)
            I.f(q, inner, want=c - mid, t0=0.5, t1=0.8)
    for k, sgn in ((0, -1), (len(rs) - 1, 1)):
        d = rs[k][2] / np.linalg.norm(rs[k][2])
        for i in range(cols - 1):
            I.f([ov[k][i], ov[k][i + 1], iv[k][i + 1], iv[k][i]], edge, want=d * sgn, t0=0.0, t1=0.2)
    for k in range(len(rs) - 1):
        for i, j in ((0, 1), (cols - 1, cols - 2)):
            want = I.verts[ov[k][i]] - I.verts[ov[k][j]]
            I.f([ov[k][i], ov[k + 1][i], iv[k + 1][i], iv[k][i]], edge, want=want, t0=0.0, t1=0.2)
    O.to(m, bones, smooth)
    I.to(m, bones, False)


def band(m, c, d, fwd, rx, rz, h, sw, bones, n=12, a0=0.0, a1=360.0, **kw):
    """A raised trim: a short ring standing proud of a plate."""
    d = np.array(d, float) / np.linalg.norm(d)
    pts = [np.array(c) - d * h / 2, np.array(c) + d * h / 2]
    if a1 - a0 >= 359.9:
        tube(m, pts, [(rx, rz)] * 2, sw, bones, fwd=fwd, n=n, smooth=False, caps=(False, False), **kw)
    else:
        shell(m, pts, [(rx, rz)] * 2, a0, a1, sw, bones, fwd=fwd, n=n, th=0.012, smooth=False, inner=sw, **kw)


def stud(m, c, nrm, r, h, sw, bones, sides=5):
    """A rivet or spike from c along nrm."""
    P = Part()
    x, u, z = basis(nrm, (0.3, 0.9, 0.2) if abs(nrm[1]) < 0.9 else (0, 0, 1))
    ring_ = [P.v(np.array(c) + (x * math.cos(2 * math.pi * k / sides) + z * math.sin(2 * math.pi * k / sides)) * r) for k in range(sides)]
    tip = P.v(np.array(c) + u * h)
    for k in range(sides):
        P.f([ring_[k], ring_[(k + 1) % sides], tip], sw, want=np.mean([P.verts[ring_[k]], P.verts[ring_[(k + 1) % sides]]], axis=0) - np.array(c) + u * 0.3 * r)
    P.to(m, bones, False)


def star(m, c, nrm, up, r, sw, bones, pts=8, th=0.012):
    """A flat many-pointed star laid on a plate, facing nrm."""
    P = Part()
    nrm = np.array(nrm, float) / np.linalg.norm(nrm)
    x, u, z = basis(up, nrm)  # u up the plate, z out of it
    rim = []
    for k in range(pts * 2):
        a = math.pi * k / pts
        rr = r if k % 2 == 0 else r * (0.32 if pts > 4 else 0.38)
        rim.append(np.array(c) + x * math.sin(a) * rr + u * math.cos(a) * rr)
    front = [P.v(p + z * th) for p in rim]
    back = [P.v(p - z * th * 0.2) for p in rim]
    top = P.v(np.array(c) + z * th * 2.5)
    nn = len(rim)
    for k in range(nn):
        j = (k + 1) % nn
        P.f([front[k], front[j], top], sw, want=z, t0=0.0, t1=0.25)
        P.f([front[k], back[k], back[j], front[j]], sw, want=(rim[k] + rim[j]) / 2 - np.array(c), t0=0.0, t1=0.3)
    P.to(m, bones, False)


def sheet(m, rows, sw, bones, th=0.014, smooth=True, edge=None, back_sw=None):
    """A cloth panel from a grid of points (rows top to bottom, each left to
    right as seen from the front, +z of the panel's own facing)."""
    edge = edge or sw
    back_sw = back_sw or sw
    O, I = Part(), Part()
    R, C = len(rows), len(rows[0])
    g = np.array(rows, float)
    # Facing per point: across the row x down the column.
    nrm = np.zeros_like(g)
    for r in range(R):
        for c in range(C):
            tx = g[r, min(c + 1, C - 1)] - g[r, max(c - 1, 0)]
            ty = g[max(r - 1, 0), c] - g[min(r + 1, R - 1), c]
            nv = np.cross(tx, ty)
            nrm[r, c] = nv / max(np.linalg.norm(nv), 1e-9)
    fo = [[O.v(g[r, c] + nrm[r, c] * th / 2) for c in range(C)] for r in range(R)]
    fe = [[I.v(g[r, c] + nrm[r, c] * th / 2) for c in range(C)] for r in range(R)]
    bk = [[I.v(g[r, c] - nrm[r, c] * th / 2) for c in range(C)] for r in range(R)]
    for r in range(R - 1):
        for c in range(C - 1):
            nm = (nrm[r, c] + nrm[r + 1, c + 1])
            O.f([fo[r][c], fo[r][c + 1], fo[r + 1][c + 1], fo[r + 1][c]], sw, want=nm)
            I.f([bk[r][c], bk[r][c + 1], bk[r + 1][c + 1], bk[r + 1][c]], back_sw, want=-nm, t0=0.4, t1=0.75)
    ring_ = [(0, c) for c in range(C)] + [(r, C - 1) for r in range(1, R)] + [(R - 1, c) for c in range(C - 2, -1, -1)] + [(r, 0) for r in range(R - 2, 0, -1)]
    mid = g.mean(axis=(0, 1))
    for k in range(len(ring_)):
        (r0, c0), (r1, c1) = ring_[k], ring_[(k + 1) % len(ring_)]
        out = (g[r0, c0] + g[r1, c1]) / 2 - mid
        out = out - (out @ nrm[r0, c0]) * nrm[r0, c0]
        I.f([fe[r0][c0], fe[r1][c1], bk[r1][c1], bk[r0][c0]], edge, want=out, t0=0.2, t1=0.5)
    O.to(m, bones, smooth)
    I.to(m, bones, False)


def jagged(n, amp, seed):
    rnd = np.random.default_rng(seed)
    return [float(amp * (0.3 + 0.7 * rnd.random()) * (1 if k % 2 else 0.35)) for k in range(n)]


# --- The knight ---------------------------------------------------------------------

def build():
    _, _, _, sk = H.skeleton()
    J = lambda nm: H.J(sk, nm)  # noqa: E731
    m = H.Mesh()
    hips, spine, chest, head = J("hips"), J("spine"), J("chest"), J("head")
    UP = (0, 1, 0)

    # Breastplate (chest) with a keel down the middle, and a back plate.
    prof = [(1.37, 0.245, 0.165, 1.05, 0.015), (1.47, 0.27, 0.178, 1.12, 0.035), (1.57, 0.29, 0.185, 1.16, 0.045),
            (1.67, 0.29, 0.18, 1.1, 0.035), (1.74, 0.245, 0.155, 1.0, 0.015), (1.79, 0.15, 0.115, 1.0, 0.0)]
    tube(m, [(0, y, 0) for y, *_ in prof], [(rx, rz) for _, rx, rz, _, _ in prof], PLATE, ["chest"], n=18,
         front=[p[3] for p in prof], point=[p[4] for p in prof])
    # Silver edges: the neck line and the bottom of the breastplate.
    band(m, (0, 1.745, 0), UP, (0, 0, 1), 0.25, 0.16, 0.025, TRIM, ["chest"], n=18, a0=-80, a1=80, front=1.0, point=0.015)
    band(m, (0, 1.385, 0), UP, (0, 0, 1), 0.25, 0.168, 0.022, TRIM, ["chest"], n=18, front=1.06, point=0.017)
    # The star on the breast, and rivets.
    star(m, (0, 1.6, 0.255), (0, 0.15, 1), UP, 0.1, TRIM, ["chest"], pts=4, th=0.018)
    star(m, (0, 1.6, 0.262), (0, 0.15, 1), UP, 0.05, "white", ["chest"], pts=4, th=0.02)
    for s in (1, -1):
        for y in (1.47, 1.56, 1.65):
            a = math.radians(62)
            stud(m, (s * 0.27 * math.sin(a) * 1.0, y, 0.185 * 1.12 * math.cos(a)), (s * 0.8, 0, 0.6), 0.012, 0.012, TRIM, ["chest"])

    # Abdomen lames (spine), each overlapping the one below, edged in silver.
    for i in range(3):
        top = 1.40 - i * 0.085
        bot = top - 0.1
        r0 = 0.24 - 0.004 * i
        tube(m, [(0, bot, 0), (0, top, 0)], [(r0 + 0.012, 0.168), (r0, 0.16)], PLATE, ["spine"], n=18, front=1.05, point=0.012, caps=(False, False))
        band(m, (0, bot + 0.008, 0), UP, (0, 0, 1), r0 + 0.015, 0.171, 0.014, TRIM, ["spine"], n=18, front=1.05, point=0.012)

    # Belt with a star buckle (hips).
    tube(m, [(0, 1.05, 0), (0, 1.115, 0)], [(0.255, 0.175)] * 2, BELT, ["hips"], n=18, front=1.04, caps=(False, False), smooth=False)
    star(m, (0, 1.083, 0.186), (0, 0, 1), UP, 0.055, "gold", ["hips"], pts=4, th=0.014)
    # A mail skirt over the pelvis, and plate faulds front and back.
    tube(m, [(0, 0.86, 0), (0, 1.06, 0)], [(0.25, 0.17), (0.245, 0.165)], MAIL, ["hips"], n=16, smooth=False, caps=(True, False))
    for a0, a1 in ((-62, 62), (118, 242)):
        shell(m, [(0, 0.95, 0), (0, 1.05, 0)], [(0.275, 0.19), (0.262, 0.18)], a0, a1, PLATE, ["hips"], n=10, edge=TRIM)

    # Tabard front and back: dark cloth to below the knee, studded, torn hem.
    for zs in (1, -1):
        rows = []
        R, C = 7, 6
        jag = jagged(C, 0.07, 3 if zs > 0 else 5)
        for r in range(R):
            y = 1.04 - r * (1.04 - 0.42) / (R - 1)
            w = 0.12 + 0.02 * r / (R - 1)
            z = zs * (0.2 + 0.02 * r / (R - 1))
            row = []
            for c in range(C):
                x = -w + 2 * w * c / (C - 1)
                yy = y - (jag[c] if r == R - 1 else 0.0)
                row.append((x * zs, yy, z + zs * 0.012 * math.sin(c * 1.7 + r)))
            rows.append(row)
        sheet(m, rows, CLOTH, ["hips", "upperleg.l", "upperleg.r"], edge=HEM)
        for r in range(1, 5):
            for x in (-0.07, 0.07):
                y = 1.0 - r * 0.1
                stud(m, (x, y, zs * (0.215 + 0.02 * (1.04 - y) / 0.62)), (0, 0, zs), 0.01, 0.01, TRIM, ["hips", "upperleg.l", "upperleg.r"])

    # Cowl: a heavy scarf bunched round the neck, hanging lower in front.
    cy = [(1.64, 0.32, 0.235, 0.07, 0.16), (1.72, 0.29, 0.215, 0.07, 0.1), (1.79, 0.21, 0.17, 0.06, 0.05), (1.845, 0.14, 0.135, 0.04, 0.0)]
    tube(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz, _, _ in cy], CLOTH, ["chest"], n=20,
         fold=[c[3] for c in cy], dip=[c[4] for c in cy], caps=(False, True))

    # Cape: from the shoulders behind, flaring out, rippled, torn at the hem.
    R, C = 10, 15
    jag = jagged(C, 0.13, 11)
    rows = []
    for r in range(R):
        t = r / (R - 1)
        y = 1.74 - t * (1.74 - 0.32)
        w = 0.27 + 0.16 * t
        zc = -0.17 - 0.16 * t
        row = []
        for c in range(C):
            u = -1 + 2 * c / (C - 1)
            a = u * math.radians(70)
            x = -w * math.sin(a)
            z = zc - 0.08 * math.cos(a) * (1 - 0.3 * t) + (0.012 + 0.045 * t) * math.sin(c * math.pi * 0.5)
            row.append((x, y - (jag[c] if r == R - 1 else 0.0), z))
        rows.append(row)
    sheet(m, rows, CLOTH, ["chest", "spine", "hips"], th=0.016)

    # Helm: a closed, beaked great helm with an eye slit and a silver crest.
    hp = [(0.0, 0.098, 0.11, 1.0, 0.0), (0.05, 0.118, 0.13, 1.05, 0.04), (0.11, 0.13, 0.145, 1.1, 0.11),
          (0.17, 0.135, 0.15, 1.12, 0.13), (0.235, 0.137, 0.152, 1.06, 0.075), (0.29, 0.134, 0.15, 1.02, 0.03),
          (0.345, 0.118, 0.134, 1.0, 0.012), (0.395, 0.085, 0.1, 1.0, 0.0), (0.44, 0.03, 0.04, 1.0, 0.0)]
    hc = head + np.array([0, -0.04, 0.0])
    tube(m, [hc + [0, y, 0] for y, *_ in hp], [(rx, rz) for _, rx, rz, _, _ in hp], PLATE, ["head"], n=18,
         front=[p[3] for p in hp], point=[p[4] for p in hp], caps=(True, True))
    # The slit: a dark band across the face under the brow.
    band(m, hc + [0, 0.215, 0], UP, (0, 0, 1), 0.14, 0.156, 0.024, "black", ["head"], n=18, a0=-78, a1=78, front=1.08, point=0.09)
    band(m, hc + [0, 0.24, 0], UP, (0, 0, 1), 0.142, 0.158, 0.014, TRIM, ["head"], n=18, a0=-80, a1=80, front=1.06, point=0.075)
    band(m, hc + [0, 0.012, 0], UP, (0, 0, 1), 0.108, 0.118, 0.022, TRIM, ["head"], n=18, front=1.02, point=0.008)
    # Crest: a silver ridge from the brow over the crown.
    crest = [hc + [0, 0.245, 0.215]] + [hc + [0, 0.2 + 0.212 * math.cos(math.radians(-80 + 170 * i / 8)), 0.155 * math.sin(-math.radians(-80 + 170 * i / 8))] for i in range(1, 9)]
    tube(m, crest, [(0.012, 0.028)] * len(crest), TRIM, ["head"], fwd=(1, 0, 0), n=4, smooth=False)
    # The beak's ridge and breaths.
    tube(m, [hc + [0, 0.04, 0.17], hc + [0, 0.13, 0.295], hc + [0, 0.2, 0.27]], [0.012, 0.014, 0.012], TRIM, ["head"], fwd=(0, 0, 1), n=4, smooth=False)
    for s in (1, -1):
        for k in range(3):
            y = 0.08 + k * 0.035
            a = math.radians(32 * s)
            p = hc + [0.138 * math.sin(a) * 1.0, y, 0.15 * 1.13 * math.cos(a)]
            tube(m, [p - [0.0, 0.0, 0.004], p + [0, 0, 0.006]], [(0.022, 0.006)] * 2, "black", ["head"], fwd=(0, 1, 0), n=4, smooth=False)

    # Arms.
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr, ha = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side), J("hand." + side)
        ax = np.array([s, 0, 0.0])
        ub, lb, wb, hb = ["upperarm." + side], ["lowerarm." + side], ["wrist." + side], ["hand." + side]
        # Pauldron: a big dome over the shoulder and three lames down the arm.
        dome = [(-0.1, 0.07), (-0.06, 0.15), (0.0, 0.19), (0.07, 0.205), (0.13, 0.2)]
        shell(m, [ua + ax * t for t, _ in dome], [(r, r * 0.95) for _, r in dome], -112, 112, PLATE, ub, fwd=UP, n=14, edge=TRIM, th=0.02)
        band(m, ua + ax * 0.125, ax, UP, 0.205, 0.195, 0.022, TRIM, ub, n=14, a0=-112, a1=112)
        for i in range(3):
            t0 = 0.12 + i * 0.055
            r0 = 0.195 - i * 0.014
            shell(m, [ua + ax * t0, ua + ax * (t0 + 0.075)], [(r0, r0 * 0.95), (r0 - 0.004, r0 * 0.95 - 0.004)], -100, 100, PLATE, ub, fwd=UP, n=12, edge=TRIM, th=0.016)
        stud(m, ua + ax * 0.04 + [0, 0.205, 0], (s * 0.2, 1, 0), 0.016, 0.02, TRIM, ub)
        # A silver flange curling up off the inner edge, to guard the neck.
        rows = []
        for hgt in (0.085, 0.0):
            row = []
            for c in range(7):
                zz = -0.15 + 0.3 * c / 6
                ys = math.sqrt(max(0.175 ** 2 - zz ** 2, 0.0))
                row.append(ua + ax * (-0.035 - hgt * 0.35) + [0, ys + hgt * (1 - (zz / 0.17) ** 2 * 0.5), zz])
            rows.append(row)
        sheet(m, rows, TRIM, ub, th=0.014, smooth=False)
        # Mail on the upper arm, and the plate down to the elbow.
        tube(m, [ua + ax * 0.05, la - ax * 0.04], [(0.085, 0.08), (0.075, 0.072)], MAIL, ub, fwd=UP, n=10, smooth=False)
        tube(m, [la - ax * 0.17, la - ax * 0.03], [(0.088, 0.083), (0.08, 0.077)], PLATE, ub, fwd=UP, n=12, caps=(False, False))
        # Couter: a cup over the point of the elbow with a fan.
        tube(m, [la + [0, 0, -0.03], la + [0, 0, -0.1], la + [0, 0, -0.125]], [0.07, 0.05, 0.0], PLATE, lb, fwd=UP, n=10, caps=(False, False))
        band(m, la + [0, 0, -0.035], (0, 0, -1), UP, 0.072, 0.072, 0.014, TRIM, lb, n=10)
        # Vambrace and gauntlet cuff, flared toward the elbow.
        tube(m, [la + ax * 0.03, wr - ax * 0.03], [(0.077, 0.075), (0.062, 0.06)], PLATE, lb, fwd=UP, n=12, front=1.05, point=0.01)
        band(m, la + ax * 0.04, ax, UP, 0.079, 0.077, 0.016, TRIM, lb, n=12)
        tube(m, [wr - ax * 0.08, wr + ax * 0.03], [(0.088, 0.085), (0.062, 0.06)], PLATE, wb, fwd=UP, n=12, caps=(False, False))
        band(m, wr - ax * 0.078, ax, UP, 0.09, 0.087, 0.014, TRIM, wb, n=12)
        # A plated fist: the back of the hand, knuckles, curled fingers, thumb.
        hh = H.BUILD["hand"] * 0.85
        tube(m, [wr + ax * 0.02, wr + ax * 0.08 * hh, wr + ax * 0.13 * hh], [(0.045 * hh, 0.055 * hh), (0.052 * hh, 0.062 * hh), (0.046 * hh, 0.056 * hh)], PLATE, hb, fwd=(0, 0, 1), n=8)
        tube(m, [wr + ax * 0.12 * hh + [0, -0.008, 0], wr + ax * 0.18 * hh + [0, -0.028, 0]], [(0.042 * hh, 0.05 * hh), (0.032 * hh, 0.044 * hh)], MAIL, hb, fwd=(0, 0, 1), n=8, smooth=False)
        band(m, wr + ax * 0.115 * hh, ax, (0, 0, 1), 0.05 * hh, 0.06 * hh, 0.016, TRIM, hb, n=8)
        tube(m, [wr + ax * 0.04 * hh + [0, -0.01, 0.045 * hh], wr + ax * 0.11 * hh + [0, -0.02, 0.07 * hh]], [0.022 * hh, 0.017 * hh], PLATE, hb, fwd=UP, n=6)

    # Legs.
    for s, side in ((1, "l"), (-1, "r")):
        ul, ll, ft, to = J("upperleg." + side), J("lowerleg." + side), J("foot." + side), J("toes." + side)
        top = ul + [-0.03 * s, -0.04, 0]
        ulb, llb, fb, tb = ["upperleg." + side], ["lowerleg." + side], ["foot." + side], ["toes." + side]
        # Cuisse: plate over the thigh, mail behind it.
        tube(m, [top, top + (ll - top) * 0.5, ll + [0, 0.05, 0]], [(0.118, 0.122), (0.105, 0.11), (0.088, 0.092)], MAIL, ulb, fwd=(0, 0, 1), n=10, smooth=False)
        shell(m, [top + [0, -0.02, 0], top + (ll - top) * 0.5, ll + [0, 0.07, 0]], [(0.128, 0.132), (0.116, 0.12), (0.098, 0.102)], -105, 105, PLATE, ulb, fwd=(0, 0, 1), n=12, edge=TRIM, front=1.05, point=0.01)
        # Tassets: three lames hung from the belt over the front of the thigh.
        for i in range(3):
            y0 = 1.03 - i * 0.075
            r0 = 0.15 - i * 0.006
            shell(m, [ul + [0, y0 - ul[1] - 0.09, 0], ul + [0, y0 - ul[1], 0]], [(r0 + 0.01, r0 + 0.014), (r0, r0 + 0.004)], -115 * s if s < 0 else -30, 30 if s < 0 else 115,
                  PLATE, ulb, fwd=(0, 0, 1), n=9, edge=TRIM, th=0.016)
        # Poleyn: a cup over the knee, with side wings.
        kn = ll + [0, 0.0, 0.0]
        tube(m, [kn + [0, 0, 0.04], kn + [0, 0, 0.1], kn + [0, 0, 0.125]], [(0.085, 0.075), (0.07, 0.06), (0.0, 0.0)], PLATE, llb, fwd=UP, n=10, caps=(False, False))
        band(m, kn + [0, 0, 0.045], (0, 0, 1), UP, 0.088, 0.078, 0.016, TRIM, llb, n=10)
        stud(m, kn + [0, 0, 0.122], (0, 0, 1), 0.016, 0.03, TRIM, llb)
        # Greave down the shin, ridged in front, flaring over the foot.
        g0, g1 = ll + (ft - ll) * 0.08, ft + (ll - ft) * 0.08
        tube(m, [g0, g0 + (g1 - g0) * 0.35, g1], [(0.088, 0.09), (0.09, 0.094), (0.072, 0.075)], PLATE, llb, fwd=(0, 0, 1), n=12,
             front=1.08, point=0.02, caps=(False, False))
        band(m, g1 + (g0 - g1) * 0.02, g1 - g0, (0, 0, 1), 0.076, 0.079, 0.016, TRIM, llb, n=12, front=1.08, point=0.018)
        # Sabaton: a plated shoe of overlapping lames.
        g = 0.0
        heel = [(-0.11, 0.06, 0.12), (-0.04, 0.072, 0.15), (0.03, 0.075, 0.12)]
        toes_ = [(0.03, 0.073, 0.11), (0.1, 0.07, 0.085), (0.16, 0.062, 0.06), (0.21, 0.045, 0.04), (0.235, 0.02, 0.02)]
        for part, bones in ((heel, fb), (toes_, tb)):
            P = Part()
            rr = []
            for z, hw, h in part:
                cz = ft[2] + z
                rr.append([P.v((ft[0] + x, g + y, cz)) for x, y in ((-hw, 0.0), (hw, 0.0), (hw * 1.0, h * 0.75), (hw * 0.6, h), (-hw * 0.6, h), (-hw, h * 0.75))])
            nn = 6
            for k in range(len(rr) - 1):
                cc = np.mean([P.verts[i] for i in rr[k] + rr[k + 1]], axis=0)
                for i in range(nn):
                    q = [rr[k][i], rr[k][(i + 1) % nn], rr[k + 1][(i + 1) % nn], rr[k + 1][i]]
                    mid = np.mean([P.verts[t] for t in q], axis=0)
                    P.f(q, PLATE if i != 0 else "black", want=mid - cc)
            for k, sg in ((0, -1), (len(rr) - 1, 1)):
                P.f(rr[k], PLATE, want=(0, 0, sg))
            P.to(m, bones, False)
        for z in (0.03, 0.1, 0.16):
            band(m, (ft[0], 0.045, ft[2] + z), (0, 0.4, 1), UP, 0.074 - z * 0.06, 0.03, 0.012, TRIM, tb if z > 0.05 else fb, n=8, a0=-90, a1=90)
    return m, sk


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    m, sk = build()
    name = "Hero_Knight_Dark"
    H.write(m, sk, g, nodes, joints, name, os.path.join(H.ROOT, "assets", "kaykit", "characters", name + ".glb"))
    print("LIFT", round(H.body_lift(), 4))
