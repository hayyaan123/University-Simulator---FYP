# Evidence review: 15 university simulator parameters

**Research contribution:** Arya | **Review date:** 2026-10-18 | **Status:** proposed documentation for team review; no simulator logic or parameters changed.

## Purpose and evidence rules

This document reviews **the same 15 parameters** agreed in [`PARAMETERS.md`](PARAMETERS.md), in the team's existing order. It does **not** propose 15 additional sliders. The model's causal chain is **parameter → determinant → student state (grades, stress, energy) → semester metric**; grades are derived from study/class hours and energy, not stress, affects attendance decisions in v1. See [`STUDENT_MODEL.md`](STUDENT_MODEL.md).

**Evidence labels:**

- **Institutional rule:** an official university workload or course-structure statement.
- **Direct research:** study addresses the stated outcome among university students or a closely matching context.
- **Indirect research:** evidence gives a plausible direction but does not measure the exact simulator mechanism.
- **Model assumption:** range, default or 0–100 state-point effect chosen by the team, **not** a measured real-world number.

Most research supports **directions**, not point-valued simulator effects. An association does not on its own prove that changing the corresponding slider causes the observed outcome. Unless otherwise stated, *the current default and allowed range come from the team's `PARAMETERS.md`, not from the cited study*.

## At-a-glance evidence and readiness

