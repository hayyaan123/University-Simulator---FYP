# CLAUDE.md

Context for Claude Code when working in this repo. Read this first, then the docs it links to.

## Project

University Simulator 2026 is a Monash final year project (FIT3161/FIT3163/FIT3188). It is a **discrete-event campus simulation** in **Godot 4.7 + GDScript**. Students follow timetables, walk between buildings (so travel time can make them late), and decide whether to attend. Adjustable parameters change the outcome, and a dashboard shows attendance, lateness, room use and crowding. There is no end-game: it's a what-if tool.

- **Semester 1 (now):** rule-based prototype due at Week 12.
- **Semester 2:** small ML models (logistic regression, decision trees) trained in Python on OULAD / UCI Dropout data plus sim logs, exported to JSON, and **run in GDScript** (`MLDecision.gd`). A Python sidecar comes later, only if time allows. We don't use ONNX, C#, or GDExtension plugins.
- The technical contribution is the scheduling, travel time and continuous-time mechanics. Visuals support the explanation; they don't replace it.

## Commands

```bash
# Run all tests (GUT must be installed in addons/gut — see docs/CONTRIBUTING.md)
godot --headless -s addons/gut/gut_cmdln.gd

# Run one test file
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_sim_engine

# Re-import after adding class_name scripts (updates the global class cache)
godot --headless --import
```

On Windows the executable is something like `Godot_v4.7.2-stable_win64.exe`. Use the full path, or ask the user where Godot is installed.

## Architecture (full detail: docs/ARCHITECTURE.md)

- Time is a `float` in minutes from Monday 00:00 (`SimTime`).
- `SimEngine` (RefCounted) owns the `EventQueue` (min-heap on time, then seq) and applies the travel, lateness and attendance rules. It has **no Node, scene or UI dependencies**.
- `DecisionModel.decide(student, context, rng) -> Action` (`ATTEND_NEXT`, `SKIP_NEXT`, `LEAVE_CAMPUS`). The model decides *what*; the engine decides *when* and *how long*. Rules and ML models both extend this class.
- `DecisionContext.to_features()` is the single feature vector used for decisions, logging and ML training. Don't rename its keys once data has been logged.
- Autoloads: `Params` (all adjustable values plus `SPECS` for ranges and UI), `EventBus` (all cross-system signals), `Stats` (aggregates from signals).
- `SimRunner` (Node) drives the engine in real time. Tests and headless runs call `engine.advance_to()` / `engine.run_to_end()` directly.
- UI and MapView only listen to `EventBus` and read `Stats` / `Params`. They never change engine state directly.

## Rules to follow

- Follow **docs/CODE_STYLE.md**: static typing everywhere, PascalCase file names that match `class_name`, snake_case members, `_private`, `##` doc comments, tabs.
- **All randomness goes through the run's `RandomNumberGenerator`** (`engine.rng`, passed to decision models). Never use `randf()`, `randi()` or `randomize()`.
- **No magic numbers.** Anything a user could tune becomes a `Params` var and a `SPECS` entry (and goes in `data/scenarios/default.json`). Fixed constants are named, with their source in a comment.
- A new signal goes in `EventBus.gd` with typed arguments and gets listed in docs/ARCHITECTURE.md.
- A change to a data format goes in the same change as `docs/DATA_FORMATS.md`.
- Every rule change in `sim/` or `decisions/` needs a GUT test in `tests/unit/`. Use `FakeCampus` / `FixedDecision` from `tests/helpers/`.
- Run the tests before saying a change is done.
- Keep `sim/Campus.gd`'s public API stable. SimEngine only calls `entrance_id()` and `travel_minutes()`.
- Keep performance in mind: 5,000 students. Draw students with MultiMesh, pre-compute all-pairs building distances, and refresh the UI once per frame.

## Working style

- Make small, focused changes that fit in one pull request. Branch names look like `feature/<name>-<task>` (see docs/CONTRIBUTING.md).
- Prefer surgical edits to existing files over rewrites.
- Give complete, working code, not stubs. If something is intentionally left for a teammate's task in docs/ROADMAP.md, say so explicitly.
- Don't treat open decisions as settled. Check docs/DECISIONS.md and ask when unsure.
- Write team-facing text (docs, PR descriptions, issues) in simple, clear language.

## Where things are

| Need | Look in |
| --- | --- |
| How the sim works | docs/ARCHITECTURE.md |
| Style rules | docs/CODE_STYLE.md |
| JSON / CSV / model formats | docs/DATA_FORMATS.md |
| Planned parameters and effects (proposal) | docs/PARAMETERS.md |
| Who owns what, sprint tasks | docs/ROADMAP.md |
| Why we chose X | docs/DECISIONS.md |
| Setup, git, PRs | docs/CONTRIBUTING.md |
