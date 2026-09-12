# ManaNet — Art Direction Guide

**Version:** 2.0.0  
**Status:** LOCKED for sprite + icon generation (2026-09-12)  
**Consumers:** humans, coding agents, AGES `ArtDirectionManager` (first ~1000 chars are injected into gen prompts)

---

## AGENT LOCK (read this first)

Fantasy: **medieval weapon archetypes built as modern energy hardware** on a dark data-grid. Not castle TD. Not generic neon city. Not pixel art.

- Plasma **crossbow** (archer) fires plasma bolts, not wooden arrows.
- **Cannon** launches glowing futuristic bombs / plasma shells, not iron balls.
- **Tesla** is an Edgeworld-style industrial coil pylon (tall lattice, stacked rings, arcing sphere) — not a toy yellow ball, not Clash of Clans cute.
- Mage / frost / sniper are the same rule: recognizable old weapon or siege form, executed in steel + conduit + energy.

World sprites: **256px max edge, ¾ isometric, true alpha PNG, no navy plate, no display plinth, no baked motion streaks.** Display size is 40–64px. If a detail dies at 48px, delete it.

UI icons: **64×64 and 128×128, flat-iso crop of the weapon head, transparent, subject ≥80% of frame.**

Palette accents: cyan `#1EB0FF` allied, gold `#FFB400` power/credits, crimson `#FF3C3C` threat, yellow-white arcs for Tesla, violet for netrunner. Backdrop `#0A0F1C` is scene only — never baked into the sprite.

Forbidden: JPEG unit art, opaque cards, photoreal textures, 1024 gameplay files, full walk cycles, second palette, castle stone / wood bows / cartoon knights.

---

## 1. Visual Theme & Tone

ManaNet is a **network-defense command surface**. The player places weapon-nodes that look like historic arms upgraded into grid hardware.

| Layer | Intent |
|---|---|
| World | Dark obsidian grid, hex pads, circuit veins |
| Towers | One readable weapon silhouette + one energy accent |
| Enemies | Corrupted constructs / drones / mechs, not fantasy orcs |
| UI | Navy panels, gold CTA, cyan secondary (`GameTheme.gd`) |
| Lexicon | Credits, Integrity, Shards, Cyber-Deck, Patch (`BrandCopy.gd`) |

Identity lock (`docs/IDENTITY_AND_UX_DIRECTION.md`) stays: you defend a **data grid**, not a castle. Medieval is **form language only**.

---

## 2. Palette & Color Script

| Role | Name | Hex | Use |
|---|---|---|---|
| Allied energy | Cyan Glow | `#1EB0FF` | player conduits, sniper beam, shields |
| Power / CTA | Gold Core | `#FFB400` | credits, upgrades, gold trim |
| Threat | Crimson Surge | `#FF3C3C` | enemies, breach, swarm optics |
| Tesla arc | Volt White-Gold | `#FFE566` | lightning coil core only |
| Mage | Hyper Violet | `#A854F7` | netrunner crystal |
| Frost | Ice Cyan | `#3EE7FF` | thermal siphon |
| Archer | Plasma Lime | `#22C55E` | bow string / bolts |
| Cannon | Shell Orange | `#FF8C1A` | bomb / barrel glow |
| Backdrop | Obsidian | `#0A0F1C` | maps and UI chrome — not sprite fill |

Do not paint the whole tower in its accent. Chassis is cool grey steel. Accent is 10–20% of pixels and must survive a 48px shrink.

---

## 3. Perspective, Scale, Roles

- Playfield camera: top-down 2D with **¾ isometric** (about 15–25° foreshortening). Same camera for towers and enemies.
- **World sprite (`world_sprite`)**: 256×256 source canvas, subject packed in the middle 80%, pivot `[0.5, 0.78]` (feet / pad).
- **Boss sprite**: 384×384 source, display ≤64px.
- **UI icon (`ui_icon`)**: 64 and 128, weapon-head crop, no pad, no environment.
- **Projectile**: 16–32px glowing bolt / shell / arc knot, alpha.
- **Map background**: 1024 max, JPEG/WebP OK (no alpha required).

Current on-disk 1024 JPGs are **marketing / bestiary only**. Runtime must not point at them.

---

## 4. Silhouette, Outline, Lighting

- 50ms readability at 0.5× mobile zoom.
- World sprites: 2px source dark contour `#050810` (reads as 1px at display).
- Icons: no heavy black border.
- Key light: **top-left 45°**. Neon is self-illuminated.
- Ground contact: small circular/hex shadow **as a separate layer or baked under feet only**. No museum plinth, stairs, or grated stand.

---

## 5. Weapon bible (existing six)

| id | Player name | Medieval form | Modern execution | Accent | Must read at 48px |
|---|---|---|---|---|---|
| `archer` | Cyber-Ranger | Crossbow / arbalest | Plasma-string bow on a short bunker; bolts are energy | lime | bow limbs + glowing string |
| `cannon` | Plasma Artillery | Bombard / siege mortar | Short wide barrel launching luminous bombs | orange | barrel + loaded shell |
| `lightning` | Tesla Node | Wardenclyffe / coil | **Edgeworld Tesla**: tall industrial lattice, stacked copper rings, arcing sphere, blue-white forks | volt gold | sphere + coil stack |
| `mage` | Netrunner | Wizard staff / spire | Crystal focus on a thin pylon; runes are circuit traces | violet | crystal + ring |
| `frost` | Thermal Siphon | Ice staff / bombard | Cryo emitter, not a snow castle | ice cyan | emitter head + vapor |
| `sniper` | Sniper Proxy | Longbow / arbalest sight | Optic rail on a slim mast | cyan | scope + beam |

Tesla anti-reference: do not ship the current “yellow orb on a short toy tower” as the final look. Keep the orb, **grow the coil, add lattice legs and visible arcs**.

---

## 6. Production rules for agents (AGES-aligned)

AGES (`gthgomez/gamedev`) already provides:

- `art_direction` in `.agent-game/manifest.yaml`
- `AssetContract` YAML + `AssetValidator` (dims, alpha, format, grid)
- promotion governance (`allow_agent_asset_promotion: false` until a human unlocks it)
- first-1000-char guide injection + good/avoid reference folders

**Required loop for any new sprite:**

1. Read this file + `docs/SPRITE_AND_WEAPON_DIRECTION.md` + matching `assets/contracts/*.asset.yaml`.
2. Generate or export **PNG RGBA** only into a candidate folder (never overwrite `assets/sprites/` without promotion).
3. Validate against the contract (size, alpha, format). JPEG fails.
4. Drop a 48px thumbnail next to the file. If the weapon type is ambiguous, reject.
5. Wire runtime paths only after human + visual checkpoint (`visual_checkpoint_smoke`).

`asset_generation` is BLOCKED in the ManaNet AGES manifest. Agents plan and validate; they do not autonomously promote art.

---

## 7. Reference corpus

- Good: `art/references/good/` — keep `tower_archer_ref.png` as “readable weapon on a compact base.”
- Avoid: `art/references/avoid/` — noisy photo texture, low-contrast mush, navy cards.
- Add future refs: Edgeworld Tesla stills (coil lattice), one plasma-crossbow crop, one bomb-cannon crop.

---

## 8. Non-goals

Full reskin of every unit before cutouts ship. Pixel-art reboot. Animated sheets for every tower. Fire TV chrome. New towers solely to show art.
