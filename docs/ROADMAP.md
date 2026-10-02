# Roadmap

**Semester 1:** a working prototype by Week 12. **Semester 2:** the Good-to-have systems, then ML decisions running inside the simulation.

## Scope

The tiers follow the first-meeting whiteboard and the supervisor's feedback on 2026-10-01 and 2026-10-02 (decisions #10 to #14 and #19 to #22).

| Priority | Feature | Semester | Status |
| --- | --- | --- | --- |
| Must | 2D campus map: buildings, rooms with capacity, walking paths with distances | 1 | First version built |
| Must | Units with class slots and enrolment numbers | 1 | Placeholder data |
| Must | Timetable generator: units, class slots, room allocation, no clashes | 1 | First version built |
| Must | Student agents, each with their own timetable, moving between rooms | 1 | Built |
| Must | Travel between classes: shortest path, on time / late / too late | 1 | Built |
| Must | Simulation clock: play, pause, speed, fixed random seed | 1 | Built (temporary HUD) |
| Must | Student states: grades, stress, energy | 1 | Built |
| Must | A size and a source or stated assumption for every effect in the determinants table | 1 | First version in `STUDENT_MODEL.md`; team review and a sensitivity check to do |
| Must | Rule-based decisions: attend, skip, study, get food, leave campus | 1 | Attend, skip and leave built; study and food to build |
| Must | Assessments and deadlines; grades measured at each assessment | 1 | Built; study hours wait for the errand planner |
| Must | Errands in free time: knapsack picks the stops, TSP orders them | 1 | To build |
| Must | Continuous run across semesters: calendar, breaks, exam period | 1 | One semester of repeating weeks built; the rest to build |
| Must | Parameter panel with the 11 Must parameters | 1 | To build |
| Must | Live dashboard and an end-of-semester report | 1 | To build |
| Good | Lecturers and tutors: staff reliability, tutors per unit | 2 | |
| Good | Lecture recordings | 2 | |
| Good | Satisfaction as a fourth state | 2 | State exists in the code; not reported |
| Good | Stress changing choices (burnout), once we can justify a trigger | 2 | Parked |
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

## Next steps after the 2026-10-02 supervisor meeting

Our supervisor's message: the determinants table is a good base, but it only shows directions. Before the next presentation we need to say how big each effect is, what "grades" means, and why. This semester is assessed on the paperwork, so settling the model on paper comes before more building.

The order of work:

1. **Settle the model on paper.** The team confirms or changes the six extreme cases, the grade formula and the proposals in decision #23, and closes the open decisions at the bottom of this file.
2. **Size the effects.** Done as a first version on 2026-10-02: every arrow has a size and a source or stated assumption in `STUDENT_MODEL.md`. Still to do: the team's review, the sources marked "still to find", and a sensitivity check.
3. **Bring the code in line.** Done on 2026-10-02.
4. **Build grades and errands.** Assessments and grades are built (moved up from Sprint 4). Errands are next: without study hours grades stay near 50, and without food stops nothing lowers stress.
5. **Check the model against the extremes.** The six cases become tests and demo scenarios. The first check runs are in `STUDENT_MODEL.md`.

