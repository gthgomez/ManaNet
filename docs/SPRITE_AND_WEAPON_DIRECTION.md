# ManaNet — Sprite, Icon, and Weapon Direction

**Status:** PROPOSED LOCK — 2026-09-12  
**Owner:** ManaNet visual + content  
**Feeds:** `art/ART_DIRECTION.md`, AGES art_direction, agent startup  
**Does not change:** simulation balance unless a later WP explicitly adds a tower

---

## 1. What the docs already said (and did not say)

### Locked today

| Doc | What it locks |
|---|---|
| `docs/IDENTITY_AND_UX_DIRECTION.md` | Data-grid fantasy. Credits / Integrity / Shards / Cyber-Deck / Patch. **Not castle TD. Not generic neon.** Prefer cutout + tint over a full reskin. |
| `docs/theme_proposals.md` Direction B | Cyber-Arcana: smart-bow, netrunner, thermal siphon, server relay. Name seed **ManaNet**. |
| `data/tower_types.gd` | Display names: Cyber-Ranger, Netrunner, Plasma Artillery, Sniper Proxy, Thermal Siphon, Server Node. |
| `data/upgrade_paths.gd` | Flavor already uses **plasma bolts**, multi-bolts, **plasma shells**, stasis shells, coils, EMP. |
| `art/ART_DIRECTION.md` (v1) | Cyber grid, cyan/gold/crimson, 32px *pixel* sprites (this was wrong vs shipped art). |
| `docs/VISUAL_THEME_SPRITE_AUDIT.md` | Integration-first: cutouts, shop icons, bosses, wordmark. |

### Not locked — until this file

No ManaNet doc used the exact phrase **“medieval weapons with modern technology.”**  
That idea is **implied** by the plasma-bow illustration, “Plasma Artillery,” and Cyber-Arcana copy, but the identity doc still frames everything as network/software, and ART_DIRECTION v1 asked for pixel tiles.

**Decision this file proposes:** lock **weapon-form energy hardware**.

- Medieval = silhouette and role (bow, bombard, coil-spire, staff, long-shot).
- Modern = materials and ammunition (plasma, bombs, tesla arcs, data-virus).
- Setting stays the data grid. No stone keeps, no wooden bows, no knights.

That resolves the identity vs art clash without reopening theme A/C/D.

---

## 2. Current sprites — critique against that lock

Shipped files are 1024×1024 RGB JPEGs with navy plates. Concept quality is high. Gameplay fitness is low. Score is “key art,” not “sprite.”

| Asset | Fits weapon-tech lock? | Breaks gameplay spec? |
|---|---|---|
| Archer JPG | **Yes** — energy crossbow on a bunker | Navy card, 3-story base, unreadable at 48px |
| Cannon JPG | **Yes** — orange plasma barrel | Square pad, no visible *bomb* in the muzzle |
| Lightning JPG | Partial — orb + coil, but **toy-scale**, not Edgeworld industrial | Short, cute, yellow-on-yellow vs credits gold |
| Mage JPG | Staff-spire / crystal — acceptable | Too tall/skinny; runes die at 48px |
| Frost JPG | Emitter ok; ground ice is extra castle-ish | Steam will fail any chromakey |
| Sniper JPG | Rail + optic — good | Fine form, still a card |
| Grunt / tank / drone / swarm | Sci-fi constructs — correct enemy side | Plinths, baked speed lines, mixed cameras |
| Shop / HUD | — | Text-only; 1024 art unused |
| Bosses | — | **No art**; renderer falls back to grunt |

AGES already flags this: `heavy_brute.asset.yaml` requires alpha + 1024, but style fields are **deferred** and `asset_style_validation` is only PARTIAL. Structural validation would **fail every current tower JPG** on alpha + format if contracts were enforced.

---

## 3. AGES / gamedev system — how agents should work

