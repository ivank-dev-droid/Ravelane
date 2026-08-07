# 04 — Cars, Decks, Parts, Progression, UX

## Cars (12)

A car is six numbers. They are not upgrades of each other — each one makes a different
deck correct, and each is unlocked by a feat rather than bought.

| Car | Mass | Grip μ | Accel | Top | Downforce | Width tol. | Character |
|---|---|---|---|---|---|---|---|
| **Fettle** | 1.0 | 1.00 | 1.0 | 1.0 | 0.0 | 1.0 | the baseline; starting car |
| **Shim** | 0.6 | 0.85 | 1.4 | 1.05 | 0.0 | 0.9 | light and twitchy; climbs anything, slides everywhere |
| **Ballast** | 1.9 | 1.30 | 0.6 | 0.9 | 0.1 | 1.3 | heavy; stalls on Rise Steep, unshakeable in corners |
| **Kite** | 0.5 | 0.70 | 1.1 | 1.0 | −0.2 | 0.9 | floats on jumps, huge air; awful grip |
| **Anvil** | 2.4 | 1.15 | 0.5 | 0.85 | 0.3 | 1.5 | ignores rumble and scrapes; hopeless uphill |
| **Sliver** | 0.7 | 0.95 | 1.2 | 1.3 | 0.0 | 0.7 | fastest top speed, narrowest margin |
| **Burr** | 1.1 | 1.05 | 1.0 | 0.95 | 0.2 | 1.1 | downforce car; grip scales with speed |
| **Tack** | 0.9 | 1.10 | 0.9 | 0.9 | 0.0 | 1.2 | forgiving; the "learn a world" car |
| **Cinder** | 1.0 | 0.90 | 1.6 | 1.15 | 0.0 | 1.0 | explosive accel, poor grip; Booster decks |
| **Loom** | 1.2 | 1.00 | 0.8 | 0.8 | 0.0 | 1.4 | slow and wide; the Runway car — more time to think |
| **Spindle** | 0.8 | 1.25 | 1.0 | 1.0 | 0.15 | 0.8 | banking specialist; bank bonus doubled |
| **Ravelane** | 1.0 | 1.00 | 1.0 | 1.0 | 0.0 | 1.0 | endgame car: **+1 hand slot**, halved draw delay |

Unlock feats are behavioural, e.g. *Loom* — finish a level with runway never dropping
below 6 s; *Kite* — land three Long Gaps in one level; *Anvil* — finish a level at zero
Integrity.

## Parts (30)

Three part slots per car. Bolt-ons that change the *building* game, not the driving game
— which is the right place for progression in a game about construction.

**Hand & draw (8)**
Sixth Slot · Fast Feed (−30 % draw delay) · Twin Draw (two slots refill at once) ·
Preview Next (see the next card) · Free Discard (no Material cost) · Rapid Discard
(−50 % cooldown) · Sorter (drawn pieces bias toward what your deck lacks) · Sticky Hand
(one slot never auto-refills — reserve a piece)

**Economy (7)**
Core Magnet (+3 m pickup radius) · Ring Bonus (+40 % checkpoint Material) · Salvage
(discarding refunds 60 % of cost) · Thrift (Straight-class pieces −30 % cost) ·
Prospector (cores reveal at 200 m) · Streak (consecutive clean landings compound) ·
Deficit (may go 20 Material negative)

**Physics (8)**
Soft Compound (+8 % grip, −5 % top speed) · Ballast Tune (−10 % mass) · Wing (+0.15
downforce) · Landing Gear (+10° landing tolerance) · Anti-roll (bank effect +40 %) ·
Regenerative Brake (Brake Strips give Material) · Momentum Keeper (corner speed loss
−25 %) · Gyro (airborne attitude self-corrects)

