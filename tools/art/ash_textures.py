# ash_textures.py: bakes the Ash Wyrm's albedo (drake base colour cooled to an
# ash ramp) and ember emission (glow only in the darkest crevices) from
# assets/sidekicks/dragon_src.glb. No runtime tint: sidekick_look uses these as is.
import json,struct,io
from PIL import Image
import numpy as np
b=open('assets/sidekicks/dragon_src.glb','rb').read(); n=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+n]); bin_=b[28+n:]
t=j['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']; im=j['images'][j['textures'][t]['source']]
bv=j['bufferViews'][im['bufferView']]; o=bv.get('byteOffset',0)
a=np.asarray(Image.open(io.BytesIO(bin_[o:o+bv['byteLength']])).convert('RGB')).astype(np.float32)/255
l=a@[0.3,0.59,0.11]
ash=np.stack([0.16+0.62*l,0.155+0.6*l,0.15+0.58*l],-1)
Image.fromarray((ash.clip(0,1)*255).astype('uint8')).save('assets/sidekicks/dragon_ash_albedo.png')
m=np.clip((0.2-l)/0.15,0,1)**1.5
Image.fromarray((np.stack([m,m*0.36,m*0.08],-1)*255).astype('uint8')).save('assets/sidekicks/dragon_ash_emission.png')
