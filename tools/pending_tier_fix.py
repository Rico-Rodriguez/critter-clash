"""Pending tier fixes (written, not applied yet).

Run:  python tools/pending_tier_fix.py

1. scripts/hunt_map.gd - a tier hunt starts at the gate node of its band,
   whatever kind that node is (the abyss band is the lair row, so the old
   "clearing only" lookup fell back to the world start).
2. scripts/run_screen.gd - a tier hunt that ends with the boss down clears
   that depth, which opens the gate into the one above it.

See .memory/topics/open-issues.md for the surrounding context.
"""

from pathlib import Path

root = Path(r'C:\Users\rico2\Projects\critter-clash')

# --- hunt_map: the entry for a tier, whatever kind of node it is ---------
p = root / 'scripts' / 'hunt_map.gd'
s = p.read_text(encoding='utf-8')
old = '''func entry_for_tier(tier_id: String) -> Vector2:
\tvar band := TierBounds.band_span(tier_id)
\tif band.is_empty():
\t\treturn start
\tvar row := int(band["to_row"])
\tfor n in nodes:
\t\tif int(n.get("row", -1)) == row and str(n.get("kind", "")) == "clearing":
\t\t\treturn n["pos"]
\treturn start'''
new = '''func entry_for_tier(tier_id: String) -> Vector2:
\tvar band := TierBounds.band_span(tier_id)
\tif band.is_empty():
\t\treturn start
\t# The band's southern edge: the row the hero walks in at. The node in
\t# that row is the gate itself, so the entry is where the band begins.
\tvar row := int(band["to_row"])
\tvar best := Vector2.INF
\tvar best_d := INF
\tfor n in nodes:
\t\tif int(n.get("row", -1)) != row:
\t\t\tcontinue
\t\tvar d: float = (n["pos"] as Vector2).distance_to(start)
\t\tif d < best_d:
\t\t\tbest_d = d
\t\t\tbest = n["pos"]
\treturn best if best_d < INF else start'''
assert old in s
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8', newline='')
print('hunt_map: tier entry takes the gate in the band')

# --- run_screen: a tier hunt won opens the gate above it -------------------
p = root / 'scripts' / 'run_screen.gd'
s = p.read_text(encoding='utf-8')
old = '''\t\t\t\t\tif daily_pass:
\t\t\t\t\t\tsummary = SaveGame.commit_daily_pass(biome_id, str(ev["id"]))
\t\t\t\t\telse:
\t\t\t\t\t\tsummary = SaveGame.commit_victory(biome_id, str(ev["id"]), sim.slain, sim.difficulty)'''
new = '''\t\t\t\t\tif daily_pass:
\t\t\t\t\t\tsummary = SaveGame.commit_daily_pass(biome_id, str(ev["id"]))
\t\t\t\t\telse:
\t\t\t\t\t\tsummary = SaveGame.commit_victory(biome_id, str(ev["id"]), sim.slain, sim.difficulty)
\t\t\t\t\t\t# A tier hunt clears that depth, which opens the gate
\t\t\t\t\t\t# into the one above it.
\t\t\t\t\t\tif tier_id != "":
\t\t\t\t\t\t\tSaveGame.clear_tier(tier_id)'''
assert old in s
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8', newline='')
print('run_screen: a cleared tier opens the gate above it')
