# 01 — Core Loop and Systems

## Pitch

A 3D racer in which you never steer. The car drives itself, forward, always, and it is
already moving when the level starts. What you control is the **track** — you lay it
piece by piece into empty space ahead of the car, choosing from a hand of parts, while
the car closes the distance behind you.

You are not driving the line. You are building it, seconds before you arrive on it.

## The single verb

The built track has exactly **one open socket** at its head. Choose a piece from your
hand and it snaps to that socket: no free 3D placement, no dragging in space. The
decision is *which* piece, never *where*. The whole game is playable with one thumb.

Each piece carries a fixed exit transform relative to its entry — a Δyaw, Δpitch, Δroll
and a length. Appending a piece is a transform multiplication, so the track is a chain
and the head socket is the running product. This is why the core is cheap to compute and
trivial to test.

## Where the spatial challenge lives

Because the car goes wherever the track goes, **building is steering**. A level is a
volume of space containing:

- a **start plinth** with 60 m of pre-built track (your opening buffer),
- a **goal gate** somewhere far away in three dimensions,
- **checkpoint rings** that must be passed, in order,
- **cores** — optional collectibles that are also the level's economy,
- **forbidden volumes** — energy fields, terrain, void — that the track may not enter,
- **hazards** — moving obstacles, collapsing regions, gravity wells.

Getting a ribbon from the plinth to the gate through all of that, at a speed you can
survive, is the game.

## The three clocks

Every failure state is a clock running down. All three are visible at all times.

### 1. Runway — the time clock

`runway = (length of built track ahead of the car) − (car's arc position)`

Displayed **in seconds at the current speed**, not in metres, because seconds are what
the player actually spends. When runway hits zero the car runs off the end of the world.

This produces the central tension of the design:

> The pieces you need in order to *go somewhere* — curves, ramps, chicanes — are short
> and burn runway. The pieces that *buy you time to think* — long straights — go nowhere.

Every placement is a trade between progress and breathing room. Panic-building straights
is survivable but never reaches the gate; building only what you need means placing
pieces with two seconds of runway left.

### 2. Material — the resource clock

Placing a piece costs Material. You earn it back by:

| Source | Yield |
|---|---|
| Passing a checkpoint ring | large |
| Collecting a core | medium |
| Clean landing after a jump (within angle tolerance) | small |
| Near-miss with a forbidden volume (< 2 m) | small |
| Sustained speed above the car's efficiency band | trickle |

Running out of Material means you cannot place, which drains runway, which kills you. So
the route is never allowed to be purely safe — it has to keep touching the economy.

### 3. Integrity — the damage clock

Scraping a wall, landing badly, clipping a hazard or riding the rumble strip costs
Integrity. At zero, the car breaks up. Integrity does **not** regenerate inside a level;
Repair Plates are pieces you must choose to spend Material and runway on.

## Physics — you build a problem for your future self

The car is simulated as a point mass constrained to the ribbon:

- **Longitudinal**: `dv/dt = F_engine/m − g·sin(pitch) − k_drag·v² − k_roll`
  Downhill accelerates, uphill decelerates, drag caps top speed.
- **Cornering**: required lateral acceleration is `v²·κ` where κ is the ribbon's
  curvature. Available grip is `μ·g·cos(bank) + g·sin(bank)`. Bank a curve and you can
  take it far faster; leave it flat and the same corner throws you off.
- **Sliding**: when demand exceeds grip, the car's lateral offset within the track width
  grows. Past the edge, it leaves the ribbon.
- **Airborne**: gap pieces launch the car ballistically. Landing requires the incoming
  velocity vector to be within tolerance of the landing piece's surface normal, or
  Integrity is lost — or the car cartwheels off.

The consequence is the thing that makes this game deep rather than fiddly: **the shape
you lay down now determines the speed you will arrive with in eight seconds.** Three
descents in a row feel great and then deliver you into your own hairpin at 40 m/s. A
long straight is safe *and* is the thing that makes the next corner lethal.

### The ghost preview

Before committing, the selected piece renders as a translucent ghost at the socket with
a **predicted speed readout at its exit**, colour-coded:

- green — comfortably within grip,
- amber — within 15 % of the limit,
- red — the car will leave the track.

The prediction runs the same integrator as the real simulation, one piece ahead. It is
never wrong and never hidden. The skill is not in guessing physics; it is in planning
under time pressure with full information.

## The hand and the deck

- **Deck**: before the level you assemble 12 piece types with counts, from those you have
  unlocked. This is a strategic layer that happens with the clock stopped.
- **Hand**: 5 slots, drawn from the deck.
- **Draw delay**: after placing, the empty slot refills after `t_draw` seconds (car- and
  part-dependent, ~1.4 s base). Placing four pieces in quick succession leaves you
  holding one.
- **Discard**: cycle one piece for Material, on a cooldown. This is the pressure valve
  and the main reason a bad hand is recoverable.
- When the deck runs out, it reshuffles — decks are pools, not finite hands.

Deck-building is where replayability lives. A deck heavy in long straights gives you time
to think but nothing to manoeuvre with; a deck of sharp curves navigates anything and
never lets you breathe.

## Junctions

The **Junction** piece leaves a *second* open socket behind. Only one socket is active —
the one the car is heading toward — but you may spend idle moments building the inactive
branch. Used for:

- return loops that let you re-collect a core you missed,
- alternate routes past a hazard that only opens periodically,
- shortcuts that a later checkpoint sends you back through.

Junctions are what turn a level from a snake into architecture. They are also the main
advanced-play skill: building a branch costs runway you are not currently spending.

## Level flow

```
Deck select (clock stopped)
  └─ Level starts: 60 m of plinth track, car already rolling at 12 m/s
       └─ loop: choose piece → ghost preview → commit → car advances
            · checkpoints in order
            · cores optional
            · Material, Runway, Integrity all draining
       └─ Goal gate crossed → Results
```

## Scoring — three stars

| Star | Condition |
|---|---|
| ★ | Reach the goal gate |
| ★★ | Use no more than the level's **par piece count** |
| ★★★ | Collect every core **and** finish under the target time |

Par is deliberately tight: it forbids the "wall of long straights" solution and forces at
least one efficient line. Target time forbids the crawl.

## What this is not

- Not an endless runner: levels are hand-authored, finite, and have a correct-ish answer.
- Not a track editor: you never place freely, never undo a committed piece, never see the
  whole route at once.
- Not a driving game: there is no steering input at all. There is a lateral nudge (±) for
  fine positioning within the track width, and that is the only direct car control.
