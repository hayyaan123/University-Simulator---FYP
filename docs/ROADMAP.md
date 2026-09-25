# Roadmap

**Semester 1:** a working prototype by Week 12. **Semester 2:** ML decisions running inside the simulation.

## Scope

| Priority | Feature | Semester |
| --- | --- | --- |
| Must | 2D campus map: buildings, rooms, walking paths with travel times | 1 |
| Must | Student agents with their own weekly timetable | 1 |
| Must | Timetable generator (units, slots, room allocation) | 1 |
| Must | Simulation clock: play, pause, speed, fixed random seed | 1 |
| Must | Travel between classes: shortest path, on time / late / too late | 1 |
| Must | Rule-based decisions: attend, skip, leave campus | 1 |
| Must | Parameter panel that changes the run | 1 |
| Must | Stats dashboard (attendance, lateness, room use, crowding) | 1 |
| Good | Data logging to CSV (matches OULAD/UCI columns) | 2 |
| Good | Small ML models running in GDScript from JSON | 2 |
| Good | Save/load scenarios and compare two runs | 2 |
| Nice | Python sidecar for larger models | 2 |
| Nice | Path crowding that slows walking; crowd heatmap | 2 |
| Nice | Visual polish | 2 |

## Areas of ownership

Each member owns one main area and reviews the areas their work connects to.

| Member | Semester 1 | Semester 2 |
| --- | --- | --- |
| Peshaant | SimEngine, rule decisions, integration, final merges | ML integration in GDScript; Python sidecar if time allows |
| Hayyaan | Campus loading + pathfinding, timetable generator, room allocation | Model training in Python, JSON export |
| Siw | MapView, ParamPanel, Dashboard, scene wiring | Run comparison, scenario save/load, UI polish |
| Shuyu | Campus and unit data, timetable rules, timetable and path tests | Data logging, OULAD/UCI column mapping, dataset cleaning |
| Arya | Research-based default values (with sources), map art, test runs and bug reports | Experiments and results for the report |

Everyone writes the report sections for their own area, takes turns on meeting minutes, and records their own vlogs.

## Semester 1 sprints

| Sprint | Goal | Peshaant | Hayyaan | Siw | Shuyu | Arya |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Skeleton runs | Project setup, Params/EventBus/Stats, EventQueue, SimEngine core (**done**) | `Campus.gd`: load JSON, graph, Dijkstra | Main scene, MapView draws buildings and paths | `campus.json` (8–12 buildings) | Default values with sources |
| 2 | Students move | Bootstrap run in Main; hook engine to MapView | `TimetableGenerator.gd` (no clashes) | Students drawn with MultiMesh; play/pause/speed UI | `units.json`, clash test cases | Test runs, bug reports, map art |
| 3 | Decisions + stats | `RuleDecision.gd`; motivation and tiredness updates | Room capacity and assignment checks | Dashboard charts from Stats | GUT tests for timetable and paths | Check stats against expected values |
| 4 | Parameters + polish | Reset with new params; 5,000-student performance | Edge cases (clashes, overfull rooms) | ParamPanel from `Params.SPECS` | Demo scenarios (normal, exam week, bad timetable) | Demo script, screenshots, report figures |

### Week 12 checklist

- [ ] Changing any parameter and pressing Reset gives a different, repeatable result
- [ ] 500 students run a full week without errors, and 5,000 run smoothly at high speed
- [ ] Dashboard shows attendance, lateness, room use and crowding
- [ ] Three demo scenarios, compared in the presentation

## Semester 2 phases

| Phase | Weeks | Work | Lead |
| --- | --- | --- | --- |
| 1 | 1–3 | CSV logging, column mapping to OULAD/UCI, cleaning | Shuyu, with Hayyaan |
| 2 | 3–6 | Train models (logistic regression, trees), check accuracy, export JSON | Hayyaan |
| 3 | 5–8 | `MLDecision.gd`, JSON model loaders, rules/ML toggle | Peshaant |
| 4 | 7–9 | Rules vs ML run comparison on the dashboard | Siw, with Arya |
| 5 | 8–11 | Python sidecar (only if Phase 3 is done by Week 7) | Peshaant, with Hayyaan |
| 6 | 10–12 | Experiments, report results, final demo | Arya + everyone |
