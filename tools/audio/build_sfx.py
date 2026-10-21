"""Build the shipped audio from licensed sources.

Sources (all downloaded to SRC; see CREDITS.md for each licence):
  Kenney audio packs (CC0): impact-sounds, interface-sounds, ui-audio,
    rpg-audio, casino-audio, music-jingles.
  OpenGameArt (CC0): rubberduck "80 CC0 RPG SFX", "80 CC0 creature SFX",
    "100 CC0 SFX", "100 CC0 SFX #2"; trazzz123 "CC0 Deep Monster Roar";
    Darsycho "Monster snarls"; cynicmusic "Victory Fanfare Short".
  Kevin MacLeod / incompetech (CC-BY 4.0): Achaidh Cheide, Heroic Age,
    Five Armies.

Every variant is mono 44.1 kHz OGG, leading silence trimmed, short fade-out,
peak-normalised to -1 dBFS; layered events are mixed here so the game plays
one stream per hit. Music is stereo OGG (q1, ~80 kbps), loudness-matched.
The moments the packs do not cover (a melee arc, a dash, a splash, gear
hitting the ground) are drawn from scratch by tools/build_sfx_synth.py,
which needs no source pack and is run from here so a full rebuild keeps
them.
usage: python3 tools/build_sfx.py [SRC]
"""
import glob, os, subprocess, sys, json

import build_sfx_synth

SRC = sys.argv[1] if len(sys.argv) > 1 else "/workspace/assets_dl/audio"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/audio/sfx")
MUS = os.path.join(ROOT, "assets/audio/music")


def find(name):
    hits = glob.glob(os.path.join(SRC, "**", name), recursive=True)
    if not hits:
        raise SystemExit("missing source " + name)
    return sorted(hits)[0]


# event -> list of variants; each variant is a list of layers
# (file, gain_db, pitch_ratio, delay_ms). Layers are mixed into one clip.
def v(*layers):
    return [l if isinstance(l, tuple) else (l, 0.0, 1.0, 0) for l in layers]


