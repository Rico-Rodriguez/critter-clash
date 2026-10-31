"""Shapes for our dark-fantasy hero kits (make_dark_<hero>.py), built as
skinned meshes on the hero skeleton (make_hero_body.py's "heroic" build), so
the baked clips play on them unchanged. Plates are skinned to one bone each,
so they move rigidly like forged metal and overlap at the joints; cloth is
blended over the bones it hangs from, so a tabard follows the legs.

Everything is in glTF space (+y up, +z the front, the hero in the rest
T-pose), colored by swatches of weapons/dark_texture.png, whose mask gives
the metal its shine (char.gdshader's mask_tex).
"""
import math
import os

import numpy as np

import make_hero_body as H

H.BUILD = H.BUILDS["heroic"]
# Every face here is wound outward as it is made.
H.ORIENT_SMALL = False

IMAGE = "../weapons/dark_texture.png"
UP = (0, 1, 0)
# Hard-surface look: rings get about half the sides and every face is flat
# shaded, so plates read as cut and hammered facets, not rounded shells.
FACET = True
SEG = 0.5


def _n(n):
    """Sides for a ring of n (even, so ridges land on the front and back)."""
    if not FACET:
        return n
    return max(6, int(round(n * SEG / 2)) * 2)


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
    n, smooth = _n(n), smooth and not FACET
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


def shell(m, pts, radii, a0, a1, sw, bones, fwd=(0, 0, 1), n=10, th=0.018, edge=None, smooth=True, inner="cloth", **kw):
    """Part of a tube, from angle a0 to a1, `th` thick: a plate (or a cape).
    The outside is smooth; the inside and the cut edges are flat."""
    n, smooth = _n(n), smooth and not FACET
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
    smooth = smooth and not FACET
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
