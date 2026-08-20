# ManaNet — Art Direction Guide

**Version:** 1.0.0  
**Domain:** Mobile Cyberpunk Tower Defense (Godot 4.6.2)  
**Target Viewport:** 900x600 (Reference) / Responsive Landscape Mobile  

---

## 1. Visual Theme & Tone

ManaNet blends a dark, tactical command center aesthetic with luminous neon energy currents.
- **Theme:** High-tech cyber grid under assault by corrupted data constructs.
- **Mood:** Tense, precise, vibrant defense in deep digital space.
- **Contrast:** Deep Obsidian / Slate backdrop (#0A0F1C) punctuated by high-luminance neon conduits.

---

## 2. Palette & Color Script

The game uses a strict 4-tier cyber palette for semantic readability:

| Role | Color Name | Hex Code | Purpose |
|---|---|---|---|
| **Primary** | Cyan Glow | `#1EB0FF` | Player towers, allied projectile conduits, energy shields |
| **Secondary** | Gold Core | `#FFB400` | Power generators, currency counters, upgrade tiers |
| **Danger** | Crimson Surge | `#FF3C3C` | Enemy units, threat vectors, breach alerts |
| **Backdrop** | Obsidian Dark | `#0A0F1C` | Map grid, non-interactive letterboxes, chassis plating |

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
  - Game World Sprites (`pixel_sprite`, `environment_prop`): 1px dark contour (`#050810`) around outer hull to ensure separation from glowing map terrain.
  - UI Icons (`ui_icon`): No heavy black border; crisp flat vector/pixel geometry with transparent alpha background.
- **Lighting Direction:** Fixed Key Light from **Top-Left (45°)**. Self-illuminated neon accents on energy channels.

---

## 5. Reference Corpus

- Positive examples live in `art/references/good/`.
- Anti-patterns to avoid (blurry photo textures, low-contrast gradients, cluttered noise) live in `art/references/avoid/`.
