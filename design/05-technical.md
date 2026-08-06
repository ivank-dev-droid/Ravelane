# 05 — Technical Architecture

## 1. The constraint that shapes everything

Development happens on Linux (Ubuntu 26.04, Swift 6.3.3 native). Building and running
happen only on macOS, because RealityKit does not exist on Linux and cannot even be
compiled against there.

Therefore:

> **Every rule of the game lives in `RavelinCore`, a pure Swift package with zero Apple
> imports, which builds and tests on Linux. The RealityKit layer renders a snapshot and
> decides nothing.**

Target: **≥ 85 % of the codebase testable under `swift test` on Linux.**

This is not architectural taste. It is the only way a 3D game gets built on a machine
that cannot run it.

## 2. Why this game suits the split unusually well

The track is a chain of pieces composed by transform multiplication. That means:

- The entire world state is `(plinthFrame, [PieceID], carState)`.
- A run serialises to **an array of integers**. Replays, ghosts, level solutions, solver
  output and regression fixtures are all the same tiny data structure.
- The renderer's job is to turn `[PieceID]` into a mesh. It holds no truth.

A physics-driven 3D game is normally the worst case for a headless-development setup.
This particular one is close to the best case.

## 3. Repository layout

```
Ravelin/
  Packages/RavelinCore/            # pure Swift — Linux — no Apple imports
    Package.swift
    Sources/RavelinCore/
      Math/       Vec3, Quat, Transform3, Spline, Integrator, Fixed
      Track/      Piece, PieceCatalog, TrackChain, Socket, Ribbon, Clearance
      Sim/        CarState, CarSpec, Physics, GripModel, Ballistics, Collision
      Play/       Session, Clocks(Runway/Material/Integrity), Objectives, Scoring
      Deck/       Deck, Hand, DrawModel, PartCatalog
      Level/      Level, Volume, Hazard, LevelCatalog, SolutionVerifier
      World/      WorldRules, GravityModel, DecayModel, FogModel
      Rng/        SplitMix64, WeightedSampler
      Replay/     RunRecord, Ghost
      Save/       SaveFile, Migration
    Resources/    pieces.json cars.json parts.json levels/*.json
    Tests/RavelinCoreTests/
  Tools/RavelinCLI/                # Linux executable: solver, sweeps, level validation
  App/                             # iOS — RealityKit + SwiftUI ONLY
    Render/   TrackMeshBuilder, RibbonLowLevelMesh, CarEntity, GhostEntity, CameraRig
    Views/    GameView, DeckBuilderView, LevelSelectView, SettingsView
    Bridge/   SessionViewModel        <- the only place Core meets RealityKit
    Audio/    EngineSynth, SFXBank, Haptics
  project.yml                      # XcodeGen; .xcodeproj is generated, never committed
  Makefile                         # same commands on both machines
  design/
  CLAUDE.md
```

## 4. Determinism

- **Fixed timestep** of 1/120 s for the car integrator, decoupled from render rate. The
  renderer interpolates; it never advances the sim.
- **No `Double` in the simulation.** Physics runs on `Fixed` — Q32.32 fixed-point. Float
  math differs subtly between x86-64 and ARM64 (FMA contraction, `libm` transcendentals),
  and a run recorded on the Linux box must replay identically on an iPhone or the whole
  replay/solution/ghost system is worthless. Fixed-point makes that a guarantee rather
  than a hope.
  - `sin`/`cos`/`atan2` come from a project-owned CORDIC table, not `libm`.
  - This is the single most important technical decision in the project. It costs perhaps
    a day and removes an entire category of "works on my machine" from a codebase
    developed on one architecture and shipped on another.
- **One RNG stream per session**, `SplitMix64`, with derived sub-streams keyed by purpose
  (`seed ⊕ hash(purpose) ⊕ index`) so adding a new random consumer later does not shift
  every existing roll.
- **No dictionary iteration** anywhere in simulation order.

## 5. The ribbon

A piece contributes a length of ribbon: a swept rectangle along a curve, with a roll
profile. Core computes it as a **centreline spline plus a frame field**:

- centreline: cubic Hermite between entry and exit frames, arc-length reparameterised to
  a lookup table (128 samples per piece) so `position(s)` and `curvature(s)` are O(1);
- frame: parallel-transport frames along the centreline, then the piece's bank applied as
  an extra roll — parallel transport avoids the twist artefacts a naive up-vector Frenet
  frame produces on corkscrews and loops;
