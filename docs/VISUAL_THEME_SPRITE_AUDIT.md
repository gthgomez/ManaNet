# ManaNet — Visual / Theme / Sprite Audit

**Status:** DRAFT — source of truth for visual roadmap planning (not yet locked)  
**Date:** 2026-07-19  
**Device context:** Samsung S25 Ultra (wireless debug; landscape)  
**Program:** Ship A · `../SHIP_PROGRAM_90_DAY.md`  
**Related authority:**

| Doc | Role |
|-----|------|
| `docs/IDENTITY_AND_UX_DIRECTION.md` | **LOCKED** fantasy, lexicon, palette direction |
| `docs/theme_proposals.md` | Historical theme options (A–D); do not reopen without explicit decision |
| `docs/ui_playability/*` | Layout/playability rules; mobile fit (P0/P1 layout landed in code) |
| `docs/DEVICE_SESSION_SCORECARD.md` | Device scoring template (fill during QA) |
| `IMPROVEMENT_PLAN.md` | Mechanics/UX backlog (boss feel, Cannon, variants) |
| This file | Visual integration audit + open questions + roadmap seed |

**Code anchors:**

- Theme: `ui/theme/GameTheme.gd`, `ui/theme/BrandCopy.gd`
- Render: `rendering/GameRenderer.gd`
- HUD: `scenes/GameScreen.gd`
- Assets: `assets/sprites/**`, `assets/shaders/**`, `assets/sfx/**`

---

## 1. Purpose of this document

Use this file to:

1. Record **current visual reality** (what ships on device today).
2. Separate **strong art** from **weak integration**.
3. Capture **open questions** that block or shape an implementation roadmap.
4. Feed a later **implementation roadmap** (phased work packages with owners, acceptance criteria, and evidence).

**This is not yet a roadmap.** Section 8 is a proposed structure to turn decisions into one.

When a decision is made, move it from §7 Open Questions → §6 Decisions Log, then break work into roadmap items.

---

## 2. Executive summary

| Verdict | Detail |
|---------|--------|
| **Art quality** | Strong isometric cyber-mech towers/enemies/maps — store-tier look at full resolution |
| **In-game presentation** | Weak on phone: opaque JPG quads, text-only shop, boss fallback art, placeholder SFX |
| **Theme system** | Coherent navy/gold/cyan UI tokens; glass/sweep shaders **off on Android** (`gl_compatibility`) |
| **Identity** | Lexicon locked (ManaNet / Patches / Credits / Integrity); **logo still says “Tactical Tower Defense”** |
| **Best ROI** | Cutouts + shop icons + boss sprites + wordmark + texture pipeline — **not** a full reskin |

Identity direction already says: *prefer cutout + unified tint; no full reskin until device scores demand it.* This audit agrees.

---

## 3. What’s working

| Area | Strength |
|------|----------|
| Tower / enemy concept art | High-quality isometric cyber style (e.g. archer tower, grunt mech) |
| Map backgrounds | Dark grid / hex / circuit language fits “data grid” fantasy |
| UI theme tokens | `GameTheme.gd`: navy panels, gold primary CTA, cyan secondary, crimson danger, violet milestones |
| Player lexicon | `BrandCopy.gd` + identity doc: Credits, Integrity, Patches, Cyber-Deck, Shards |
| Render architecture | MultiMesh batching is correct for mobile unit density |
| Juice wiring | `JuiceManager` + SFX paths exist; easy to replace placeholders |
| Layout (recent) | P0/P1 modal/safe-area work in `ResponsiveLayout.gd` + `GameScreen.gd` (wave shop / placement fit) |

---

## 4. Critical integration gaps (ship-visible)

### 4.1 Sprites are full-bleed JPGs, not game cutouts

| Fact | Evidence |
|------|----------|
| Towers/enemies are large JPGs (~0.5–1.3 MB) with **solid navy backgrounds** | `assets/sprites/towers/*_tower_icon.jpg`, `assets/sprites/enemies/*.jpg` |
| Drawn as MultiMesh quads | `GameRenderer.gd` `TOWER_SPRITE_PATHS` / `ENEMY_SPRITE_PATHS` |
| Chromakey cutout exists | `assets/shaders/tower_cutout.gdshader` |
| Android disables most visual shaders | `GameTheme.shader_effects_enabled()` returns false when `android` + `gl_compatibility` |
| Project mobile renderer | `project.godot` → `renderer/rendering_method.mobile="gl_compatibility"` |

