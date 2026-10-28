"""Adds clips to boss glbs that ship a single take: python3 tools/art/boss_clips.py [model ...]
Runs sidekick_clips.py's builder on assets/foes/<file>_src.glb with the specs in boss_clip_specs.py.
Renames the shipped take to RENAME's name first. Re-running rebuilds the owned clips from the
original data (the shipped take and everything else in the file stay byte-identical)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import sidekick_clips as sc
from boss_clip_specs import MODELS
sc.DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'foes')
RENAME = {'frost_troll': ('mixamo.com', 'Idle'), 'yeti': ('c5_action', 'Idle')}
OWNED = {'Walk', 'Run', 'Attack', 'Slam', 'Roar', 'Hit', 'Death'}

def run(key):
    cfg = MODELS[key]; path = os.path.join(sc.DIR, cfg['file'] + '_src.glb')
    j, bin_ = sc.load(path)
    j['animations'] = [a for a in j['animations'] if a['name'] not in OWNED]
    old, new = RENAME[key]
    for a in j['animations']:
        if a['name'] == old: a['name'] = new
    m = sc.Model(j, bin_)
    cfg['H'] = 1.0 / sc.tscn_scale(cfg['file'])
    for name, spec in cfg['clips'].items():
        sc.build_clip(m, cfg, name, spec)
    sc.save(path, m.j, m.bin)
    print(key, [a['name'] for a in m.j['animations']], f'{os.path.getsize(path)/1e6:.2f} MB')

if __name__ == '__main__':
    for k in sys.argv[1:] or list(MODELS): run(k)
