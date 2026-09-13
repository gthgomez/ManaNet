# ManaNet — Art Direction Guide

**Version:** 2.0.0
**Domain:** Futuristic network-defense tower defense (Godot 4.6.2)
**Target Viewport:** 900x600 (Reference) / Responsive Landscape Mobile  

---

## 1. Visual Theme & Tone

ManaNet is futuristic first and historical weapon archetype second. Its defensive nodes are engineered aerospace machines descended from durable combat geometries: a crossbow becomes a plasma repeater, a ballista becomes a rail accelerator, and an obelisk becomes a cryogenic field generator.
- **Theme:** Physicalized data infrastructure under assault by hostile software.
- **Mood:** Tense, precise, industrial, and legible at mobile scale.
- **Contrast:** Deep navy structural mass with restrained cyan, gold, crimson, and violet energy accents.
- **Forbidden read:** medieval equipment with neon decorations, fantasy castles, wizard props, rustic wood/rope/leather, or generic rainbow cyberpunk.

---

## 2. Palette & Color Script

The game uses a strict 4-tier cyber palette for semantic readability:

| Role | Color Name | Hex Code | Purpose |
|---|---|---|---|
| **Network** | Cyan Conduit | `#28D7FF` | Allied energy, rails, shields, support systems |
| **High value** | Gold Core | `#FFB84A` | Credits, targeting, primary power elements |
| **Danger** | Crimson Surge | `#FF4664` | Hostile processes, threat vectors, breach alerts |
| **Advanced** | Violet Quantum | `#A78BFA` | Stasis, computation, milestones, Flux systems |
| **Structure** | Obsidian Navy | `#07111F` | Chassis, map substrate, negative space |

---

## 3. Perspective & Scale

- **World Playfield:** Top-down 2D grid with a slight isometric projection angle (15° vertical foreshortening).
- **Sprite Dimensions:**
  - **Towers / Turrets:** $32 \times 32\text{ px}$ baseline footprint; up to $48\text{ px}$ height for antenna/cores.
  - **Enemy Units:** $24 \times 24\text{ px}$ to $40 \times 40\text{ px}$ (boss units up to $64\text{ px}$).
  - **UI Icons:** $64 \times 64\text{ px}$ square, centered, borderless flat silhouette.
  - **Projectiles:** $8 \times 8\text{ px}$ to $16 \times 16\text{ px}$ glowing energy bolts.

---

## 4. Silhouette, Outlines & Lighting

- **Silhouette Readability:** Every character, tower, and icon must have a distinct silhouette recognizable within 50ms at 0.5x mobile zoom.
- **Outline Rules:**
  - Game World Sprites (`world_sprite`, `environment_prop`): 1px dark contour (`#030711`) around outer hull to ensure separation from glowing map terrain.
  - UI Icons (`ui_icon`): No heavy black border; crisp flat vector/pixel geometry with transparent alpha background.
- **Lighting Direction:** Fixed key light from **Top-Left (45°)**. Self-illumination is reserved for active energy, charging, heat, targeting, and status effects.

## 5. Material and silhouette rules

- Use dark aerospace alloys, ceramic composite plates, carbon structures, articulated joints, electromagnetic rails, plasma chambers, cooling fins, containment rings, and synthetic circuitry.
- Preserve one strong mechanical silhouette per entity. Color alone may not carry a gameplay role.
- Historical cues may influence geometry and firing posture, but never the material. A Plasma Repeater has accelerator limbs and a chamber—not wood and a bowstring.
- Keep a 1px dark contour around world sprites. UI icons remain clean, flat, and borderless.
- Prefer transparent cutouts. Opaque photographic backgrounds are rejected for production sprites.

---

## 6. Reference Corpus

- Positive examples live in `art/references/good/`.
- Anti-patterns to avoid (blurry photo textures, low-contrast gradients, cluttered noise) live in `art/references/avoid/`.

The machine-readable contract and acceptance matrix are in `art/contracts/mananet_asset_contract.yaml` and `assets/production/asset_manifest.json`.
