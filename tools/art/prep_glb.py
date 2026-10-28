# prep_glb.py in.glb out.glb [--keep "name1,name2"] [--speed "NAME=2.4,NAME2=1.5"] [--tex 1024] [--q 88] [--eps 0.0015]
# Shrinks a downloaded Sketchfab glb before merge_skinned.py / decimate_skinned.py:
#  - drops the animations not listed in --keep (exact clip names; every clip when omitted),
#  - plays the named clips faster (--speed; keys move to t/factor) so a 4 s slam fits a 1.4 s swing,
#  - key-reduces every LINEAR animation sampler (a key goes when the lerp of its neighbours is within
#    --eps of it, translations scaled by the model's size; constant channels shrink to two keys),
#  - re-encodes each embedded image no larger than --tex pixels (JPEG when it has no alpha, else PNG),
#  - drops meshes no node uses,
#  - rewrites the BIN chunk with only the buffer views the file still uses.
# Nodes, skins, materials, UVs and the kept clips are otherwise untouched. Box tool: needs numpy, Pillow.
import json,struct,sys,io
import numpy as np
from PIL import Image
args=sys.argv[1:]; src,dst=args[0],args[1]
def opt(k,d=None):
    return args[args.index(k)+1] if k in args else d
keep=[s for s in (opt('--keep') or '').split(',') if s]; cap=int(opt('--tex','1024')); q=int(opt('--q','88')); eps=float(opt('--eps','0.0015'))
speed={kv.rsplit('=',1)[0]:float(kv.rsplit('=',1)[1]) for kv in (opt('--speed') or '').split(',') if kv}
b=open(src,'rb').read(); n=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+n])
bn=struct.unpack('<I',b[20+n:24+n])[0]; bin_=b[28+n:28+n+bn]
CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'MAT4':16,'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def read(ai):
    a=j['accessors'][ai]
    if '_data' in a: return np.frombuffer(a['_data'],np.float32).reshape(a['count'],NC[a['type']]).copy()
    bv=j['bufferViews'][a['bufferView']]; dt=np.dtype(CT[a['componentType']]); nc=NC[a['type']]
    st=bv.get('byteStride',dt.itemsize*nc); off=bv.get('byteOffset',0)+a.get('byteOffset',0)
    raw=np.frombuffer(bin_,dtype=np.uint8,count=st*(a['count']-1)+dt.itemsize*nc,offset=off)
    out=np.lib.stride_tricks.as_strided(raw,shape=(a['count'],dt.itemsize*nc),strides=(st,1)).copy().view(dt).reshape(a['count'],nc)
    if a.get('normalized') and dt!=np.float32: out=out.astype(np.float32)/np.iinfo(dt).max
    return out.astype(np.float32)
if keep and j.get('animations'):
    j['animations']=[a for a in j['animations'] if a.get('name') in keep]
# meshes no node uses (merge_skinned.py leaves the originals behind) go too
ref=sorted({nd['mesh'] for nd in j['nodes'] if 'mesh' in nd}); mm={o:i for i,o in enumerate(ref)}
j['meshes']=[j['meshes'][o] for o in ref]
for nd in j['nodes']:
    if 'mesh' in nd: nd['mesh']=mm[nd['mesh']]
size=1.0
pos=[j['accessors'][p['attributes']['POSITION']] for m in j.get('meshes',[]) for p in m['primitives'] if 'POSITION' in p['attributes']]
if pos and all('min' in a for a in pos):
    lo=np.min([a['min'] for a in pos],0); hi=np.max([a['max'] for a in pos],0); size=float(np.max(hi-lo)) or 1.0
def reduce_keys(t,v,tol):
    n=len(t)
    if n<=2: return t,v
    flat=np.abs(v-v[0]).max()<=tol
    if flat: return t[[0,-1]],v[[0,-1]]
    kp=np.zeros(n,bool); kp[0]=kp[-1]=True
    stack=[(0,n-1)]
    while stack:
        a,c=stack.pop()
        if c-a<2: continue
        w=((t[a+1:c]-t[a])/max(t[c]-t[a],1e-9))[:,None]
        err=np.abs(v[a+1:c]-(v[a]+(v[c]-v[a])*w)).max(1); k=int(err.argmax())
        if err[k]>tol:
            kp[a+1+k]=True; stack.append((a,a+1+k)); stack.append((a+1+k,c))
    return t[kp],v[kp]
def new_acc(arr,typ,**kw):
    arr=np.ascontiguousarray(arr.astype(np.float32))
    a={'componentType':5126,'count':len(arr),'type':typ,'_data':arr.tobytes()}
    if typ=='SCALAR': a['min']=[float(arr.min())]; a['max']=[float(arr.max())]
    a.update(kw); j['accessors'].append(a); return len(j['accessors'])-1
