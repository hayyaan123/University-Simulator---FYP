# Code style

We follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), plus the rules below. When in doubt, match the code around you.

## Typing

- **Static types everywhere.** Variables, parameters, return types, and loop variables.
  ```gdscript
  var travel: float = campus.travel_minutes(from, to)
  func next_session(time: float) -> ClassSession:
  for student: Student in students:
  ```
- Use typed arrays (`Array[Student]`). For dictionaries, write the key and value types in a comment: `var _by_id: Dictionary = {}  # int -> Student`.
- `-> void` on functions that return nothing.
- The project warns on untyped declarations. Fix the warning; don't silence it.

## Naming

| Thing | Style | Example |
| --- | --- | --- |
| Files (scripts, scenes) | PascalCase, same as class | `SimEngine.gd`, `MapView.tscn` |
| Test files | `test_` + snake_case | `test_sim_engine.gd` |
| Classes | PascalCase + `class_name` | `class_name ClassSession` |
| Functions, variables | snake_case | `schedule_next_decision` |
| Private members | leading underscore | `_queue`, `_on_class_end()` |
| Constants, enum values | UPPER_SNAKE_CASE | `MINUTES_PER_DAY`, `State.IN_CLASS` |
| Signals | past tense, snake_case | `student_arrived` |
| Signal handlers | `_on_<source>_<signal>` | `_on_student_attended` |
| StringName ids | `&"..."` literals | `&"ENTRANCE"` |

Put units in names when a value has one: `walking_speed_m_per_min`, `lecture_minutes`, `distance_m`.

## File layout (top to bottom)

1. `class_name`, then `extends`
2. `##` doc comment: what the class is for, in one to three lines
3. signals → enums → constants → exported vars → public vars → private vars → `@onready` vars
4. `_init`, `_ready`, then other built-in callbacks
5. public methods
6. private methods (`_name`)

Leave two blank lines between functions and use tabs for indentation (see `.editorconfig`).

## Rules for this project

- **No magic numbers.** Anything a user might tune goes in `Params`. Fixed values are named constants with a comment saying where they come from.
- **All randomness goes through the run's `RandomNumberGenerator`.** Never call `randf()`, `randi()` or `randomize()`. Otherwise runs can't be repeated.
- **Core code has no Node or UI dependency.** `sim/` and `decisions/` extend `RefCounted` and only talk to Params and EventBus.
- **UI never changes simulation state directly.** It changes Params and calls SimRunner (play, pause, reset).
- **Signals over direct calls** between systems. Connect in `_ready`, and disconnect if the listener can be freed before the emitter.
- **Keep functions short.** Aim for under about 40 lines. Split helpers out when a function does two things.
- **Comments explain why, not what.** Every public method gets a `##` doc comment if its purpose isn't obvious from the name.
- **Errors:** `push_error()` for bad data, `assert()` for programmer mistakes (asserts are removed in release builds).
- **Scenes:** one root script per scene, small scenes composed together, no logic in `.tscn` files.

## Tests

- Framework: GUT 9.x. Tests go in `tests/unit/test_<thing>.gd` and extend `GutTest`.
- Test the rules, not the rendering: timetables, pathfinding, the event queue, lateness, decisions.
- Use `tests/helpers/` fakes (for example `FakeCampus`) instead of real data files where you can.
- Call `Params.reset_to_defaults()` in `before_each` if the test changes Params.
- Name tests as sentences: `test_far_back_to_back_class_makes_student_late`.

## Python (tools/)

- Python 3.11+, PEP 8, type hints, `black` formatting.
- Scripts take paths as arguments; don't hard-code paths from your own machine.
- Pin package versions in `tools/requirements.txt`.
