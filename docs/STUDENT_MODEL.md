# Student model

How a student's grades, stress, energy and satisfaction change, and how those states change what the student does. This is the design agreed on 2026-10-01 (decisions #11 to #13 in `DECISIONS.md`). The states, the effects table and the skip rule are in the code; see [In the code](#in-the-code) for what is still to build.

## The four states

Every student has four hidden states. They are not sliders. Each runs from 0 to 100.

| State | What it collects | Tier |
| --- | --- | --- |
| Grades | How much the student has learned: hours put into each unit, measured at each assessment | Must |
| Stress | Academic pressure: deadlines, workload, hours in class | Must |
| Energy | Physical tiredness: commute, early starts, hours in class, walking | Must |
| Satisfaction | Frustration with the campus: being late, full rooms, queues, cancelled classes | Must |

The averages of the four states are the **end-of-semester metrics**. They should trade off against each other, so no single setup wins on all of them.

## Rule 1: states never feed each other

Grades, stress, energy and satisfaction are **not calculated from each other**. Each one is driven separately by the determinants below. For example, attending class raises grades, raises stress and lowers energy, all at once. The trade-off between the metrics comes from that, not from a formula that links them.

## Rule 2: nothing changes grades directly

A determinant affects grades only by changing **the hours a student puts into a unit**. Arriving late doesn't cost marks; the student just attends fewer minutes. Completing an assessment doesn't add marks; the assessment is where the grade is measured.

- Each assessment's mark comes from the hours the student has put into that unit before the due date (class hours attended plus study hours), against the hours expected by then.
- The semester grade for a unit is the average of its assessment marks.

## Rule 3: states can change choices

Low energy or high stress makes a student more likely to skip a class or leave campus early. Stress above the student's Resilience means the student has burned out and skips far more. That choice then changes the determinants, which change the states. A state still never appears in another state's formula.

## Determinants

Arrows show the direction of the effect; "–" means no effect.

### v1 rows (12)

| Determinant | Grades | Stress | Energy | Satisfaction |
| --- | --- | --- | --- | --- |
| Hours of class attended | ↑ | ↑ | ↓ | – |
| Hours of study in free time | ↑ | – | ↓ | – |
| Skipping a class | – (no hours gained) | – | ↑ | – |
| Arriving late | – (fewer hours attended) | ↑ | – | ↓ |
| Deadlines approaching (more when clustered) | – | ↑ | – | – |
| Commute and early start | – | – | ↓ | ↓ |
| Walking between classes | – | – | ↓ | – |
| Food stop in free time | – | – | ↑ | ↑ |
| Breaks (mid-semester, between semesters) | – | ↓ | ↑ | ↑ |
| Turned away from a full room | – (hours lost) | ↑ | – | ↓ |
| Queueing at a food outlet | – | – | – | ↓ |
| Back-to-back classes with no break | – | ↑ | ↓ | – |

The last three rows were added on 2026-10-01 (decision #18) so that Room capacity, Food outlets and Gap between slots each reach a metric.

"Hours of study in free time" adds a new student activity: in free time a student chooses between studying and getting food. Without it, grades would only be the attendance rate under another name.

### Later candidates (not in v1)

| Determinant | Grades | Stress | Energy | Satisfaction |
| --- | --- | --- | --- | --- |
| Coming in for a single class | – | – | – | ↓ |
| Rushing (walk time close to the gap length) | – | ↑ | ↓ | – |
| Long idle gap with nothing to do | – | – | – | ↓ |
| Long day on campus (first class to last) | – | – | ↓ | ↓ |
| Weekend or free day | – | ↓ | ↑ | ↑ |
| Exam period | – | ↑ | ↓ | – |
| Several deadlines in the same week | – | ↑ | – | ↓ |

### Rows that need the Good-to-have systems

| Determinant | Grades | Stress | Energy | Satisfaction | Needs |
| --- | --- | --- | --- | --- | --- |
| Watching a lecture recording | ↑ (part of an hour) | – | ↓ | – | Lecture recordings |
| Class cancelled after travelling in | – (hours lost) | – | – | ↓ | Staff reliability |
| Lecturer arrives late | – (fewer hours) | – | – | ↓ | Staff reliability |
| Large tutorial group | ↑ less per hour | – | – | ↓ | Tutors per unit |
| Attending with friends | – | ↓ | – | ↑ | Friend influence |
| Friends skipping | – | – | – | ↓ | Friend influence |

### Left out on purpose

- **A mark received changes satisfaction or stress.** That is one state feeding another, which breaks rule 1.
- **Part-time work, sleep habits, living situation, finances.** Each is a new student attribute with no parameter behind it.
- **Teaching quality, unit difficulty.** These need per-unit values we have no data to set.

## Adding a determinant

A determinant costs two things:

1. **One row in the effects table** (`EFFECTS` in `sim/students/StateEffects.gd`), with a number per state and a source or stated assumption for each number.
2. **The sim has to notice the event.** Most are already events the engine handles (attended, skipped, arrived late, walked). Some need a small check, such as counting today's classes.

Keep the table short. Every number needs a justification, so fewer rows is better for v1.

## Scenarios are not code

Nobody writes "if the day starts at 7am, lower attendance". A scenario is a saved set of parameter values (`data/scenarios/*.json`). An early start lowers energy, low energy raises the skip chance, and skipped classes mean fewer hours and lower grades. The effect comes out of the rules.

If a result looks wrong, change a number in the effects table. Don't add a special case.

## In the code

**Built**

- **`sim/students/Student.gd`** has `stress`, `energy`, `satisfaction` and `resilience` (0 to 100), `commute_minutes`, plus hours attended and hours studied per unit. The timetable generator gives each student their own commute and resilience, spread around the two parameters.
- **`sim/students/StateEffects.gd`** holds the effects table (`EFFECTS`) and `apply(student, event, amount)`. It is the only place that changes stress, energy and satisfaction, and the only place the numbers live. **Every number in it is a placeholder** until it has a source.
- **`sim/core/SimEngine.gd`** calls `apply()` for the rows it can already see: hours of class attended, skipping, arriving late, walking, back-to-back classes, and the commute and early start. Energy is restored at the start of each day, before the commute is taken off.
- **`decisions/RuleDecision.gd`** is rule 3: `skip_chance(student)` rises as energy falls below a threshold and again when the student is burned out. The app uses it.
- **`decisions/DecisionContext.gd`**: `to_features()` now carries the states in place of `motivation` and `tiredness`.
- **Tests:** `tests/unit/test_state_effects.gd` checks every row and rule 1 (a row never changes a state it doesn't name). `test_sim_engine.gd` and `test_rule_decision.gd` cover the engine hooks and the skip rule.

**Not built yet**

| Row or feature | Waiting for |
| --- | --- |
| Hours of study, food stop, queueing | The errand planner and food outlets |
| Deadlines approaching, grades | Assessments (`sim/timetable/Assessment.gd`): a unit, a due week and a weight; the mark comes from hours put in |
| Breaks | The semester calendar |
| Turned away from a full room | A capacity check when a student arrives |
| State averages in `Stats` and the semester report | The dashboard work |

Until deadlines exist, stress only rises slowly from class hours, so burnout does not happen in a normal run.
