class_name AssessmentPlanner
extends RefCounted
## Decides when each unit's assessments are due, from two parameters:
## Params.assessments_per_unit and Params.deadline_clustering.
##
## Each unit's assessments are spread evenly over the teaching weeks, with the
## last one due in the final week. Clustering decides how the units line up:
## at 0 each unit is shifted earlier by a different amount, so deadlines from
## different units fall in different weeks; at 1 no unit is shifted, so every
## unit's deadlines hit in the same weeks.


## Returns the assessments for `unit_codes`, in unit order, using Params.
static func plan(unit_codes: Array[StringName]) -> Array[Assessment]:
	var assessments: Array[Assessment] = []
	var per_unit: int = Params.assessments_per_unit
	var weeks: int = FixedSettings.TEACHING_WEEKS
	var spacing: float = float(weeks) / float(per_unit)
	var spread: float = 1.0 - Params.deadline_clustering
	for u: int in range(unit_codes.size()):
		# Units are shifted by different fractions of the spacing between deadlines.
		var shift: float = spacing * spread * float(u) / float(unit_codes.size())
		for i: int in range(per_unit):
			var week: int = clampi(roundi(spacing * float(i + 1) - shift), 1, weeks)
			assessments.append(Assessment.new(assessments.size(), unit_codes[u], week, 1.0 / float(per_unit)))
	return assessments


## Unit codes from the "units" array of units.json, in file order.
static func unit_codes_of(units: Array) -> Array[StringName]:
	var codes: Array[StringName] = []
	for unit: Dictionary in units:
		codes.append(StringName(unit["code"]))
	return codes
