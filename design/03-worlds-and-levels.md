# 03 — Worlds, Levels, Hazards

## Six worlds, six rule changes

A world is not a skybox. Each one changes a physical or informational rule, invalidates
part of your deck, and unlocks pieces that only make sense there.

### 1. Foundry — levels 1–10
Baseline. Standard gravity (9.81), wide default track, generous Material, no hazards
beyond static geometry. This world teaches the three clocks, one at a time: levels 1–3
have infinite Material, 4–6 introduce it, 7–10 add Integrity.

*Unlocks:* the Straight, Turn and Vertical classes.

### 2. Updraft — levels 11–20
Gravity 3.6 m/s². Jumps carry three times as far, ballistic arcs are long and lazy,
landings are gentle. But **uphill costs almost nothing and downhill gives almost
nothing**, so the entire speed economy inverts: you can no longer buy velocity with
altitude, and Booster Strips become the only real accelerant. Track is narrower.

*Unlocks:* Kicker, Long Gap, Landing Pad, Launch Rail, **Lift**.
*Hazard:* drifting debris clouds — slow-moving forbidden volumes.

### 3. Magnetite — levels 21–32
The car adheres to the ribbon regardless of orientation. **Gravity is relative to the
track's surface normal**, so you can build up walls, across ceilings, and through
full inversions without a Loop's entry-speed requirement. Levels are interiors —
box volumes where the walls are usable surface, not boundary.

This is the world where the game stops being a road and becomes architecture. It is also
where the physics core earns its keep: the same integrator runs, only the gravity vector
is now `-normal · g` instead of `(0,-g,0)`.

*Unlocks:* Magnet Strip, Wall Transition, Ceiling Transition, Corkscrew L/R.
*Hazard:* polarity fields that periodically repel the track — timed windows.

### 4. Haze — levels 33–42
Visible range collapses to 45 m. You are building into fog, and the checkpoint markers
are the only thing that pierce it. A **scanner** ping (on a cooldown) briefly reveals
geometry within 120 m; Beacon pieces reveal permanently along their stretch.

The mechanical change is informational rather than physical, and it is the hardest world
to build for, because the ghost preview can only show you what is inside the fog.

*Unlocks:* Beacon, Adjustable Curve.
*Hazard:* unmarked forbidden volumes — the fog hides them until scanned.

### 5. Rundown — levels 43–52
A **decay wave** follows the car, consuming built track at a rising rate. Junction
branches die unless Anchored. You can never go back, and a route that loops through its
own earlier stretch will find that stretch gone.

Decay speed starts at 60 % of the car's speed and rises to 105 % by level 52 — at which
point the wave is faster than you are and the only survival is to keep accelerating.

*Unlocks:* Anchor, Repair Plate, Scaffold.
*Hazard:* the wave itself; plus collapse zones that pre-decay ahead of you.

### 6. Overdrive — levels 53–60
Base speed starts at 45 m/s and the car has no lower gear. Track is at its narrowest,
grip at its lowest, and banking is not optional — an unbanked Sharp Curve is fatal at
these speeds. Every deck here is a banking deck.

The final level, **The Ravelin**, is a single continuous 4 km build through all five
previous worlds' rulesets in sequence, with the ruleset switching at gates.

*Unlocks:* nothing new — Overdrive is the exam.

---

## Level authoring

Levels are **hand-authored data**, not procedural, except in Endless mode. A level file
holds:

```
Level {
  id, world, name, parPieces, targetTime
  plinth        Transform (start frame + 60 m of pre-built track)
  goal          Gate (position, orientation, radius)
  checkpoints   [Gate]           ordered, mandatory
  cores         [Vec3]           optional, 5–12 per level
  volumes       [Volume]         forbidden regions: boxes, spheres, capsules
  hazards       [Hazard]         moving/timed volumes with a period and phase
  deckLimit     Int?             some levels cap deck size or forbid a class
  gravity       Vec3 | .surface
  fogRange      Float?
  decay         DecayProfile?
  startSpeed    Float
  materialStart Int
}
```

**Every level ships with a stored solution** — a piece-ID array that the headless solver
verified reaches the goal within par. This is a hard requirement of the content pipeline:
a level without a verified solution does not build. It also gives the hint system a real
answer to reveal, and gives balance sweeps a baseline to compare player policies against.

## Hazard types

| Hazard | Behaviour |
|---|---|
| **Static volume** | never enterable; terrain, pillars, the level's shell |
| **Pulse field** | forbidden on a period; safe in the gap. Phase is shown as a countdown ring |
| **Drifter** | a volume moving on a fixed path; predictable, blocks a corridor |
| **Crusher** | two volumes closing on a period; the corridor between them narrows |
| **Decay wave** | Rundown's follower; consumes track behind you |
| **Grav well** | bends the car's ballistic arc while airborne; does not affect the track |
| **Scrambler** | shuffles your hand every 12 s while inside its radius |
| **Dead zone** | no Material earned inside; forces you to route around the economy |

## The star curve

Par piece counts are set from the stored solution: `par = solutionLength + slack`, where
slack runs from `+8` in Foundry down to `+1` in Overdrive. Target times are
`solutionTime × 1.25` down to `× 1.08`.

This means the third star is genuinely hard from world 4 onward, and impossible without
understanding the speed-shape relationship — which is the skill the game is about.

## Endless mode

A procedural objective stream: gates spawn ahead at increasing distance and increasingly
awkward relative angles, cores scatter, and the world ruleset rotates every 90 seconds.
Runway pressure ramps continuously. One **daily seed** shared by all local profiles, with
a local leaderboard and a replay of your own best (the run is just an integer array, so a
replay is a few hundred bytes).

Endless is not the main mode and does not gate any unlock. It exists so a player who has
finished 60 levels still has the machine to play with.