| # | Parameter | Current default | Evidence useful to simulation | Readiness / unresolved issue |
| --- | --- | --- | --- | --- |
| 1 | Students | 500 | Capacity/room utilisation depends on enrolment; class-size studies give context [R08] | 500 is a test population, not a measured campus enrolment |
| 2 | Units per student | 4 | Monash typical full-time load is four 6-point units [R01] | Supported **as a typical load**, not the whole 1–6 range |
| 3 | Average commute | 45 min | Commute and campus presence are associated [R04] | Exact 45 min and fixed energy/minute need calibration |
| 4 | Resilience (parked) | 70/100 | Stress–resilience association [R10] | **Do not implement** without an approved determinant |
| 5 | Teaching day (start/end) | 08:00–18:00 | Early class schedules associated with shorter sleep and reduced attendance [R05] | Ten-hour campus window is a schedule assumption |
| 6 | Class length | 120/60 min | Classroom movement breaks may improve alertness [R11] | Evidence does not prove a fixed loss per class hour |
| 7 | Gap between slots | 10 min | Breaks support alertness; movement requires walking time [R11, R12] | Zero-gap tests previously found no late arrivals |
| 8 | Room capacity | 1.0× | Large university classes can be associated with lower results [R08]; crowd density raises arousal [R09] | Overfull rooms: students get in with a stress hit (decision #24) |
| 9 | Food outlets (open) | 4 | Food access matters, but campus-food studies do not fix stop effects [R13, R06] | System not built; count and energy gain are assumptions |
| 10 | Assessments per unit | 3 | Academic assessment pressure contributes to stress [R07] | Three is a balanced experimental baseline, not a literature rule |
| 11 | Deadline clustering | 0.5 | Workload timing matters; stress is not only final total [R07] | Current model shows equal final stress at 0 and 1 |
| 12 | Lecture recordings | 0% | Review of 71 papers finds benefits, drawbacks and weak causal evidence [R14] | Semester 2; recorded hour equivalence is an assumption |
| 13 | Staff reliability | 2% / 5 min | Missed class time is relevant to achievement [R03] | Semester 2; figures need campus data, staff agents |
| 14 | Tutors per unit | 3 | University class-size findings give indirect support [R08] | Semester 2; no evidence for 3 specifically |
| 15 | Friend influence | 0.3 | University peer effects are mixed across studies [R15, R16] | Semester 2; shared unit ≠ confirmed friendship |

## Individual factor reviews

### 1. Students (`student_count`)

- **Current specification:** 50–5000, default **500**, implemented. More students can raise room utilisation and crowding, assuming room stock and timetables do not scale equally.
- **Evidence:** In an Italian university setting, De Paola & Scoppa found larger teaching classes negatively affected examination outcomes [R08]. This is about **class size**, not a finding that total campus population directly harms grades.
- **Simulation link:** students → competition for available rooms / overcrowded classes → **stress ↑, energy slightly ↓** (proposed overcrowding treatment in `STUDENT_MODEL.md`); when food queues are built, free time also changes.
- **Default assessment:** **500 is an engineering baseline**, suitable for reproducible runs; do not describe it as Monash Malaysia's enrolment. Need room-size data and enrolment statistics to claim local realism.
- **Check:** 250 vs 500 vs 750 with the same seed; log overloaded-class events per 100 students and peak crowding, not just semester means.

### 2. Units per student (`units_per_student`)

- **Current specification:** 1–6, default **4**, implemented.
- **Evidence:** Monash states that a typical full-time course load is **24 credit points per semester**, usually four 6-point units, and each such unit requires about **12 hours/week over 12 weeks** [R01]. This supports **4** as a meaningful default, not 6 as ordinary practice.
- **Simulation link:** more units → more classes, assessment deadlines and travel → **stress ↑, energy ↓**; attendance/study hours then influence **grades**.
- **Default assessment:** **institutionally supported typical load**, with the assumption that simulated units resemble 6-point units. Unit-to-unit difficulty is intentionally excluded.
- **Check:** 2 / 4 / 6 units; compare class hours, number of deadlines, attendance, end stress and energy.

### 3. Average commute (`average_commute_minutes`)

- **Current specification:** 5–120 minutes, default **45 minutes**, implemented; each student's commute is drawn from 50%–150% of the average.
- **Evidence:** Kobus, Rietveld & van Ommeren report that longer commutes are associated with fewer campus visits and poorer academic outcomes [R04]. They do not provide a conversion between a minute of travel and a point on this project's energy scale.
- **Simulation link:** commute → **energy ↓** → higher chance of skipping → fewer class hours → **grades potentially ↓**. Do **not** also subtract grades directly.
- **Default assessment:** **45 minutes and energy −0.167/min are team assumptions**. A survey or local transport evidence is needed for location-specific calibration.
- **Check:** 15 / 45 / 90 minutes and identical timetable/seed. Inspect students with very long individual commutes and early classes.

### 4. Resilience (**parked**, no `Params.gd` entry)

- **Current specification:** proposed 0–100, previous default **70**, **not active**.
- **Evidence:** A 2025 meta-analysis of 25 studies (32,613 students) reported a **moderate negative correlation between resilience and stress (r ≈ −0.29)**; this is an association and not a defensible burnout threshold [R10].
- **Simulation link:** **none in v1**. The team explicitly removed stress-driven skipping; adding this slider without an observable determinant would mislead users.
- **Default assessment:** **70/100 is unsupported and inactive**. Do not add or calibrate it until the supervisor/team defines a measurable, implementable role.
- **Check:** not applicable in current runs. An approved future design would need explicit burnout rules and independent validation.

### 5. Teaching day (`day_start_hour`, `day_end_hour`)

- **Current specification:** start 6–12, end 14–22; default **08:00–18:00**; this counts as **one** parameter with two settings.
- **Evidence:** Yeo et al. find that early-morning university classes are associated with less sleep and poorer attendance/academic outcomes [R05]. The existing model documentation reports around **10 percentage points lower attendance for 08:00 classes**; confirm the exact comparison from the primary paper before reporting it as independently verified.
- **Simulation link:** earlier first class → early-start energy penalty → **energy ↓**, then attendance decisions and learned hours; a long teaching-day window changes the schedule possibilities, not a guaranteed ten hours spent in classes.
- **Default assessment:** **08:00–18:00 is a planning window**, not a published energy dose. The model's −25 energy per early-start hour was calibrated to an attendance pattern, not measured in energy points.
- **Check:** 08:00 vs 10:00 starts holding everything else constant; compare attendance for the first class and all classes.

### 6. Class length (`lecture_minutes`, `tutorial_minutes`)

- **Current specification:** 30–180 minutes, default **120-minute lecture / 60-minute tutorial**; a single parameter with two settings.
- **Evidence:** A study of university lectures found that short movement breaks improved concentration and alertness during longer classes [R11]. This supports considering sustained activity and opportunities to rest, **not** a universal linear energy loss.
- **Simulation link:** longer scheduled class → more attended hours → **grades ↑ through hours**, alongside **stress ↑** and **energy ↓**; students can skip due to low energy.
- **Default assessment:** durations are **team timetable assumptions**. An active-hour cost of 10 points is the project's energy-scale anchor, not an empirical unit conversion.
- **Check:** compare 60/60, 120/60, 180/60 under feasible room allocations; record total attended hours to distinguish longer teaching from fatigue.

### 7. Gap between slots (`slot_gap_minutes`)

- **Current specification:** 0–30 minutes, default **10 minutes**, implemented.
- **Evidence:** Movement-break research supports the possible importance of short pauses for alertness [R11]. It does not establish that **10 minutes** is enough to cross the specific Godot campus map; that depends on shortest-path length and walking speed.
- **Simulation link:** gap → ability to walk in time; zero-gap back-to-back classes → **stress ↑ and energy ↓**; lateness reduces **attended hours**, not grades directly.
- **Default assessment:** **10 minutes is a pragmatic timetabling assumption**. The existing check runs found no late arrivals even at gap 0, so the map distances or lateness rule may dilute this effect.
- **Check:** 0 / 10 / 20 / 30 minutes with logged travel-distance quantiles, late-arrival counts, and back-to-back events. Do not claim improved punctuality if no events change.

### 8. Room capacity (`room_capacity_multiplier`)

- **Current specification:** 0.5–1.5×, default **1.0×**, implemented.
- **Evidence:** University class-size research supports possible academic consequences of large groups [R08]. Research on human crowd density supports a relationship with arousal, but does not directly quantify classroom stress [R09].
- **Simulation link:** enrolment relative to capacity → **overcrowded-room events** → **stress ↑ (large), energy ↓ (slight)** under the revised `STUDENT_MODEL.md` proposal. The team confirmed this rule on 2026-10-09 (decision #24).
- **Default assessment:** **1.0× is a neutral multiplier**, not a survey-based value.
- **Check:** 0.5× / 1.0× / 1.5×, and document actual code behaviour for overfull rooms and number of overcrowding events.

### 9. Food outlets (open; not yet in `Params.gd`)

- **Current specification:** 1–10, proposed default **4**, **waiting for the errand planner and campus outlet data**.
- **Evidence:** A review of university-student food insecurity finds poorer dietary outcomes among food-insecure students [R13]. This demonstrates that access to food can matter for student well-being, **but food insecurity is not the same as changing a cafeteria count**. Micro-break evidence provides only indirect justification for rest effects [R06].
- **Simulation link:** outlets available → queue and travel time → opportunity for a food stop vs studying; a completed stop currently **reduces stress and increases energy** under the design, with no food-type differences.
- **Default assessment:** **4 outlets, +20 energy and −0.5 stress per stop are modelling assumptions**. Verify campus layout, service times, queue logic and successful stop counts before claiming a calibrated effect.
- **Check:** after implementation, 1 / 4 / 8 outlets; collect queue lengths, successful visits, missed classes, study time and all three states.

### 10. Assessments per unit (`assessments_per_unit`)

- **Current specification:** 1–6, default **3**, implemented.
- **Evidence:** Pitt et al. documented variation in student stress across the semester and academic pressure as a major source [R07]. This supports linking academic workload to stress, not an exact penalty per assessment.
- **Simulation link:** assessment count → number of **near-deadline days** → **stress ↑** (model applies +0.5 per near deadline per day). Grades are marked from accumulated learning hours, not directly deducted for assessments.
- **Default assessment:** **three assessments is a scenario choice**, not a Monash-wide rule; actual unit handbooks would be better evidence.
- **Check:** 1 / 3 / 6 assessments, logging total deadline exposure and stress peaks as well as semester-end averages.

### 11. Deadline clustering (`deadline_clustering`)

- **Current specification:** 0–1, default **0.5**, implemented.
- **Evidence:** Workload-related stress can vary by week [R07]. This suggests testing stress **timing** and recovery, not assuming a fixed effect on final average.
- **Simulation link:** clustering → when deadlines approach → **weekly stress spikes**; the total number of near-deadline days can remain unchanged, so end-of-semester stress can be identical.
- **Default assessment:** **0.5 is a design midpoint**, not an evidence-derived average. Existing model check runs show end stress of **99.1** for both 0 and 1 at six assessments/unit, an unresolved model issue.
- **Check:** 0 / 0.5 / 1, track **maximum weekly stress, weekly variance, time above 80,** and final stress; rerun after breaks/food are present.

### 12. Lecture recordings (Good to have)

- **Current specification:** 0–100% of units, default **0%**, **Semester 2**.
- **Evidence:** Banerjee's systematic review synthesised **71 lecture-capture studies**; students and teachers report contrasting perceived benefits/risks and causal evidence is relatively limited [R14]. A university programme study found beneficial associations from supplementing attendance with recordings in some groups [R17].
- **Simulation link:** recorded unit → recording use can count toward the time spent learning, as the team's planned determinant; watching time may cost energy. Effects on in-person attendance must be modelled and checked, not assumed.
- **Default assessment:** **0% is an explicit no-recordings control**, not the rate of recording at Monash. The one-hour-recording = one-hour-class convention is not proven by research.
- **Check:** only after implementation: 0% / 50% / 100%, distinguishing physical attendance, recording watch time and assessment marks.

### 13. Staff reliability (Good to have)

- **Current specification:** absence **0–10%**, default **2%**; punctuality **0–15 min**, default **5 min**, **Semester 2**.
- **Evidence:** Research on missed university classes supports a relationship between absence and student achievement [R03]. It does **not** independently quantify teacher absence rates or show that 2% and five minutes are typical.
- **Simulation link:** cancelled/late class → less usable student learning time (possibly after travelling); according to the team's planned rules, **grades change only through hours**, not direct penalties for cancelled lectures.
- **Default assessment:** **both figures are illustrative assumptions** until university timetabling or staffing data are available. Lecturer/tutor agents are required first.
- **Check:** 0% / 2% / 10% cancellations and 0 / 5 / 15 minutes delay, once implemented; track lost teaching hours and their downstream consequences.

### 14. Tutors per unit (Good to have)

- **Current specification:** 1–10, default **3**, **Semester 2**.
- **Evidence:** De Paola & Scoppa provide university-level evidence that class size can matter for assessments [R08]. However, the relation between tutor headcount, class size, quality and grades is not guaranteed or linear.
- **Simulation link:** available tutors → number of tutorial groups → tutorial size → potential difference in **learning gained per hour**, subject to explicit team approval of the planned rule.
- **Default assessment:** **three tutors is a staffing scenario assumption**, not a published norm. The planned state rule for tutorial learning needs a defined size and validation.
- **Check:** 1 / 3 / 6 tutors; log tutorial group size and student-hour allocation before fitting any achievement effect.

### 15. Friend influence (Good to have)

- **Current specification:** 0–1, default **0.3**, **Semester 2**.
- **Evidence:** University network studies suggest that peers and selection may matter for performance [R15], while another longitudinal learning-community study found **no detectable influence on academic performance** [R16]. Social similarity and causal peer influence should not be conflated.
- **Simulation link:** future friends/network → possibility of attending or skipping together, potentially changing hours and states indirectly. The team's assumption that students sharing units are "friends" is a **proxy**, not a measured social network.
- **Default assessment:** **0.3 has no defensible empirical meaning yet**; implement only with explicit mechanics, testable outcomes and team approval.
- **Check:** with a friend-network system: 0 / 0.3 / 1 and multiple seeds; distinguish correlated behaviour from a change actually caused by the parameter.

## Priority follow-up work

1. **High:** Verify the primary Yeo et al. paper's attendance contrast and the original sources marked incomplete in `STUDENT_MODEL.md` (especially Plant 2005 and Boksem 2008). A paywall/abstract alone is not full-text verification.
2. **High:** Resolve the room-capacity wording conflict (turn-away vs overcrowding stress), and rerun the zero-gap and clustered-deadline checks.
3. **High:** Obtain project-specific campus/classroom capacity, walking distances and if possible typical commute or timetable data; these are needed to calibrate values rather than merely cite general literature.
4. **Medium:** After food stops and breaks are implemented, rerun the stress results; the existing notes say that missing recovery mechanisms inflate end-of-semester stress.
5. **Medium:** For all assumption-sized state effects, perform 0.5×, 1.0× and 1.5× sensitivity analysis, taking care to log saturation at 0 and 100 (see [`RESEARCH_VALIDATION.md`](RESEARCH_VALIDATION.md)).
6. **Later:** Collect campus policies/data for recordings, staff punctuality, tutorial staffing and friendships *before* adding their four Semester-2 sliders.

## References and verification notes

The first several sources below are also listed in the team's existing `STUDENT_MODEL.md`. New sources were cross-checked against accessible journal, university, PubMed, or publisher abstracts/web pages on **2026-10-18**. **Abstract checked** means we verified the published summary, *not* that we have read and validated all methods, estimates or supplementary data. Some source findings are associations and are explicitly not causal constants for this simulator.

- **[R01] Institutional rule.** Monash University, *Handbook glossary*: four 6-point units per typical full-time semester; 12 hours/week for each 6-point unit for 12 weeks. <https://www.monash.edu/students/handbooks/help/handbook-glossary>. University page checked.
- **[R02] Direct research.** Credé, Roch & Kieszczynka (2010), *Class attendance in college: A meta-analytic review*, *Review of Educational Research*. <https://doi.org/10.3102/0034654310362998>. Research details already recorded by team; quantitative r = 0.43 for class grades in `STUDENT_MODEL.md`.
- **[R03] Direct research.** Arulampalam, Naylor & Smith (2012), *Am I missing something? The effects of absence from class on student performance*, *Economics of Education Review*. <https://doi.org/10.1016/j.econedurev.2011.12.002>. Publisher abstract checked; missed student classes, not lecturer-specific cancellation.
- **[R04] Direct research.** Kobus, Rietveld & van Ommeren (2015), *Student commute time, university presence and academic achievement*, *Regional Science and Urban Economics*. <https://doi.org/10.1016/j.regsciurbeco.2015.03.001>. Team source summary; exact regression estimate needs full-text check.
- **[R05] Direct research.** Yeo et al. (2023), *Early morning university classes are associated with impaired sleep and academic performance*, *Nature Human Behaviour*. <https://doi.org/10.1038/s41562-023-01531-x>. Primary text access remains restricted; team's attendance contrast was secondary-source based.
- **[R06] Indirect research.** Albulescu et al. (2022), *Give me a break! A systematic review and meta-analysis on the efficacy of micro-breaks*, *PLoS ONE*. <https://doi.org/10.1371/journal.pone.0272460>. Team's original source list.
- **[R07] Direct research.** Pitt, Oprescu, Tapia & Gray (2018), *An exploratory study of students' weekly stress levels and sources of stress during the semester*, *Active Learning in Higher Education*. <https://doi.org/10.1177/1469787417731194>. Team source summary.
- **[R08] Direct research.** De Paola & Scoppa (2011), *The effects of class size on the achievement of college students*, *The Manchester School*, 79(6), 1061–1079. <https://doi.org/10.1111/j.1467-9957.2010.02208.x>. Publisher abstract checked.
- **[R09] Indirect research.** Beermann & Sieben (2023), *The connection between stress, density, and speed in crowds*, *Scientific Reports*. <https://doi.org/10.1038/s41598-023-39006-8>. Team summary; pedestrian crowd, **not a classroom study**.
- **[R10] Direct research.** Ansari & Iqbal (2025), *Association of stress and resilience in college students: A systematic review and meta-analysis*, *Personality and Individual Differences*, 236, 113006. <https://doi.org/10.1016/j.paid.2024.113006>. Publisher abstract checked; correlational finding only.
- **[R11] Direct research.** *Classroom Movement Breaks Reduce Sedentary Behavior and Increase Concentration, Alertness and Enjoyment during University Classes* (2021), *International Journal of Environmental Research and Public Health*, 18(11), 5589. <https://doi.org/10.3390/ijerph18115589>. Full public abstract checked; n = 85 students and 6 tutors; intervention within class, not between-class travel.
- **[R12] Direct research.** *Sweat So You Don't Forget: Exercise Breaks During a University Lecture Increase On-Task Attention and Learning* (2018), *Journal of Applied Research in Memory and Cognition*. <https://doi.org/10.1016/j.jarmac.2018.01.012>. Publisher abstract checked; 5-minute movement breaks within a recorded lesson, not a validated 10-minute campus gap.
- **[R13] Indirect research.** Shi, Davies & Allman-Farinelli (2021), *The Association Between Food Insecurity and Dietary Outcomes in University Students: A Systematic Review*, *Journal of the Academy of Nutrition and Dietetics*. <https://doi.org/10.1016/j.jand.2021.07.015>. PubMed abstract checked. Food insecurity is **not** cafeteria-count variation.
- **[R14] Direct research.** Banerjee (2021), *To capture the research landscape of lecture capture in university education*, *Computers & Education*, 160, 104032. <https://doi.org/10.1016/j.compedu.2020.104032>. PubMed Central open article checked; review covers 71 studies.
- **[R15] Direct research.** *Achievement in student peer networks: A study of the selection process, peer effects and student centrality* (2019/2020), *International Journal of Educational Research*. <https://doi.org/10.1016/j.ijer.2019.101499>. Publisher abstract checked; n = 120; selection and influence both relevant.
- **[R16] Direct research, counterevidence.** *The development of peer networks and academic performance in learning communities in higher education* (2022), *Learning and Instruction*, 80, 101603. <https://doi.org/10.1016/j.learninstruc.2022.101603>. Publisher abstract checked; n = 95, no evidence of performance influence in that setting.
- **[R17] Direct research.** *Turn up, tune in, don't drop out: the relationship between lecture attendance, use of lecture recordings, and achievement at different levels of study* (2019), *Higher Education*. <https://doi.org/10.1007/s10734-018-0320-8>. Publisher abstract checked; observed patterns vary by student group.

## Team-review checklist

- [ ] Confirm the parameter list and parked/Good-to-have tiers have **not** been altered.
- [ ] Review the **qualifications**: academic evidence generally supports direction, not precise simulator point sizes.
- [ ] Record any accepted model/number changes separately in `DECISIONS.md` and, if approved, in code.
- [x] Resolve the overfull-room contradiction explicitly (decision #24).
- [ ] Run and record the experiments described in `RESEARCH_VALIDATION.md`.
