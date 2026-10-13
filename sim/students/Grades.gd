class_name Grades
extends RefCounted
## How grades are measured (docs/STUDENT_MODEL.md, "What grades means").
##
## "Grades" stands for the knowledge a student needs to get the grade. Nothing
## adds or removes marks directly: a mark is the hours a student has put into a
## unit (class plus study) against the hours expected by the due date.

const MIN_MARK: float = 0.0
const MAX_MARK: float = 100.0
## Returned when there is nothing to grade yet.
const NO_GRADE: float = -1.0


## Hours a student is expected to have put into one unit by the end of `week`
## (1 = the first teaching week).
static func hours_expected(week: int) -> float:
	return FixedSettings.EXPECTED_HOURS_PER_UNIT_WEEK * float(maxi(0, week))


## Mark (0 to 100) for hours put in against hours expected. It rises in a
## straight line and stops at 100: extra hours don't earn more than full marks.
static func mark(hours_put_in: float, expected_hours: float) -> float:
	if expected_hours <= 0.0:
		return MAX_MARK
	return clampf(MAX_MARK * hours_put_in / expected_hours, MIN_MARK, MAX_MARK)


## Grade for one unit: the average of its assessment marks, weighted by each
## assessment's weight. NO_GRADE if the unit has no marks yet.
static func unit_grade(marks: Array, weights: Array) -> float:
	var total: float = 0.0
	var weight_sum: float = 0.0
	for i: int in range(marks.size()):
		total += float(marks[i]) * float(weights[i])
		weight_sum += float(weights[i])
	return NO_GRADE if weight_sum <= 0.0 else total / weight_sum
