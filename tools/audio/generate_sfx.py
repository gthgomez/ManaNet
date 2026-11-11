#!/usr/bin/env python3
"""Generate ManaNet's original SFX set.

All sounds are synthesized from scratch (no sampled/licensed material), then
peak-normalized to the per-cue target below so frequent cues stay quiet and
milestone cues carry weight. Output is mono 44.1 kHz Ogg Vorbis in assets/sfx/.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44_100
OUT = Path(__file__).resolve().parents[2] / "assets" / "sfx"
rng = np.random.default_rng(20261111)


def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def env(n: int, attack: float = 0.006, release: float = 0.25, curve: float = 3.0) -> np.ndarray:
    """attack is seconds; release is a fraction of the sound's duration."""
    a = max(1, min(n, int(SR * attack)))
    r = max(1, min(n, int(n * release)))
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a) ** 0.7
    tail = np.linspace(1.0, 0.0, r) ** curve
    e[-r:] *= tail
    return e


def tone(freq: float, dur: float, *, partials=(1.0,), detune: float = 0.0,
         phase: float = 0.0) -> np.ndarray:
    x = np.zeros(int(SR * dur))
    tt = t(dur)
    for i, amp in enumerate(partials, start=1):
        f = freq * i * (1.0 + detune * (i - 1))
        x += amp * np.sin(2.0 * math.pi * f * tt + phase * i)
    return x


def sweep(f0: float, f1: float, dur: float, *, partials=(1.0,)) -> np.ndarray:
    tt = t(dur)
    freq = np.linspace(f0, f1, len(tt))
    phase = 2.0 * math.pi * np.cumsum(freq) / SR
    x = np.zeros_like(tt)
    for i, amp in enumerate(partials, start=1):
        x += amp * np.sin(phase * i)
    return x


def noise(dur: float, *, lp: float = 0.18) -> np.ndarray:
    n = rng.standard_normal(int(SR * dur))
    out = np.zeros_like(n)
    acc = 0.0
    for i, v in enumerate(n):
        acc += lp * (v - acc)
        out[i] = acc
    return out


def mix(*parts: tuple[float, np.ndarray]) -> np.ndarray:
    length = max(int(SR * start) + len(x) for start, x in parts)
    out = np.zeros(length)
    for start, x in parts:
        i = int(SR * start)
        out[i:i + len(x)] += x
    return out


def ping(freq: float, dur: float, *, amp: float = 1.0, attack: float = 0.004,
         release: float = 0.9, partials=(1.0, 0.35, 0.12)) -> np.ndarray:
    n = int(SR * dur)
    return amp * tone(freq, dur, partials=partials) * env(n, attack, release, 2.2)


def finish(x: np.ndarray, peak_db: float, *, stereo: bool = False) -> np.ndarray:
    # Remove DC and normalise to the requested peak.
    x = x - float(np.mean(x))
    peak = float(np.max(np.abs(x))) or 1.0
    target = 10.0 ** (peak_db / 20.0)
    x = np.tanh(x / peak * 1.15) / math.tanh(1.15)
    x *= target / (float(np.max(np.abs(x))) or 1.0)
    fade = min(len(x), int(SR * 0.004))
    x[:fade] *= np.linspace(0.0, 1.0, fade)
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    if stereo:
        delay = int(SR * 0.004)
        left = x
        right = np.concatenate([np.zeros(delay), x[:-delay]]) * 0.92
        return np.stack([left, right], axis=1)
    return x


