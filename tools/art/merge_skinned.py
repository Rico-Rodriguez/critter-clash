# merge_skinned.py in.glb out.glb: merges every skinned primitive (plus meshes parented under a
# joint, re-bound rigidly to it) into one primitive per material, so a multi-mesh Sketchfab rig
# draws in a few calls. Materials, UVs and weights are untouched. Box tool: needs numpy.
import json,struct,sys,numpy as np
b=open(sys.argv[1],'rb').read(); n=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+n])
bn=struct.unpack('<I',b[20+n:24+n])[0]; bin_=bytearray(b[28+n:28+n+bn])
CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'MAT4':16,'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def read(ai):
    a=j['accessors'][ai]; bv=j['bufferViews'][a['bufferView']]; dt=np.dtype(CT[a['componentType']]); nc=NC[a['type']]
    st=bv.get('byteStride',dt.itemsize*nc); off=bv.get('byteOffset',0)+a.get('byteOffset',0)
    raw=np.frombuffer(bytes(bin_),dtype=np.uint8,count=st*(a['count']-1)+dt.itemsize*nc,offset=off)
    out=np.lib.stride_tricks.as_strided(raw,shape=(a['count'],dt.itemsize*nc),strides=(st,1)).copy().view(dt).reshape(a['count'],nc)
    if a.get('normalized') and dt!=np.float32: out=out.astype(np.float32)/np.iinfo(dt).max
    return out
def write(arr,ct,typ,target=None):
    arr=np.ascontiguousarray(arr.astype(CT[ct])); 
    while len(bin_)%4: bin_.append(0)
    off=len(bin_); bin_.extend(arr.tobytes())
    bv={'buffer':0,'byteOffset':off,'byteLength':arr.nbytes}
    if target: bv['target']=target
    j['bufferViews'].append(bv)
    acc={'bufferView':len(j['bufferViews'])-1,'componentType':ct,'count':len(arr),'type':typ}
    if typ=='VEC3' and ct==5126: acc['min']=arr.min(0).tolist(); acc['max']=arr.max(0).tolist()
    j['accessors'].append(acc); return len(j['accessors'])-1
def nodemat(nd):
    if 'matrix' in nd: return np.array(nd['matrix'],dtype=np.float64).reshape(4,4).T
    t=nd.get('translation',[0,0,0]); r=nd.get('rotation',[0,0,0,1]); sc=nd.get('scale',[1,1,1])
    x,y,z,w=r; R=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    M=np.eye(4); M[:3,:3]=R*np.array(sc); M[:3,3]=t; return M
par={c:i for i,nd in enumerate(j['nodes']) for c in nd.get('children',[])}
sj=j['skins'][0]['joints']; IBM=read(j['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1).astype(np.float64)
extra=[]
for i,nd in enumerate(j['nodes']):
    if 'mesh' in nd and 'skin' not in nd:
        M=nodemat(nd); p=par.get(i)
        while p is not None and p not in sj: M=nodemat(j['nodes'][p])@M; p=par.get(p)
        if p is None: continue
        ji=sj.index(p); T=np.linalg.inv(IBM[ji])@M; N3=np.linalg.inv(T[:3,:3]).T
        for pr in j['meshes'][nd['mesh']]['primitives']:
            P=read(pr['attributes']['POSITION']).astype(np.float64); P=(np.c_[P,np.ones(len(P))]@T.T)[:,:3]
            Nn=read(pr['attributes']['NORMAL']).astype(np.float64)@N3.T; Nn/=np.linalg.norm(Nn,axis=1,keepdims=True)+1e-12
            na=dict(pr['attributes']); na['POSITION']=write(P,5126,'VEC3'); na['NORMAL']=write(Nn,5126,'VEC3')
            na['JOINTS_0']=write(np.tile([ji,0,0,0],(len(P),1)),5123,'VEC4'); na['WEIGHTS_0']=write(np.tile([1.,0,0,0],(len(P),1)),5126,'VEC4')
            extra.append(dict(pr,attributes=na))
        del nd['mesh']
groups={}; meshnodes=[i for i,nd in enumerate(j['nodes']) if 'mesh' in nd and 'skin' in nd]
for ni in meshnodes:
    for p in j['meshes'][j['nodes'][ni]['mesh']]['primitives']:
        groups.setdefault(p.get('material'),[]).append(p)
for pr in extra: groups.setdefault(pr.get('material'),[]).append(pr)
prims=[]
for mat,ps in groups.items():
    keys=set.intersection(*[set(p['attributes']) for p in ps]); A={k:[] for k in keys}; I=[]; base=0
    for p in ps:
        for k in keys: A[k].append(read(p['attributes'][k]))
        I.append(read(p['indices'])[:,0].astype(np.uint32)+base); base+=j['accessors'][p['attributes']['POSITION']]['count']
    att={}
    for k in keys:
        v=np.concatenate(A[k])
        if k.startswith('JOINTS'): att[k]=write(v,5123,'VEC4',34962)
        else: att[k]=write(v.astype(np.float32),5126,{1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'}[v.shape[1]],34962)
    pr={'attributes':att,'indices':write(np.concatenate(I),5125,'SCALAR',34963)}
    if mat is not None: pr['material']=mat
    prims.append(pr)
j['meshes'].append({'name':'merged','primitives':prims})
for k,ni in enumerate(meshnodes):
    if k==0: j['nodes'][ni]['mesh']=len(j['meshes'])-1
    else: del j['nodes'][ni]['mesh']; del j['nodes'][ni]['skin']
while len(bin_)%4: bin_.append(0)
j['buffers'][0]['byteLength']=len(bin_)
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((4-len(js)%4)%4)
out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(bin_))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(bin_),0x004E4942)+bytes(bin_)
open(sys.argv[2],'wb').write(out); print('prims',len(prims),'from',sum(len(v) for v in groups.values()))
