"""Keyframe specs for boss_clips.py: clips added to boss glbs that ship a single take. Angles in
degrees, times in s; the format and the motion language are sidekick_clip_specs.py's (heavy wind-up,
short fast strike, held follow-through, slow settle, no squash or bounce)."""
from sidekick_clip_specs import k, cyc, gait, hit

def kk(*pairs): return list(pairs)

def ramp(t1, v, t_end, hold=None):
    """0 -> v at t1, hold, back to 0 at t_end (hold = time the pose is kept until)."""
    return kk((0, 0), (t1, v), (hold or t1, v), (t_end, 0))

A, SL, RO, HT = 0.75, 1.0, 1.7, 0.4   # attack, slam, roar, hit lengths

def frost_troll():
    cfg = {'file': 'frost_troll', 'idle': 'Idle', 'root': 'Mutant:Hips_01', 'roles': {
        'spine': r'Mutant:Spine\d?_0[234]', 'head': r'Mutant:(Neck_05|Head_06)',
        'armL': r'Mutant:LeftArm_09', 'armR': r'Mutant:RightArm_013',
        'foreL': r'Mutant:LeftForeArm_010', 'foreR': r'Mutant:RightForeArm_014',
        'thighL': r'Mutant:LeftUpLeg_027', 'thighR': r'Mutant:RightUpLeg_032',
        'calfL': r'Mutant:LeftLeg_028', 'calfR': r'Mutant:RightLeg_033'}}
    a1, a2 = 0.3, 0.42   # wind-up peak, strike (strike lands at ~55% of the clip)
    s1, s2 = 0.42, 0.58
    cfg['clips'] = {
        'Walk': gait(1.2, 18, 30, 10, 6, -0.02),
        'Run': gait(0.7, 30, 55, 22, 14, -0.04),
        # One-handed overhand swing with the right arm.
        'Attack': {'dur': A, 'offs': {
            'spine': [('x', kk((0, 0), (a1, -16), (a2, 30), (0.55, 26), (A, 0)))],
            'head': [('x', kk((0, 0), (a1, -8), (a2, 14), (0.55, 12), (A, 0)))],
            'armR': [('x', kk((0, 0), (a1, -130), (a2, 20), (0.55, 15), (A, 0)))],
            'foreR': [('x', kk((0, 0), (a1, -45), (a2, 0), (A, 0)))]},
            'root': kk((0, (0, 0, 0)), (a1, (0, 0, -0.03)), (a2, (0, -0.04, 0.12)), (0.55, (0, -0.03, 0.1)), (A, (0, 0, 0)))},
        # Both fists up, then down into the ground.
        'Slam': {'dur': SL, 'offs': {
            'spine': [('x', kk((0, 0), (s1, -24), (s2, 38), (0.78, 34), (SL, 0)))],
            'head': [('x', kk((0, 0), (s1, -20), (s2, 22), (0.78, 20), (SL, 0)))],
            'armL': [('x', kk((0, 0), (s1, -150), (s2, 12), (0.78, 10), (SL, 0))), ('z', kk((0, 0), (s1, 14), (s2, 18), (SL, 0)))],
            'armR': [('x', kk((0, 0), (s1, -150), (s2, 12), (0.78, 10), (SL, 0))), ('z', kk((0, 0), (s1, 14), (s2, 18), (SL, 0)))]},
            'root': kk((0, (0, 0, 0)), (s1, (0, 0.03, -0.04)), (s2, (0, -0.1, 0.08)), (0.78, (0, -0.08, 0.06)), (SL, (0, 0, 0)))},
        # Head back, chest out, arms flung wide.
        'Roar': {'dur': RO, 'offs': {
            'spine': [('x', kk((0, 0), (0.4, -26), (1.3, -22), (RO, 0)))],
            'head': [('x', kk((0, 0), (0.4, -38), (1.3, -34), (RO, 0)))],
            'armL': [('z', kk((0, 0), (0.4, 38), (1.3, 34), (RO, 0))), ('x', kk((0, 0), (0.4, -25), (1.3, -20), (RO, 0)))],
            'armR': [('z', kk((0, 0), (0.4, 38), (1.3, 34), (RO, 0))), ('x', kk((0, 0), (0.4, -25), (1.3, -20), (RO, 0)))]},
            'root': kk((0, (0, 0, 0)), (0.4, (0, 0.02, -0.04)), (1.3, (0, 0.02, -0.03)), (RO, (0, 0, 0)))},
        'Hit': {'dur': HT, 'offs': {
            'spine': [('x', hit(-18))], 'head': [('x', hit(-22)), ('y', hit(10))],
            'armL': [('z', hit(25))], 'armR': [('z', hit(25))]},
            'root': kk((0, (0, 0, 0)), (0.07, (0, -0.02, -0.07)), (HT, (0, 0, 0)))},
        # Staggers, drops to the knees, slumps forward and stays down.
        'Death': {'dur': 1.5, 'offs': {
            'spine': [('x', kk((0, 0), (0.25, -14), (1.0, 62), (1.5, 66)))],
            'head': [('x', kk((0, 0), (0.25, -20), (1.0, 28), (1.5, 30)))],
            'armL': [('x', kk((0, 0), (1.0, 20), (1.5, 24)))], 'armR': [('x', kk((0, 0), (1.0, 20), (1.5, 24)))],
            'thighL': [('x', kk((0, 0), (1.0, -75), (1.5, -78)))], 'thighR': [('x', kk((0, 0), (1.0, -75), (1.5, -78)))],
            'calfL': [('x', kk((0, 0), (1.0, 105), (1.5, 108)))], 'calfR': [('x', kk((0, 0), (1.0, 105), (1.5, 108)))]},
            'root': kk((0, (0, 0, 0)), (0.25, (0, 0, -0.05)), (1.0, (0, -0.3, 0.1)), (1.5, (0, -0.32, 0.12)))},
    }
    return cfg

def yeti():
    """The Rime Yeti (foe, a Mixamo biped): the troll's moves on its rig, a hunched, quicker gait."""
    cfg = frost_troll()
    cfg.update({'file': 'yeti', 'root': 'mixamorig:Hips_00', 'roles': {
        'spine': r'mixamorig:Spine[12]?_0[123]', 'head': r'mixamorig:(Neck_04|Head_05)',
        'armL': r'mixamorig:LeftArm_07', 'armR': r'mixamorig:RightArm_011',
        'foreL': r'mixamorig:LeftForeArm_08', 'foreR': r'mixamorig:RightForeArm_012',
        'thighL': r'mixamorig:LeftUpLeg_014', 'thighR': r'mixamorig:RightUpLeg_019',
        'calfL': r'mixamorig:LeftLeg_015', 'calfR': r'mixamorig:RightLeg_020'}})
    cfg['clips'] = dict(cfg['clips'])
    cfg['clips']['Walk'] = gait(1.05, 20, 34, 12, 12, -0.02)
    cfg['clips']['Run'] = gait(0.62, 32, 58, 24, 18, -0.04)
    return cfg

MODELS = {'frost_troll': frost_troll(), 'yeti': yeti()}
