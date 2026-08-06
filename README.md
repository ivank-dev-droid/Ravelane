# Ravelin

A 3D racer in which you never steer.

The car drives itself, forward, always, and it is already moving when the level starts.
What you control is the **track** — you lay it piece by piece into empty space ahead of the
car, choosing from a hand of parts, while the car closes the distance behind you.

Because the car goes wherever the track goes, building *is* steering. And because the shape
you lay down now decides the speed you will arrive with in eight seconds, you are always
building a physics problem for your future self.

## The three clocks

| Clock | Runs out when |
|---|---|
| **Runway** — track ahead, measured in seconds at the current speed | the car runs off the end of the world |
| **Material** — spent to place, earned by checkpoints, cores and clean landings | you can no longer build, which drains the first clock |
| **Integrity** — scrapes, bad landings, rumble strips | the car breaks up |

The tension is that the pieces which take you *somewhere* — curves, ramps, chicanes — are
short and burn Runway, while the pieces that buy you *time to think* go nowhere.

## Where things are

```
Packages/RavelinCore/   every rule of the game; pure Swift, no Apple imports, tested on Linux
Tools/RavelinCLI/       solver, level generator, balance sweeps, SVG track renderer
App/                    iOS — RealityKit and SwiftUI only, renders a snapshot, decides nothing
design/                 the full design document, six parts
```

`CLAUDE.md` is the working brief: architecture rules, determinism guarantees, the geometry
model, and the traps already fallen into.

## Building

```
make test      # 145 tests, Linux or macOS
make verify    # every level still has a solution that drives
make sweep     # archetype balance sweep
make gen       # generate the Xcode project (macOS)
```

`swift run --package-path Tools/RavelinCLI RavelinCLI render --out out` writes orthographic
plan, elevation and section projections of a track as SVG, so geometry is reviewable without
a renderer or a Mac.

## Guarantees the build enforces

- **145 tests** run on x86-64 Linux and ARM64 macOS in CI on every push.
- **Five golden fingerprints** — transform chains, catalog geometry, fixed-point arithmetic
  and a full simulated run — must reproduce bit-for-bit on both architectures. The
  simulation uses Q32.32 fixed point and a project-owned CORDIC rather than `Double` and
  `libm` precisely so this holds.
- **A purity scan** fails the build if `Double`, `Float`, `Foundation` or a bare `libm` call
  reaches the simulation.
- **60 levels, 60 verified solutions.** A level whose stored solution does not survive the
  real physics is never written out.
- **The iOS app is compiled** by `xcodebuild` against the iOS Simulator in CI, so the
  RealityKit layer is never unverified code.

## State

Milestones 0–4 and the first pass of 6 are done. What works: the full simulation, 46 track
pieces, 12 cars, 18 parts, deck and hand, 60 levels across 6 worlds, star scoring, and an
iOS app that builds and runs the game loop.

Not done yet: junction branch building, the 12 parts whose systems do not exist, audio and
haptics, and deck-archetype balance — the sweep currently shows most archetype/world
combinations failing, which is the next real piece of work.