Source of truth for the pipeline is `gthgomez/gamedev` (AGES v2), already mounted in ManaNet as `.agent-game/`.

| AGES piece | ManaNet hook | Agent rule |
|---|---|---|
| `art_direction.guide` | `art/ART_DIRECTION.md` | First ~1000 chars go into gen prompts. Keep the lock paragraph at the top. |
| `art_direction.profiles` | `.agent-game/manifest.yaml` | Use `world_sprite` (256, iso, alpha) and `ui_icon` (64, flat-iso, alpha). Do not use the old 32px `pixel_sprite` profile for towers. |
| `art/references/good` + `avoid` | hashed into `art_context_hash` | Drop one good crop per weapon family before generating more. |
| `AssetContract` YAML | `assets/contracts/` | One contract per runtime sprite. Validator checks dims, alpha, PNG, pivot. |
| `allow_agent_asset_promotion` | **false** | Agents may generate candidates. Humans promote into `assets/sprites/`. |
| `asset_generation` capability | **BLOCKED** | Do not claim an agent “shipped” a sprite because it wrote a file. |
| Visual gate | `visual_checkpoint_smoke` | Cutouts must show no navy plate on the 900×600 capture. |
| Trust boundary | `gamedev/docs/AGES_TRUST_BOUNDARIES.md` | Directional visual changes escalate to human review. |

### Agent startup addition

After `PROJECT_CONTEXT.md`, any agent that touches art must read:

1. `art/ART_DIRECTION.md`
2. this file
3. the relevant `assets/contracts/*.asset.yaml`
4. `.agent-game/manifest.yaml` → `art_direction` + `governance`

Then it may plan exports. It may not invent new tower *mechanics* (`AGENTS.md`). New weapons below are **roster proposals**, not code.

---

## 4. Target file layout

```
art/
  ART_DIRECTION.md              # prompt + human lock
  style_manifest.yaml
  references/good/
  references/avoid/
  source/                       # 1024 key art (not runtime)
assets/
  contracts/                    # AGES YAML
  sprites/towers/<id>.png       # 256 alpha world
  sprites/towers/<id>_icon.png  # 64/128
  sprites/enemies/<Type>.png
  sprites/bosses/<Type>.png
  sprites/ui/
```

Runtime maps in `rendering/GameRenderer.gd` must point at the PNG world files, not `*_tower_icon.jpg`.

---

## 5. World sprite + icon spec (acceptance)

**World sprite PASS if all of:**

- PNG RGBA, 256×256 (boss 384)
- No opaque full-frame background (alpha around subject)
- Subject bbox ≥ 55% of canvas
- Weapon type identifiable in a 48×48 downscale
- No plinth, stairs-as-architecture, motion streaks, or readable hull text
- 1px-at-display dark outline
- Pivot near feet (`[0.5, 0.78]`)

**Icon PASS if all of:**

- 64 and 128 PNG RGBA
- Crop of the weapon head / unique part
- Subject ≥ 80% of frame
- Accent color matches the tower table
- Readable as a shop tile next to a gold cost

**Tesla extra PASS:**

- Tall lattice or stacked rings visible at 48px
- Visible arc or sphere, not only a yellow ball
- Reads industrial (Edgeworld / Wardenclyffe), not toy

---

## 6. Existing six — rebuild brief

### Cyber-Ranger (`archer`) — plasma crossbow

Keep the current bow. Rebuild as a **short** bunker + oversized prod. String and bolt are lime plasma. No wooden limbs. Shop icon = bow only.

### Plasma Artillery (`cannon`) — futuristic bombard

Keep the wide orange barrel. Put a **visible bomb / shell** in or just leaving the muzzle (glowing orange-white lozenge with fins or a plasma core). Base is a compact hex pad, not a factory.

### Tesla Node (`lightning`) — Edgeworld coil

Reference: Kabam Edgeworld Tesla Tower (multi-target industrial defense coil), plus Wardenclyffe silhouette.

