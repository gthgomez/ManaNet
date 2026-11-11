# Sound effects

Original procedural SFX synthesized for ManaNet — no sampled or licensed audio.
Every cue is peak-normalized by the generator so frequent events (button press,
enemy death) stay quiet while milestone cues (promotion, boss, victory) carry
weight. Files match the `JuiceManager.SFX` paths in
`feedback/JuiceManager.gd`.

| Cue | Length | Peak |
| --- | --- | --- |
| btn_press | 0.05 s | −13 dBFS |
| tower_place | 0.18 s | −8 dBFS |
| tower_upgrade | 0.40 s | −6 dBFS |
| tower_promote | 0.91 s | −5 dBFS |
| tower_sell | 0.44 s | −9 dBFS |
| enemy_death | 0.17 s | −14 dBFS |
| boss_appear | 1.00 s | −5 dBFS |
| wave_start | 0.45 s | −10 dBFS |
| wave_clear | 0.55 s | −7 dBFS |
| wave_shop | 0.32 s | −12 dBFS |
| integrity_lost | 0.34 s | −10 dBFS |
| error | 0.16 s | −12 dBFS |
| purchase | 0.48 s | −7 dBFS |
| game_over | 1.40 s | −6 dBFS |
| win | 1.16 s | −5 dBFS |

Regenerate deterministically (requires Python 3, numpy, soundfile):

```bash
python3 tools/audio/generate_sfx.py
```

Toggle: Settings → **Sound Effects** (`sfx_enabled` in progression save). Master
mute on the menu still silences all output.
