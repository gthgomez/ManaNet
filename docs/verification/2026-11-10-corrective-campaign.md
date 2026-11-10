# Corrective campaign — 2026-11-10

Engine: Godot 4.6.2.stable.official.71f334935 on Linux x86_64.
Isolated saves via `MANANET_PROFILE_PATH`. Headless suites do not load a GPU
presentation. Menu captures used a graphical Godot window on a local display
(llvmpipe). TowerDefenseKivy was not on this machine. No `export_presets.cfg`,
no Android export templates, no device, no Windows host.

Combat curves were not changed.

| Finding | Root cause | Fix | Verification | Status | Follow-up |
| --- | --- | --- | --- | --- | --- |
| Future-version saves could be replaced by a default profile | Loader kept an in-memory default and later saves were allowed | Explicit persist states. Unsupported, unreadable, and failed-quarantine loads block writes. Recovery copies a verified backup first | `tests/simulation/save_faults.gd` 89/89, including purchases, settings, and run completion after a blocked load | Verified | None for the tested filesystem |
| `initialize()` could retarget a path without reloading | A second initialize returned early once `_initialized` was set | A different path discards memory and loads the new file | Path-switch test: profile A stays 111 after profile B is saved as 222 | Verified | None |
| Promotion buffs used wall time while combat used simulation time | `GameScreen` passed `Time.get_ticks_msec()` into actions that stamped `burst_until` | `apply_action` stamps gameplay mutations with `sim_now()`. Wall time stays on effects and HUD toasts | `clock_authority.gd` 46/46. Input journey confirms a real Confirm button stamps sim+6000 and the bonus drops after that boundary at 3× | Verified | None |
| Wave-shop offers and particles shared the global RNG | `Array.shuffle()` and `randf_range()` | Offer stream and presentation stream, separate seeds | `rng_isolation.gd` seeds 3, 17, 101, 4099 match with particles off, normal, and heavy | Verified | None |
| A failed end-of-run save still looked saved | `_run_recorded` was set and the scene changed on `save_failed` | Unsaved copy, Retry Save, no second award, original bytes kept | Input journey: future-version file unchanged, retry commits once, second retry does not rewrite it | Verified | Leave-anyway is explicit |
| `set_speed` accepted any multiplier | No allow-list | Only 1, 2, and 3. Non-finite and other values return false | `clock_authority.gd` rejects -1, 0, 0.5, 4, 100, inf, nan | Verified | None |
| Full-run tests treated a loss as success | `wins >= 0` and won-or-lost as the only bar | Liveness stays in `full_run.gd`. Victory is a separate legal economy-first run | `full_run.gd` 31/31 terminal. `victory_qualification.gd`: S-Curve, Gauntlet, and Spiral won at wave 15, seed 4242, 7 towers, lives 5/7/11 | Verified | Archer-focus still loses early; that is measured, not retuned |
| Player journey called APIs instead of controls | Scene tests set state directly | `InputJourneyTest` uses keyboard accept, mouse clicks, and world input on the live controls | 55/55. Desktop synthetic input only | Verified | Not an Android touch certificate |
| Import gate could pass on a nonzero, silent process | `run_parse_gate` did not require exit 0 | Exit status plus script/parse text. Timeout and launch failure are exit 2 | `TestParseGateClassification` 7/7, including a fake process | Verified | None |
| Menu showed an opaque mage plate and the legacy logo | SVG plate was scaled up; `title_logo.png` still read Tactical Tower Defense | Mage is not instanced. Logo node is hidden. Wordmark is the title. Assets were not overwritten | Graphical captures `menu_after_*.png` at six landscape sizes | Verified | Portrait is unsupported |
| Short landscapes hid upgrade/sell | Panel minimum size overran a 320–360px height, and a shop click toggled placement off | Compact panel density; shop `button_down` no longer cancels the same click | `ViewportGeometryTest` 182/182. Sell and upgrade on-screen at 568×320 and 640×360 | Verified | Portrait not claimed |
| Benchmark reported simulation cost as if it were FPS | The number was a step time | Report stays CPU step time, with an explicit note | 50 towers, peak 188 enemies, 299 particles, p99 0.755 ms, static 23.62 MiB. 3× mean 0.668 ms. Not rendered FPS | Verified | No device frame-time capture |
| Late-game credit surplus | Measured, not diagnosed as a single bug. Reference repo absent | No curve edit | Strategy benchmark 13/30 wins (43%). Winning end gold 1930–6123, average 4790. economy_first won 6/6 maps/seeds | Partially verified | Do not retune without the Kivy reference or an explicit design decision |
| Android / Windows release | No export preset, templates, SDK use, or device | None applied | Inspected `project.godot` (landscape, gl_compatibility) and `android/` manifest (landscape, GLES 3) | Blocked | Install 4.6.2 templates, Android SDK/NDK, and a debug keystore outside the repo. Then add a preset and run a device install |
| Showcase MP4/GIF | Older capture. The movie driver is a `--script` SceneTree, so it does not load autoloads | Not regenerated | Menu PNGs above are from the current MenuScreen. The checked-in MP4/GIF stay labeled historical | Blocked | Point the movie driver at a real scene so Progression exists, then rerun `tools/showcase/capture.sh` |

## Commands and results from this host

```
tests/simulation/save_faults.gd          PASS 89
tests/simulation/clock_authority.gd      PASS 46
tests/simulation/rng_isolation.gd        PASS 16
tests/simulation/regression_checks.gd    PASS 118
tests/simulation/speed_parity.gd         PASS 31
tests/simulation/full_run.gd             PASS 31
tests/simulation/victory_qualification.gd PASS 6
tests/simulation/strategy_benchmark.gd   PASS 3 (13/30 wins)
tests/ui/UIRegressionTest.tscn           PASS 35
tests/ui/PlayerJourneyTest.tscn          PASS 28
tests/ui/InputJourneyTest.tscn           PASS 55
tests/ui/ViewportGeometryTest.tscn       PASS 182
scenes/SimTest.tscn                      exit 0
scripts/benchmark.gd                     exit 0
tests/verifier_exit TestParseGateClassification  7/7
```

`python3 tools/verify_game.py --all` on this host exited 0. Every gate passed:
parse, audit, simulation regression, UI regression, player journey, viewport
geometry, speed parity, save faults, full-run liveness, clock authority, RNG
isolation, victory qualification, input journey, verifier exit contract, and
early-run smoke. The input journey stops button audio before process exit so
an in-flight `btn_press.ogg` playback is not reported as a leaked resource.
