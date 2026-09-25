# Contributing

## Setup (once)

1. Install **Godot 4.7.x, Standard build** (not .NET) from [godotengine.org](https://godotengine.org/download). Everyone uses the same minor version.
2. Clone the repo and open `project.godot` in Godot.
3. Install GUT for tests: open the AssetLib tab, search "GUT", and install version 9.x into `addons/gut`. Then go to Project → Project Settings → Plugins and enable it. (`addons/gut/` is git-ignored, so everyone installs it locally.)
4. Check that the tests run (see below).

## Running

- **Game:** press F5 (the main scene is `scenes/Main.tscn`).
- **Tests (editor):** open the GUT panel at the bottom, then click Run All.
- **Tests (command line):**
  ```
  godot --headless -s addons/gut/gut_cmdln.gd
  ```
  Settings are in `.gutconfig.json`.

## Git workflow

- `main` is protected: nobody pushes to it directly.
- One branch per task: `feature/<name>-<task>`, `fix/<name>-<bug>`, `docs/<name>-<topic>`.
  Example: `feature/siw-dashboard`, `fix/shuyu-timetable-clash`.
- Keep branches short-lived (a few days). Pull `main` into your branch often.
- Commit messages: imperative and specific. Example: `Add Dijkstra distances to Campus`, not `update`.

## Pull requests

1. Open a PR into `main` and fill in the template.
2. Link the issue (`Closes #12`).
3. Get **one approval** from a teammate, ideally the person whose code yours connects to.
4. The author merges after approval ("Squash and merge").

Reviewers check that the change works, is tested, follows `docs/CODE_STYLE.md`, and doesn't break the layer rules in `docs/ARCHITECTURE.md`.

## Scenes and conflicts

`.tscn` files merge badly. To avoid conflicts:

- Each scene has one owner at a time (listed in the issue).
- Build the UI from small scenes (MapView, ParamPanel, Dashboard), each with its own owner.
- If you need to change someone else's scene, tell them first or pair on it.

## Tasks

- GitHub Issues hold tasks, and the GitHub Project board has the columns **To do → Doing → Review → Done**.
- Every task in `docs/ROADMAP.md` becomes an issue using the Task template.
- Move your card when you start a task and when you open the PR. We review the board at the weekly meeting.

## Definition of done

A task is done when it runs in Godot 4.7 with no new errors, has tests where it makes sense, is reviewed and merged, and has been shown at the sprint demo.
