# Low-poly KayKit-style mimic chest. Exports a .glb.
import bpy, math, sys
out = sys.argv[sys.argv.index("--") + 1]
exec(open("/tmp/claude-0/blend/kit.py").read())
WOOD = mat("wood", srgb("8a5a34")); WOOD_D = mat("wood_d", srgb("5e3b22"))
IRON = mat("iron", srgb("9aa0a6"), 0.4); GOLD = mat("gold", srgb("e0a83a"), 0.35)
MOUTH = mat("mouth", srgb("3a1418")); TONGUE = mat("tongue", srgb("d4566a"))
TOOTH = mat("tooth", srgb("f2ead6")); EYE = mat("eye", srgb("ffd34a"), 0.3); PUP = mat("pup", srgb("1b1a1f"))
# Base box, dark inside, iron bands.
cube((0, 0, 0.36), (0.5, 0.36, 0.26), m=WOOD, sub=0, bevel=0.03)
cube((0, 0, 0.6), (0.44, 0.3, 0.03), m=MOUTH, sub=0)
for x in (-0.33, 0.33):
    cube((x, 0, 0.36), (0.05, 0.375, 0.27), m=IRON, sub=0, bevel=0.01)
cube((0, -0.37, 0.48), (0.08, 0.02, 0.09), m=GOLD, sub=0, bevel=0.01)
# Lid hinged at the back, opened about 50 degrees, as one pivot so it rotates as a piece.
bpy.ops.object.empty_add(location=(0, 0.36, 0.62)); lid = bpy.context.object
for o in [cube((0, -0.36, 0.13), (0.5, 0.36, 0.14), m=WOOD, sub=0, bevel=0.03),
          cube((-0.33, -0.36, 0.13), (0.05, 0.375, 0.15), m=IRON, sub=0, bevel=0.01),
          cube((0.33, -0.36, 0.13), (0.05, 0.375, 0.15), m=IRON, sub=0, bevel=0.01),
          cube((0, -0.36, 0.0), (0.44, 0.3, 0.02), m=MOUTH, sub=0)]:
    o.location.y += 0.36; o.location.z -= 0.0; o.parent = lid
    o.location = (o.location.x, o.location.y - 0.36, o.location.z)
for i in range(7):
    x = -0.39 + i * 0.13
    o = cone((x, -0.32 - 0.36 + 0.36, -0.06), 0.045, 0.0, 0.12, (math.pi, 0, 0), TOOTH, verts=4); o.parent = lid
    o.location = (x, -0.66, -0.05)
lid.rotation_euler = (math.radians(-52), 0, 0)
for i in range(6):
    x = -0.33 + i * 0.13
    cone((x, -0.3, 0.66), 0.045, 0.0, 0.12, (0, 0, 0), TOOTH, verts=4)
# Tongue lolling over the front edge.
cube((0.05, -0.28, 0.63), (0.13, 0.2, 0.03), m=TONGUE, sub=2)
cube((0.08, -0.46, 0.55), (0.11, 0.06, 0.1), rot=(math.radians(60), 0, 0), m=TONGUE, sub=2)
# Eyes inside the dark under the lid.
for s in (-1, 1):
    sphere((s * 0.17, 0.12, 0.78), (0.08, 0.06, 0.08), m=EYE)
    sphere((s * 0.17, 0.065, 0.78), (0.03, 0.02, 0.05), m=PUP, seg=6, ring=4)
# Stubby legs.
for x in (-0.36, 0.36):
    for y in (-0.22, 0.22):
        cube((x, y, 0.06), (0.07, 0.07, 0.08), m=WOOD_D, sub=2)
finish(out, "Mimic")