Must have:

- Vertical lattice / four legs or an open truss
- 2–4 copper rings or wrapped coils up the shaft
- A charged sphere or torus at the crown
- One or two drawn arcs (small, not a full lightning storm that fills the canvas)
- Cool steel chassis; volt-gold only on the charge path

Current sprite keeps the orb but loses the industrial height. That is the main Tesla rewrite.

### Netrunner (`mage`)

Crystal focus on a slim pylon. Circuit-rune traces, not stone gothic. Icon = crystal + ring.

### Thermal Siphon (`frost`)

Cryo nozzle / condenser. Ice is energy coolant, not a frozen keep. No ground crystal garden.

### Sniper Proxy (`sniper`)

Long optic rail. Icon = scope + beam tick.

---

## 7. Other weapons to add (content proposals)

Do **not** implement until Ship A cutouts + shop icons exist. Each proposal fills a hole the current six leave.

Role coverage now: ST (ranger), burst ST (sniper), splash (cannon), slow (frost), chain (tesla), burn/mark (mage). Missing: ground control / blockade, anti-air dedicated, support/buff, wall-adjacent trap, resource, true melee/hold.

| Proposed id | Medieval form | Modern execution | Role | Why it belongs |
|---|---|---|---|---|
| `ballista` | Siege ballista | Rail-spear that pins (root) flyers + ground | Anti-air + pin | Ranger is ST; nothing specializes vs drone |
| `trebuchet` | Trebuchet | Gravity-catapult that lobs delayed plasma charges over walls | Long-arc splash, slow projectile | Cannon is direct; this is lob / timing |
| `glaive` | Throwing glaive | Orbiting energy disc around the node | Point-defense / melee radius | Holds a chokepoint without a projectile pool |
| `pavise` | Shield wall | Hard-light pavise that tethers Integrity loss in a cone | Support / soak | No support tower exists |
| `halberd` | Halberd | Beam polearm that cleaves a short line along the path | Lane cleave | Different from tesla chain and cannon circle |
| `onager` | Onager / slung shot | Cluster bomblets (your “futuristic bombs” as a *family*, not a second cannon) | Multi-mini-splash | Only if cannon stays single-shell |
| `beacon` | Signal lantern / brazier | Uplink beacon that marks + reveals | Utility reveal | Sniper already reveals on-hit; this is aura |
| `scythe` | Scythe | Sweeping arc that executes low-Integrity targets | Execute / cleanup | Late-wave juice without new splash math |

**Recommended first add after the six are cut out:** `ballista` (anti-air hole) **or** `glaive` (melee hole). Not both in the same week.

**Do not add:** generic machine gun, generic missile silo, wizard-in-a-hat, wooden catapult, second Tesla.

Boss art (still missing, higher priority than new towers):

| Wave | Type | Weapon-tech read |
|---|---|---|
| 5 | BossShieldBrute | Pavise / tower-shield mech |
| 10 | BossSwarmCarrier | Hive-ballista / drone rack |
| 15 | BossRegenerator | Cracked coil-golem that re-arcs |

---

## 8. UI implication

Shop strip uses **icons**, not 1024 plates. Labels can stay code ids internally; player names come from `tower_types.gd`. If Tesla’s player name stays “Server Node,” consider renaming display to **Tesla Node** so the Edgeworld reference is explicit. That is BrandCopy / display only — not a sim change.

---

## 9. Work order

1. Lock this file + ART_DIRECTION v2 + contracts (this commit).
2. Re-export six world PNGs + six icons from existing key art (crop/cutout first; Tesla may need a new paint).
3. Retarget `GameRenderer` + shop buttons.
4. Three boss sprites.
5. Only then consider `ballista` or `glaive`.

Verification: S25 (or 900×600 checkpoint) — no navy plates, shop icons readable at arm’s length, W5 boss ≠ grunt, Tesla reads as a coil at 48px.
