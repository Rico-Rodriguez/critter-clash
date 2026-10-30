"""A grown-up hero body on KayKit's Rig_Medium skeleton, so every baked clip
and every bone-pinned prop keeps working.

    python3 tools/art/make_hero_body.py [hero ...]   (plain Python + numpy)

Writes assets/kaykit/characters/Hero_<name>.glb. The skeleton is Knight.glb's,
node for node, with longer bones where the clips only rotate them (upper and
lower arm and leg, spine, chest, neck); the clips also set the shoulder, hip
and leg-root positions, so those stay KayKit's. The legs come out about 0.69
longer than KayKit's, so the hips must be lifted by that much in play
(BoneScaler.lift, BODY_LIFT below).

The mesh is lofted from rings (an ellipse per ring, `loft`), in glTF space:
+y up, +z the front, the hero standing in the rest T-pose. Colors come from
the shared KayKit swatch texture (weapons/knight_texture.png), as our props'
do, so the character shader grades it like any KayKit character. Each vertex
is skinned to the two or three nearest bones of the part it belongs to.
"""
import json
import math
import os
import struct
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "kaykit", "characters", "Knight.glb")

# New lengths (the child's translation along its parent bone).
LENGTHS = {"spine": 0.2, "chest": 0.4, "head": 0.215, "lowerarm.l": 0.4, "lowerarm.r": 0.4,
           "wrist.l": 0.35, "wrist.r": 0.35, "lowerleg.l": 0.55, "lowerleg.r": 0.55,
           "foot.l": 0.5, "foot.r": 0.5}
KK_LEG = 0.22707749903202057 + 0.14943702518939972
HEAD_SCALE = 1.12
BODY_LIFT = LENGTHS["lowerleg.l"] + LENGTHS["foot.l"] - KK_LEG

SWATCH = {
    "steel": (3, 0), "steel_dark": (4, 0), "black": (2, 0), "gold": (4, 1),
    "red": (0, 1), "wood": (6, 1), "leather": (6, 0), "bone": (1, 1),
    "copper": (5, 1), "skin": (0, 0), "rust": (5, 0), "tan": (1, 0),
    "slate": (7, 1), "stone": (1, 2), "white": (0, 2),
}


def uv(sw, t):
    c, r = SWATCH[sw]
    t = min(max(t, 0.0), 1.0)
    # glTF's v runs down.
    return ((c + 0.5) / 8.0, (r + 0.06 + t * 0.88) / 4.0)


# --- Skeleton ------------------------------------------------------------------

def load_src():
    f = open(SRC, "rb").read()
    ln = struct.unpack("<I", f[12:16])[0]
    return json.loads(f[20:20 + ln])


def qmat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def trs(n):
    m = np.eye(4)
    s = np.array(n.get("scale", [1, 1, 1]))
    m[:3, :3] = qmat(n.get("rotation", [0, 0, 0, 1])) @ np.diag(s)
    m[:3, 3] = n.get("translation", [0, 0, 0])
    return m


def skeleton():
    """The joint nodes with the new lengths, and each joint's rest matrix."""
    g = load_src()
    nodes = g["nodes"]
    joints = g["skins"][0]["joints"]
    for i in joints:
        n = nodes[i]
        if n["name"] in LENGTHS:
            t = n.get("translation", [0, 0, 0])
            n["translation"] = [t[0], LENGTHS[n["name"]], t[2]]
        if n["name"] == "hips":
            n["translation"] = [0, n["translation"][1] + BODY_LIFT, 0]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    world = {}

    def w(i):
        if i not in world:
            world[i] = (w(parent[i]) if i in parent and parent[i] in joints else np.eye(4)) @ trs(nodes[i])
        return world[i]

    by_name = {}
    for i in joints:
        by_name[nodes[i]["name"]] = (i, w(i))
    return g, nodes, joints, by_name


# --- Mesh building -----------------------------------------------------------------

class Mesh:
    def __init__(self):
        self.parts = []  # (verts, faces, uvs, smooth, bones)

    def add(self, verts, quads, uvs, bones, smooth=True):
        self.parts.append((np.array(verts, float), quads, uvs, smooth, bones))


