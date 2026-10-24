"""Per-model keyframe specs for sidekick_clips.py. Angles in degrees, times in s.
Game timing (src/hunt/sidekick.gd): one-shots are fitted to 0.55 s with the hit at
0.22 s (40%); specials to 0.8 s landing at 0.32 s (40%); hits are ~0.3 s flinches.
So every Attack strikes at 40% of its length, every Special lands at 40%.
Motion language: slow heavy wind-up, a short fast strike, a held follow-through,
a slow settle. No squash, no bounce."""

import math
A, S, HT = 0.6, 0.9, 0.35          # attack, special, hit lengths
a_w, a_s = 0.17, 0.24              # attack wind-up peak, strike
s_w, s_s = 0.26, 0.36              # special wind-up peak, landing

def k(*pairs): return list(pairs)

def atk(wind, strike, hold=0.42):
    """wind-up value, strike value -> keys over the attack length."""
    return k((0, 0), (a_w, wind), (a_s, strike), (hold, strike * 0.85), (A, 0))

def spc(wind, land, hold=0.62):
    return k((0, 0), (s_w, wind), (s_s, land), (hold, land * 0.9), (S, 0))

def hit(v):
    return k((0, 0), (0.07, v), (0.16, v * 0.7), (HT, 0))

def cyc(amp, per, phase=0.0, off=0.0, n=16, cycles=1, rect=False):
    """Sine keys over `cycles` periods; rect keeps only the positive lobe (knee bends)."""
    out = []
    for i in range(n * cycles + 1):
        t = per * i / n; v = math.sin(2 * math.pi * (i / n + phase))
        out.append((t, off + amp * (max(v, 0.0) if rect else v)))
    return out

def gait(per, stride, knee, arm, lean, bob, base=None):
    """Keyed walk/run cycle in place: thighs swing opposite, knees fold on the
    forward swing, arms counter-swing, the body dips twice per cycle."""
    o = {'thighL': [('x', cyc(-stride, per))], 'thighR': [('x', cyc(stride, per))],
         'calfL': [('x', cyc(knee, per, 0.25, rect=True))], 'calfR': [('x', cyc(knee, per, 0.75, rect=True))],
         'armL': [('x', cyc(arm, per))], 'armR': [('x', cyc(-arm, per))],
         'spine': [('x', k((0, lean), (per, lean))), ('y', cyc(4, per))]}
    sp = {'dur': per, 'offs': o, 'root': [(t, (0, bob * v, 0)) for t, v in cyc(1, per / 2, 0.25, n=8, cycles=2)]}
    if base: sp.update(base)
    return sp

def biped(cfg, attack_arm='armR', run_from=None, special=None):
    """Melee biped: overhand strike, recoil, two-handed overhead slam/cast."""
    clips = {
        'Attack': {'dur': A, 'offs': {
            'spine': [('x', atk(-14, 26))], 'head': [('x', atk(-8, 14))],
            attack_arm: [('x', atk(-125, 25))], 'fore' + attack_arm[-1]: [('x', atk(-40, 0))],
        }, 'root': k((0, (0, 0, 0)), (a_w, (0, 0, -0.03)), (a_s, (0, -0.04, 0.12)), (0.42, (0, -0.03, 0.1)), (A, (0, 0, 0)))},
        'Hit': {'dur': HT, 'offs': {
            'spine': [('x', hit(-18))], 'head': [('x', hit(-22)), ('y', hit(10))],
            'armL': [('z', hit(25))], 'armR': [('z', hit(25))],
        }, 'root': k((0, (0, 0, 0)), (0.07, (0, -0.02, -0.07)), (HT, (0, 0, 0)))},
        'Special': special or {'dur': S, 'offs': {
            'spine': [('x', spc(-22, 34))], 'head': [('x', spc(-18, 20))],
            'armL': [('x', spc(-150, 10)), ('z', spc(10, 20))], 'armR': [('x', spc(-150, 10)), ('z', spc(10, 20))],
        }, 'root': k((0, (0, 0, 0)), (s_w, (0, 0.03, -0.04)), (s_s, (0, -0.08, 0.06)), (0.62, (0, -0.07, 0.05)), (S, (0, 0, 0)))},
    }
    if run_from:
        clips['Run'] = {'dur': run_from[1], 'base': run_from[0], 'speed': run_from[2],
                        'offs': {'spine': [('x', k((0, 14), (run_from[1], 14)))], 'head': [('x', k((0, -8), (run_from[1], -8)))]}}
    cfg['clips'] = clips
    return cfg

