# Student model

How a student's grades, stress and energy change, and how they change what the student does. The design was agreed on 2026-10-01 (decisions #11 to #13 in `DECISIONS.md`) and revised after the supervisor meeting on 2026-10-02 (decisions #19 to #23). The code matches this document; see [In the code](#in-the-code) for what is still to build.

## The three states

Every student has three states. They are not sliders. Each runs from 0 to 100.

| State | What it collects | Tier |
| --- | --- | --- |
| Grades | How much the student has learned: hours put into each unit, measured at each assessment | Must |
| Stress | Academic pressure: deadlines, workload, hours in class, crowded rooms | Must |
| Energy | Physical tiredness: commute, early starts, hours in class, walking | Must |

The averages of the three states are the **end-of-semester metrics**. They are shown openly in the report, not hidden. They should trade off against each other, so no single setup wins on all of them.

**Satisfaction** was a fourth state. It is now Good to have (decision #19), so it is not a v1 metric and is not in the code. Its rows are listed under [Satisfaction](#satisfaction-good-to-have).

## Rule 1: states never feed each other

Grades, stress and energy are **not calculated from each other**. Each one is driven separately by the determinants below. For example, attending class raises grades, raises stress and lowers energy, all at once. The trade-off between the metrics comes from that, not from a formula that links them.

## Rule 2: nothing changes grades directly

A determinant affects grades only by changing **the hours a student puts into a unit**. Arriving late doesn't cost marks; the student just attends fewer minutes. Skipping a class doesn't cost marks either; the student misses those hours and can make them up by studying.

## Rule 3: energy can change choices

The lower a student's energy, the more likely they are to skip a class or leave campus early, and a student with no energy cannot come to class. That choice then changes the determinants, which change the states. A state still never appears in another state's formula.

The skip chance is a curve, not a straight line:

```
skip chance = 0.03 + 0.97 × (energy lost ÷ 100)²
```

A little tiredness changes little; the chance reaches 1 at zero energy. The curve and the early-start size together reproduce a published number: attendance at 08:00 classes about 10 percentage points lower than at later classes (Yeo et al. 2023, source 4).

**Stress does not change choices in v1** (decision #20). There is no point we can justify at which stress makes a student stop attending: two students with the same stress act differently. Burnout and the Resilience parameter are parked until we have a trigger we can defend.

## What "grades" means

"Grades" stands for **the knowledge a student needs to get the grade**. It is not a mark that events add to or take away from. This is what we say when someone asks "how can coming late lower your grades?": it can't, but the part of the class you missed can.

| Term | Definition |
| --- | --- |
| Hours put in | Class hours attended plus hours of study in free time, per unit. An hour of each counts the same |
| Hours expected | 6 hours per unit per teaching week, on campus (see below) |
| Assessment mark | 100 × hours put in before the due date ÷ hours expected by then, capped at 100 |
| Unit grade | The average of the unit's assessment marks, by weight |
| Grades state | The average over the student's units |

**Why 6 hours.** Monash sets 12 hours a week for a 6-point unit, counting classes, assigned work and private study (source 1). The sim only sees what happens on campus. Assumption: half of the 12 hours are done on campus and every student does the other half at home. So a student who attends every class of a 3-hour unit and never studies on campus scores 50, a bare pass, and has to study between classes to do better.

**Why a straight line.** Class attendance is the best single predictor of grades (r = 0.43 with class grades, source 2), so hours attended driving the mark is supported. How much each extra hour is worth is not something the sources give us, so the straight line with a cap is a stated assumption. Study time on its own is a weak predictor of grades (source 3), which is a known limit of counting a study hour the same as a class hour.

This formula is proposed (decision #23) and is what the code does. The team can still change it.

## Determinants

Arrows show the direction of the effect; "–" means no effect.

### v1 rows (11)

| Determinant | Grades | Stress | Energy |
| --- | --- | --- | --- |
| Hours of class attended | ↑ | ↑ | ↓ |
| Hours of study in free time | ↑ | ↑ | ↓ |
| Skipping a class | – (no hours gained) | – | ↑ |
| Arriving late | – (fewer hours attended) | ↑ | – |
| Deadlines approaching (more when clustered) | – | ↑ | – |
| Commute and early start | – | – | ↓ |
| Walking between classes | – | – | ↓ |
| Food stop in free time | – | ↓ | ↑ |
| Breaks (mid-semester, between semesters) | – | ↓ | ↑ |
| Overcrowded room | – | ↑ (large) | ↓ (slight) |
| Back-to-back classes with no break | – | ↑ | ↓ |

Changes on 2026-10-02:

- **Food stop** now lowers stress as well as raising energy (decision #21). Every outlet has the same effect; we don't model different kinds of outlet.
- **Overcrowded room** replaces "turned away from a full room". The student still gets in and takes a large stress hit and a slight energy hit, which is our supervisor's preference. He also said turning them away comes to the same thing, so this is proposed (decision #23), not settled.
- **Hours of study** now raises stress the same way class does (decision #23). Before, studying beat attending on every count.
- **Queueing at a food outlet** is no longer a row. It only moved satisfaction. Queue time still matters: it uses up free time, so fewer food stops and study hours fit in. That is how Food outlets still reaches the metrics.

"Hours of study in free time" is a student activity: in free time a student chooses between studying and getting food. Without it, grades would only be the attendance rate under another name.

### Later candidates (not in v1)

| Determinant | Grades | Stress | Energy |
| --- | --- | --- | --- |
| Rushing (walk time close to the gap length) | – | ↑ | ↓ |
| Long day on campus (first class to last) | – | – | ↓ |
| Weekend or free day | – | ↓ | ↑ |
| Exam period | – | ↑ | ↓ |
| Several deadlines in the same week | – | ↑ | – |

Our supervisor is open to one or two more determinants, but not to more parameters or hidden values.

### Rows that need the Good-to-have systems

| Determinant | Grades | Stress | Energy | Needs |
| --- | --- | --- | --- | --- |
| Watching a lecture recording | ↑ (part of an hour) | – | ↓ | Lecture recordings |
| Class cancelled after travelling in | – (hours lost) | – | – | Staff reliability |
| Lecturer arrives late | – (fewer hours) | – | – | Staff reliability |
| Large tutorial group | ↑ less per hour | – | – | Tutors per unit |
| Attending with friends | – | ↓ | – | Friend influence |

### Satisfaction (Good to have)

If satisfaction comes back as a fourth state, these are the rows that move it. Down: arriving late, commute and early start, overcrowded room, queueing at a food outlet, coming in for a single class, a long idle gap, a long day on campus, a cancelled class, a late lecturer, a large tutorial, friends skipping. Up: a food stop, breaks, attending with friends.

### Left out on purpose

- **A mark received changes stress.** That is one state feeding another, which breaks rule 1.
- **Stress makes a student skip (burnout).** Parked, see rule 3.
- **Part-time work, sleep habits, living situation, finances.** Each is a new student attribute with no parameter behind it.
- **Teaching quality, unit difficulty.** These need per-unit values we have no data to set.
- **Different kinds of food outlet.** One abstract outlet is enough.

## Effect sizes

Every arrow has a size. The sizes live in `EFFECTS` in `sim/students/StateEffects.gd`, and nowhere else.

Rules for v1:

- **Sizes are fixed.** They are decided before a run and don't change during it (decision #22). They are the same for every student.
- **Straight lines.** One more hour, minute or event always moves the state by the same amount. The only bends are the 0 and 100 limits, the cap on an assessment mark, and the skip-chance curve in rule 3.
- **Students differ through their attributes, not through the effects.** Each student has their own commute, drawn around the parameter.

**What the sources can and can't give us.** No paper says "an hour of class costs 10 energy points", because our 0 to 100 scales are our own. The sources support the **direction** of each effect and, in places, a real-world number we can check against. Each size is then an **anchor**: a plain statement of what the scale means, which anyone can argue with. Two anchors set most of the table.

- **Energy anchor:** ten hours of activity with no break empty a rested student. That is the length of the default teaching day (08:00 to 18:00). So every active hour costs 10, whether it is class, study, the commute or walking.
- **Stress anchor:** arriving late adds 1. Every other one-off stress event is sized against it.

| Determinant | Unit | Stress | Energy | Basis |
| --- | --- | --- | --- | --- |
| Hours of class attended | per hour | +0.1 | −10 | Energy anchor. Fatigue builds with time on a demanding task (source 11). Stress: assumption, a default workload adds about 30 over a semester |
| Hours of study in free time | per hour | +0.1 | −10 | Same academic work as class (decision #23) |
| Skipping a class | per class | – | +5 | Assumption: rest gives back half an active hour |
| Arriving late | per arrival | +1 | – | Stress anchor (assumption) |
| Deadlines approaching | per day, per deadline within 7 days | +0.5 | – | Stress rises through the semester and peaks at assessment times (source 6). Size: assumption, 12 deadlines add about 40 |
| Commute | per minute | – | −0.167 | Energy anchor (10 an hour). Longer commutes go with fewer days on campus and lower grades (source 5) |
| Early start | per hour before 09:00 | – | −25 | Students slept about an hour less before 08:00 classes and attendance was about 10 points lower (source 4). Size chosen so the model gives that 10-point drop |
| Walking between classes | per minute | – | −0.167 | Energy anchor (10 an hour) |
| Food stop | per stop | −0.5 | +20 | Breaks reduce fatigue (d = 0.35) and raise vigour (d = 0.36), more so when longer (source 7). Size: assumption, a meal gives back two active hours |
| Breaks | per day | −3 | (none needed) | Time off improves well-being (d = 0.43) and the gain fades after work resumes (source 8). Size: assumption, a 7-day break takes off about 20. Energy needs no number: there is no commute or class on a break day |
| Overcrowded room | per class | +3 | −2 | Arousal rises as people are packed closer (source 9). Size: assumption, three times arriving late |
| Back-to-back classes | per class | +0.5 | −2 | Stress built up over back-to-back sessions and reset with 10-minute breaks (source 10). Size: assumption, half of arriving late |

Other numbers in the model:

| Number | Value | Basis |
| --- | --- | --- |
| Hours expected per unit per week | 6 | Half of Monash's 12 (source 1); the half is an assumption |
| Teaching weeks | 12 | Source 1 |
| Deadline is "near" | 7 days | Assumption |
| Skip chance at full energy | 3% | Assumption, no source yet |
| Skip-chance curve | square of energy lost | Chosen with the early-start size to match source 4 |
| Goes home instead of skipping one class | below 50 energy, after at least one class | Assumption |

**How to defend an assumption:** say it is one, say what it is anchored to, and show what happens when it is halved or raised by half. That sensitivity check is still to run.

### Sources

Sources 1 to 11 were opened and read on 2026-10-02 (the page, the abstract or the first page). Each entry says what was read.

1. Monash University. *Handbook glossary*: "Each 6-credit-point unit requires an average workload (class attendance, assigned work, and private study) of 12 hours per week for 12 weeks." <https://www.monash.edu/students/handbooks/help/handbook-glossary>
2. Credé, M., Roch, S. G., & Kieszczynka, U. M. (2010). Class attendance in college: a meta-analytic review of the relationship of class attendance with grades and student characteristics. *Review of Educational Research*, 80(2), 272–295. <https://doi.org/10.3102/0034654310362998>. Attendance and class grades: r = 0.43 (95% CI 0.38 to 0.47); with GPA: r = 0.36. Figures read from the published dataset's documentation: <https://wviechtb.github.io/metadat/reference/dat.crede2010.html>
3. Plant, E. A., Ericsson, K. A., Hill, L., & Asberg, K. (2005). Why study time does not predict grade point average across college students. *Contemporary Educational Psychology*. <https://doi.org/10.1016/j.cedpsych.2004.06.001>. The amount of study is a poor predictor of performance. Read from the ERIC record; volume and pages still to add.
4. Yeo, S. C., et al. (2023). Early morning university classes are associated with impaired sleep and academic performance. *Nature Human Behaviour*. <https://doi.org/10.1038/s41562-023-01531-x>. Attendance about 10 percentage points lower at 08:00 classes; about an hour less sleep; more morning classes, lower GPA. Read from a news report of the paper (<https://phys.org/news/2023-02-early-grades-poorer.html>), because the journal page needs a login. Arya to check against the paper itself.
5. Kobus, M. B. W., Rietveld, P., & van Ommeren, J. N. (2015). Student commute time, university presence and academic achievement. *Regional Science and Urban Economics*, 52, 129–140. <https://doi.org/10.1016/j.regsciurbeco.2015.03.001>. An extra hour of one-way commute means 0.65 fewer days on campus a week, and lower average grades.
6. Pitt, A., Oprescu, F., Tapia, G., & Gray, M. (2018). An exploratory study of students' weekly stress levels and sources of stress during the semester. *Active Learning in Higher Education*, 19(1), 61–75. <https://doi.org/10.1177/1469787417731194>. Stress trends upward over the semester; academic pressure is a main stressor.
7. Albulescu, P., Macsinga, I., Rusu, A., Sulea, C., Bodnaru, A., & Tulbure, B. T. (2022). "Give me a break!" A systematic review and meta-analysis on the efficacy of micro-breaks for increasing well-being and performance. *PLoS ONE*, 17(8), e0272460. <https://doi.org/10.1371/journal.pone.0272460>
8. de Bloom, J., Kompier, M., Geurts, S., de Weerth, C., Taris, T., & Sonnentag, S. (2009). Do we recover from vacation? Meta-analysis of vacation effects on health and well-being. *Journal of Occupational Health*, 51(1), 13–25. <https://doi.org/10.1539/joh.K8004>
9. Beermann, M., & Sieben, A. (2023). The connection between stress, density, and speed in crowds. *Scientific Reports*, 13, 13626. <https://doi.org/10.1038/s41598-023-39006-8>. Skin-conductance arousal rose with crowd density. It is about walking crowds, not classrooms, so it supports the direction only.
10. Microsoft Human Factors Lab (2021). *Research proves your brain needs breaks.* <https://www.microsoft.com/en-us/worklab/work-trend-index/brain-research>. 14 people, EEG. It is an industry study, not peer reviewed, so it is weak evidence; a peer-reviewed source would be better.
11. Boksem, M. A. S., & Tops, M. (2008). Mental fatigue: costs and benefits. *Brain Research Reviews*. <https://boksem.nl/pdf/boksem2008brr.pdf>. People stop wanting to continue a task when its energy cost outweighs its reward. First page read; volume and pages still to add.

Still to find (Arya): a source for commuting and tiredness (a study linking longer commutes to less sleep came up in search but was not opened), a classroom study of crowding, a peer-reviewed replacement for source 10, and anything on how often rested students skip.

## The six extreme cases

Our supervisor asked for a thought experiment: what would a student have to do to reach each end of each metric? The cases don't have to happen in a run. They tell us what the model really says, and they give the sizes something to be measured against. The answers follow from the sizes above. **The team still has to confirm them.**

| # | Question | Answer | What it costs the student |
| --- | --- | --- | --- |
| 1 | 100% grades | Put in 6 hours on campus per unit every week before every due date: attend every class in full, never late, and study the remaining hours between classes | With 4 units that is 24 active hours a week: high stress and low energy |
| 2 | 0% grades | Put in zero hours: miss every class (skipped, or too late to enter) **and** never study. Skipping every class is not enough on its own, because study hours count too | Nothing. Stress stays low and energy stays high |
| 3 | Zero stress | No class hours, no study, never late, no crowded rooms, no back-to-back classes. Deadlines still raise stress for everyone, so food stops and breaks have to cancel that out | Zero grades. Studying is no way around it: it raises stress like class does |
| 4 | Maximum stress | Everything that raises it and nothing that lowers it: attend and study every hour, back to back, late, in overcrowded rooms, with many deadlines, and never stop for food | Low energy as well. Grades are high |
| 5 | Maximum energy | Stay home. Energy is full every morning and only falls from the commute, an early start, class, walking and study | Zero grades |
| 6 | Zero energy | Ten active hours with no food stop. Fewer with an early start: a 06:00 first class takes 75 before the day begins | Grades and stress are both high, until the student is too tired to attend |

### What the cases showed, and what was done

| # | Finding | Status |
| --- | --- | --- |
| 1 | Studying beat attending: same grade, less energy, no stress | Fixed, proposed: an hour of study now costs the same as an hour of class |
| 2 | Class alone gave 25 out of 100 against Monash's 12 hours | Fixed, proposed: 6 hours expected on campus, so class alone gives about 50 |
| 3 | "Deadline near" had no definition | Fixed, proposed: within 7 days |
| 4 | Energy never reached zero | Fixed: ten active hours now empty a student |
| 5 | A student with no energy still attended 57% of the time | Fixed: the skip chance reaches 100% at zero energy |
| 6 | **Deadline clustering does not change the end-of-semester stress average.** The same deadlines add the same total whenever they fall | Open. It should show in peak stress once food stops and breaks let stress fall between deadlines. Check again after the errand planner is built |
| 7 | **No late arrivals in any check run**, even with the gap at 0. Walks on this campus are short | Open. Hayyaan and Shuyu to check walking distances; the gap may only matter through back-to-back classes |

## First check runs

One 12-week semester, 500 students, seed 42, run headless on 2026-10-02. Study and food stops are not built yet, so grades can't go much above 50 and nothing lowers stress.

| Scenario | Attendance | Grades | Stress (end) | Energy (end of day) |
| --- | --- | --- | --- | --- |
| Default | 89.5% | 44.5 | 60.4 | 66.6 |
| 2 units per student | 91.7% | 44.9 | 29.1 | 81.5 |
| 6 units per student | 81.5% | 40.3 | 91.5 | 53.9 |
| Day starts 06:00, 120-minute commute | 61.0% | 30.6 | 53.7 | 48.0 |
| Day starts 10:00, 10-minute commute | 95.1% | 47.3 | 65.2 | 74.9 |
| 6 assessments per unit, clustering 1 | 89.5% | 44.6 | 99.1 | 66.6 |
| 6 assessments per unit, clustering 0 | 89.5% | 44.5 | 99.1 | 66.6 |
| Gap between slots 0 | 88.6% | 49.5 | 61.8 | 64.4 |
| Room capacity 0.5 × | 88.9% | 44.3 | 70.0 | 66.9 |

What this shows:

- **The trade-off is there.** More units push stress up and energy down. A late start with a short commute raises attendance, grades and energy, and also raises stress, because students sit through more class hours.
- **Early starts and long commutes work without any special rule.** Attendance falls to 61% and grades follow.
- **Stress runs high** (60 at default) because food stops and breaks, the two things that lower it, are not built. Re-check the stress sizes once they are.
- Findings 6 and 7 above come from this table.

## Adding a determinant

A determinant costs two things:

1. **One row in the effects table** (`EFFECTS` in `sim/students/StateEffects.gd`), with a number per state and a source or stated assumption for each number.
2. **The sim has to notice the event.** Most are already events the engine handles (attended, skipped, arrived late, walked). Some need a small check, such as counting today's classes.

Keep the table short. Every number needs a justification.

## Scenarios are not code

Nobody writes "if the day starts at 7am, lower attendance". A scenario is a saved set of parameter values (`data/scenarios/*.json`). An early start lowers energy, low energy raises the skip chance, and skipped classes mean fewer hours and lower grades. The effect comes out of the rules.

If a result looks wrong, change a number in the effects table. Don't add a special case.

## In the code

**Built**

- **`sim/students/Student.gd`** has `stress` and `energy` (0 to 100), `commute_minutes`, hours attended and hours studied per unit, and the assessment marks per unit. `grade()` is the grades state.
- **`sim/students/StateEffects.gd`** holds the effects table (`EFFECTS`) and `apply(student, event, amount)`. It is the only place that changes stress and energy, and the only place the sizes live.
- **`sim/students/Grades.gd`** is the grade formula: hours expected, the mark, and the unit grade.
- **`sim/timetable/Assessment.gd`** and **`AssessmentPlanner.gd`**: each unit gets `Params.assessments_per_unit` assessments spread over the 12 teaching weeks. `Params.deadline_clustering` decides whether different units' deadlines fall in different weeks (0) or the same weeks (1).
- **`sim/core/SimEngine.gd`** calls `apply()` for: hours of class attended, skipping, arriving late, walking, back-to-back classes, the commute and early start, deadlines approaching, and an overcrowded room. The weekly timetable repeats, up to 84 days. At the end of each week the assessments due that week are marked.
- **`decisions/RuleDecision.gd`** is rule 3: `skip_chance(student)` from energy. The app uses it.
- **`decisions/DecisionContext.gd`**: `to_features()` carries stress and energy.
- **Tests:** `test_state_effects.gd`, `test_grades.gd`, `test_assessment_planner.gd`, `test_rule_decision.gd` and `test_sim_engine.gd`.

**Not built yet**

| Row or feature | Waiting for |
| --- | --- |
| Hours of study, food stop | The errand planner and food outlets (Hayyaan) |
| Breaks, exam period, semester after semester | The semester calendar (Sprint 4) |
| State averages in `Stats` and the semester report | The dashboard work (Siw) |

Until study and food stops exist, grades stay near 50 at most and nothing lowers stress.
