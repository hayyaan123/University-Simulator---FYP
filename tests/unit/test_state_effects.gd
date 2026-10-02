extends GutTest
## StateEffects: the determinants table moves stress, energy and satisfaction.

const STATES: Array[StringName] = [&"stress", &"energy", &"satisfaction"]
## Mid-range starting value, so a state can move either way without being clamped.
const MID: float = 50.0


func _student() -> Student:
	var student: Student = Student.new(1)
	for state: StringName in STATES:
		student.set(state, MID)
	return student


func test_every_row_moves_only_its_own_states() -> void:
	for event: StringName in StateEffects.EFFECTS:
		var student: Student = _student()
		StateEffects.apply(student, event)
		var row: Dictionary = StateEffects.EFFECTS[event]
		for state: StringName in STATES:
			var expected: float = MID + float(row.get(state, 0.0))
			assert_almost_eq(float(student.get(state)), expected, 0.0001, "%s -> %s" % [event, state])


func test_every_row_names_a_real_state() -> void:
	for event: StringName in StateEffects.EFFECTS:
		for state: StringName in StateEffects.EFFECTS[event]:
			assert_true(state in STATES, "%s changes unknown state %s" % [event, state])


func test_no_row_changes_grades_directly() -> void:
	for event: StringName in StateEffects.EFFECTS:
		var student: Student = _student()
		StateEffects.apply(student, event)
		assert_eq(student.hours_attended.size(), 0, "%s changed hours attended" % event)
		assert_eq(student.hours_studied.size(), 0, "%s changed hours studied" % event)


func test_amount_scales_the_effect() -> void:
	var student: Student = _student()
	StateEffects.apply(student, StateEffects.WALKED_MINUTE, 10.0)
	var per_minute: float = StateEffects.EFFECTS[StateEffects.WALKED_MINUTE][&"energy"]
	assert_almost_eq(student.energy, MID + per_minute * 10.0, 0.0001)


func test_states_stay_between_min_and_max() -> void:
	var student: Student = _student()
	StateEffects.apply(student, StateEffects.ATTENDED_CLASS_HOUR, 1000.0)
	assert_eq(student.energy, StateEffects.STATE_MIN)
	assert_eq(student.stress, StateEffects.STATE_MAX)


func test_attending_class_raises_stress_and_lowers_energy() -> void:
	var student: Student = _student()
	StateEffects.apply(student, StateEffects.ATTENDED_CLASS_HOUR)
	assert_gt(student.stress, MID)
	assert_lt(student.energy, MID)
	assert_eq(student.satisfaction, MID)


func test_arriving_late_raises_stress_and_lowers_satisfaction() -> void:
	var student: Student = _student()
	StateEffects.apply(student, StateEffects.ARRIVED_LATE)
	assert_gt(student.stress, MID)
	assert_lt(student.satisfaction, MID)
	assert_eq(student.energy, MID)


func test_start_day_restores_energy_but_keeps_stress() -> void:
	var student: Student = _student()
	student.stress = 40.0
	student.energy = 10.0
	student.last_class_end = 500.0
	StateEffects.start_day(student)
	assert_eq(student.energy, StateEffects.START_ENERGY)
	assert_eq(student.stress, 40.0)
	assert_eq(student.last_class_end, -INF)


func test_burnout_starts_above_resilience() -> void:
	var student: Student = _student()
	student.resilience = 60.0
	student.stress = 60.0
	assert_false(student.is_burned_out())
	student.stress = 60.5
	assert_true(student.is_burned_out())
