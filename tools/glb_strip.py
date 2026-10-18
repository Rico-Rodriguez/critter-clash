#!/usr/bin/env python3
# Used to drop the Troll Cave clips from troll.glb once boss_bake.gd had baked them
# into troll_anims.res (34 MB -> ~15 MB). Re-bake from the original Sketchfab download.
"""Keep only the named animations in a .glb and drop buffer data nothing references.
usage: glb_strip.py in.glb out.glb "Clip A,Clip B"
"""
import json, struct, sys
src, dst, keep = sys.argv[1], sys.argv[2], set(sys.argv[3].split(","))
f = open(src, "rb").read()
jl = struct.unpack_from("<I", f, 12)[0]
j = json.loads(f[20:20 + jl])
bo = 20 + jl
bl = struct.unpack_from("<I", f, bo)[0]
binb = f[bo + 8: bo + 8 + bl]
j["animations"] = [a for a in j.get("animations", []) if a["name"] in keep]
# accessors still referenced
used_acc = set()
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ("indices", "input", "output", "inverseBindMatrices") and isinstance(v, int):
                used_acc.add(v)
            elif k == "attributes" or k == "targets":
                pass
            walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
for m in j["meshes"]:
    for p in m["primitives"]:
        used_acc.update(p["attributes"].values())
        if "indices" in p: used_acc.add(p["indices"])
        for t in p.get("targets", []): used_acc.update(t.values())
for s in j.get("skins", []):
    if "inverseBindMatrices" in s: used_acc.add(s["inverseBindMatrices"])
for a in j["animations"]:
    for s in a["samplers"]:
        used_acc.add(s["input"]); used_acc.add(s["output"])
acc_map = {}
new_acc = []
for i, a in enumerate(j["accessors"]):
    if i in used_acc:
        acc_map[i] = len(new_acc); new_acc.append(a)
used_bv = set(a["bufferView"] for a in new_acc if "bufferView" in a)
used_bv.update(im["bufferView"] for im in j.get("images", []) if "bufferView" in im)
bv_map = {}; new_bv = []; out = bytearray()
for i, bv in enumerate(j["bufferViews"]):
    if i not in used_bv: continue
    while len(out) % 8: out.append(0)
    data = binb[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
    nb = dict(bv); nb["byteOffset"] = len(out); out += data
    bv_map[i] = len(new_bv); new_bv.append(nb)
for a in new_acc:
    if "bufferView" in a: a["bufferView"] = bv_map[a["bufferView"]]
for im in j.get("images", []):
    if "bufferView" in im: im["bufferView"] = bv_map[im["bufferView"]]
for m in j["meshes"]:
    for p in m["primitives"]:
        p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
        if "indices" in p: p["indices"] = acc_map[p["indices"]]
        if "targets" in p: p["targets"] = [{k: acc_map[v] for k, v in t.items()} for t in p["targets"]]
for s in j.get("skins", []):
    if "inverseBindMatrices" in s: s["inverseBindMatrices"] = acc_map[s["inverseBindMatrices"]]
for a in j["animations"]:
    for s in a["samplers"]:
        s["input"] = acc_map[s["input"]]; s["output"] = acc_map[s["output"]]
j["accessors"] = new_acc; j["bufferViews"] = new_bv
while len(out) % 4: out.append(0)
j["buffers"] = [{"byteLength": len(out)}]
js = json.dumps(j, separators=(",", ":")).encode()
while len(js) % 4: js += b" "
total = 12 + 8 + len(js) + 8 + len(out)
with open(dst, "wb") as o:
    o.write(struct.pack("<III", 0x46546C67, 2, total))
    o.write(struct.pack("<II", len(js), 0x4E4F534A)); o.write(js)
    o.write(struct.pack("<II", len(out), 0x004E4942)); o.write(out)
print(dst, total)