**Survival (7)**
Plating (+30 max Integrity) · Scrape Guard (wall contact costs half) · Second Wind (one
free crash per level, at 50 % speed) · Warning Line (audible cue at 3 s runway) ·
Long Ghost (preview shows two pieces ahead) · Anchor Field (Junction branches never
decay) · Fog Cutter (+25 m visible range)

## Deck building

- 12 slots. Each slot holds a piece type and a count (1–5). Total pieces 12–36.
- Draw is weighted by count, so a 5× Straight deck reliably feeds straights.
- Levels may impose limits: *Foundry 9* forbids the Turn class entirely (you navigate
  with Chicanes and Junctions only); *Overdrive 4* requires at least 4 banking pieces.
- **Deck presets** are saveable and named; the game ships 8 archetype presets so a new
  player is never staring at an empty builder.

Four archetypes the catalog supports, each viable to the end:

1. **Runway** — long straights, few turns, buy thinking time, navigate with Adjustable
   Curves. Slow, safe, always over par.
2. **Scalpel** — sharp curves and hairpins, minimum length, always 2 s from death, wildly
   under par. The three-star deck.
3. **Air** — Kickers, Long Gaps, Launch Rails. Skips terrain entirely; needs Updraft
   physics or big speed.
4. **Bank** — Bank pieces before every curve, carry enormous corner speed, live on the
   grip limit. Pairs with Spindle and Anti-roll.

## Progression

**Unlock-driven, never power-driven.** Nothing you unlock makes a level mathematically
easier; it widens the space of solutions. Parts are sidegrades with an explicit cost on
the other side of the ledger.

| Track | Gate |
|---|---|
| Pieces | one or two per level, tied to the world |
| Cars | behavioural feats (12) |
| Parts | star totals and per-world completions (30) |
| Worlds | 8 stars in the previous world |
| Endless | finish Foundry |
| Mirror mode | 3-star a world → replay it mirrored, par −2 |

There is no currency, no energy, no ads, no IAP. A level costs nothing to retry and
retries are instant — the whole failure loop is `crash → 0.6 s → back on the plinth`.

## UX rules

**The three clocks are always on screen** and never lie: Runway in seconds, Material as a
number, Integrity as a bar. All three flash at their own thresholds with distinct audio.

**Ghost preview is mandatory, not a toggle.** Selecting a piece shows the ghost and its
exit speed. This is the difference between a game about planning and a game about
guessing.

**One-thumb layout.** Hand along the bottom edge, tap to select, tap the socket or swipe
up to commit. Lateral nudge is a two-finger drag. Nothing needs the top half of the
screen, which is where the track is.

**Camera.** Chase camera locked behind the car, pitching to keep the head socket in
frame. It automatically pulls back as runway grows so the whole buffer is visible; that
means the camera itself communicates the most important number. A held two-finger gesture
gives a free orbit with the simulation slowed to 25 % — the "think" camera, on a budget
of ~10 s per level.

**Retry preserves the deck** and drops you straight back on the plinth. Never a menu.

**Colourblind-safe** — the ghost's green/amber/red is doubled with a shape cue (✓ / ! /
✕) and the exact number.

**Reduce motion** setting disables camera roll and corkscrew spin, which are the two
things most likely to cause discomfort in a 3D racer.

## Audio

- The car's engine note is driven by actual simulated speed, not a loop.
- Each piece class has a distinct *snap* on placement, pitched by cost.
- **Runway has a heartbeat** that speeds up below 4 s. It is the single most important
  audio cue in the game and is on by default even with music off.
- Grip is audible: tyre load scales a filtered noise layer, so you can hear a corner
  going wrong a beat before you see it.
- Haptics: `.light` on placement, `.rigid` on landing, a custom pattern on the grip limit.

## Accessibility

- Assist mode: slow the world to 70 % without affecting scoring bands (scores are marked
  as assisted).
- Auto-nudge: the lateral position self-centres.
- Extended tolerances: landing angle and grip limit both +20 %.
- Full remapping of the commit gesture; a hold-to-commit option for players who mis-tap.