def ring(c, rx, rz, n, rot=None, front=0.0):
    """An ellipse of n points around c in the plane across `rot`'s y axis;
    `front` pushes the +z half forward (a chest, a calf)."""
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, z = rx * math.sin(a), rz * math.cos(a)
        if z > 0:
            z *= 1 + front
        p = np.array([x, 0.0, z])
        out.append(np.array(c) + (rot @ p if rot is not None else p))
    return out


def frame(d):
    """A rotation taking +y to direction d."""
    d = np.array(d, float) / np.linalg.norm(d)
    up = np.array([0, 1.0, 0])
    if abs(d @ up) > 0.999:
        return np.eye(3) if d[1] > 0 else np.diag([1, -1, -1.0])
    ax = np.cross(up, d)
    s = np.linalg.norm(ax)
    ax /= s
    ang = math.atan2(s, up @ d)
    K = np.array([[0, -ax[2], ax[1]], [ax[2], 0, -ax[0]], [-ax[1], ax[0], 0]])
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * K @ K


def loft(mesh, rings, sws, bones, smooth=True, cap0=True, cap1=True, ts=None):
    """Joins rings (each a list of n points) into a tube; sws[k] colors the
    band from ring k to k+1. Ends are capped with a fan."""
    n = len(rings[0])
    verts, quads, uvs = [], [], []
    for k, r in enumerate(rings):
        verts.extend(r)
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            a, b, c, d = k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i
            # Light from above and the front: higher rings and +z faces sit higher in the swatch.
            side = 0.5 - 0.35 * math.cos(2 * math.pi * (i + 0.5) / n)
            t0 = side if ts is None else ts[k]
            t1 = side if ts is None else ts[k + 1]
            quads.append(((a, b, c, d), sws[min(k, len(sws) - 1)], (t0, t0, t1, t1)))
    for k, flip in ((0, True), (len(rings) - 1, False)):
        if (k == 0 and not cap0) or (k > 0 and not cap1):
            continue
        cidx = len(verts)
        verts.append(np.mean(rings[k], axis=0))
        sw = sws[0] if k == 0 else sws[-1]
        for i in range(n):
            j = (i + 1) % n
            tri = (k * n + i, k * n + j, cidx)
            quads.append((tri[::-1] if flip else tri, sw, (0.3, 0.3, 0.2)))
    mesh.add(verts, quads, None, bones, smooth)


def limb(mesh, pts, radii, sws, bones, n=10, smooth=True, front=None):
    """A tube through points with a radius at each (rx, rz) or r."""
    rings = []
    for k, p in enumerate(pts):
        d = np.array(pts[min(k + 1, len(pts) - 1)]) - np.array(pts[max(k - 1, 0)])
        r = radii[k]
        rx, rz = (r, r) if not isinstance(r, tuple) else r
        rings.append(ring(p, rx, rz, n, frame(d), front[k] if front else 0.0))
    loft(mesh, rings, sws, bones, smooth)


def blob(mesh, c, r, sw, bones, n=10, m=6, squash=(1, 1, 1), smooth=True):
    """An ellipsoid (a deltoid, a knuckle, a nose)."""
    rings = []
    for k in range(1, m):
        a = math.pi * k / m
        y = -math.cos(a)
        rr = math.sin(a)
        rings.append(ring((c[0], c[1] + y * r * squash[1], c[2]), rr * r * squash[0], rr * r * squash[2], n))
    loft(mesh, rings, [sw], bones, smooth)


