# blender -b -P tools/art/decimate_glb.py -- in.glb out.glb max_tris
# Collapse-decimates every mesh to fit max_tris (weights, UVs and clips kept).
import bpy,sys
a=sys.argv[sys.argv.index('--')+1:]; src,dst,cap=a[0],a[1],int(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
ms=[o for o in bpy.data.objects if o.type=='MESH']
tri=lambda o: sum(len(p.vertices)-2 for p in o.data.polygons)
tot=sum(tri(o) for o in ms); r=min(1.0,cap/tot*0.97)
for o in ms:
    while len(o.data.uv_layers)>1: o.data.uv_layers.remove(o.data.uv_layers[-1])
    d=o.modifiers.new('dec','DECIMATE'); d.ratio=r; d.use_collapse_triangulate=True
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=d.name)
print('DECIMATE',tot,'->',sum(tri(o) for o in ms))
bpy.ops.export_scene.gltf(filepath=dst,export_format='GLB',export_animations=True,export_skins=True,export_image_format='AUTO')