def flyer(cfg, fly_clip, wing=45, special=None):
    """Winged: rear up with wings raised, then a diving snap / bite."""
    cfg['clips'] = {
        'Attack': {'dur': A, 'base': fly_clip, 'offs': {
            'spine': [('x', atk(-22, 24))], 'head': [('x', atk(-26, 34))], 'jaw': [('x', atk(10, 32))],
            'wingL': [('z', atk(wing, -wing * 0.6))], 'wingR': [('z', atk(wing, -wing * 0.6))],
        }, 'root': k((0, (0, 0, 0)), (a_w, (0, 0.08, -0.05)), (a_s, (0, -0.1, 0.22)), (0.42, (0, -0.08, 0.18)), (A, (0, 0, 0)))},
        'Hit': {'dur': HT, 'base': fly_clip, 'offs': {
            'spine': [('x', hit(-20))], 'head': [('x', hit(-28))],
            'wingL': [('z', hit(30))], 'wingR': [('z', hit(30))],
        }, 'root': k((0, (0, 0, 0)), (0.07, (0, 0.04, -0.1)), (HT, (0, 0, 0)))},
        'Special': special or {'dur': S, 'base': fly_clip, 'offs': {
            'spine': [('x', spc(-30, 18))], 'head': [('x', spc(-40, 30))], 'jaw': [('x', spc(8, 45, 0.7))],
            'wingL': [('z', spc(wing * 1.2, -wing * 0.4))], 'wingR': [('z', spc(wing * 1.2, -wing * 0.4))],
        }, 'root': k((0, (0, 0, 0)), (s_w, (0, 0.12, -0.08)), (s_s, (0, -0.02, 0.1)), (0.7, (0, -0.02, 0.08)), (S, (0, 0, 0)))},
    }
    return cfg

