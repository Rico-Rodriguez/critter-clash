# Art options: grittier, realistic-proportion characters

Researched for plan task A.1. Only free options were considered; every license
was read from the pack's own page. I downloaded and inspected the Quaternius
packs (file lists, skeleton, clips, triangle counts); the rest are judged from
their pages and screenshots.

## The requirement

A real OSRS / Diablo knight: adult proportions, armor that reads as armor, a
dark dirty palette. Heroes (knight, ranger, mage, barbarian), a horde of
undead (40 on screen), and a boss. One shared skeleton so one animation set
drives everyone. Cheap enough for a phone.

## Verdict first

**No free pack covers the full cast in a realistic style.** Realistic free
characters exist for single roles (a ranger, a peasant), but nothing free and
safe to ship gives a knight, a mage, a barbarian *and* a horde on one rig.
The only way to get that look for the whole cast without paying is Mixamo
(see below), which has a license catch.

So the recommendation is a **two-step plan**:

1. **Grit pass on KayKit now** (recommended, done in A.2 below): head scaled
   down on the shared skeleton, darker desaturated palette, dirt and wear in
   the character shader. Costs nothing, keeps one rig and the full 100-clip
   animation set, and keeps 40 skeletons cheap.
2. **Swap individual heroes later** if a good free model turns up (the loader
   supports a per-hero `"pack"`).

## Candidates

| Pack | License | Cast | Look | Cost on a phone | Verdict |
| --- | --- | --- | --- | --- | --- |
| **KayKit** (current) | CC0 | all four heroes, 4 skeletons, weapons, props | chibi: big heads, toy palette | ~2–5k tris per character, 1 small texture | Keep; re-grade (see A.2) |
| [Quaternius Modular Character Outfits – Fantasy](https://quaternius.itch.io/modular-character-outfits-fantasy) | CC0 | **Free download = Ranger + Peasant only** (male and female; 4 outfits). The page advertises 12 outfits, but the Standard zip I downloaded holds just those four. | realistic adult proportions, PBR textures (base color, normal, ORM) | **~27k tris per character, 65 bones**: fine for one hero, too heavy for a horde | Good for the Ranger hero only |
| [Quaternius Universal Animation Library](https://quaternius.itch.io/universal-animation-library) | CC0 | 43 clips (idle, jog, roll, `Sword_Attack`, `Spell_Simple_*`, `Death01`, `Hit_*`, punches) on the same 65-bone rig as the Quaternius characters | – | 13.7k-tri reference mesh | Needed if the Quaternius Ranger is used; no bow or two-handed clips, so the Ranger's shooting would have to reuse `Pistol_*`/`Spell_*` or be hand-made |
| [Quaternius Universal Base Characters](https://quaternius.itch.io/universal-base-characters) | CC0 | 2 bare bodies + 5 hairstyles | realistic | – | Not useful without outfits |
| [Quaternius Bestiary – Dungeon Monsters Kit](https://quaternius.itch.io/bestiary-dungeon-monsters-kit) | CC0 | free tier: Imp and Pugline (3 colors each) | stylized monsters, T-pose | – | No skeletons; could add variety later |
| [Quaternius LowPoly Animated Knight](https://quaternius.itch.io/lowpoly-animated-knight) | CC0 | one knight | very simple, flat grey | tiny | Cuter than KayKit; no |
| [Quaternius LowPoly RPG Characters](https://opengameart.org/content/lowpoly-rpg-characters) | CC0 | wizard, warrior, rogue, monk, ranger (+1) | low-poly, rigged, not checked visually | small | Unchecked; likely the same chibi-ish look |
| [Fullplate Armor Knight](https://magicalgothgirrl.itch.io/fullplate-armor-knight) | CC0 | one knight (325 kB) | PSX; I looked at its screenshots: crude blocky mesh, simple rig, one walk cycle | tiny | Too crude |
| [PSX Dark Knights Pack](https://retro-spud.itch.io/psx-dark-knights-pack) | paid ($4.99) and tagged "AI Assisted" | 7 knights | PSX, 256² textures | tiny | Paid, and the user doesn't want AI-made meshes: skip |
| MCSTEEG PSX Dungeon packs | paid; license forbids redistribution as your own work | skeleton warrior etc. | PSX | tiny | Paid: skip |
| [Mixamo](https://www.mixamo.com) | Adobe terms: free to use in commercial games with an Adobe login; **raw character and animation files may not be redistributed** | realistic knight ("Paladin"), skeletons, zombies, brutes, mages and a huge animation library, all on one rig | realistic | 10–30k tris typical (needs decimating for hordes) | Best match for the look, but needs the user to download (login) and a **private repo** |

## Mixamo, if the user wants the real thing

- The user downloads the characters and animations themselves (it needs an
  Adobe login; I can't do it from a build session), as FBX with skin, then
  drops them in a folder.
- Adobe's rule (from the Mixamo FAQ as quoted on the Adobe forums): you may use
  them in a released game, but not distribute the raw files. A **public**
  GitHub repo containing the FBX files would break that. Keep the repo
  private, or keep the Mixamo files out of git (add to `.gitignore`, document
  how to fetch them) and let CI download nothing. The shipped IPA bakes them
  into the game package, which is allowed.
- Decimate each character to ≤ 8k tris and use a 512² texture. Enemies need
  2–4k.
- A shared skeleton (Mixamo's) means all characters take all animations.

## Recommendation and next step

1. **Do the grit pass on KayKit (A.2).** Show before/after to the user.
2. If the user wants more than that, they choose between:
   - **Quaternius Ranger** for the Ranger hero only (realistic archer; ~27k tris
     is fine for one on-screen character), animated with the UAL clips, or
   - **Mixamo** for everything (the full realistic look; needs the steps above).
3. A.3 (convert everything) only happens after the user picks 2.