def build() -> dict[str, np.ndarray]:
    cues: dict[str, np.ndarray] = {}

    # UI: soft, short, quiet.
    click = mix(
        (0.0, ping(1180, 0.055, amp=0.7)),
        (0.0, 0.25 * noise(0.03, lp=0.6) * env(int(SR * 0.03), 0.001, 0.7)),
    )
    cues["btn_press"] = finish(click, -13.0)

    # Build: low chassis thud plus a confirming blip.
    thud = sweep(150, 82, 0.18, partials=(1.0, 0.4)) * env(int(SR * 0.18), 0.002, 0.14, 3.0)
    confirm = ping(587, 0.12, amp=0.55, release=0.6)
    cues["tower_place"] = finish(mix((0.0, thud), (0.02, confirm)), -8.0)

    # Upgrade: rising three-note arpeggio with a sparkle.
    lead = mix(
        (0.00, ping(440, 0.16, amp=0.7)),
        (0.07, ping(554, 0.18, amp=0.7)),
        (0.14, ping(659, 0.26, amp=0.75)),
        (0.20, ping(1319, 0.20, amp=0.25, partials=(1.0, 0.2))),
    )
    cues["tower_upgrade"] = finish(lead, -6.0)

    # Promotion: longer, bigger arc.
    promo = mix(
        (0.00, ping(330, 0.22, amp=0.65)),
        (0.09, ping(440, 0.24, amp=0.65)),
        (0.18, ping(554, 0.26, amp=0.7)),
        (0.27, ping(659, 0.34, amp=0.7)),
        (0.36, ping(880, 0.55, amp=0.55)),
        (0.36, ping(1109, 0.50, amp=0.25)),
    )
    cues["tower_promote"] = finish(promo, -5.0, stereo=True)

    # Sell: descending coin-like triple.
    sell = mix(
        (0.00, ping(784, 0.12, amp=0.6)),
        (0.08, ping(622, 0.14, amp=0.6)),
        (0.16, ping(466, 0.28, amp=0.6)),
    )
    cues["tower_sell"] = finish(sell, -9.0)

    # Enemy death: filtered burst + falling body.
    burst = noise(0.16, lp=0.22) * env(int(SR * 0.16), 0.001, 0.13, 3.5)
    fall = sweep(300, 110, 0.17, partials=(1.0, 0.35)) * env(int(SR * 0.17), 0.001, 0.15, 2.5)
    cues["enemy_death"] = finish(mix((0.0, 0.85 * burst), (0.0, 0.6 * fall)), -14.0)

    # Boss: low tremolo rumble + rising alarm.
    dur = 1.0
    tt = t(dur)
    rumble = np.sin(2 * math.pi * 55 * tt) * (0.6 + 0.4 * np.sin(2 * math.pi * 7 * tt))
    rumble += 0.35 * np.sin(2 * math.pi * 82.5 * tt)
    alarm = sweep(220, 330, 0.75, partials=(1.0, 0.25)) * env(int(SR * 0.75), 0.02, 0.6, 2.0)
    boss = mix(
        (0.0, 0.7 * rumble * env(len(rumble), 0.02, 0.6, 2.0)),
        (0.18, alarm),
    )
    cues["boss_appear"] = finish(boss, -5.0, stereo=True)

    # Wave start: clean rising sweep.
    ws = sweep(220, 660, 0.45, partials=(1.0, 0.25, 0.08)) * env(int(SR * 0.45), 0.01, 0.35, 2.0)
    cues["wave_start"] = finish(ws, -10.0)

    # Wave clear: warm two-note chime.
    wc = mix(
        (0.00, ping(523, 0.30, amp=0.7)),
        (0.13, ping(784, 0.42, amp=0.7)),
        (0.13, ping(1046, 0.36, amp=0.18)),
    )
    cues["wave_clear"] = finish(wc, -7.0)

    # Wave shop: gentle prompt, not a reward.
    shop = mix((0.00, ping(392, 0.16, amp=0.6)), (0.10, ping(523, 0.22, amp=0.55)))
    cues["wave_shop"] = finish(shop, -12.0)

    # Integrity lost: urgent two-tone alert.
    lost = mix(
        (0.00, sweep(240, 190, 0.14, partials=(1.0, 0.4))),
        (0.16, sweep(200, 150, 0.18, partials=(1.0, 0.4))),
    )
    cues["integrity_lost"] = finish(lost, -10.0)

    # Error / cannot afford: short low buzz.
    err = tone(124, 0.16, partials=(1.0, 0.5, 0.25)) * env(int(SR * 0.16), 0.003, 0.12, 2.0)
    cues["error"] = finish(err, -12.0)

    # Purchase: brighter coin chord.
    buy = mix(
        (0.00, ping(880, 0.16, amp=0.6)),
        (0.09, ping(1175, 0.20, amp=0.55)),
        (0.18, ping(1568, 0.30, amp=0.4)),
    )
    cues["purchase"] = finish(buy, -7.0)

    # Defeat: slow descending minor figure.
    over = mix(
        (0.00, ping(392, 0.35, amp=0.65)),
        (0.22, ping(330, 0.40, amp=0.65)),
        (0.44, ping(262, 0.50, amp=0.7)),
        (0.70, ping(196, 0.70, amp=0.7)),
    )
    cues["game_over"] = finish(over, -6.0, stereo=True)

    # Victory: major arpeggio with a sustained chord.
    win = mix(
        (0.00, ping(523, 0.30, amp=0.6)),
        (0.12, ping(659, 0.32, amp=0.6)),
        (0.24, ping(784, 0.36, amp=0.6)),
        (0.36, ping(1046, 0.70, amp=0.6)),
        (0.36, ping(1318, 0.60, amp=0.22)),
        (0.36, ping(784, 0.80, amp=0.25)),
    )
    cues["win"] = finish(win, -5.0, stereo=True)
    return cues


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, audio in build().items():
        path = OUT / f"{name}.ogg"
        # Ogg Vorbis quality 5 keeps files small without audible artifacts.
        sf.write(path, audio, SR, format="OGG", subtype="VORBIS", compression_level=0.35)
        peak = 20 * math.log10(max(float(np.max(np.abs(audio))), 1e-9))
        rms = 20 * math.log10(max(float(np.sqrt(np.mean(audio ** 2))), 1e-9))
        print(f"{path.name:22s} peak {peak:6.1f} dBFS  rms {rms:6.1f} dBFS  {len(audio)/SR:.2f}s")


if __name__ == "__main__":
    main()