MODELS = {
    'bonelet': biped({'file': 'skeleton', 'idle': 'Idle', 'root': '_rootJoint', 'roles': {
        'spine': r'Bip01_Spine\d?_01[1-4]', 'head': r'Bip01_(Neck1|Head1)_01[56]',
        'armL': r'Bip01_L_UpperArm_019', 'armR': r'Bip01_R_UpperArm_043', 'foreR': r'Bip01_R_Forearm_044'}},
        run_from=('Walk', 3.33 / 1.7, 1.7)),
    'hexling': biped({'file': 'lich', 'idle': 'Idle', 'root': 'Hip_01', 'roles': {
        'spine': r'Spine[123]_0[234]', 'head': r'(Neck1_05|Head_06)', 'jaw': r'Jaw_024',
        'armL': r'Shoulder_Left_026', 'armR': r'Shoulder_Right_038', 'foreR': r'Elbow_Right_039'}}),
    'acolyte': biped({'file': 'plague', 'idle': 'Idle', 'root': 'b_Pelvis_03', 'roles': {
        'spine': r'b_(Belly_010|Chest_011)', 'head': r'b_(Neck_012|Face_013)',
        'armL': r'b_Arm_Upper_Left_015', 'foreL': r'b_Arm_Lower_Left_016', 'armR': r'b_Arm_Upper_Right_023', 'foreR': r'b_Arm_Lower_Right_024'}},
        attack_arm='armL', run_from=('Walk', 3.33 / 1.7, 1.7)),
    'shade': biped({'file': 'wraith', 'idle': 'Idle', 'root': 'Spine3_01', 'roles': {
        'spine': r'Spine[12]_0[56]', 'head': r'(Neck_07|Head_08)',
        'armL': r'Forearm\.l_042', 'armR': r'Forearm\.r_059', 'foreR': r'Arm\.r_060'}},
        run_from=('Walk', 3.33 / 1.8, 1.8)),
    'sapling': biped({'file': 'treant', 'idle': 'Idle', 'root': '_rootJoint', 'roles': {
        'spine': r'Root\.00[12]_0[23]', 'head': r'Head_04', 'jaw': r'Jaw_05',
        'armL': r'Arm1_L_08', 'armR': r'Arm1_R_022', 'foreR': r'Arm2_R_023'}}),
    'barrow_squire': biped({'file': 'squire', 'idle': 'Idle', 'root': '_rootJoint',
        'link': {'spine': ['spine2']}, 'roles': {
        'spine2': r'spine_fk\.00[23]_(00|0104)',
        'spine': r'DEF-spine\.00[234]_0[789]', 'head': r'DEF-spine\.00[56]_01[01]',
        'armL': r'DEF-upper_arm\.L_0176', 'armR': r'DEF-upper_arm\.R_0241', 'foreR': r'DEF-forearm\.R_0243'}}),
    'wisp': flyer({'file': 'mawko', 'idle': 'Idle', 'root': 'Mawko_Rig_00', 'roles': {
        'spine': r'Spine[123]_0[345]', 'head': r'Mawko_Rig_00', 'jaw': r'Jaw_030',
        'wingL': r'Fin1_Left_026', 'wingR': r'Fin1_Right_028'}}, 'Idle', wing=30),
    'drake': flyer({'file': 'dragon', 'idle': 'Flying_Idle', 'root': r'root.4_4', 'roles': {
        'spine': r'spine_0[5-8]\.\d+_\d+', 'head': r'(neck_0[6-9]|neck_1[01])\.\d+_\d+', 'jaw': r'jaw_01\.26_26',
        'wingL': r'l_shoulder\.73_73', 'wingR': r'r_shoulder\.114_114'}}, 'Flying_Idle', wing=40),
    'crow': flyer({'file': 'crow', 'idle': 'Idle', 'root': 'CROW_ Pelvis_02', 'roles': {
        'spine': r'CROW_ Spine_03', 'head': r'CROW_ (Neck_04|Head_05)', 'jaw': r'CROW_ Head_05',
        'wingL': r'CROW_ L UpperArm_08', 'wingR': r'CROW_ R UpperArm_020'}}, 'Idle', wing=55),
    'bat': flyer({'file': 'bat', 'idle': 'Bat_Flying', 'root': 'Hip_00', 'roles': {
        'spine': r'(Tammy_01|Chest_02)', 'head': r'(Neck_03|Haed_04)', 'jaw': r'Haed_04',
        'wingL': r'Clavicle_L_012', 'wingR': r'Clavicle_R_018'}}, 'Bat_Flying', wing=35),
    'mimic': {'file': 'mimic', 'idle': 'Idle', 'root': 'RootNode', 'roles': {
        'lid': r'polySurface67', 'body': r'side5'}},
}
# Bat: a calmer hover so standing still isn't full flapping (60% toward rest, 0.7x).
MODELS['bat']['clips']['Hover'] = {'dur': 2.25 / 0.7, 'base': 'Bat_Flying', 'speed': 0.7, 'calm': 0.55}
# Crow only flies when moving; its attack/hit/special happen grounded, wings half-open.
# Mimic: lid slams shut and the chest jolts back (Hit); a lunging double snap (Special).
MODELS['mimic']['clips'] = {
    'Hit': {'dur': HT, 'offs': {'lid': [('x', hit(8))], 'body': [('x', hit(-10))]},
            'root': k((0, (0, 0, 0)), (0.07, (0, 0.04, -0.08)), (HT, (0, 0, 0)))},
    'Special': {'dur': S, 'offs': {
        'lid': [('x', k((0, 0), (0.22, -55), (0.3, 5), (0.42, -45), (0.5, 5), (0.7, -10), (S, 0)))],
        'body': [('x', k((0, 0), (s_w, -12), (s_s, 14), (0.62, 10), (S, 0)))]},
        'root': k((0, (0, 0, 0)), (s_w, (0, 0.06, -0.05)), (s_s, (0, 0, 0.2)), (0.62, (0, 0, 0.16)), (S, (0, 0, 0)))},
}
# Squire ships Punch (mapped as attack); keep it, add a shield-bash Special built on it.
del MODELS['barrow_squire']['clips']['Attack']
MODELS['barrow_squire']['clips']['Special'] = {'dur': S, 'base': 'Punch', 'speed': 1.21 / S, 'offs': {
    'spine': [('x', spc(-16, 24))], 'head': [('x', spc(-6, 10))], 'armL': [('x', spc(-30, -80))]},
    'root': k((0, (0, 0, 0)), (s_w, (0, 0, -0.06)), (s_s, (0, -0.03, 0.22)), (0.62, (0, -0.02, 0.18)), (S, (0, 0, 0)))}