- width: constant per piece.

Everything the physics needs — `position`, `tangent`, `normal`, `curvature`, `bank`,
`width` at arc length `s` — comes from this. The renderer consumes exactly the same
structure to build vertices, so **the thing you see and the thing you collide with cannot
diverge**.

## 6. Clearance and self-intersection

A newly proposed piece must not intersect existing track. Naive pairwise checks are
O(n²); a level's track reaches ~400 pieces.

Approach: each piece registers a small set of **capsules** (3–6, along its centreline) in
a uniform spatial hash with 8 m cells. A candidate placement queries only the cells its
own capsules touch. Vertical clearance is allowed — passing over your own track at ≥ 6 m
separation is legal and encouraged (that is how the architecture in Magnetite works).

This is pure geometry and fully Linux-testable, with a fixture set of known-bad placements.

## 7. Content as data

`pieces.json`, `cars.json`, `parts.json`, and one JSON per level. A validator runs in CI
and in `swift test`:

1. every piece's L/R mirror is exactly a negated angle;
2. every level has a **stored solution** that the verifier replays to the goal within par;
3. no level references an unlocked-later piece;
4. every level's cores are reachable from at least one legal route;
5. Material earned along the stored solution ≥ Material spent (levels are winnable).

Rule 2 is the important one. **A level that has no verified solution does not build.**

## 8. RavelinCLI — the Linux workhorse

```bash
swift run RavelinCLI verify   --all                    # validate every level + solution
swift run RavelinCLI solve    --level foundry_07 --budget 200000
swift run RavelinCLI sweep    --world updraft --policy scalpel --runs 5000
swift run RavelinCLI replay   --record run.json --assert-deterministic
swift run RavelinCLI render   --level magnetite_03 --svg out.svg   # top/side ortho
```

- **solve** — a beam search over piece sequences, scored by distance-to-next-objective,
  survivable speed, and Material. It is the level-validation oracle and the hint system's
  source of truth.
- **sweep** — runs scripted building policies (runway / scalpel / air / bank) thousands of
  times to find which levels are unbeatable by an archetype, and where par is wrong.
- **render --svg** — orthographic projections of a level and its solution, written as
  SVG. This is how a level gets reviewed **without a Mac and without a renderer**. It is
  worth building on day one.

## 9. The UI bridge

```swift
public struct StepResult {
    public let car: CarState
    public let clocks: Clocks
    public let events: [SimEvent]      // .placed, .checkpoint, .core, .scrape, .land, .crash
    public let trackRevision: Int      // bumps only when geometry changed
}
public func step(_ session: inout Session, dt: Fixed) -> StepResult
```

`SessionViewModel` owns a `Session`, calls `step` at 120 Hz on a display link, and hands
snapshots to RealityKit. `trackRevision` is what tells the renderer to regenerate mesh —
so mesh rebuilds happen on placement, not per frame.

## 10. Rendering plan (Mac-side)

- **RealityKit**, because SceneKit was soft-deprecated at WWDC25 and is in maintenance.
- The ribbon is one **`LowLevelMesh`** whose vertex buffer is rewritten by a Metal compute
  shader when `trackRevision` changes. 400 pieces × 128 samples is well inside budget, and
  a `LowLevelMesh` avoids rebuilding a `MeshResource` from scratch on every placement —
  which is the naive approach that would stutter.
- One material for the ribbon with an emissive edge-glow driven by a per-vertex attribute
  (piece class → colour). This is what carries the neon look with a single draw call.
- Ghost preview is a second, small `LowLevelMesh` with a translucent material.
- Car, cores, gates: USDZ entities. Hazards: instanced primitives.
- Budget: 60 fps on iPhone 12; 120 fps on ProMotion devices.

## 11. Save format

Versioned JSON, atomic write. Holds unlocks, stars, parts, deck presets, settings,
statistics, and **run records as integer arrays**. A full level replay is a few hundred
bytes, so keeping every personal best is free.

## 12. Toolchain

| Machine | Setup |
|---|---|
| **Linux (dev)** | Swift 6.3.3 via swiftly (`--platform ubuntu24.04` override for 26.04) |
| **macOS (build)** | Xcode 16+, `brew install xcodegen`, `xcodegen generate` |
| **Shared** | private GitHub repo; `.xcodeproj` generated, never committed |

`make test`, `make verify`, `make sweep`, `make gen` work identically on both machines.
