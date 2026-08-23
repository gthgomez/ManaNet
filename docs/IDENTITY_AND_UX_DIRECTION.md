# ManaNet — Identity & UX Direction

**Status:** LOCKED for Gate A1 polish (2026-07-19)  
**Program:** Ship A · `../SHIP_PROGRAM_90_DAY.md`  
**Code source of player strings:** `ui/theme/BrandCopy.gd`

---

## One-sentence fantasy

You are defending a **data grid** against viral intrusion: place node-defenders, spend **Credits**, and **patch** the network between waves.

## Signature hook

**Network defense / software patches** — not castle TD, not generic neon.

| System | Player read |
|--------|-------------|
| Wave shop | **Patch** draft (choose one bonus) |
| Meta | **Cyber-Deck** (firmware upgrades) |
| Meta currency | **Shards** |
| Run currency | **Credits** |
| Core resource | **Integrity** (was “Lives”) |
| Boss peaks | Named threats on the wire (W5/10/15) |

Optional later signature VFX (one only): packet/glitch flash on boss spawn.

---

## Brand lexicon

| Concept | Use in UI | Code may keep |
|---------|-----------|---------------|
| Run money | Credits | `gold` |
| Core HP | Integrity / INT | `lives` |
| Meta bank | Shards | `rp`, `banked_rp` |
| Meta screen | Cyber-Deck | — |
| Between-wave cards | Patch / Network bonus | `wave_shop_*` |
| Start combat | Start Wave (clarity) | — |

**Forbidden player-facing:** bare `RP`, `Robo Base`, `Research Points`, `Gold` as currency label.

---

## Visual system

Extend `GameTheme.gd` only. Navy panels, gold primary, cyan secondary, crimson danger, violet milestones.

Art: prefer cutout + unified tint; no full reskin until device scores demand it.

---

## Phases (summary)

0. Identity lock — this doc  
1. Lexicon consistency — BrandCopy + screens  
2. Device Map 0→W5 baseline session  
3. P0/P1 from device notes (boss read, shop strip, HUD, SFX)  
4. Optional one signature VFX  
5. Gate A1 checklist  

## Non-goals

Fire TV, new towers/maps for A1, second palette, SimLife parallel features during ManaNet focus week.

## Phone scorecard (1–5)

Clarity · Placement · Shop strip · Wave shop · Boss W5 · SFX · Professionalism · Originality · Would-replay  
