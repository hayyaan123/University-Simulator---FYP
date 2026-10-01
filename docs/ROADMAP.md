# Roadmap

**Semester 1:** a working prototype by Week 12. **Semester 2:** the Good-to-have systems, then ML decisions running inside the simulation.

## Scope

The tiers follow the first-meeting whiteboard and the supervisor's feedback on 2026-10-01 (decisions #10 to #14).

| Priority | Feature | Semester | Status |
| --- | --- | --- | --- |
| Must | 2D campus map: buildings, rooms with capacity, walking paths with distances | 1 | First version built |
| Must | Units with class slots and enrolment numbers | 1 | Placeholder data |
| Must | Timetable generator: units, class slots, room allocation, no clashes | 1 | First version built |
| Must | Student agents, each with their own timetable, moving between rooms | 1 | Built |
| Must | Travel between classes: shortest path, on time / late / too late | 1 | Built |
| Must | Simulation clock: play, pause, speed, fixed random seed | 1 | Built (temporary HUD) |
| Must | Student states: grades, stress, energy, satisfaction | 1 | Built, except grades; numbers are placeholders |
| Must | Rule-based decisions: attend, skip, study, get food, leave campus | 1 | Attend, skip and leave built; study and food to build |
| Must | Assessments and deadlines; grades measured at each assessment | 1 | To build |
| Must | Errands in free time: knapsack picks the stops, TSP orders them | 1 | To build |
| Must | Continuous run across semesters: calendar, breaks, exam period | 1 | To build |
| Must | Parameter panel with the 11 Must parameters | 1 | To build |
| Must | Live dashboard and an end-of-semester report | 1 | To build |
| Good | Lecturers and tutors: staff reliability, tutors per unit | 2 | |
| Good | Lecture recordings | 2 | |
| Good | Friend groups and friend influence | 2 | |
| Good | Changing a student's units between semesters (knapsack on workload) | 2 | |
| Good | Small ML models running in GDScript from JSON | 2 | |
| Good | Data logging to CSV (matches OULAD/UCI columns) | 2 | |
| Good | Save/load scenarios and compare two runs | 2 | |
| Good | Path crowding that slows walking (fixed formula) | 2 | |
| Good | 3D buildings and rooms, only after everything above works | 2 | |
| Nice | Python sidecar for larger models | 2 | |
| Nice | Collision detection, crowd heatmap | 2 | |
| Nice | Graphics polish and music | 2 | |

## Areas of ownership

Each member owns one main area and reviews the areas their work connects to. The folders match `docs/ARCHITECTURE.md`.

| Member | Semester 1 | Folders | Semester 2 |
| --- | --- | --- | --- |
| Peshaant | SimEngine, calendar, student states, rule decisions, integration, final merges | `sim/core/`, `sim/students/`, `decisions/`, `autoload/` | Friend influence; ML integration in GDScript; Python sidecar if time allows |
| Hayyaan | Campus and pathfinding, timetable generator and room allocation, errand planner | `sim/campus/`, `sim/timetable/`, `sim/errands/` | Lecturers and tutors; model training in Python, JSON export |
| Siw | MapView, ParamPanel, Dashboard, semester report, scene wiring | `scenes/`, `ui/` | Run comparison, scenario save/load, UI polish |
| Shuyu | Campus, unit, assessment and calendar data; tests for timetable, paths, errands and states | `data/`, `tests/` | Lecture recordings data; data logging, OULAD/UCI column mapping |
| Arya | Research-based values with sources (defaults and effect sizes), map art, test runs and bug reports | `docs/PARAMETERS.md`, `docs/STUDENT_MODEL.md` | Experiments and results for the report |

Everyone writes the report sections for their own area, takes turns on meeting minutes, and records their own vlogs.

## Semester 1 sprints

Sprints 1 and 2 are mostly done. First versions of the campus, timetable generator and map were built together in one change so the whole loop runs; their owners now take them over.

| Sprint | Goal | Peshaant | Hayyaan | Siw | Shuyu | Arya |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Skeleton runs | Project setup, Params/EventBus/Stats, EventQueue, SimEngine core (**done**) | `Campus.gd`: load JSON, graph, Dijkstra (**first version done**) | Main scene, MapView draws buildings and paths (**first version done**) | `campus.json` (**done**, from OpenStreetMap) | Default values with sources |
| 2 | Students move | Run bootstrapped in Main; engine hooked to MapView (**done**) | `TimetableGenerator.gd`, no clashes (**first version done**) | Students drawn with MultiMesh (**done**); play/pause/speed in the real UI | `units.json` checked against the handbook; clash test cases | Test runs, bug reports, map art |
| 3 | States + errands | Student states and `StateEffects` (**done**); `RuleDecision`: attend, skip, leave (**done**), study and food (with the errand planner); `Params` trimmed to the agreed list, with commute and resilience added (**done**) | `ErrandPlanner` (knapsack + TSP); food outlets with queues; room allocation as knapsack; students turned away from full rooms | `Stats` for the four states; Dashboard charts | Food outlets and assessments in the data files; GUT tests for errands and state effects | A source or stated assumption for every effect size; check results against expected values |
| 4 | Semesters + parameters | `Calendar`: weeks, breaks, exams, week-by-week scheduling, no end time; assessments and grades; 5,000-student performance | Path closures with rerouting; edge cases | ParamPanel from `Params.SPECS`; semester report screen | Calendar presets; demo scenarios (normal semester, clustered deadlines, early starts with long commutes) | Demo script, screenshots, report figures |

If time runs short, cut in this order: path closures, the Trimester preset, yearly intake and graduation. The four states and the 11 parameters stay.

### Week 12 checklist

- [ ] Changing any of the 11 Must parameters and pressing Reset gives a different, repeatable result
- [ ] Every Must parameter moves at least one of the four metrics
- [ ] 500 students run two full semesters without errors, and 5,000 run smoothly at high speed
- [ ] The end-of-semester report shows grades, stress, energy and satisfaction
- [ ] The dashboard shows attendance, lateness, room use and food queues
- [ ] The demo shows pathfinding, knapsack and TSP working on the map
- [ ] Three demo scenarios, compared in the presentation

## Semester 2 phases

| Phase | Weeks | Work | Lead |
| --- | --- | --- | --- |
| 1 | 1–4 | Lecturers and tutors, lecture recordings, friend groups; the 4 Good parameters added to the panel | Hayyaan and Peshaant; panel: Siw |
| 2 | 2–4 | CSV logging, column mapping to OULAD/UCI, cleaning | Shuyu, with Hayyaan |
| 3 | 4–7 | Train models (logistic regression, trees), check accuracy, export JSON | Hayyaan |
| 4 | 6–9 | `MLDecision.gd`, JSON model loaders, rules/ML toggle | Peshaant |
| 5 | 8–10 | Rules vs ML run comparison on the dashboard; scenario save/load | Siw, with Arya |
| 6 | 9–11 | Python sidecar (only if Phase 4 is done by Week 8) | Peshaant, with Hayyaan |
| 7 | 10–12 | Experiments, report results, final demo | Arya + everyone |

## Open decisions

- [ ] The effect sizes in `docs/STUDENT_MODEL.md` (a number and a justification per row)
- [ ] Which part of the sim uses AI
- [ ] Does the app show the campus as "Monash University Malaysia", or a neutral name?
- [ ] Do we commit Godot's `.gd.uid` files? (Godot 4.4 and later recommends it)
- [ ] Sprint dates for Sprints 3 and 4