def boxy(mesh, c, size, sw, bones, rot=None, smooth=False, taper=1.0):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    rings = []
    for sy, tp in ((-1, 1.0), (1, taper)):
        pts = [np.array([sx * hx * tp, sy * hy, sz * hz * tp]) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        rings.append([np.array(c) + (rot @ p if rot is not None else p) for p in pts])
    loft(mesh, rings, [sw], bones, smooth)


# --- The body -------------------------------------------------------------------------

def J(sk, name):
    return sk[name][1][:3, 3].copy()


def build(look):
    _, _, _, sk = skeleton()
    m = Mesh()
    hips, spine, chest, head = J(sk, "hips"), J(sk, "spine"), J(sk, "chest"), J(sk, "head")
    shirt, pants, boots, skin = look["shirt"], look["pants"], look["boots"], "skin"
    T = ["hips", "spine", "chest"]

    # Torso: pelvis to collar, a V from broad shoulders to the waist, the
    # pelvis wide enough to take the tops of the thighs.
    y0 = hips[1] - 0.06
    prof = [(y0, 0.2, 0.13, 0.0), (hips[1] + 0.1, 0.26, 0.15, 0.0), (spine[1] + 0.08, 0.215, 0.14, 0.05),
            (spine[1] + 0.25, 0.23, 0.15, 0.15), (chest[1] - 0.04, 0.26, 0.16, 0.2), (chest[1] + 0.07, 0.275, 0.155, 0.15),
            (chest[1] + 0.14, 0.24, 0.125, 0.05), (chest[1] + 0.19, 0.09, 0.075, 0.0)]
    rings = [ring((0, y, 0), rx, rz, 16, front=f) for y, rx, rz, f in prof]
    belt = look.get("belt", "leather")
    loft(m, rings, [pants, belt, shirt, shirt, shirt, shirt, shirt], T + ["head"], ts=None)
    # Neck.
    limb(m, [(0, chest[1] + 0.12, 0.0), (0, head[1] + 0.06, 0.01)], [0.07, 0.065], [skin], ["chest", "head"], n=10)
    # Head, a little larger than life so the face reads on a phone.
    n0 = len(m.parts)
    head_mesh(m, head, look)
    for k in range(n0, len(m.parts)):
        v, q, u, sm, b = m.parts[k]
        m.parts[k] = (head + (v - head) * HEAD_SCALE, q, u, sm, b)
    # Arms.
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr, ha = J(sk, "upperarm." + side), J(sk, "lowerarm." + side), J(sk, "wrist." + side), J(sk, "hand." + side)
        sleeve = shirt if look.get("sleeves", "long") != "none" else skin
        limb(m, [ua + [-0.02 * s, 0, 0], ua + [0.12 * s, 0, 0], la, la + (wr - la) * 0.1, wr - [0.02 * s, 0, 0]],
             [(0.1, 0.095), (0.095, 0.09), (0.075, 0.072), (0.072, 0.07), (0.05, 0.045)],
             [sleeve, sleeve, look.get("cuff", sleeve) if look.get("sleeves", "long") == "long" else skin, skin],
             ["chest", "upperarm." + side, "lowerarm." + side, "wrist." + side], n=10)
        # Deltoid over the shoulder.
        blob(m, ua + [0.06 * s, 0.01, 0], 0.115, sleeve, ["chest", "upperarm." + side], squash=(1.1, 0.9, 1.0))
        hand_mesh(m, wr, ha, s, side, look.get("gloves", skin))
    # Legs.
    for s, side in ((1, "l"), (-1, "r")):
        ul, ll, ft, to = J(sk, "upperleg." + side), J(sk, "lowerleg." + side), J(sk, "foot." + side), J(sk, "toes." + side)
        top = ul + [0.0, -0.07, 0]
        limb(m, [top, top + (ll - top) * 0.45, ll, ll + (ft - ll) * 0.35, ll + (ft - ll) * 0.6, ft + [0, 0.02, 0]],
             [(0.122, 0.12), (0.112, 0.108), (0.082, 0.085), (0.08, 0.09), (0.08, 0.078), (0.068, 0.068)],
             [pants, pants, pants, boots, boots], ["hips", "upperleg." + side, "lowerleg." + side, "foot." + side], n=10,
             front=[0.0, 0.0, 0.1, -0.15, 0.0, 0.0])
        # Boot top cuff and foot.
        cuff = ll + (ft - ll) * 0.6
        limb(m, [cuff - [0, 0.03, 0], cuff + [0, 0.03, 0]], [0.085, 0.085], [boots], ["lowerleg." + side], n=10)
        foot_mesh(m, ft, to, s, side, boots)
    return m, sk


def head_mesh(m, head, look):
    """A long, square-jawed head, about 0.32 tall: 7 heads to the body."""
    hb = ["head"]
    skin, hair = "skin", look["hair"]
    c = head + np.array([0, 0.0, 0.0])
    # (y above the head joint, half width, half depth back, half depth front)
    prof = [(0.02, 0.05, 0.06, 0.07), (0.05, 0.085, 0.09, 0.105), (0.1, 0.1, 0.105, 0.115), (0.16, 0.107, 0.11, 0.115),
            (0.22, 0.108, 0.115, 0.112), (0.27, 0.1, 0.11, 0.1), (0.31, 0.075, 0.085, 0.07), (0.335, 0.03, 0.035, 0.025)]
    rings = []
    n = 14
    for y, hw, bk, fr in prof:
        r = []
        for i in range(n):
            a = 2 * math.pi * i / n
            x, z = hw * math.sin(a), math.cos(a)
            z = z * (fr if z > 0 else bk)
            # Flat cheeks and a square jaw: pull the corners out.
            sq = 1.0 + 0.12 * abs(math.sin(2 * a))
            r.append(c + np.array([x * sq, y, z * (1.0 if z > 0 else sq) + 0.01]))
        rings.append(r)
    loft(m, rings, [skin] * 5 + [hair, hair], hb)
    f = c + np.array([0, 0, 0.12])
    # Nose: a wedge down the middle of the face.
    nose = [[f + [0, 0.205, -0.01], f + [0, 0.13, 0.035], f + [-0.02, 0.12, 0.005], f + [0.02, 0.12, 0.005]]]
    vs = nose[0]
    m.add(vs, [((0, 2, 1), skin, (0.2, 0.4, 0.3)), ((0, 1, 3), skin, (0.2, 0.3, 0.4)), ((1, 2, 3), skin, (0.6, 0.6, 0.6))], None, hb, smooth=False)
    # Brow ridge and eyes set under it.
    boxy(m, f + [0, 0.215, -0.012], (0.17, 0.028, 0.03), look.get("brow", hair), hb)
    for s in (1, -1):
        blob(m, f + [s * 0.045, 0.185, -0.022], 0.017, "black", hb, n=8, m=4, squash=(1.2, 0.7, 0.6), smooth=False)
        # Ears.
        boxy(m, c + [s * 0.11, 0.17, -0.01], (0.025, 0.07, 0.045), skin, hb)
    # Mouth line.
    boxy(m, f + [0, 0.085, -0.008], (0.06, 0.008, 0.012), "leather", hb)
    # Hair: a cap over the crown and back, and a beard if any.
    style = look.get("hair_style", "short")
    if style != "bald":
        caps = [(0.2, 0.112, 0.12, 0.05), (0.26, 0.112, 0.125, 0.09), (0.31, 0.088, 0.1, 0.085), (0.345, 0.045, 0.05, 0.045)]
        rings = []
        for y, hw, bk, fr in caps:
            r = []
            for i in range(n):
                a = 2 * math.pi * i / n
                z = math.cos(a)
                r.append(c + np.array([hw * 1.06 * math.sin(a), y, z * (fr if z > 0 else bk) + 0.008]))
            rings.append(r)
        loft(m, rings, [hair], hb, smooth=False, cap0=False)
        if style == "long":
            limb(m, [c + [0, 0.24, -0.08], c + [0, 0.05, -0.1], c + [0, -0.05, -0.08]], [(0.11, 0.05), (0.1, 0.05), (0.07, 0.03)],
                 [hair], hb + ["chest"], n=8, smooth=False)
    if look.get("beard"):
        rings = []
        for y, hw, fr in ((0.0, 0.04, 0.11), (0.05, 0.085, 0.13), (0.11, 0.1, 0.125), (0.14, 0.104, 0.118)):
            r = []
            for i in range(n):
                a = 2 * math.pi * i / n
                z = math.cos(a)
                r.append(c + np.array([hw * math.sin(a), y, z * (fr if z > 0 else 0.06) + 0.012]))
            rings.append(r)
        loft(m, rings, [look["beard"]], hb, smooth=False, cap1=False)


def hand_mesh(m, wr, ha, s, side, sw):
    """A closed fist-ish hand: palm, a block of fingers curled under, a thumb."""
    hb = ["wrist." + side, "hand." + side]
    d = np.array([s, 0, 0.0])
    limb(m, [wr + d * 0.01, wr + d * 0.07, wr + d * 0.12], [(0.042, 0.05), (0.05, 0.058), (0.045, 0.055)], [sw], hb, n=8)
    limb(m, [wr + d * 0.11 + [0, -0.005, 0], wr + d * 0.165 + [0, -0.02, 0]], [(0.04, 0.05), (0.03, 0.042)], [sw], ["hand." + side], n=8)
    limb(m, [wr + d * 0.04 + [0, -0.01, 0.04], wr + d * 0.1 + [0, -0.02, 0.065]], [0.02, 0.016], [sw], hb, n=6)


def foot_mesh(m, ft, to, s, side, sw):
    fb = ["foot." + side, "toes." + side]
    # Heel to toe along +z, flat on the ground under the ankle.
    g = ft[1] - 0.1
    rings = []
    for z, hw, h in ((-0.07, 0.055, 0.11), (0.0, 0.065, 0.13), (0.09, 0.07, 0.1), (0.17, 0.065, 0.07), (0.22, 0.05, 0.05)):
        cz = ft[2] + z
        rings.append([np.array([ft[0] + x, g + y, cz]) for x, y in ((-hw, 0), (hw, 0), (hw * 0.9, h), (-hw * 0.9, h))])
    loft(m, rings, [sw], fb, smooth=False)


# --- Skinning and export ----------------------------------------------------------------

def segments(sk):
    seg = {}
    kids = {"hips": "spine", "spine": "chest", "chest": "head", "head": None,
            "upperarm.l": "lowerarm.l", "lowerarm.l": "wrist.l", "wrist.l": "hand.l", "hand.l": None,
            "upperarm.r": "lowerarm.r", "lowerarm.r": "wrist.r", "wrist.r": "hand.r", "hand.r": None,
            "upperleg.l": "lowerleg.l", "lowerleg.l": "foot.l", "foot.l": "toes.l", "toes.l": None,
            "upperleg.r": "lowerleg.r", "lowerleg.r": "foot.r", "foot.r": "toes.r", "toes.r": None}
    for b, c in kids.items():
        a = J(sk, b)
        if c:
            e = J(sk, c)
        else:
            y = sk[b][1][:3, 1]
            e = a + y * (0.3 if b == "head" else 0.1)
        seg[b] = (a, e)
    return seg


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + ab * t))