**Player impact:** Units look like framed cards, not entities on the map — especially on the S25 Ultra build.

**Direction (proposed):** True alpha PNG/WebP **or** mobile-safe cutout that always runs on Android even when glass/fidelity is off.

### 4.2 Bosses have no dedicated art path

| Fact | Evidence |
|------|----------|
| Boss classes set unique `type_name` | `Enemy.BossShieldBrute` → `"BossShieldBrute"`, etc. |
| MultiMesh only knows 6 base types | `ENEMY_TYPE_ORDER` — no boss keys |
| Unknown types fall back to index 0 | `ENEMY_TYPE_ORDER.find(...)` → `idx = 0` → grunt sprite |

**Player impact:** Boss waves (W5/10/15) are the emotional peak; silhouette is wrong or generic.

### 4.3 Brand mismatch on title screen

| Fact | Evidence |
|------|----------|
| Menu uses logo texture | `MenuScreen.gd` → `assets/sprites/ui/title_logo.png` |
| Logo text | **“TACTICAL TOWER DEFENSE”** |
| Product / package | **ManaNet** (`com.mananet.godottd`) |

**Player impact:** First 3 seconds read as generic TD, not ManaNet.

### 4.4 Shop strip is text-only

| Fact | Evidence |
|------|----------|
| Shop buttons: name + cost labels only | `GameScreen.gd` shop build loop |
| Full tower icons already on disk | `assets/sprites/towers/*_tower_icon.jpg` |
| Variant icons exist but unused at runtime | e.g. `archer_veteran_icon.jpg` — MultiMesh uses base only + tint |

**Player impact:** Strip feels like a prototype despite premium source art.

### 4.5 Audio is placeholder

| Fact | Evidence |
|------|----------|
| SFX are procedural sine tones | `assets/sfx/README.md` |
| Wired to JuiceManager | `feedback/JuiceManager.gd` |

**Player impact:** Premium art + toy audio = “unfinished.”

### 4.6 Asset weight vs on-screen size

| Fact | Evidence |
|------|----------|
| ~21 MB jpg/png under `assets/` | Inventory 2026-07-19 |
| Units drawn ~40–64 px in 900×600 world | `GameRenderer` scale from radius |
| Import: no size limit, compress mode 0, no mipmaps | e.g. `archer_tower_icon.jpg.import` |

**Player impact:** Memory, APK size, decode cost on mobile for little on-screen fidelity.

---

## 5. Scorecards

### 5.1 Sprite system

| Asset class | Form | In-game use | Grade | Issue |
|-------------|------|-------------|-------|-------|
| Tower JPGs | 6 base + 6 variants | MultiMesh | B art / D integration | Opaque BG, huge files, variants not swapped |
| Tower SVGs | 6 tiny placeholders | **Unused** | F | Dead assets — delete or repurpose as HUD glyphs |
| Enemies | 5 JPG + 1 PNG | MultiMesh | B / C | Same BG problem |
| Bosses | **0 dedicated sprites** | Fallback / tint / pips | F | Highest moment underserved |
| Maps | 3 JPG | Background | B | Good mood; no per-map accent; heavy files |
| UI logo | 1 PNG ~1.3 MB | Menu | C | Wrong product name |
| Icons / splash | Several ~1–2 MB | Store / splash | B | Overweight |
| SFX | 12 tiny oggs | JuiceManager | D | Placeholder tones |

### 5.2 Theme / presentation system

| Layer | Grade | Notes |
|-------|-------|-------|
| Palette tokens | A− | Clear, mobile-readable |
| Button / panel styles | B+ | Solid; glass/sweep off on Android |
| Typography | C+ | Default Godot fonts; no brand typeface |
| HUD information design | B− | Functional; shop/icons weak |
| Fantasy ↔ cyber merge | C | Art is cyber; names/logo still hybrid |
| Signature VFX | D | Identity allows one boss packet/glitch flash — not done |

