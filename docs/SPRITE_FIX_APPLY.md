# Apply the sprite / shop / renderer fix

`rendering/GameRenderer.gd` on `main` was accidentally overwritten. Restore it first.

```bash
git fetch origin
git checkout 8e57b8701440f24849091452b80b9c7a7d85292c -- rendering/GameRenderer.gd
```

Then change this one line in `_build_multimesh_pools`:

```
mat.set_shader_parameter("glow_intensity", 3.5)
```

to:

```
mat.set_shader_parameter("glow_intensity", 0.85)
```

`assets/shaders/TowerFidelity.gdshader` on `main` is already the alpha-safe version. Keep it.

Copy these files over `assets/sprites/towers/`:

- mage.png, mage_icon.png, mage_icon_128.png
- lightning.png, lightning_icon.png, lightning_icon_128.png
- frost.png, frost_icon.png, frost_icon_128.png
- archer.png, cannon.png, sniper.png (recropped, same art)

Shop strip: in `scenes/GameScreen.gd` replace the stacked shop VBox with an HBox (icon | name+cost) and set:

```
sbtn.custom_minimum_size = Vector2(126.0, 88.0)
var shop_h: float = 72.0 if compact_shop else 88.0
```

Do not pull `46e24b1` or `6abacea` as the source of GameRenderer.