for an in j.get('animations',[]):
    path_of={}
    for ch in an['channels']: path_of.setdefault(ch['sampler'],ch['target']['path'])
    for si,s in enumerate(an['samplers']):
        t=read(s['input'])[:,0].astype(np.float64)/speed.get(an.get('name'),1.0); oa=j['accessors'][s['output']]; v=read(s['output'])
        if s.get('interpolation','LINEAR')=='LINEAR' and path_of.get(si)!='weights':
            t,v=reduce_keys(t,v,eps*(size if path_of.get(si)=='translation' else 1.0))
        s['input']=new_acc(t.astype(np.float32).reshape(-1,1),'SCALAR'); s['output']=new_acc(v,oa['type'])
used=set()
def acc(i):
    if i is not None: used.add(i)
for m in j.get('meshes',[]):
    for p in m['primitives']:
        for v in p.get('attributes',{}).values(): acc(v)
        acc(p.get('indices'))
        for t in p.get('targets',[]):
            for v in t.values(): acc(v)
for s in j.get('skins',[]): acc(s.get('inverseBindMatrices'))
for an in j.get('animations',[]):
    for s in an['samplers']: acc(s['input']); acc(s['output'])
order=sorted(used); amap={o:i for i,o in enumerate(order)}
bvs=set()
for i in order:
    a=j['accessors'][i]
    if 'bufferView' in a: bvs.add(a['bufferView'])
    sp=a.get('sparse')
    if sp: bvs.add(sp['indices']['bufferView']); bvs.add(sp['values']['bufferView'])
img_bv={}
for k,im in enumerate(j.get('images',[])):
    if 'bufferView' in im: bvs.add(im['bufferView']); img_bv[im['bufferView']]=k
out=bytearray(); nb=[]; bmap={}
def put(data,**kw):
    while len(out)%4: out.append(0)
    v={'buffer':0,'byteOffset':len(out),'byteLength':len(data)}; v.update(kw); out.extend(data); nb.append(v); return len(nb)-1
for o in sorted(bvs):
    v=j['bufferViews'][o]; data=bin_[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
    if o in img_bv:
        im=Image.open(io.BytesIO(data)); im.load()
        if max(im.size)>cap:
            s=cap/max(im.size); im=im.resize((max(1,round(im.width*s)),max(1,round(im.height*s))),Image.LANCZOS)
        alpha=im.mode in('RGBA','LA','P') and (im.convert('RGBA').getchannel('A').getextrema()[0]<255)
        buf=io.BytesIO()
        if alpha: im.convert('RGBA').save(buf,'PNG',optimize=True); j['images'][img_bv[o]]['mimeType']='image/png'
        else: im.convert('RGB').save(buf,'JPEG',quality=q,optimize=True); j['images'][img_bv[o]]['mimeType']='image/jpeg'
        data=buf.getvalue(); bmap[o]=put(data)
    else:
        extra={k:v[k] for k in ('byteStride','target') if k in v}
        bmap[o]=put(data,**extra)
accs=[]
for i in order:
    a=dict(j['accessors'][i])
    if '_data' in a: a['bufferView']=put(a.pop('_data')); a.pop('byteOffset',None)
    elif 'bufferView' in a: a['bufferView']=bmap[a['bufferView']]
    sp=a.get('sparse')
    if sp:
        sp['indices']['bufferView']=bmap[sp['indices']['bufferView']]; sp['values']['bufferView']=bmap[sp['values']['bufferView']]
    accs.append(a)
for m in j.get('meshes',[]):
    for p in m['primitives']:
        p['attributes']={k:amap[v] for k,v in p['attributes'].items()}
        if 'indices' in p: p['indices']=amap[p['indices']]
        if 'targets' in p: p['targets']=[{k:amap[v] for k,v in t.items()} for t in p['targets']]
for s in j.get('skins',[]):
    if 'inverseBindMatrices' in s: s['inverseBindMatrices']=amap[s['inverseBindMatrices']]
for an in j.get('animations',[]):
    for s in an['samplers']: s['input']=amap[s['input']]; s['output']=amap[s['output']]
for im in j.get('images',[]):
    if 'bufferView' in im: im['bufferView']=bmap[im['bufferView']]
j['accessors']=accs; j['bufferViews']=nb; j['buffers']=[{'byteLength':len(out)}]
while len(out)%4: out.append(0)
js=json.dumps(j,separators=(',',':')).encode()
while len(js)%4: js+=b' '
tot=12+8+len(js)+8+len(out)
open(dst,'wb').write(b'glTF'+struct.pack('<II',2,tot)+struct.pack('<I',len(js))+b'JSON'+js+struct.pack('<I',len(out))+b'BIN\0'+bytes(out))
print(dst,len(b)//1024,'KB ->',tot//1024,'KB')