# Wisp (Mawko): head-first serpent rig (Neck is the chain root), so the head
# strikes by pitching Neck while Spine1 counter-rotates to keep the body level;
# the tail whips through. Clips sit on its own Idle so the lanterns keep swaying.
def wisp_clips():
    tail = r'Tail[1-4]_0(07|08|09|10)'
    return {
        'Attack': {'dur': A, 'offs': {
            'neck': [('x', atk(-30, 26))], 'body': [('x', atk(26, -20))], 'jaw': [('x', atk(6, 38))],
            'tail': [('x', atk(-20, 30))], 'finL': [('z', atk(30, -15))], 'finR': [('z', atk(30, -15))]},
            'root': k((0, (0, 0, 0)), (a_w, (0, 0.06, -0.1)), (a_s, (0, -0.06, 0.3)), (0.42, (0, -0.05, 0.25)), (A, (0, 0, 0)))},
        'Hit': {'dur': HT, 'offs': {
            'neck': [('x', hit(-25)), ('y', hit(14))], 'body': [('x', hit(15))], 'tail': [('y', hit(-25))],
            'finL': [('z', hit(25))], 'finR': [('z', hit(25))]},
            'root': k((0, (0, 0, 0)), (0.07, (0, 0.03, -0.14)), (HT, (0, 0, 0)))},
        'Special': {'dur': S, 'offs': {
            'neck': [('x', spc(-45, -20))], 'body': [('x', spc(30, 12))], 'jaw': [('x', spc(10, 45, 0.7))],
            'tail': [('x', spc(-25, -10)), ('y', k((0, 0), (0.3, 20), (0.5, -20), (0.7, 12), (S, 0)))],
            'finL': [('z', spc(45, 55))], 'finR': [('z', spc(45, 55))]},
            'root': k((0, (0, 0, 0)), (s_w, (0, 0.18, -0.05)), (s_s, (0, 0.22, 0)), (0.7, (0, 0.18, 0)), (S, (0, 0, 0)))},
    }
MODELS['wisp'] = {'file': 'mawko', 'idle': 'Idle', 'root': 'Mawko_Rig_00', 'roles': {
    'neck': r'Neck_01', 'body': r'Spine1_03', 'jaw': r'Jaw_030', 'tail': r'Tail[1-4]_0\d+',
    'finL': r'Fin1_Left_026', 'finR': r'Fin1_Right_028'}, 'clips': wisp_clips()}

# Six of the Sketchfab files ship one take that the wrap tool split into
# identical Idle and Walk copies, so they never actually walk. Bonelet's take
# also folds into a heap at 1.0-1.6 s (the source's death pose) every loop.
# Idle and Walk stay as shipped; the map points at these clean loops instead.
LEGS = {
    'bonelet': {'thighL': r'Bip01_L_Thigh_02', 'thighR': r'Bip01_R_Thigh_07', 'calfL': r'Bip01_L_Calf_03', 'calfR': r'Bip01_R_Calf_00'},
    'acolyte': {'thighL': r'b_Leg_Left_Upper_04', 'thighR': r'b_Leg_rIGHT_Upper_07', 'calfL': r'b_Leg_Left_Lower_05', 'calfR': r'b_Leg_Right_Lower_08'},
    # treant: four root-legs, moved in diagonal pairs (front-left with back-right)
    'sapling': {'thighL': r'(Leg_L_036|BackLeg_R_044)', 'thighR': r'(Leg_R_042|BackLeg_L_038)',
                'calfL': r'(Foot_L_037|BackFoot_R_045)', 'calfR': r'(Foot_R_043|BackFoot_L_039)'},
}
for kk, legs in LEGS.items():
    MODELS[kk]['roles'].update(legs)
MODELS['bonelet']['base_pp'] = (0.0, 0.8, 1.6)
MODELS['bonelet']['clips']['Idle_Loop'] = {'dur': 1.6}
MODELS['bonelet']['clips']['Walk_Loop'] = gait(1.0, 24, 40, 20, 6, -0.025)
MODELS['bonelet']['clips']['Run'] = gait(0.6, 36, 70, 32, 16, -0.04)
MODELS['acolyte']['clips']['Walk_Loop'] = gait(1.1, 20, 35, 0, 5, -0.02)
MODELS['acolyte']['clips']['Run'] = gait(0.66, 30, 60, 0, 14, -0.035)
MODELS['sapling']['clips']['Walk_Loop'] = gait(1.0, 18, 18, 14, 4, -0.02)
# Shade floats: its Walk is its own; Run is the Walk, quicker and leaning in.
MODELS['sapling']['flat'] = ('thighL', 'thighR', 'calfL', 'calfR')
# Wisp: its 7.7 s take loops slowly at phone size; a 3 s ping-pong of the first 1.5 s.
MODELS['wisp']['clips']['Idle_Loop'] = {'dur': 3.0, 'pp': (0.0, 1.5, 3.0)}
