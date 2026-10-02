class_name FixedSettings
extends RefCounted
## Values the simulation needs but that are not experiment levers, so they are
## not sliders in Params (docs/PARAMETERS.md, "Fixed settings").
##
## Sources and reasoning are in docs/PARAMETERS.md and docs/STUDENT_MODEL.md. A
## value with no source named here is still a placeholder (Arya).

## Average walking speed, about 1.3 m/s.
const WALKING_SPEED_M_PER_MIN: float = 80.0
## Students aim to arrive this many minutes before a class starts.
const LEAVE_EARLY_MINUTES: float = 5.0
## An arrival counts as late after this many minutes.
const LATE_AFTER_MINUTES: float = 5.0
## A student this late cannot enter, and the class counts as missed.
const TOO_LATE_MINUTES: float = 20.0
## A first class before this hour counts as an early start.
const EARLY_START_REFERENCE_HOUR: float = 9.0
## Each student's commute is the average times a value from 1 - spread to 1 + spread.
const COMMUTE_SPREAD: float = 0.5
## Teaching weeks in a semester. Monash: a unit runs for 12 weeks (Handbook glossary).
const TEACHING_WEEKS: int = 12
## Hours a student is expected to put into one unit per teaching week, on campus.
## Monash sets 12 hours a week for a 6-point unit, counting classes and private
## study (Handbook glossary). Assumption: half of that is done on campus, where the
## sim can see it, and every student does the other half at home.
const EXPECTED_HOURS_PER_UNIT_WEEK: float = 6.0
## A deadline raises stress on each of this many days before it is due.
## Assumption: one week.
const DEADLINE_NEAR_DAYS: int = 7