What each member does next (proposed, inside each member's area):

| Member | Next |
| --- | --- |
| Peshaant | Done: grade formula, code brought in line, assessments and grades, a 12-week run, first effect sizes with sources. Next: run the team session on the six cases and decision #23, and record the outcomes in `DECISIONS.md`. Open the pull request. Run the sensitivity check (each assumed size at half and at one and a half times). Add the study and food choices to the rules once the errand planner exists. Then the calendar |
| Hayyaan | Build `ErrandPlanner`, the next priority: write down the knapsack values and weights for a study hour against a food stop, then knapsack and TSP. Food outlets with queues, one kind of outlet. With Shuyu, find out why no student ever arrives late |
| Siw | `Stats` for the three metrics: average grade, average and peak stress, average energy. Dashboard charts, using the new `week_ended` signal for a weekly line. Redraw the model diagram for the presentation so it shows the sizes and what "grades" means, not only arrows |
| Shuyu | Add food outlets (one kind) to `campus.json`. Assessments need no data file: they come from the two parameters. Check class hours per unit against the handbook, since grades are measured against them. Write the six extreme cases as GUT tests. Run the full test suite with real GUT and report the result. Check walking distances with Hayyaan |
| Arya | A first pass of sources is in `STUDENT_MODEL.md`. Next: read sources 3, 4 and 11 in full and add the missing details; find the sources listed as "still to find"; challenge any size that looks wrong. Propose how much students should differ from each other |

## Semester 1 sprints

Sprints 1 and 2 are mostly done. First versions of the campus, timetable generator and map were built together in one change so the whole loop runs; their owners now take them over.

| Sprint | Goal | Peshaant | Hayyaan | Siw | Shuyu | Arya |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Skeleton runs | Project setup, Params/EventBus/Stats, EventQueue, SimEngine core (**done**) | `Campus.gd`: load JSON, graph, Dijkstra (**first version done**) | Main scene, MapView draws buildings and paths (**first version done**) | `campus.json` (**done**, from OpenStreetMap) | Default values with sources |
| 2 | Students move | Run bootstrapped in Main; engine hooked to MapView (**done**) | `TimetableGenerator.gd`, no clashes (**first version done**) | Students drawn with MultiMesh (**done**); play/pause/speed in the real UI | `units.json` checked against the handbook; clash test cases | Test runs, bug reports, map art |
| 3 | Model settled, then grades + errands | Student states and `StateEffects` (**done**); `RuleDecision`: attend, skip, leave (**done**), study and food (with the errand planner); `Params` trimmed to the agreed list (**done**); code brought in line with `STUDENT_MODEL.md` (**done**); assessments and grades (**done**); six cases and decision #23 settled with the team; sensitivity check | `ErrandPlanner` (knapsack + TSP); food outlets with queues, one kind of outlet; room allocation as knapsack; overcrowded rooms | `Stats` for the three states; Dashboard charts; model diagram for the presentation | Food outlets and assessments in the data files; GUT tests for errands, state effects and the six extreme cases | A size, shape and source for every effect, grades first; check results against the six extreme cases |
| 4 | Semesters + parameters | `Calendar`: weeks, breaks, exams, week-by-week scheduling, no end time; 5,000-student performance | Path closures with rerouting; edge cases | ParamPanel from `Params.SPECS`; semester report screen | Calendar presets; demo scenarios (normal semester, clustered deadlines, early starts with long commutes) | Demo script, screenshots, report figures |

If time runs short, cut in this order: path closures, the Trimester preset, yearly intake and graduation. The three states and the Must parameters stay.

### Week 12 checklist

- [ ] Changing any of the 11 Must parameters and pressing Reset gives a different, repeatable result
- [ ] Every Must parameter moves at least one of the three metrics
- [ ] Every effect size has a source or a stated assumption
- [ ] 500 students run two full semesters without errors, and 5,000 run smoothly at high speed
- [ ] The end-of-semester report shows grades, stress and energy
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

- [ ] Confirm or change the proposals in decision #23. The code already follows them:
    - an hour of study counts the same as an hour of class
    - grades are measured against 6 hours per unit per week on campus, so class alone gives about 50
    - a student still gets into an overcrowded room and takes a stress hit (our supervisor's preference)
    - a deadline is "near" for 7 days
    - a student with no energy always skips
    - Resilience is parked, leaving 10 Must parameters
- [ ] The effect sizes in `docs/STUDENT_MODEL.md`: confirm or change each assumed size
- [ ] The six extreme cases in `docs/STUDENT_MODEL.md`: confirm or change the answers
- [ ] Grades: is "knowledge" a separate hidden value, or is it what the grades state already means? As built, it is what the grades state means (our supervisor is fine with either and wants as few hidden values as possible)
- [ ] Deadline clustering does not change the end-of-semester stress average, only when stress peaks. Is peak stress in the report enough, or does it need the "several deadlines in the same week" row?
- [ ] No student arrives late in the check runs, even with no gap between slots. Are the walking distances right?
- [ ] Which part of the sim uses AI
- [ ] Does the app show the campus as "Monash University Malaysia", or a neutral name?
- [ ] Do we commit Godot's `.gd.uid` files? (Godot 4.4 and later recommends it)
- [ ] Sprint dates for Sprints 3 and 4