def write(m, sk, g, nodes, joints, name, out):
    seg = segments(sk)
    jidx = {nodes[j]["name"]: k for k, j in enumerate(joints)}
    P, N, UV, JO, WE, IDX = [], [], [], [], [], []
    for verts, quads, _, smooth, bones in m.parts:
        # Weights per vertex from the part's own bones.
        wts = []
        for p in verts:
            ds = np.array([seg_dist(p, *seg[b]) for b in bones])
            w = 1.0 / (ds + 0.02) ** 4
            order = np.argsort(-w)[:3]
            ww = w[order] / w[order].sum()
            wts.append(([jidx[bones[o]] for o in order] + [0] * (4 - len(order)), list(ww) + [0.0] * (4 - len(order))))
        # Normals: smooth shares them per position, flat per face.
        fnorm = []
        acc = np.zeros_like(verts)
        for idx, sw, ts in quads:
            pts = verts[list(idx)]
            nrm = np.cross(pts[1] - pts[0], pts[2] - pts[0])
            if len(idx) == 4:
                nrm = nrm + np.cross(pts[2] - pts[0], pts[3] - pts[0])
            ln = np.linalg.norm(nrm)
            nrm = nrm / ln if ln > 0 else np.array([0, 1.0, 0])
            fnorm.append(nrm)
            for i in idx:
                acc[i] += nrm
        vn = acc / np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-9)
        for (idx, sw, ts), fn in zip(quads, fnorm):
            base = len(P)
            for i, t in zip(idx, ts):
                P.append(verts[i])
                N.append(vn[i] if smooth else fn)
                UV.append(uv(sw, t))
                JO.append(wts[i][0])
                WE.append(wts[i][1])
            tris = [(0, 1, 2)] if len(idx) == 3 else [(0, 1, 2), (0, 2, 3)]
            for a, b, c in tris:
                IDX.extend([base + a, base + b, base + c])
    P = np.array(P, np.float32)
    N = np.array(N, np.float32)
    UV = np.array(UV, np.float32)
    JO = np.array(JO, np.uint16)
    WE = np.array(WE, np.float32)
    IDX = np.array(IDX, np.uint32)
    # Faces must look outward for the culling shader: flip any triangle whose
    # winding disagrees with its normal.
    tri = IDX.reshape(-1, 3)
    a, b, c = P[tri[:, 0]], P[tri[:, 1]], P[tri[:, 2]]
    wn = np.cross(b - a, c - a)
    flip = (wn * (N[tri[:, 0]] + N[tri[:, 1]] + N[tri[:, 2]])).sum(1) < 0
    tri[flip] = tri[flip][:, [0, 2, 1]]
    IDX = tri.reshape(-1)
    ibm = []
    for j in joints:
        ibm.append(np.linalg.inv(sk[nodes[j]["name"]][1]).T.astype(np.float32).reshape(-1))
    IBM = np.array(ibm, np.float32)

    blobs = [P.tobytes(), N.tobytes(), UV.tobytes(), JO.tobytes(), WE.tobytes(), IDX.tobytes(), IBM.tobytes()]
    views, buf = [], b""
    for bl in blobs:
        views.append({"buffer": 0, "byteOffset": len(buf), "byteLength": len(bl)})
        buf += bl + b"\0" * ((4 - len(bl) % 4) % 4)
    nv = len(P)
    acc = [
        {"bufferView": 0, "componentType": 5126, "count": nv, "type": "VEC3", "min": P.min(0).tolist(), "max": P.max(0).tolist()},
        {"bufferView": 1, "componentType": 5126, "count": nv, "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": nv, "type": "VEC2"},
        {"bufferView": 3, "componentType": 5123, "count": nv, "type": "VEC4"},
        {"bufferView": 4, "componentType": 5126, "count": nv, "type": "VEC4"},
        {"bufferView": 5, "componentType": 5125, "count": len(IDX), "type": "SCALAR"},
        {"bufferView": 6, "componentType": 5126, "count": len(joints), "type": "MAT4"},
    ]
    jn = [dict(nodes[j]) for j in joints]
    # Keep the joint nodes in their source order, remapping child indices.
    remap = {j: k for k, j in enumerate(joints)}
    out_nodes = []
    for n in jn:
        n = dict(n)
        if "children" in n:
            n["children"] = [remap[c] for c in n["children"]]
        out_nodes.append(n)
    root_joint = remap[[j for j in joints if nodes[j]["name"] == "root"][0]]
    mesh_node = len(out_nodes)
    out_nodes.append({"name": name + "_Body", "mesh": 0, "skin": 0})
    out_nodes.append({"name": "Rig_Medium", "children": [mesh_node, root_joint]})
    gl = {
        "asset": {"version": "2.0", "generator": "make_hero_body.py"},
        "scene": 0, "scenes": [{"name": "Scene", "nodes": [len(out_nodes) - 1]}],
        "nodes": out_nodes,
        "meshes": [{"name": name + "_Body", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2, "JOINTS_0": 3, "WEIGHTS_0": 4}, "indices": 5, "material": 0}]}],
        "skins": [{"joints": list(range(len(joints))), "inverseBindMatrices": 6, "name": "Rig_Medium"}],
        "materials": [{"doubleSided": False, "name": "knight", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0, "roughnessFactor": 0.5}}],
        "textures": [{"source": 0}],
        "images": [{"mimeType": "image/png", "name": "knight_texture", "uri": "../weapons/knight_texture.png"}],
        "accessors": acc, "bufferViews": views, "buffers": [{"byteLength": len(buf)}],
    }
    js = json.dumps(gl, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    glb = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf))
    glb += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(buf), 0x004E4942) + buf
    open(out, "wb").write(glb)
    print("WROTE", out, nv, "verts", len(IDX) // 3, "tris")


LOOKS = {
    "knight": {"shirt": "tan", "pants": "leather", "boots": "black", "hair": "leather", "beard": "leather", "hair_style": "short"},
}


if __name__ == "__main__":
    names = sys.argv[1:] or list(LOOKS)
    for nm in names:
        g, nodes, joints, _ = skeleton()
        m, sk = build(LOOKS[nm])
        write(m, sk, g, nodes, joints, "Hero_" + nm.capitalize(), os.path.join(ROOT, "assets", "kaykit", "characters", "Hero_%s.glb" % nm.capitalize()))
