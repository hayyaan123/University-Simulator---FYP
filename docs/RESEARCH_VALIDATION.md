# Research validation: reproducible simulator experiments

**Owner:** Arya | **Prepared:** 2026-10-18 | **Status:** plan and baseline extracted from existing docs; **new experiments NOT RUN**.

## Goal

Test the **15 documented parameters** and the assumed state-effect values without adding new parameters, silently changing code, or treating synthetic 0–100 points as measured physiological values. See [RESEARCH_15_FACTORS.md](RESEARCH_15_FACTORS.md), [PARAMETERS.md](PARAMETERS.md) and [STUDENT_MODEL.md](STUDENT_MODEL.md).

## Execution prerequisites

- Use the Godot version in the repository README (**Godot 4.7.x, Standard build**) and the project checkout matching the commit being tested.
- The repo README suggests `godot --headless -s addons/gut/gut_cmdln.gd` for GUT tests. **The supplied ZIP does not contain an `addons/gut` directory**, so install/configure the expected GUT dependency before relying on that command. Do not mark tests passing without a successful run.
- Run one **12-week semester** (the model's existing `SimEngine` check used 84 days). The team currently runs headless check cases; adapt the execution command to the branch's working runner and record the exact command. Do not invent a CLI option not actually supported by `SimRunner.gd`.
- Start from `data/scenarios/default.json` and change **one parameter at a time** where possible. Parameters are read **once per run**; reset between trials.
- Hold seed at **42** for primary controlled comparisons. When stochastic variation matters, repeat using 5 different seeds chosen and recorded in advance (e.g., **42–46**); never confuse separate-seed comparisons with the fixed-seed experiment.
- The Good-to-have parameters and parked resilience **cannot be evaluated in the current implementation**. Mark these experiments "blocked", rather than recording zero impact as evidence.

## Model facts that should not change during the tests

1. A parameter changes student determinants; states then produce the three semester metrics.
2. **Grades:** only class/study hours, assessment marks and unit averages. No direct marks penalty for late/skip/stress.
3. **States:** grades, stress and energy do not directly feed into each other. **Energy** affects skip behaviour; **stress does not** in v1.
4. Early start, commute, travel, class, study and recovery effects in the project are **model anchors**. Quantities from a research paper are not simulator state points.
5. The current source docs disagree about whether an overfull room turns students away or simply applies overcrowding stress; log actual behaviour and seek a team decision.

## Experiment matrix (proposed; not results)

| ID | Lever / configuration | Test values (baseline in **bold**) | Expected direction or diagnostic | Output to inspect | Status |
| --- | --- | --- | --- | --- | --- |
| P01 | Student count | 250 / **500** / 750 | More crowded sessions only if fixed resources bind | Overfull events per student, stress, attendance | To run |
| P02 | Units/student | 2 / **4** / 6 | More classes and deadlines → stress up, energy down | Weekly hours, deadlines, grades/stress/energy | To run |
| P03 | Avg commute, min | 15 / **45** / 90 | More energy loss → possibly more skips | Skip %, class hours, energy | To run |
| P04 | Resilience | parked (70 was proposed) | **No meaningful test until mechanism approved** | N/A | Blocked / parked |
| P05 | Day start/end | **08:00–18:00**, 10:00–20:00, 06:00–16:00 | Early first classes reduce attendance via energy; end hour alone may not | First-class attendance, energy | To run |
| P06 | Lecture/tutorial length | 60/60, **120/60**, 180/60 | More offered hours might boost learning, exhaust energy | Attended minutes, stress, energy | To run |
| P07 | Slot gap, min | 0 / **10** / 30 | Lateness only if routes exceed available changeover | Late counts, walk minutes, back-to-back events | To run |
| P08 | Room capacity multiplier | 0.5 / **1.0** / 1.5 | Overcrowding events and stress should vary | Occupancy/capacity ratio, effect events | To run |
| P09 | Food outlets | 1 / **4** / 8 | Queue/visit effects after errand planner exists | Queue delay, visit counts, study time, states | Blocked / system pending |
| P10 | Assessments/unit | 1 / **3** / 6 | More near-deadline exposure generally raises stress | Deadline exposures, stress peak, mean | To run |
| P11 | Deadline clustering | 0 / **0.5** / 1 | Peaks/timing may differ even if final stress equal | Weekly max/variance/time stress >80 | To run |
| P12 | Recorded lectures | **0%** / 50% / 100% | Watch vs attendance differences TBD | Hours recorded/watched, grades | Blocked / Semester 2 |
| P13 | Staff absences/delay | 0/0, **2%/5**, 10%/15 | Lost teaching hours if cancellation agents exist | Lost class minutes, student trips, marks | Blocked / Semester 2 |
| P14 | Tutors/unit | 1 / **3** / 6 | Tutorial group size/learning relationship TBD | Group size, contact hours, grades | Blocked / Semester 2 |
| P15 | Friend influence | 0 / **0.3** / 1 | Change in correlated attendance if real network present | Attendance correlation vs no influence | Blocked / Semester 2 |

**Caution:** Some variations can create infeasible timetables or very different total class hours. Record failures as findings; do not quietly substitute other numbers. Changing the teaching day window and class duration can change capacity and schedule feasibility, so compare total classes *scheduled* as well as attended.

## Effect-size sensitivity checks

The supervisor/team requested sensitivity to chosen 0–100 state-effect **magnitudes**. For every *active* determinant in `sim/students/StateEffects.gd`, do controlled reruns at **0.5×, 1.0×, 1.5×** of its current magnitude, keeping the sign, unit, other sizes, parameters, engine version and seed fixed. Do not change the operational baseline without a reviewed decision.

| Existing anchor / effect (from `STUDENT_MODEL.md`) | Baseline | 0.5× example | 1.5× example | Specific check |
| --- | --- | --- | --- | --- |
| Class/study energy | −10 per hour | −5 | −15 | Energy floor, skipped classes |
| Commute/walk energy | −0.167 per minute | −0.0835 | −0.2505 | Commute distribution, energy floor |
| Early-start energy | −25 per hour early | −12.5 | −37.5 | 08:00 vs 10:00 attendance |
| Arrive-late stress | +1 per event | +0.5 | +1.5 | Requires actual late events |
| Deadline-near stress | +0.5 per day/deadline | +0.25 | +0.75 | Peak vs final stress |
| Food-stop energy | +20 per stop | +10 | +30 | **Blocked** until food stop events |
| Overcrowded-room stress | +3 per class | +1.5 | +4.5 | Confirm room rule |
| Back-to-back stress | +0.5 per class | +0.25 | +0.75 | Event count under gap settings |

These are **illustrative arithmetic test values**, not new recommendations or implemented code. For a complete sweep also include class/study stress, skip-rest energy, food-stop stress, break stress, overcrowding energy and back-to-back energy. The skip-probability **shape** should be tested separately rather than by blindly multiplying the probability by 1.5 (which would exceed 100%). Preserve the exact existing curve and check its endpoints.

### Skip-curve algebra checks

Under the current equation `p_skip = 0.03 + 0.97 × ((100 - energy)/100)²`:

| Energy | Expected skip probability |
| --- | --- |
| 100 | 0.0300 = 3.00% |
| 75 | 0.090625 = 9.0625% |
| 50 | 0.2725 = 27.25% |
| 25 | 0.575625 = 57.5625% |
| 0 | 1.0000 = 100% |

These are deterministic **formula values**; real simulation attendance percentages will also depend on schedules and the distribution of energy across students.

## Previously documented results (historical, NOT rerun)

These values are copied **only** from the existing `STUDENT_MODEL.md` section "First check runs": team run on **2026-10-02**, one 12-week semester, 500 students, seed 42. At that time food stops and studying were not built; the original notes warn this constrains grades and inflates stress. Treat the numbers as **baseline context**, not current-branch verification.

| 2026-10-02 scenario | Attendance | Grades | Stress end | Energy end-of-day |
| --- | ---: | ---: | ---: | ---: |
| Default | 89.5% | 44.5 | 60.4 | 66.6 |
| 2 units/student | 91.7% | 44.9 | 29.1 | 81.5 |
| 6 units/student | 81.5% | 40.3 | 91.5 | 53.9 |
| Day start 06:00 + commute 120 minutes | 61.0% | 30.6 | 53.7 | 48.0 |
| Day start 10:00 + commute 10 minutes | 95.1% | 47.3 | 65.2 | 74.9 |
| 6 assessments/unit, clustering 1 | 89.5% | 44.6 | 99.1 | 66.6 |
| 6 assessments/unit, clustering 0 | 89.5% | 44.5 | 99.1 | 66.6 |
| Slot gap 0 | 88.6% | 49.5 | 61.8 | 64.4 |
| Room capacity 0.5× | 88.9% | 44.3 | 70.0 | 66.9 |

Do **not** cite those rows as new experiments or claim to reproduce them unless the exact branch, dependency versions, seed and runner reproduce them.

## New experiment recording template — deliberately blank

Copy and fill in **one row for each completed run**. `TBD` is not an observed measurement.

| Run ID | Git commit SHA | Godot / deps | Scenario and changed value | Seed | Exact runner command | Attendance % | Grade mean | Stress mean / peak | Energy mean | Error log / notes |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| EXP-001 | TBD | TBD | baseline 500 / 4 units / 45 min | 42 | TBD | TBD | TBD | TBD | TBD | Not run |
| EXP-002 | TBD | TBD | 2 units | 42 | TBD | TBD | TBD | TBD | TBD | Not run |
| EXP-003 | TBD | TBD | 6 units | 42 | TBD | TBD | TBD | TBD | TBD | Not run |

## Issues to log (not silently fix)

- **Deadline clustering:** final mean/final stress can hide variation in weekly peaks; earlier source shows 99.1 for both extremes.
- **Zero-gap lateness:** if no lateness occurs, inspect map paths, timetable allocations and walking thresholds before asserting lateness effects.
- **Overfull-room behaviour:** `PARAMETERS.md` and `STUDENT_MODEL.md` disagree on turn-away versus crowded entry. Record what the *code* does, file an issue and request a team decision.
- **Missing features:** food visits, semester breaks and all Good-to-have systems may be absent on this branch. Label blocked tests and do not substitute invented results.
- **0–100 saturation:** record clipping counts. If a change produces the same end-of-semester mean, that might be a ceiling effect, not no causal impact in the model.

## Test and sign-off checklist

- [ ] Record Git SHA, exact seed, engine version, data files, test dependencies and run command.
- [ ] Confirm existing GUT unit tests run; attach actual output if/when available.
- [ ] Run fixed-seed base and 2/4/6-unit experiments.
- [ ] Run the early-start × commute comparison, then single-variable changes.
- [ ] Run 0/0.5/1 deadline clustering and log weekly peaks.
- [ ] Verify overcrowding and short gaps via event logs.
- [ ] Run state-effect 0.5×/1×/1.5× experiments without modifying the committed production defaults.
- [ ] Clearly separate existing historical source results, new observations, assumptions and literature findings in the report.
- [ ] Raise open issues / team decisions **before** changing `Params.gd`, `StateEffects.gd` or `DECISIONS.md`.
