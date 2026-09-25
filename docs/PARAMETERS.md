# Parameters and effects

**Status: proposal for team review.** Nothing new here is in the code yet. Parameters marked ✓ are already in `autoload/Params.gd`, and effects marked ✓ are already tracked in `autoload/Stats.gd`. Every new default is a starting guess. Arya checks it against a source before it goes into `Params.gd`.

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

### Population

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| ✓ Students (starting population) | 50–5000 | 500 | Crowding and room pressure |
| New intake per year | 0–2000 | 170 | Population growth or shrinkage over the years |
| Course length (years) | 2–5 | 3 | When students graduate |
| ✓ Units | 5–60 | 20 | Timetable variety |
| ✓ Units per student | 1–6 | 4 | Workload and stress |
| Commute mix (walk / public transport / car / live on campus) | shares adding to 100% | 10 / 55 / 25 / 10 | Arrivals come in bursts (trains); a long commute makes a one-class day less worth it |
| Average commute (min) | 5–120 | 45 | Skipping days with only one class |
| Part-time work (hours per week) | 0–30 | 10 | Fatigue, less free time, more skipping |
| Motivation (mean / spread) | 0–1 | 0.7 / 0.15 | Baseline attendance |
| Resilience (mean / spread) | 0–1 | 0.5 / 0.2 | How fast stress builds up and recovers |

### Semester

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| Teaching weeks per semester (replaces ✓ days to simulate) | 1–15 | 12 | Length of each semester |
| Semesters per year | 1–3 | 2 | How often reports appear and timetables change |
| Break between semesters (weeks) | 0–12 | 4 | Stress recovery; the sim skips quickly through it because nothing is scheduled |
| Mid-semester break | on / off | on | A week for stress to recover |
| Exam period | on / off | on | Final stress peak, different campus use |
| Assessments per unit | 1–6 | 3 | Number of stress spikes |
| Deadline clustering | 0–1 | 0.5 | 0 = deadlines spread across the semester, 1 = all units due in the same weeks |
| Lecture recordings available | 0–100% | 80% | Lecture attendance drops when recordings exist |

### Timetable

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| ✓ Lecture length (min) | 30–180 | 120 | Fatigue, long days |
| ✓ Tutorial length (min) | 30–180 | 60 | Fatigue, long days |
| ✓ Gap between slots (min) | 0–30 | 10 | The main cause of lateness between far-apart classes |
| ✓ Day starts / ends (hour) | 6–12 / 14–22 | 8 / 18 | Early-class skipping, long days |
| Timetable compactness | 0–1 | 0.5 | Packed days (tiring, fewer trips to campus) vs spread days (gaps, more commuting) |
| Max back-to-back classes | 1–6 | 3 | Fatigue, missed lunch |
| Protected lunch hour | on / off | off | Lunch queues, afternoon fatigue |
| Online / hybrid share | 0–100% | 10% | Fewer students on campus |

### Campus and movement

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| ✓ Walking speed (m/min) | 40–120 | 80 | Travel time |
| Walking speed spread (m/min) | 0–30 | 10 | Some students are always slower and more often late |
| ✓ Crowding strength | 0–1 | 0.3 | How much busy paths slow people down (alpha in the BPR function) |
| Path capacity | per path, in `campus.json` | from data | Bottlenecks on narrow paths |
| Path closures | choose paths | none | Forces rerouting (shows the pathfinding working) |
| ✓ Room capacity multiplier | 0.5–1.5 | 1.0 | Overfull rooms, students turned away |
| Rain chance per day | 0–100% | 20% | Slower walking, more skipping, covered paths preferred |
| Food outlets | 1–10 | 4 | Lunch queues |
| Food service time (min per person) | 1–5 | 2 | Lunch queues, lateness after lunch |
| Library seats | 50–2000 | 300 | Where students spend gaps |

### Behaviour

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| ✓ Leave early by (min) | 0–15 | 5 | How early students aim to arrive |
| ✓ Late after (min) | 0–15 | 5 | When an arrival counts as late |
| ✓ Too late to enter (min) | 5–60 | 20 | When a late student gives up |
| ✓ Base attendance chance | 0.3–1.0 | 0.85 | Overall attendance |
| Friend influence | 0–1 | 0.3 | Skipping spreads through friend groups (friends = students who share units) |
| Stress per deadline | 0–1 | 0.3 | How hard each deadline hits |
| Fatigue per km walked | 0–0.2 | 0.05 | Tiredness from walking |
| Fatigue per class hour | 0–0.2 | 0.03 | Tiredness from long days |
| Burnout threshold | 0.5–1.0 | 0.85 | Stress level where students start to disengage |