SFX = {
    # UI
    "ui_tap": [v(("click1.ogg", 0, 1.0, 0), ("click_002.ogg", -8, 1.0, 0)), v(("click2.ogg", 0, 1.0, 0), ("click_003.ogg", -8, 1.0, 0))],
    "ui_press": [v(("click3.ogg", 0, 1.0, 0), ("select_002.ogg", -4, 1.0, 0), ("impactWood_light_000.ogg", -10, 1.4, 0)),
                 v(("click3.ogg", 0, 0.95, 0), ("select_003.ogg", -4, 1.0, 0), ("impactWood_light_002.ogg", -10, 1.4, 0))],
    "ui_back": [v("back_002.ogg")],
    "ui_error": [v("error_006.ogg")],
    "ui_toggle": [v("switch_002.ogg")],
    # Hero attacks per role
    "atk_mage": [v(("spell_fire_01.ogg", 0, 1.0, 0), ("sfx100v2_air_01.ogg", -8, 1.2, 0)),
                 v(("spell_fire_03.ogg", 0, 1.0, 0), ("sfx100v2_air_02.ogg", -8, 1.2, 0)),
                 v(("spell_fire_05.ogg", 0, 1.0, 0), ("sfx100v2_air_03.ogg", -8, 1.2, 0))],
    "atk_archer": [v(("sfx100v2_air_01.ogg", 0, 1.35, 0), ("drawKnife1.ogg", -6, 1.2, 0)),
                   v(("sfx100v2_air_02.ogg", 0, 1.35, 0), ("drawKnife2.ogg", -6, 1.2, 0)),
                   v(("sfx100v2_air_03.ogg", 0, 1.35, 0), ("drawKnife3.ogg", -6, 1.2, 0))],
    "atk_tank": [v(("impactPunch_heavy_000.ogg", 0, 0.9, 0), ("impactWood_heavy_000.ogg", -6, 1.0, 0)),
                 v(("impactPunch_heavy_002.ogg", 0, 0.9, 0), ("impactWood_heavy_002.ogg", -6, 1.0, 0))],
    "atk_enemy": [v(("spit_01.ogg", 0, 1.2, 0)), v(("spit_02.ogg", 0, 1.2, 0)), v(("spit_03.ogg", 0, 1.2, 0))],
    # Hits
    "hit": [v(("impactPunch_medium_000.ogg", 0, 1.0, 0), ("impactSoft_medium_000.ogg", -6, 1.0, 0)),
            v(("impactPunch_medium_001.ogg", 0, 1.0, 0), ("impactSoft_medium_001.ogg", -6, 1.0, 0)),
            v(("impactPunch_medium_002.ogg", 0, 1.0, 0), ("impactSoft_medium_002.ogg", -6, 1.0, 0)),
            v(("impactPunch_medium_003.ogg", 0, 1.0, 0), ("impactSoft_medium_003.ogg", -6, 1.0, 0))],
    "crit": [v(("impactPunch_heavy_001.ogg", 0, 1.0, 0), ("impactMetal_light_000.ogg", -4, 1.3, 0), ("impactGlass_light_001.ogg", -10, 1.0, 20)),
             v(("impactPunch_heavy_003.ogg", 0, 1.0, 0), ("impactMetal_light_002.ogg", -4, 1.3, 0), ("impactGlass_light_003.ogg", -10, 1.0, 20))],
    "hero_hurt": [v(("hurt_01.ogg", -2, 1.25, 0), ("impactSoft_heavy_000.ogg", -2, 1.0, 0)),
                  v(("hurt_03.ogg", -2, 1.25, 0), ("impactSoft_heavy_002.ogg", -2, 1.0, 0))],
    "enemy_die": [v(("cute_03.ogg", -3, 1.1, 0), ("plop_01.ogg", -4, 1.0, 40), ("impactSoft_medium_004.ogg", -6, 0.9, 0)),
                  v(("cute_05.ogg", -3, 1.1, 0), ("plop_02.ogg", -4, 1.0, 40), ("impactSoft_medium_002.ogg", -6, 0.9, 0)),
                  v(("cute_07.ogg", -3, 1.1, 0), ("plop_01.ogg", -4, 1.1, 40), ("impactSoft_medium_000.ogg", -6, 0.9, 0))],
    # Boss
    "boss_roar": [v(("monster_roar.wav", 0, 1.15, 0), ("creature_roar_01.ogg", -6, 1.0, 120))],
    "boss_windup": [v(("monster-snarl-attack.ogg", 0, 1.0, 0)), v(("creature_monster_02.ogg", 0, 1.0, 0))],
    "boss_slam": [v(("slam_02.ogg", 0, 0.85, 0), ("impactPunch_heavy_004.ogg", -2, 0.7, 0), ("sfx100v2_stones_01.ogg", -6, 1.0, 30))],
    "boss_hit": [v(("impactPunch_heavy_000.ogg", 0, 0.8, 0), ("impactWood_heavy_001.ogg", -4, 0.8, 0)),
                 v(("impactPunch_heavy_002.ogg", 0, 0.8, 0), ("impactWood_heavy_003.ogg", -4, 0.8, 0))],
    "boss_die": [v(("creature_die_01.ogg", 0, 0.8, 0), ("slam_05.ogg", -4, 0.8, 300), ("gong_02.ogg", -10, 1.0, 400))],
    # Loot and progress
    "gem": [v(("item_gem_02.ogg", -2, 1.0, 0))],
    "coin": [v("handleCoins.ogg"), v("handleCoins2.ogg")],
    "levelup": [v(("jingles_PIZZI02.ogg", 0, 1.0, 0), ("glass_002.ogg", -8, 1.0, 400), ("maximize_006.ogg", -6, 1.0, 0))],
    "card_pick": [v(("card-place-1.ogg", 0, 1.0, 0), ("confirmation_002.ogg", -6, 1.0, 40)), v(("card-place-3.ogg", 0, 1.0, 0), ("confirmation_002.ogg", -6, 1.05, 40))],
    "card_flip": [v("card-slide-1.ogg"), v("card-slide-3.ogg"), v("card-slide-5.ogg")],
    "chest_land": [v(("impactWood_heavy_004.ogg", 0, 0.9, 0), ("dropLeather.ogg", -6, 1.0, 0))],
    "chest_rattle": [v(("impactWood_light_001.ogg", -4, 1.0, 0), ("metalLatch.ogg", -6, 1.0, 30))],
    "chest_open": [v(("wooded_box_open.ogg", 0, 1.0, 0), ("handleCoins2.ogg", -4, 1.0, 180), ("creak1.ogg", -8, 1.0, 0))],
    "sparkle": [v(("glass_004.ogg", -2, 1.0, 0), ("glass_006.ogg", -4, 1.2, 90), ("bell_02.ogg", -10, 1.5, 160))],
    "rare_chime": [v(("bell_01.ogg", 0, 1.0, 0), ("glass_005.ogg", -4, 1.0, 120), ("maximize_008.ogg", -6, 1.0, 0))],
    "unlock_start": [v(("lock_02.ogg", 0, 1.0, 0), ("metalClick.ogg", -4, 1.0, 80))],
    # Stings (mono is fine at this length)
    "sting_victory": [v(("Heavy_ConceptB.wav", 0, 1.0, 0))],
    "sting_defeat": [v(("jingles_PIZZI01.ogg", 0, 0.8, 0), ("gong_02.ogg", -12, 0.8, 0))],
}
MAX_LEN = {"atk_mage": 0.85, "atk_archer": 0.6, "sting_victory": 8.0, "boss_roar": 2.6, "boss_die": 3.0, "sting_defeat": 3.0}