### 5.3 Identity residue (vs locked doc)

| Residue | Example | Severity |
|---------|---------|----------|
| Fantasy unit names | Archer, Mage, Frost | Medium (art is cyber) |
| Old product title in art | “Tactical Tower Defense” | High (first impression) |
| Theme proposal still “open” historically | Magitech vs Cyber-Arcana vs Sim | Process — should stay closed on Cyber/ManaNet unless reopen is deliberate |
| Shader dual-path | Desktop pretty / Android flat | High for visual ship claims |

---

## 6. Decisions log

Record binding choices here so the roadmap does not re-litigate them.

| ID | Decision | Status | Date | Notes |
|----|----------|--------|------|-------|
| D0 | Identity fantasy + lexicon | **LOCKED** | 2026-07-19 | See `IDENTITY_AND_UX_DIRECTION.md` |
| D1 | Full reskin vs integration-first | **PROPOSED: integration-first** | 2026-07-19 | This audit; confirm before roadmap lock |
| D2 | Theme family (A Magitech / B Cyber-Arcana / C Junk / D Sim) | **PROPOSED: B Cyber-Arcana / ManaNet** | — | Matches art + identity; confirm |
| D3 | Unit art format (alpha PNG vs chroma cutout) | **OPEN** | — | See Q1 |
| D4 | Tower soft-rename now vs later | **OPEN** | — | See Q2 |
| D5 | Mobile renderer: stay gl_compat vs explore Vulkan | **OPEN** | — | See Q3 |
| D6 | Who produces new art / logo / SFX | **OPEN** | — | See Q4 |

Update status to **LOCKED** only after explicit user/owner confirmation.

---

## 7. Open questions

Answer these before or during roadmap planning. Each question blocks or shapes a work package.

### Art pipeline

| ID | Question | Options | Recommendation | Blocks |
|----|----------|---------|----------------|--------|
| **Q1** | How do we remove navy backgrounds for runtime? | (a) Export true alpha PNG/WebP (b) Always-on chroma cutout on mobile (c) Both: alpha preferred, cutout fallback | (c) | Tier 0 cutouts |
| **Q2** | Soft-rename towers/paths to network language in this milestone? | (a) Copy-only rename now (b) After Tier 0 visual (c) Never / keep fantasy names as “sim avatars” | (b) | BrandCopy pass scope |
| **Q3** | Keep Android on `gl_compatibility`? | (a) Keep + make flat path look good (b) Trial mobile Vulkan for glass/fidelity (c) Hybrid | (a) for ship; (b) as experiment only | Shader work package |
| **Q4** | Art production source? | (a) Existing Imagine/batch tools (b) External artist (c) Code-only rework of current JPG | Depends on Q1 | Schedule |
| **Q5** | Target max texture size for units / maps? | e.g. units 128–256, maps 1024 | Units **256**, maps **1024** | Import pipeline |
| **Q6** | Delete unused SVGs and unused variant files if not wired? | (a) Wire variants then keep (b) Delete unused after audit | Wire variants first, then prune | Cleanup scope |

### Scope / product

| ID | Question | Options | Recommendation | Blocks |
|----|----------|---------|----------------|--------|
| **Q7** | ManaNet wordmark: replace logo only or full menu redesign? | (a) Logo + subtitle only (b) Logo + menu layout pass | (a) | Menu work package |
| **Q8** | Boss pack: 3 unique bosses or 1 shared boss + tints? | (a) 3 unique (b) 1 + strong VFX (c) Reuse HeavyBrute scaled + unique FX | (a) if art available else (c) short-term | Boss art WP |
| **Q9** | Shop icons: cutout of full tower art or dedicated 2D icons? | (a) Downscale gameplay cutouts (b) Separate HUD icons | (a) for speed | Shop WP |
| **Q10** | SFX: license pack vs generate vs commission? | (a) Licensed pack (b) AI/gen short oneshots (c) Commission | (a) or (b) for speed | Audio WP |
| **Q11** | Does visual Tier 0 gate Gate A1 / device scorecard? | (a) Yes — block A1 without cutouts+shop icons (b) No — parallel | Prefer (a) for “professionalism” score | Program sequencing |
| **Q12** | Parallel with SimLife ship days or ManaNet-only weeks? | Follow `SHIP_PROGRAM_90_DAY.md` cadence | Mon–Tue ManaNet default | Scheduling |

