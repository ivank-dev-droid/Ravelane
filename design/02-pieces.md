# 02 — Piece Catalog (40)

## Piece anatomy

Every piece is a value type with no behaviour of its own:

```
Piece {
  id, name, class, rarity/unlockTier
  length        metres of ribbon
  exitDelta     Δyaw, Δpitch, Δroll  (radians, applied at the exit frame)
  width         track width in metres (affects grip margin, not collision volume)
  bank          static roll of the driving surface
  cost          Material
  drawWeight    how often it appears when in the deck
  tags          [Straight, Turn, Vertical, Roll, Air, Structural, Utility, World-locked]
  surface       .normal | .boost | .brake | .rumble | .magnet | .scaffold
  clearance     swept-volume radius used for self-intersection checks
}
```

The **exit transform** is what makes the chain work:

```
headFrame' = headFrame · translate(0, 0, length) · rotate(Δyaw, Δpitch, Δroll)
```

Because pieces compose by matrix multiplication, the entire track is derivable from the
plinth frame plus an ordered list of piece IDs. **A whole run serialises to an array of
integers** — which is what makes replays, ghost data, level solutions and the headless
solver all cheap.

## Runway economics

The number that matters for each piece is **seconds of runway bought**:
`length ÷ current speed`. At 30 m/s a Straight Long buys 0.8 s; a Hairpin buys 0.47 s
and also cuts your speed. The catalog is tuned so that navigation is always a time
sacrifice.

---

## Class: Straight (4)

| # | Piece | Length | Exit Δ | Cost | Notes |
|---|---|---|---|---|---|
| 1 | **Stub** | 8 m | — | 4 | cheapest filler, fine adjustment |
| 2 | **Straight** | 24 m | — | 10 | the workhorse |
| 3 | **Long Run** | 48 m | — | 22 | the runway purchase |
| 4 | **Narrow Bridge** | 32 m | — | 6 | half width; cheap, unforgiving at speed |

## Class: Turn (10)

| # | Piece | Length | Δyaw | Cost | Notes |
|---|---|---|---|---|---|
| 5 | **Gentle Curve L** | 16 m | −30° | 9 | |
| 6 | **Gentle Curve R** | 16 m | +30° | 9 | |
| 7 | **Sharp Curve L** | 12 m | −60° | 12 | needs bank above ~28 m/s |
| 8 | **Sharp Curve R** | 12 m | +60° | 12 | |
| 9 | **Hairpin L** | 14 m | −120° | 18 | speed-killer, huge direction change |
| 10 | **Hairpin R** | 14 m | +120° | 18 | |
| 11 | **Banked Curve L** | 18 m | −60° | 20 | ships with 30° bank; premium |
| 12 | **Banked Curve R** | 18 m | +60° | 20 | |
| 13 | **Chicane L-R** | 26 m | net 0° | 15 | net-straight, bleeds speed, dodges obstacles |
| 14 | **Off-camber Curve** | 14 m | ±45° | 5 | negative bank; cheap and treacherous |

## Class: Vertical (8)

| # | Piece | Length | Δpitch | Cost | Notes |
|---|---|---|---|---|---|
| 15 | **Rise Shallow** | 20 m | +12° | 11 | costs speed |
| 16 | **Rise Steep** | 16 m | +30° | 16 | can stall a heavy car |
| 17 | **Drop Shallow** | 20 m | −12° | 11 | free speed |
| 18 | **Drop Steep** | 16 m | −30° | 16 | dangerous free speed |
| 19 | **Crest** | 22 m | +18 then −18 | 14 | launches lightly at speed |
| 20 | **Dip** | 22 m | −18 then +18 | 14 | compresses; grip spike at the bottom |
| 21 | **Spiral Up** | 44 m | helix, +1 turn, +18 m | 26 | gains altitude in a small footprint |
| 22 | **Spiral Down** | 44 m | helix, −1 turn, −18 m | 24 | |

## Class: Roll (4)

| # | Piece | Length | Δroll | Cost | Notes |
|---|---|---|---|---|---|
| 23 | **Bank L** | 14 m | −25° | 8 | sets up the next curve |
| 24 | **Bank R** | 14 m | +25° | 8 | |
| 25 | **Corkscrew L** | 40 m | −360° | 28 | spectacle piece, holds speed |
| 26 | **Corkscrew R** | 40 m | +360° | 28 | |

## Class: Air (5)

| # | Piece | Length | Effect | Cost | Notes |
|---|---|---|---|---|---|
| 27 | **Kicker** | 10 m | +15° launch, then gap | 12 | short ballistic hop |
| 28 | **Long Gap** | 6 m | gap of up to 45 m | 20 | needs a landing within tolerance |
| 29 | **Landing Pad** | 20 m | double width, 25° tolerance | 14 | forgiving receiver |
| 30 | **Loop** | 56 m | full 360° pitch | 34 | requires ≥ 34 m/s entry or the car falls |
| 31 | **Launch Rail** | 18 m | boost + 25° launch | 24 | the big-air combo piece |

## Class: Surface (4)

| # | Piece | Length | Effect | Cost |
|---|---|---|---|---|
| 32 | **Booster Strip** | 16 m | +8 m/s over its length | 15 |
| 33 | **Brake Strip** | 16 m | −10 m/s; the only deliberate slow-down | 9 |
| 34 | **Rumble Strip** | 20 m | −4 m/s, −2 Integrity, very cheap | 2 |
| 35 | **Wide Plate** | 24 m | double width; large grip margin | 16 |

## Class: Structural & Utility (5)

| # | Piece | Length | Effect | Cost |
|---|---|---|---|---|
| 36 | **Junction** | 18 m | leaves a second open socket | 22 |
| 37 | **Merge** | 18 m | joins an existing loose socket back in | 18 |
| 38 | **Scaffold** | 30 m | free, but collapses 3 s after the car passes | 0 |
| 39 | **Repair Plate** | 20 m | restores 25 Integrity as the car crosses | 26 |
| 40 | **Adjustable Curve** | 16 m | player picks Δyaw in 15° steps, ±90° | 30 |

## World-locked pieces

Unlocked with their world and only legal there (or in Endless once earned):

| Piece | World | Effect |
|---|---|---|
| **Magnet Strip** | Magnetite | the car adheres regardless of orientation |
| **Wall Transition** | Magnetite | rotates the gravity frame 90° onto a wall |
| **Ceiling Transition** | Magnetite | inverts the gravity frame |
| **Beacon** | Haze | extends visible range by 60 m for 8 s |
| **Anchor** | Rundown | the decay wave will not consume this piece |
| **Lift** | Updraft | vertical elevator, +30 m, zero horizontal travel |

## Design rules the catalog obeys

1. **Every turn is a speed tax.** There is no piece that changes direction for free. The
   only way to turn fast is to have banked *beforehand*, which costs a separate piece and
   its own runway.
2. **Free speed is always downhill and always a trap.** Drops are cheap and feel
   generous; they set up the corner that kills you.
3. **The cheapest pieces are the worst pieces.** Rumble Strip, Off-camber, Narrow Bridge
   and Scaffold exist so that a Material-starved player has an ugly way out.
4. **Nothing has a hidden number.** Every value in this table is visible on the piece card
   in-game, and the ghost preview shows the resulting speed exactly.
5. **L/R symmetry is real symmetry.** Mirrored pieces are the same struct with a negated
   angle, not two hand-tuned entries. The validator enforces this.
