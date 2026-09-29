# Parameters and effects

**Status: final list of 44 parameters** (decision #9 in `DECISIONS.md`). Don't add new ones without checking with the team first. Nothing new here is in the code yet. Parameters marked ✓ are already in `autoload/Params.gd`, and effects marked ✓ are already tracked in `autoload/Stats.gd`. Every new default is a starting guess. Arya checks it against a source before it goes into `Params.gd`.

## How a run works

**The simulation never ends on its own.** It keeps running semester after semester until the user stops it (see decision #7 in `DECISIONS.md`).

- Each semester has teaching weeks, a mid-semester break and an exam period, then a break before the next one.
- At the end of every semester the dashboard shows a **semester report** and adds it to the history, so you can see trends across semesters.
- Students move through their degree: each year some graduate, a new intake starts, and some drop out. Stress and motivation carry over between semesters.
- **Lecturers and tutors are simulated too** (see decision #8 in `DECISIONS.md`). They have their own timetables and walk between classes, and a class can't start until its teacher arrives.
- You can change parameters while it runs. Some take effect straight away and others at the start of the next semester (see [When a change takes effect](#when-a-change-takes-effect)). The dashboard marks the semester where a parameter changed, so you can see the before and after.
- Live stats (today, this week) keep updating in between semester reports.

## Algorithms we write ourselves

Our supervisor wants pathing, scheduling and walking distance coded by us, so we don't use Godot's `AStar2D`, `NavigationServer` or `NavigationAgent`.

| Problem | Where it appears in the sim | Algorithm |
| --- | --- | --- |
| Shortest path | Walking from one class to the next | Dijkstra from each building, stored as a lookup table (`Campus.gd`). A* once 3D floors add many more nodes |
| Travelling salesman | **Errands in free time.** A student has 50 minutes before class and wants food, the library and the printer. Which stops, in what order, while still arriving on time? | Held-Karp (exact) for up to about 10 stops; nearest neighbour + 2-opt for more. With the class start as a deadline this is the *orienteering problem* (TSP with time windows) |
| Scheduling | Building the timetable: no room double-bookings, no student clashes, no staff clashes, staff teaching-hour limits | Greedy graph colouring + backtracking, then local search to reduce gaps and long walks |
| Congestion | Busy paths slow everyone down | BPR function from traffic engineering: `t = t0 * (1 + alpha * (flow / capacity) ^ beta)` |

Walking between classes on its own is **not** a travelling salesman problem, because the timetable already fixes the order. The TSP appears when the student chooses the order, which is the errands case.

**3D later:** the campus is stored as a graph (points joined by walking distances). Floors, stairs and lifts become extra points and links, so the algorithms above don't change. Lift queues are a good extra effect.

## Parameters

44 in total: **39 simulation parameters** (12 on the main panel, 5 set by the calendar preset, 22 under Advanced settings) plus **5 controls, map and test settings**. Names match the parameter screen. ✓ = already in `autoload/Params.gd` (sometimes under a code name, e.g. `room_capacity_multiplier`).

**When** says when a change during a run takes effect: **Now** (the next walk or decision), or **Next sem** (the next semester, because it needs a new timetable or intake).

### Main panel (12)

| # | Parameter | Range | Default | When | Why we chose it |
| --- | --- | --- | --- | --- | --- |
| 1 | ✓ Students | 50–5000 | 500 | Next sem | "What if enrolments grow?" Drives crowding and room pressure |
| 2 | New intake per year | 0–2000 | 170 | Next sem | The sim never ends, so new students must arrive or the population never changes |
| 3 | ✓ Gap between slots | 0–30 min | 10 | Next sem | The time students have to walk between classes. The main lateness lever |
| 4 | ✓ Lecture length | 30–180 min | 120 | Next sem | "Are 2-hour lectures too long?" Fatigue and long days |
| 5 | ✓ Day starts | 6–12 (hour) | 8 | Next sem | "Do 8am classes hurt attendance?" |
| 6 | ✓ Walking speed | 40–120 m/min | 80 | Now | Turns walking distance into travel time, the core mechanic |
| 7 | ✓ Room capacity | 0.5–1.5 × | 1.0 | Next sem | "What if rooms are smaller?" Overfull rooms, students turned away |
| 8 | Deadline clustering | 0–1 | 0.5 | Next sem | Deadlines bunch up in weeks 10–12 in real semesters. The main stress lever (0 = spread out, 1 = all in the same weeks) |
| 9 | Lecture recordings | 0–100% | 80% | Next sem | A common real reason students skip lectures |
| 10 | Food outlets | 1–10 | 4 | Now | Places to go between classes, which creates the travelling-salesman errands, plus lunch queues |
| 11 | Tutors per unit | 1–10 | 3 | Next sem | A real limit on how many tutorial groups a unit can run, and so on tutorial size |
| 12 | Staff absence rate | 0–10% | 2% | Now | Cancelled classes and wasted student trips. Happens every semester |

### Calendar (5), set by one preset dropdown

| # | Parameter | Monash standard | Trimester | Why we chose it |
| --- | --- | --- | --- | --- |
| 13 | Teaching weeks per semester (replaces ✓ days to simulate) | 12 | 10 | Core of the calendar. The sim reports at the end of every semester |
| 14 | Semesters per year | 2 | 3 | How often reports and new timetables happen |
| 15 | Break between semesters (weeks) | 4 | 2 | Stress recovers between semesters. The sim skips quickly through it because nothing is scheduled |
| 16 | Mid-semester break | on | off | A real recovery week. Shows how breaks affect stress |
| 17 | Exam period | on | on | The final stress peak of each semester |

All five take effect at the next semester. The preset values are starting guesses for Arya to check.

### Advanced settings (22)

| # | Parameter | Range | Default | When | Why we chose it |
| --- | --- | --- | --- | --- | --- |
| | **Population** | | | | |
| 18 | ✓ Units | 5–60 | 20 | Next sem | How varied the timetable is, and so how hard it is to schedule without clashes |
| 19 | ✓ Units per student | 1–6 | 4 | Next sem | Each student's workload. Feeds stress and clashes |
| 20 | Course length | 2–5 years | 3 | Next sem | When students graduate. Keeps the population moving with New intake per year |
| 21 | Commuters by public transport | 0–100% | 55% | Next sem | Long-distance commuters skip days with only one class, and trains and buses make arrivals come in bursts at the BRT station. The rest walk, drive or live on campus in fixed shares |
| 22 | Average commute | 5–120 min | 45 | Next sem | Decides whether coming in for a single class is "worth it" |
| 23 | Part-time work | 0–30 hrs/week | 10 | Next sem | Working students have less time and get more tired |
| 24 | Resilience (average) | 0–1 | 0.5 | Next sem | Students handle stress differently, so they don't all struggle at the same moment. The spread around the average is a fixed value |
| | **Semester** | | | | |
| 25 | Assessments per unit | 1–6 | 3 | Next sem | How many stress spikes students face |
| | **Timetable** | | | | |
| 26 | ✓ Tutorial length | 30–180 min | 60 | Next sem | Same idea as Lecture length, for tutorials and labs |
| 27 | ✓ Day ends | 14–22 (hour) | 18 | Next sem | Long days mean fatigue and leaving early |
| | **Campus** | | | | |
| 28 | Walking speed spread | 0–30 m/min | 10 | Now | Real people walk at different speeds, so some are always late |
| 29 | ✓ Crowding strength | 0–1 | 0.3 | Now | Busy paths slow people down (alpha in the BPR traffic formula). Matters more than distance on our compact campus |
| 30 | Library seats | 50–2000 | 300 | Now | A second errand destination, and where students spend gaps |
| | **Behaviour** | | | | |
| 31 | ✓ Leave early by | 0–15 min | 5 | Now | How early students aim to arrive. Decides when they start walking |
| 32 | ✓ Late after | 0–15 min | 5 | Now | When an arrival counts as late. Needed for the lateness stats |
| 33 | ✓ Too late to enter | 5–60 min | 20 | Now | When a late student gives up. Turns lateness into skips |
| 34 | ✓ Base attendance chance | 0.3–1.0 | 0.85 | Now | The overall attendance level before other effects |
| 35 | Friend influence | 0–1 | 0.3 | Now | Skipping spreads through friend groups (friends = students who share units). A peer effect that's interesting to watch emerge |
| 36 | Stress per deadline | 0–1 | 0.3 | Now | How hard each deadline hits. Needed for stress to work |
| 37 | Fatigue per class hour | 0–0.2 | 0.03 | Now | Long days make students tired and more likely to skip later classes |
| | **Staff** | | | | |
| 38 | Max teaching hours | 4–20 hrs/week | 12 | Next sem | A real timetabling constraint. Makes scheduling harder and more realistic |
| 39 | Staff punctuality | 0–15 min | 5 | Now | How early staff leave for class. A late teacher delays the whole class, so lateness spreads from one person to many |

### Controls, map and test settings (5)

| # | Parameter | Where | Default | Why we chose it |
| --- | --- | --- | --- | --- |
| 40 | ✓ Sim speed | Toolbar | 5 sim min/s | Watch a slow morning or skip through a semester. Playback only, doesn't change results |
| 41 | ✓ Seed | Toolbar | 42 | Same seed and same settings give the same result, so experiments can be repeated |
| 42 | Path closures | Click a path on the map | none | Shows the pathfinding live: close a path and students reroute |
| 43 | Path capacity | Map data (`campus.json`) | from data | Narrow paths become bottlenecks |
| 44 | Stop after N semesters | Headless runs only | 0 (never) | Test and data-logging runs need an end point. The normal app never stops |

The parameter panel should show which changed parameters are waiting for the next semester.

## Build order

This is the order to build them in, based on how much each one shows off the core work (pathing, scheduling, walking, continuous time), how visible its effect is, and how much it costs.

**Tier 1: first, aim for Week 12**
- Calendar (teaching weeks, semesters per year, break between semesters): the continuous run needs them
- New intake per year, Course length: without them the population never changes
- Tutors per unit, Max teaching hours: staff clashes and limits make the scheduling realistic
- Path closures: shows the pathfinding live (close a path, watch students reroute and get late)
- Walking speed spread: one number that makes lateness realistic
- Food outlets, Library seats: places to go between classes, which is what creates the errands travelling-salesman problem
- Deadline clustering, Stress per deadline, Resilience (average): the smallest set that makes stress work
- Lecture recordings: one number with a big effect on attendance

**Tier 2: next**
- Commuters by public transport, Average commute: realistic, but need arrival modelling (train bursts, parking)
- Friend influence: a strong emergent effect, but needs a friend network
- Mid-semester break, Exam period, Assessments per unit: cheap once the semester calendar exists
- Staff absence rate, Staff punctuality: cancellations and late starts

**Tier 3: if there's time**
- Part-time work
- Fatigue per class hour

## Considered and dropped

- **2026-09-25:** timetable compactness, max back-to-back classes, protected lunch hour, online / hybrid share, rain chance per day, food service time (a fixed named constant instead), fatigue per km walked.
- **2026-09-29:** Motivation (average) and Burnout threshold. Students still have motivation and can still burn out, but the starting motivation and the stress level where burnout starts are fixed values in the code, not settings.

## Effects (outputs)

Live values (today, this week) update while the sim runs. Each area below also goes into the **semester report** at the end of every semester, and the reports are kept so each effect can be charted across semesters.

| Area | Effects |
| --- | --- |
| Attendance | ✓ Attendance rate, ✓ by unit, ✓ by day, ✓ skips by reason. New: lecture vs tutorial, by time of day (early classes), attendance decline across the weeks |
| Lateness | ✓ Late count, ✓ average minutes late, ✓ too late to enter. New: lateness hotspots, meaning which building-to-building walks cause the most lateness |
| Movement | Distance walked per student per day, time spent walking, busiest paths (heatmap), bottlenecks, reroutes caused by closures |
| Rooms | Room use over time, overfull rooms (students turned away), under-used bookings (under 30% full), peak occupancy |
| Facilities | Lunch queue wait, library occupancy, errands completed vs given up (the TSP result) |
| Wellbeing | Average stress across the semester (it should peak with deadline clusters), stress spread, fatigue, number of burnt-out students (burnout starts at a fixed stress level), motivation trend |
| Time use | Hours on campus, dead time between classes, commute time compared with class time |
| Semester outcomes | Engagement score leading to pass / at-risk / fail bands, dropout risk, withdrawals. These link to the UCI Dropout dataset in Semester 2 |
| Fairness | Any effect above split by group: commuters vs on-campus students, working vs not working, year level. Shows who a bad timetable hurts most |
| Staff | Classes starting late (and by how much), cancelled classes, student trips wasted on a cancelled class, staff teaching hours, staff walking distance |
| Across semesters | Trend of every headline number per semester, population over time, retention of each intake (cohort), graduation rate, dropouts per semester, and markers showing where parameters were changed |

## What this needs in the code

- **No end time:** `SimEngine` currently has an `end_time` and stops at midnight after `days_to_simulate` days. The app version runs with no end, and only headless runs use "Stop after N semesters".
- **Schedule as you go:** `SimEngine.setup()` currently puts every class event in the queue at the start. An endless run can't do that, so each week (or semester) schedules the next one: a `WEEK_START` event queues that week's classes, and a `SEMESTER_START` / `SEMESTER_END` pair builds the timetable, runs intake and graduation, and sends the report.
- **Calendar:** add week and semester numbers to `SimTime`. Time can stay as float minutes: GDScript floats are 64-bit, so years of minutes keep full precision.
- **Stats per semester:** `Stats` keeps live counters plus a list of finished semester reports. A new `EventBus.semester_ended(report)` signal lets the dashboard and the CSV logger save each one.
- **State that carries over:** stress, fatigue and motivation carry between days, weeks and semesters. `Student.gd` has `motivation` and `tiredness`, but nothing updates them yet.
- **Changing students:** intake, graduation and dropout add and remove students while the sim runs, so MapView's MultiMesh and every per-student list must handle a changing population.
- **Staff:** add a `Staff` class. Put the walking and location logic in a shared base class that `Student` and `Staff` both extend, so it's written once. There are only around 50–150 staff, so the cost is small.
- **Class start depends on the teacher:** today a class starts at a fixed time (`CLASS_START`). With staff, the actual start is `max(scheduled start, teacher arrives)`, and student lateness is measured from the actual start. This touches the lateness rules in `SimEngine` and the timetable generator, so the engine and timetable owners agree on it first.
- **Cancellations:** an absent teacher cancels the class. Students still walk there unless they find out first, and the trip counts as wasted.
- **Memory:** keep one summary per semester, not every event, so long runs don't keep growing.
- **Speed:** one semester is about 5,000 students × 12 weeks, so millions of events. In the app it plays at the chosen speed, but headless runs must be fast enough to log many semesters. Measure early.
- **Adding a parameter:** follow the rules in `CLAUDE.md`: a typed var plus a `SPECS` entry in `Params.gd`, the value in `data/scenarios/default.json`, and a source for the default.