### Acceptance / evidence

| ID | Question | Options | Recommendation | Blocks |
|----|----------|---------|----------------|--------|
| **Q13** | Success metric for “looks shippable”? | Device scorecard 1–5 on Professionalism + Originality + Would-replay | Min **4/5** Professionalism on S25 Map0→W5 | Gate definition |
| **Q14** | Screenshot/evidence path? | e.g. `run-captures/visual-roadmap/` | Yes, required per WP | Verification |
| **Q15** | APK size / memory budget for art? | Align with `PERFORMANCE_BUDGET.md` | Stay under existing mobile memory target; shrink art first | Import WP |

---

## 8. Proposed work tiers (roadmap seed)

Convert each item into a roadmap work package (WP) after open questions are answered.  
**Acceptance** should always include: device check on S25 (or named device) + headless regression if code touches sim boundaries (should not).

### Tier 0 — Highest ROI (visual “real game”)

| WP | Work | Primary files / assets | Depends on | Acceptance (draft) |
|----|------|------------------------|------------|--------------------|
| **V0.1** | Mobile-safe unit cutouts (towers + enemies) | Art export; `GameRenderer.gd`; cutout shader or alpha textures | Q1, Q3, Q4, Q5 | No solid navy plate behind units on Android |
| **V0.2** | Shop strip icon-first tiles | `GameScreen.gd`; tower textures | V0.1 preferred | Shop shows icon + cost; tappable |
| **V0.3** | Boss type → sprite/FX mapping | `GameRenderer.gd`; boss art | Q8 | W5 boss not grunt-sized grunt art |
| **V0.4** | ManaNet wordmark | `title_logo.png` or replacement; `MenuScreen.gd` | Q7 | Menu shows ManaNet, not Tactical TD |
| **V0.5** | Always-on Android presentation path | `GameTheme.shader_effects_enabled` policy; cutout on mobile | Q3 | Cutouts work even if glass disabled |

### Tier 1 — Compounding polish

| WP | Work | Depends on | Acceptance (draft) |
|----|------|------------|--------------------|
| **V1.1** | Texture import pipeline (size limit, compress, mipmaps) | Q5, Q15 | Smaller imports; no visual mush at gameplay size |
| **V1.2** | Variant texture swap when active | V0.1; Progression variants | Active variant readable in-run |
| **V1.3** | Real SFX replace placeholders | Q10 | Place/death/patch/boss/win not sine-only |
| **V1.4** | UI font (one geometric sans) | — | HUD/menu consistent type |
| **V1.5** | One signature boss spawn VFX | Identity non-goal limits to **one** | W5 spawn has packet/glitch flash |

### Tier 2 — After device scorecard

| WP | Work | Depends on | Notes |
|----|------|------------|-------|
| **V2.1** | Soft-rename towers/paths (BrandCopy only) | Q2; Tier 0 done | No sim/balance changes |
| **V2.2** | Per-map accent color | Maps stay same art | Cheap differentiation |
| **V2.3** | Cheap motion (idle bob, death dissolve) | Perf budget | No full animation sheets |
| **V2.4** | Asset prune (SVGs, duplicates) | Q6 | After wiring |

### Explicit non-goals (until scorecard demands)

- Full 3D-style reskin of all units  
- Full animated sprite sheets for every tower/enemy  
- Second color palette  
- Fire TV visual chrome  
- New towers/maps solely for art showcase  

---

## 9. Suggested sequencing (template)

Adjust after answering Q11–Q12.

```text
Week A
  Day 1–2  V0.1 cutouts (+ V0.5 Android path)
  Day 3    V0.2 shop icons
  Day 4–5  V0.3 bosses (+ optional V1.5 VFX)
  Day 6    V0.4 wordmark
  Day 7    Device scorecard Map0→W5; fill DEVICE_SESSION_SCORECARD.md

Week B (if scores demand)
  V1.1 import pipeline
  V1.2 variants
  V1.3 SFX
  V1.4 font
  Re-score
```

