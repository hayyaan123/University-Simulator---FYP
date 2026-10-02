# Student model

How a student's grades, stress, energy and satisfaction change, and how those states change what the student does. This is the design agreed on 2026-10-01 (decisions #11 to #13 in `DECISIONS.md`). None of it is in the code yet.

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

1. **One row in the effects table** (below), with a number per state and a source or stated assumption for each number.
2. **The sim has to notice the event.** Most are already events the engine handles (attended, skipped, arrived late, walked). Some need a small check, such as counting today's classes.

Keep the table short. Every number needs a justification, so fewer rows is better for v1.

## Scenarios are not code

Nobody writes "if the day starts at 7am, lower attendance". A scenario is a saved set of parameter values (`data/scenarios/*.json`). An early start lowers energy, low energy raises the skip chance, and skipped classes mean fewer hours and lower grades. The effect comes out of the rules.

If a result looks wrong, change a number in the effects table. Don't add a special case.

## What this needs in the code

Planned shape, to be built in Sprint 3 (see `ROADMAP.md`). File locations follow `ARCHITECTURE.md`.

- **`sim/students/Student.gd`:** replace `motivation` and `tiredness` with `stress`, `energy` and `satisfaction` (0–100), add `resilience` and `commute_minutes`, and keep hours attended and hours studied per unit.
- **`sim/students/StateEffects.gd` (new):** the effects table as data, plus one `apply(student, event)` function. This is the only place that changes stress, energy and satisfaction.

  ```gdscript
  ## event -> {state: change}. Placeholder numbers: each needs a source.
  const EFFECTS: Dictionary = {
  	&"attended_class_hour": {&"stress": 0.5, &"energy": -4.0},
  	&"studied_hour": {&"energy": -3.0},
  	&"skipped_class": {&"energy": 2.0},
  	&"arrived_late": {&"stress": 1.0, &"satisfaction": -1.0},
  	&"deadline_near": {&"stress": 2.0},
  	&"walked_minute": {&"energy": -0.2},
  	&"food_stop": {&"energy": 10.0, &"satisfaction": 1.0},
  	&"break_day": {&"stress": -3.0, &"energy": 5.0, &"satisfaction": 1.0},
	&"turned_away": {&"stress": 1.0, &"satisfaction": -3.0},
	&"queued_minute": {&"satisfaction": -0.2},
	&"back_to_back_class": {&"stress": 0.5, &"energy": -1.0},
  }
  ```

- **`sim/timetable/Assessment.gd` (new):** a unit, a due week and a weight. The mark is worked out from hours put in when the assessment falls due.
- **`decisions/RuleDecision.gd` (new):** the skip chance rises when energy is low or stress is above resilience (rule 3). It also picks what to do in free time: study, get food, or wait.
- **`decisions/DecisionContext.gd`:** `to_features()` swaps `motivation` and `tiredness` for the new states. No data has been logged yet, so the keys can still change.
- **`autoload/Stats.gd`:** keeps the average of each state and writes them into the semester report.
- **Tests:** one GUT test per row of the effects table, and one that checks rule 1 (changing one state never changes another).
