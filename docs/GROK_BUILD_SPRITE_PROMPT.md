# ManaNet — Grok Build Mode prompt (sprites + wiring)

Use this as the **first message** in Grok Build (mobile or web).  
Attach or open the **existing** `gthgomez/ManaNet` Godot project first. Do not start a blank app.

---

## PASTE FROM HERE

```
You are working in the EXISTING Godot 4.6 project ManaNet (gthgomez/ManaNet). Do not create a new game. Do not rewrite simulation/, maps, economy, or upgrade math. This job is visual assets + wiring only.

GOAL
Ship playable cutout sprites for the six existing towers, then point the game at them.

READ FIRST (in this order)
1. art/ART_DIRECTION.md — the AGENT LOCK at the top is law
2. docs/SPRITE_AND_WEAPON_DIRECTION.md
3. assets/contracts/tower_archer.asset.yaml
4. assets/contracts/tower_cannon.asset.yaml
5. assets/contracts/tower_lightning.asset.yaml
6. assets/contracts/ui_icon_archer.asset.yaml
7. rendering/GameRenderer.gd (TOWER_SPRITE_PATHS)
8. scenes/GameScreen.gd shop-strip builder (_shop_btns)

FANTASY LOCK
Medieval weapon SHAPES built as modern energy hardware on a dark data-grid.
Not castle TD. Not pixel art. Not wooden bows. Not cartoon knights.
- archer = plasma crossbow (Cyber-Ranger)
- cannon = bombard that fires glowing futuristic bombs (Plasma Artillery)
- lightning = Edgeworld-style industrial Tesla coil: tall lattice, stacked rings, arcing sphere (not a toy yellow ball)
- mage = crystal staff / netrunner spire
- frost = cryo emitter / thermal siphon
- sniper = long optic rail

TECH LOCK
- World sprites: 256x256 PNG RGBA, 3/4 isometric, subject centered, feet near bottom, NO navy card, NO museum plinth, NO baked motion streaks.
- Icons: 64x64 PNG RGBA (also save 128x128 if easy), weapon-head crop, subject >= 80% of frame.
- Display size in-game is ~40–64px. If a detail dies at 48px, delete it.
- Chassis = cool grey steel. Accent is 10–20% of pixels.
- Accents: archer lime #22C55E, cannon orange #FF8C1A, tesla volt #FFE566, mage violet #A854F7, frost #3EE7FF, sniper cyan #1EB0FF.
- Backdrop #0A0F1C is the MAP, never baked into the sprite.
- Keep existing 1024 JPG key art. Do not delete it. Do not point runtime at it.

GENERATE THESE FILES (create folders if missing)
assets/sprites/towers/archer.png
assets/sprites/towers/mage.png
assets/sprites/towers/cannon.png
assets/sprites/towers/sniper.png
assets/sprites/towers/frost.png
assets/sprites/towers/lightning.png
assets/sprites/towers/archer_icon.png
assets/sprites/towers/mage_icon.png
assets/sprites/towers/cannon_icon.png
assets/sprites/towers/sniper_icon.png
assets/sprites/towers/frost_icon.png
assets/sprites/towers/lightning_icon.png

IMAGE PROMPTS (use one generation per file; transparent background; game sprite not poster)

WORLD — archer.png
"Game sprite, 3/4 isometric, single object centered, transparent background, no frame, no pedestal. Short steel bunker with a large futuristic crossbow on top. Limbs are metal, string is glowing lime plasma #22C55E, one plasma bolt nocked. Compact silhouette readable at 48 pixels. Cool grey metal, dark 1px outline, top-left light. Not wood, not pixel art, not a photo."

WORLD — cannon.png
"Game sprite, 3/4 isometric, transparent background, no frame, no factory. Short siege bombard / mortar of steel and bronze with a wide orange barrel. A glowing orange-white plasma bomb with fins sits in or just leaving the muzzle. Compact hex pad only. Readable at 48 pixels. Not a tank, not pixel art."

WORLD — lightning.png
"Game sprite, 3/4 isometric, transparent background. Industrial Tesla defense pylon inspired by Edgeworld Tesla Tower and Wardenclyffe: tall open lattice or four-leg truss, 3 stacked copper coils, charged sphere on top with two small electric arcs. Steel chassis, volt-gold #FFE566 only on the charge path. Tall and industrial, not a toy orb house, not Clash of Clans cute, not pixel art. Readable at 48 pixels."

WORLD — mage.png
"Game sprite, 3/4 isometric, transparent background. Slim steel pylon with a faceted violet crystal focus and a thin energy ring. Circuit-trace runes, not stone gothic. Accent #A854F7. Compact, readable at 48 pixels."

WORLD — frost.png
"Game sprite, 3/4 isometric, transparent background. Cryo condenser / thermal siphon nozzle of steel with ice-cyan #3EE7FF coolant glow. No ice castle, no ground crystal garden. Compact emitter head readable at 48 pixels."

WORLD — sniper.png
"Game sprite, 3/4 isometric, transparent background. Slim mast with a long optic rail and cyan #1EB0FF scope glow. One small beam tick. No radar dish farm. Readable at 48 pixels."

ICON — *_icon.png
Same subject as the matching world sprite, cropped to the weapon head only, 64x64, transparent, fills 80%+ of the square, no pad, no text.

WIRE INTO THE GAME

1) rendering/GameRenderer.gd — change TOWER_SPRITE_PATHS to the new PNGs:

const TOWER_SPRITE_PATHS: Dictionary = {
	"archer": "res://assets/sprites/towers/archer.png",
	"mage": "res://assets/sprites/towers/mage.png",
	"cannon": "res://assets/sprites/towers/cannon.png",
	"sniper": "res://assets/sprites/towers/sniper.png",
	"frost": "res://assets/sprites/towers/frost.png",
	"lightning": "res://assets/sprites/towers/lightning.png",
}

Keep JPEG paths nowhere in this dict.

2) scenes/GameScreen.gd — in the shop-strip loop that builds _shop_btns, add a TextureRect ABOVE the name label for each ttype:

var icon := TextureRect.new()
icon.texture = load("res://assets/sprites/towers/%s_icon.png" % ttype)
icon.custom_minimum_size = Vector2(40, 40)
icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
shop_vbox.add_child(icon)  # before name_lbl

If load() returns null, skip the icon and keep the text labels. Do not crash.

3) Do not change MultiMesh instance sizing in this pass unless a sprite is clipped; if you must, keep tower draw size at tower.radius * 2.2.

OUT OF SCOPE
- No new tower types
- No enemy/boss sprites in this pass
- No HUD chrome redesign
- No simulation/ edits
- No deleting the old *_tower_icon.jpg files
- No claiming done without the 12 PNGs existing AND the two script path/icon edits

ACCEPTANCE
- 12 PNGs on disk with real alpha (not a navy rectangle)
- GameRenderer loads the six world PNGs
- Shop buttons show 40px icons plus existing name/cost text
- Tesla reads as a tall coil, not a yellow ball
- Cannon shows a bomb/shell
- Archer shows a plasma string

WORK ORDER
1. Generate the 12 images and save to the paths above.
2. Patch GameRenderer.gd paths.
3. Patch GameScreen.gd shop icons.
4. List every file you created or edited.
5. If image generation cannot write binary PNGs into the Godot project, say that explicitly and output: (a) the exact prompts, (b) the exact Godot path each file must be saved to, (c) the exact GDScript diffs. Do not fake placeholder JPEGs.

Start now with archer.png + archer_icon.png, then cannon, then lightning, then the remaining three, then the two script patches.
```

## PASTE ENDS HERE

---

## How to run this in Grok Build

1. Open Grok on web or mobile → **Build**.
2. Point it at the ManaNet project (GitHub `gthgomez/ManaNet` or a local/upload of the repo). If Build starts a blank canvas, stop and attach the repo.
3. Paste the block above as the first instruction. Do not add “also redesign the menu.”
4. After it finishes, check:
   - `assets/sprites/towers/*.png` exist and are transparent
   - `TOWER_SPRITE_PATHS` no longer ends in `.jpg`
   - Shop buttons have a `TextureRect`
5. Open Godot, let it import the PNGs, run a wave, look at a placed tower and the shop strip.

## If Build cannot write PNGs

That is common in the app. Have it emit the 12 images in chat, then you (or this coding agent) save them to the paths and apply the two diffs. The prompt already tells it to fall back to prompts + diffs instead of fake JPEGs.

## Do not do in the same Build chat

New weapons (ballista, glaive), boss sprites, map art, or a pixel-art reboot. Those are later passes.