---

## 10. How to turn this into an implementation roadmap

### Step 1 — Resolve open questions (§7)

Fill the Decisions log (§6). Minimum to start coding Tier 0:

- [ ] Q1 art format  
- [ ] Q3 mobile shader policy  
- [ ] Q4 who makes art  
- [ ] Q7 logo scope  
- [ ] Q8 boss scope  
- [ ] Q11 whether Tier 0 gates A1  

### Step 2 — Create roadmap doc (suggested next file)

**Suggested path:** `docs/VISUAL_IMPLEMENTATION_ROADMAP.md`

Per work package, use this template:

```markdown
### WP-V0.1 — Mobile-safe unit cutouts

- **Goal:** …
- **Status:** pending | in_progress | done | blocked
- **Depends on:** Q1=…, D3=…
- **Owner:** …
- **Files:** …
- **Out of scope:** …
- **Acceptance:**
  - [ ] …
- **Verification:**
  - Device: S25 Ultra landscape screenshot `run-captures/...`
  - Headless: full_audit / regression (if code touched)
- **Risk:** LOW | MEDIUM | HIGH
- **Evidence:** …
```

### Step 3 — Board / ship program link

- Add WP IDs to `SHIP_PROGRAM_90_DAY.md` week log or W-gate checklist when scheduled.  
- Do not mix visual WPs with balance changes (`IMPROVEMENT_PLAN` #9 Cannon, etc.) unless explicitly dual-scoped.

### Step 4 — Close the loop

After each WP:

1. Update this audit’s §6 if a decision changed.  
2. Attach evidence paths.  
3. Re-run device scorecard criteria that WP claimed to fix.  
4. Only then mark WP done.

---

## 11. Evidence & inventory snapshot (2026-07-19)

### Asset weight (approx.)

| Ext | Count | ~MB |
|-----|------:|----:|
| `.jpg` | 20 | 11.4 |
| `.png` | 7 | 10.1 |
| `.ogg` | 12 | 0.04 |
| `.svg` | 6 | ~0 |

### Runtime sprite maps (`GameRenderer.gd`)

**Towers:** archer, mage, cannon, sniper, frost, lightning → `*_tower_icon.jpg`  
**Enemies:** Enemy, FastScout, ArmoredTank, FlyingDrone, SwarmMinion, HeavyBrute  
**Missing from MultiMesh keys:** BossShieldBrute, BossSwarmCarrier, other bosses  

### Unused / underused

- `assets/sprites/towers/*.svg` (placeholder geometry)  
- Variant JPGs (exist; not swapped at runtime)  
- `tower_cutout.gdshader` (exists; not reliably applied on Android)  

### Related recent engineering (layout, not art)

- P0/P1 UI fit: `ui/layout/ResponsiveLayout.gd`, `scenes/GameScreen.gd`  
- Wave shop height cap, single placement confirm bar, safe-area margins, phone ultrawide layout class  

---

## 12. Device QA gates (visual)

Use with `docs/DEVICE_SESSION_SCORECARD.md`.

| Check | Pass if |
|-------|---------|
| Units on map | No solid rectangular navy plates |
| Shop strip | Icon + cost readable at arm’s length |
| Boss W5 | Distinct silhouette vs trash |
| Menu | “ManaNet” (or approved wordmark) visible |
| Patch modal | Still fully usable post-layout P0 (regression) |
| SFX | No pure sine “beep kit” for core actions (after V1.3) |
| Perf | No thermal/FPS cliff vs pre-art APK (after V1.1) |

---

## 13. Changelog

| Date | Change |
|------|--------|
| 2026-07-19 | Initial audit from codebase + asset inspection + S25 context; roadmap seed + open questions |

---

## 14. Next action (for human / agent)

1. Review §7 open questions; answer Q1, Q3, Q4, Q7, Q8, Q11 first.  
2. Lock D1–D3 in §6.  
3. Spawn `docs/VISUAL_IMPLEMENTATION_ROADMAP.md` from §8–§10 templates.  
4. Schedule Tier 0 WPs on the ship cadence.  
)