### Staff (lecturers and tutors)

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| Tutors per unit | 1–10 | 3 | Number of tutorial groups, and so tutorial size |
| Max teaching hours per staff member per week | 4–20 | 12 | Scheduling pressure; staff teaching back-to-back across campus |
| Staff absence rate | 0–10% | 2% | Cancelled classes and wasted student trips |
| Staff punctuality (leave early by, min) | 0–15 | 5 | Classes starting late |

### Run

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| ✓ Sim minutes per second | 0.5–240 | 5 | Playback speed only |
| ✓ Random seed | 0 or more | 42 | Same seed + same parameter changes at the same sim times = same result |
| Stop after N semesters | 0–50 | 0 (never) | Headless runs and tests only (data logging, experiments). The normal app ignores it |

### When a change takes effect

| Takes effect | Parameters | Why |
| --- | --- | --- |
| Straight away | Walking speed and spread, crowding strength, path closures, rain, food outlets and service time, library seats, all Behaviour parameters, staff absence rate, staff punctuality, sim speed | They only change how the next walk or decision plays out |
| Next semester | Population, Semester and Timetable parameters, room capacity multiplier, tutors per unit, max teaching hours | They need a new timetable or a new intake, which are built at the start of a semester |

The parameter panel should show which parameters are waiting for the next semester.

## Build order

All the parameters above are planned. This is the order to build them in, based on how much each one shows off the core work (pathing, scheduling, walking, continuous time), how visible its effect is, and how much it costs.

**Tier 1: first, aim for Week 12**
- Teaching weeks per semester, semesters per year, break between semesters: the continuous run needs them
- New intake per year, course length: without them the population never changes
- Timetable compactness, max back-to-back classes: they drive the scheduler directly
- Tutors per unit, max teaching hours per staff member: staff clashes and limits make the scheduling realistic
- Path closures: shows the pathfinding live (close a path, watch students reroute and get late)
- Walking speed spread: one number that makes lateness realistic
- Food outlets, library seats: give students places to go between classes, which is what creates the errands travelling-salesman problem
- Deadline clustering, stress per deadline, resilience, burnout threshold: the smallest set that makes stress work
- Lecture recordings available: one number with a big, well-documented effect on attendance
- Motivation (mean / spread): needed to give students starting values anyway

**Tier 2: next**
- Commute mix, average commute: realistic, but need arrival modelling (train bursts, parking)
- Friend influence: a strong emergent effect, but needs a friend network
- Food service time: turns lunch into proper queues
- Fatigue per km walked: links walking to behaviour
- Mid-semester break, exam period, assessments per unit: cheap once the semester calendar exists
- Staff absence rate, staff punctuality: cancellations and late starts

**Tier 3: if there's time**
- Rain chance per day
- Part-time work, online / hybrid share, protected lunch hour
- Fatigue per class hour

## Effects (outputs)

Live values (today, this week) update while the sim runs. Each area below also goes into the **semester report** at the end of every semester, and the reports are kept so each effect can be charted across semesters.

| Area | Effects |
| --- | --- |
| Attendance | ✓ Attendance rate, ✓ by unit, ✓ by day, ✓ skips by reason. New: lecture vs tutorial, by time of day (early classes), attendance decline across the weeks |
| Lateness | ✓ Late count, ✓ average minutes late, ✓ too late to enter. New: lateness hotspots, meaning which building-to-building walks cause the most lateness |
| Movement | Distance walked per student per day, time spent walking, busiest paths (heatmap), bottlenecks, reroutes caused by closures |
| Rooms | Room use over time, overfull rooms (students turned away), under-used bookings (under 30% full), peak occupancy |
| Facilities | Lunch queue wait, library occupancy, errands completed vs given up (the TSP result) |
| Wellbeing | Average stress across the semester (it should peak with deadline clusters), stress spread, fatigue, number of burnt-out students, motivation trend |
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
