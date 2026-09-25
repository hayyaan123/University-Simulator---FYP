# Parameters and effects

**Status: proposal for team review.** Nothing new here is in the code yet. Parameters marked ✓ are already in `autoload/Params.gd`, and effects marked ✓ are already tracked in `autoload/Stats.gd`. Every new default is a starting guess. Arya checks it against a source before it goes into `Params.gd`.

The goal is a campus you can adjust and then watch the effects play out over a whole simulated **semester**: 12 teaching weeks, a mid-semester break and the exam period. Results are shown per day, per week and at the end of the semester.

## Algorithms we write ourselves

Our supervisor wants pathing, scheduling and walking distance coded by us, so we don't use Godot's `AStar2D`, `NavigationServer` or `NavigationAgent`.

| Problem | Where it appears in the sim | Algorithm |
| --- | --- | --- |
| Shortest path | Walking from one class to the next | Dijkstra from each building, stored as a lookup table (`Campus.gd`). A* once 3D floors add many more nodes |
| Travelling salesman | **Errands in free time.** A student has 50 minutes before class and wants food, the library and the printer. Which stops, in what order, while still arriving on time? | Held-Karp (exact) for up to about 10 stops; nearest neighbour + 2-opt for more. With the class start as a deadline this is the *orienteering problem* (TSP with time windows) |
| Scheduling | Building the timetable: no room double-bookings, no student clashes | Greedy graph colouring + backtracking, then local search to reduce gaps and long walks |
| Congestion | Busy paths slow everyone down | BPR function from traffic engineering: `t = t0 * (1 + alpha * (flow / capacity) ^ beta)` |

Walking between classes on its own is **not** a travelling salesman problem, because the timetable already fixes the order. The TSP appears when the student chooses the order, which is the errands case.

**3D later:** the campus is stored as a graph (points joined by walking distances). Floors, stairs and lifts become extra points and links, so the algorithms above don't change. Lift queues are a good extra effect.

## Parameters

### Population

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| ✓ Students | 50–5000 | 500 | Crowding and room pressure |
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
| Teaching weeks (replaces ✓ days to simulate) | 1–15 | 12 | Length of the run |
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

### Run

| Parameter | Range | Default | What it changes |
| --- | --- | --- | --- |
| ✓ Sim minutes per second | 0.5–240 | 5 | Playback speed only |
| ✓ Random seed | any int | 42 | Same seed + same parameters = same result |

## Effects (outputs)

Shown per day and per week while the sim runs, and as a report at the end of the semester.

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

## What this needs in the code

- **Semester-length runs:** add a week number to `SimTime`, repeat the weekly timetable, and replace the 7-day `days_to_simulate` limit.
- **State that carries over:** stress, fatigue and motivation carry from day to day and week to week. `Student.gd` has `motivation` and `tiredness`, but nothing updates them yet.
- **Speed:** 5,000 students over 12 weeks is millions of events. Measure the headless run time early.
- **Adding a parameter:** follow the rules in `CLAUDE.md`: a typed var plus a `SPECS` entry in `Params.gd`, the value in `data/scenarios/default.json`, and a source for the default.
