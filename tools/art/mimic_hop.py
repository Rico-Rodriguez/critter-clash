# mimic_hop.py in.glb out.glb: adds "Idle" (lid breathing) and "Walk" (hop with lid flaps)
# clips to the Mimic_Chest glb, which ships with only Bite_Front. Keyframes rigid nodes
# only (RootNode translation, lid rotation); meshes and materials stay untouched.
import json,struct,sys,math
import numpy as np
b=open(sys.argv[1],'rb').read(); n=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+n])
bn=struct.unpack('<I',b[20+n:24+n])[0]; bin_=bytearray(b[28+n:28+n+bn])
def write(arr,typ):
    arr=np.ascontiguousarray(np.asarray(arr,dtype=np.float32))
    while len(bin_)%4: bin_.append(0)
    off=len(bin_); bin_.extend(arr.tobytes())
    j['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':arr.nbytes})
    acc={'bufferView':len(j['bufferViews'])-1,'componentType':5126,'count':len(arr),'type':typ}
    if typ=='SCALAR': acc['min']=[float(arr.min())]; acc['max']=[float(arr.max())]
    j['accessors'].append(acc); return len(j['accessors'])-1
def qmul(a,b):
    x1,y1,z1,w1=a; x2,y2,z2,w2=b
    return [w1*x2+x1*w2+y1*z2-z1*y2, w1*y2-x1*z2+y1*w2+z1*x2, w1*z2+x1*y2-y1*x2+z1*w2, w1*w2-x1*x2-y1*y2-z1*z2]
names={nd.get('name'):i for i,nd in enumerate(j['nodes'])}
root=names['RootNode']; lid=names['polySurface67']; q0=j['nodes'][lid]['rotation']
def lidq(deg): h=math.radians(deg)/2; return qmul(q0,[math.sin(h),0,0,math.cos(h)])
def clip(name,dur,hop,lid_amp,lid_freq,N=31):
    t=np.linspace(0,dur,N); ch=[]; sm=[]
    tr=[[0,hop*abs(math.sin(math.pi*k/dur*2)),0] for k in t] if hop else None
    if tr:
        sm.append({'input':write(t,'SCALAR'),'output':write(tr,'VEC3'),'interpolation':'LINEAR'}); ch.append({'sampler':0,'target':{'node':root,'path':'translation'}})
    rq=[lidq(lid_amp*(0.5-0.5*math.cos(2*math.pi*lid_freq*k/dur))) for k in t]
    sm.append({'input':write(t,'SCALAR'),'output':write(rq,'VEC4'),'interpolation':'LINEAR'}); ch.append({'sampler':len(sm)-1,'target':{'node':lid,'path':'rotation'}})
    j['animations'].append({'name':name,'channels':ch,'samplers':sm})
clip('Idle',2.4,0,-6,1)
clip('Walk',0.8,40,-14,2)
while len(bin_)%4: bin_.append(0)
j['buffers'][0]['byteLength']=len(bin_)
js=json.dumps(j,separators=(',',':')).encode(); js+=b' '*((4-len(js)%4)%4)
open(sys.argv[2],'wb').write(struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(bin_))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(bin_),0x004E4942)+bytes(bin_))
