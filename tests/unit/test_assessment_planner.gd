extends GutTest
## AssessmentPlanner: due weeks from Assessments per unit and Deadline clustering.

const UNITS: Array[StringName] = [&"FIT0001", &"FIT0002", &"FIT0003", &"FIT0004"]


func before_each() -> void:
	Params.reset_to_defaults()


func after_all() -> void:
	Params.reset_to_defaults()


func _weeks_of(assessments: Array[Assessment], unit_code: StringName) -> Array[int]:
	var weeks: Array[int] = []
	for assessment: Assessment in assessments:
		if assessment.unit_code == unit_code:
			weeks.append(assessment.due_week)
	return weeks


## How many different weeks have at least one deadline.
func _weeks_used(assessments: Array[Assessment]) -> int:
	var used: Dictionary = {}
	for assessment: Assessment in assessments:
		used[assessment.due_week] = true
	return used.size()


func test_every_unit_gets_the_set_number_of_assessments() -> void:
	Params.set_value(&"assessments_per_unit", 4)
	var assessments: Array[Assessment] = AssessmentPlanner.plan(UNITS)
	assert_eq(assessments.size(), 4 * UNITS.size())
	for unit_code: StringName in UNITS:
		assert_eq(_weeks_of(assessments, unit_code).size(), 4)


func test_weights_of_a_unit_add_up_to_one() -> void:
	var assessments: Array[Assessment] = AssessmentPlanner.plan(UNITS)
	var total: float = 0.0
	for assessment: Assessment in assessments:
		if assessment.unit_code == UNITS[0]:
			total += assessment.weight
	assert_almost_eq(total, 1.0, 0.0001)


func test_due_weeks_stay_inside_the_semester() -> void:
	for per_unit: int in range(1, 7):
		Params.set_value(&"assessments_per_unit", per_unit)
		for clustering: float in [0.0, 0.5, 1.0]:
			Params.set_value(&"deadline_clustering", clustering)
			for assessment: Assessment in AssessmentPlanner.plan(UNITS):
				assert_gte(assessment.due_week, 1)
				assert_lte(assessment.due_week, FixedSettings.TEACHING_WEEKS)


func test_full_clustering_puts_every_unit_in_the_same_weeks() -> void:
	Params.set_value(&"deadline_clustering", 1.0)
	var assessments: Array[Assessment] = AssessmentPlanner.plan(UNITS)
	assert_eq(_weeks_of(assessments, UNITS[0]), [4, 8, 12] as Array[int])
	for unit_code: StringName in UNITS:
		assert_eq(_weeks_of(assessments, unit_code), _weeks_of(assessments, UNITS[0]))
	assert_eq(_weeks_used(assessments), 3)


func test_no_clustering_spreads_units_over_different_weeks() -> void:
	Params.set_value(&"deadline_clustering", 0.0)
	var spread: Array[Assessment] = AssessmentPlanner.plan(UNITS)
	Params.set_value(&"deadline_clustering", 1.0)
	var clustered: Array[Assessment] = AssessmentPlanner.plan(UNITS)
	assert_gt(_weeks_used(spread), _weeks_used(clustered))
	assert_eq(_weeks_used(spread), 12)


func test_the_same_settings_give_the_same_plan() -> void:
	var first: Array[Assessment] = AssessmentPlanner.plan(UNITS)
	var second: Array[Assessment] = AssessmentPlanner.plan(UNITS)
	assert_eq(first.size(), second.size())
	for i: int in range(first.size()):
		assert_eq(str(first[i]), str(second[i]))


func test_assessment_is_due_at_the_end_of_its_week() -> void:
	var assessment: Assessment = Assessment.new(0, &"FIT0001", 2, 1.0)
	assert_eq(assessment.due_day(), 14)


func test_unit_codes_come_from_the_units_file_format() -> void:
	var units: Array = [{"code": "FIT0001"}, {"code": "FIT0002"}]
	assert_eq(AssessmentPlanner.unit_codes_of(units), [&"FIT0001", &"FIT0002"] as Array[StringName])