MUSIC = {
    "home": "km_Achaidh%20Cheide.mp3",
    "hunt": "km_Heroic%20Age.mp3",
    "boss": "km_Five%20Armies.mp3",
}


def layer_filter(i, gain, pitch, delay):
    f = "[%d:a]aformat=sample_rates=44100:channel_layouts=mono" % i
    if abs(pitch - 1.0) > 1e-3:
        f += ",asetrate=%d,aresample=44100" % int(44100 * pitch)
    f += ",silenceremove=start_periods=1:start_threshold=-50dB"
    if delay:
        f += ",adelay=%d" % delay
    f += ",volume=%.1fdB[l%d]" % (gain, i)
    return f


def peak(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True).stderr
    for line in out.splitlines():
        if "max_volume" in line:
            return float(line.split(":")[1].split()[0])
    return 0.0


def build_sfx():
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, "*.ogg")):
        os.remove(f)
    manifest = {}
    for name, variants in SFX.items():
        manifest[name] = len(variants)
        for k, layers in enumerate(variants):
            tmp = "/tmp/_sfx.wav"
            args = ["ffmpeg", "-y", "-loglevel", "error"]
            for (f, g, p, d) in layers:
                args += ["-i", find(f)]
            chains = [layer_filter(i, g, p, d) for i, (f, g, p, d) in enumerate(layers)]
            mix = "".join("[l%d]" % i for i in range(len(layers)))
            mx = MAX_LEN.get(name, 1.6)
            chains.append("%samix=inputs=%d:normalize=0:duration=longest,atrim=0:%.2f,afade=t=out:st=%.2f:d=0.12[o]" % (mix, len(layers), mx, max(0.0, mx - 0.12)))
            subprocess.run(args + ["-filter_complex", ";".join(chains), "-map", "[o]", tmp], check=True)
            # Trim the tail silence too, then normalise the peak to -1 dBFS.
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", "areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse", "/tmp/_sfx2.wav"], check=True)
            gain = -1.0 - peak("/tmp/_sfx2.wav")
            dst = os.path.join(OUT, "%s_%d.ogg" % (name, k + 1))
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/_sfx2.wav", "-af", "volume=%.2fdB" % gain, "-c:a", "libvorbis", "-q:a", "3", dst], check=True)
    # The moments the licensed packs do not cover are synthesized (no source
    # pack needed) and share the folder, the loader and the manifest.
    manifest.update(build_sfx_synth.render_all(OUT))
    # A script constant, not a JSON file: exports drop non-resource files.
    with open(os.path.join(ROOT, "scripts/sfx_manifest.gd"), "w") as fh:
        fh.write("class_name SfxManifest\nextends RefCounted\n\n## Generated by tools/build_sfx.py and tools/build_sfx_synth.py: variants per\n## effect event.\nconst COUNTS := {\n")
        for k in sorted(manifest):
            fh.write('\t"%s": %d,\n' % (k, manifest[k]))
        fh.write("}\n")
    print("sfx events", len(manifest), "clips", sum(manifest.values()))


def build_music():
    os.makedirs(MUS, exist_ok=True)
    for key, src in MUSIC.items():
        dst = os.path.join(MUS, key + ".ogg")
        # Loudness-matched so crossfades don't jump: -18 LUFS integrated.
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", find(src), "-af", "loudnorm=I=-18:TP=-1.5:LRA=11", "-ar", "44100", "-ac", "2", "-c:a", "libvorbis", "-q:a", "1", dst], check=True)
        print("music", key, os.path.getsize(dst) // 1024, "KB")


if __name__ == "__main__":
    build_sfx()
    build_music()
