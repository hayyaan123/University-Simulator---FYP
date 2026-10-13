extends GutTest
## SimEngine rules: travel time, lateness, too-late skips, decisions, going home.


var campus: FakeCampus


func before_each() -> void:
	Params.reset_to_defaults()
	Params.set_value(&"days_to_simulate", 1)
	campus = FakeCampus.new()
	campus.set_travel(&"ENTRANCE", &"B1", 5.0)
	campus.set_travel(&"ENTRANCE", &"B2", 5.0)


func after_all() -> void:
	Params.reset_to_defaults()


func _session(id: int, building: StringName, hour: int, minute: int, duration: float) -> ClassSession:
	return ClassSession.new(id, &"FIT0001", ClassSession.Kind.LECTURE, &"R%d" % id, building,
		SimTime.at(0, hour, minute), duration, 100)


func _run(sessions: Array[ClassSession], model: DecisionModel = DecisionModel.new(), commute_minutes: float = 0.0,
		assessments: Array[Assessment] = []) -> Student:
	var student: Student = Student.new(1)
	student.commute_minutes = commute_minutes
	student.set_timetable(sessions)
	for session: ClassSession in sessions:
		session.enrolled_ids.append(student.id)
	var engine: SimEngine = SimEngine.new()
	engine.setup(campus, sessions, [student] as Array[Student], model, assessments)
	engine.run_to_end()
	assert_true(engine.is_finished())
	return student


func test_same_building_back_to_back_is_on_time() -> void:
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B1", 10, 0, 60.0),
	] as Array[ClassSession])
	assert_eq(student.attended_count, 2)
	assert_eq(student.late_count, 0)
	assert_eq(Stats.attended, 2)
	assert_eq(Stats.late, 0)


func test_far_back_to_back_class_makes_student_late() -> void:
	campus.set_travel(&"B1", &"B2", 12.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B2", 10, 0, 60.0),
	] as Array[ClassSession])
	assert_eq(student.attended_count, 2)
	assert_eq(student.late_count, 1)
	assert_almost_eq(Stats.average_minutes_late(), 12.0, 0.001)


func test_walk_within_grace_is_not_late() -> void:
	campus.set_travel(&"B1", &"B2", 4.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B2", 10, 0, 60.0),
	] as Array[ClassSession])
	assert_eq(student.late_count, 0)


func test_gap_between_classes_prevents_lateness() -> void:
	campus.set_travel(&"B1", &"B2", 12.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 50.0),
		_session(2, &"B2", 10, 10, 60.0),
	] as Array[ClassSession])
	assert_eq(student.late_count, 0)


func test_too_late_to_enter_counts_as_skip() -> void:
	campus.set_travel(&"B1", &"B2", 30.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B2", 10, 0, 60.0),
	] as Array[ClassSession])
	assert_eq(student.attended_count, 1)
	assert_eq(student.skipped_count, 1)
	assert_eq(Stats.skipped_by_reason.get(&"too_late", 0), 1)


func test_arriving_after_short_class_ended_counts_as_skip() -> void:
	# 15 min late is under the too-late limit, but the 10 min class is already over.
	campus.set_travel(&"B1", &"B2", 15.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 30.0),
		_session(2, &"B2", 9, 30, 10.0),
	] as Array[ClassSession])
	assert_eq(student.attended_count, 1)
	assert_eq(student.skipped_count, 1)
	assert_eq(Stats.skipped_by_reason.get(&"too_late", 0), 1)
	assert_eq(student.state, Student.State.OFF_CAMPUS)


func test_skip_model_skips_everything() -> void:
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B2", 13, 0, 60.0),
	] as Array[ClassSession], FixedDecision.new(DecisionModel.Action.SKIP_NEXT))
	assert_eq(student.attended_count, 0)
	assert_eq(student.skipped_count, 2)
	assert_eq(student.state, Student.State.OFF_CAMPUS)


func test_leave_campus_skips_rest_of_day() -> void:
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B1", 11, 0, 60.0),
		_session(3, &"B2", 14, 0, 60.0),
	] as Array[ClassSession], FixedDecision.new(DecisionModel.Action.LEAVE_CAMPUS))
	assert_eq(student.skipped_count, 3)
	assert_eq(Stats.skipped_by_reason.get(&"left_campus", 0), 3)


func test_student_goes_home_after_last_class() -> void:
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession])
	assert_eq(student.state, Student.State.OFF_CAMPUS)
	assert_eq(student.location, &"ENTRANCE")


func test_student_leaves_home_in_time_for_first_class() -> void:
	var departures: Array[float] = []
	var on_departed: Callable = func(_s: Student, _from: StringName, _to: StringName, arrive: float) -> void:
		departures.append(arrive)
	EventBus.student_departed.connect(on_departed)
	_run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession])
	EventBus.student_departed.disconnect(on_departed)
	# Leaves at 08:50 (9:00 - 5 walk - 5 buffer), arrives 08:55.
	assert_eq(departures[0], SimTime.at(0, 8, 55))


# --- Student states (docs/STUDENT_MODEL.md) -------------------------------------

func _effect(event: StringName, state: StringName) -> float:
	return float(StateEffects.EFFECTS[event].get(state, 0.0))


func test_attending_records_hours_and_moves_states() -> void:
	# 5 min walk from the entrance, then a 60 min class.
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession])
	assert_almost_eq(student.hours_put_in(&"FIT0001"), 1.0, 0.0001)
	var expected_energy: float = (StateEffects.START_ENERGY
		+ 5.0 * _effect(StateEffects.WALKED_MINUTE, &"energy")
		+ _effect(StateEffects.ATTENDED_CLASS_HOUR, &"energy"))
	assert_almost_eq(student.energy, expected_energy, 0.0001)
	assert_almost_eq(student.stress,
		StateEffects.START_STRESS + _effect(StateEffects.ATTENDED_CLASS_HOUR, &"stress"), 0.0001)


func test_late_student_gets_fewer_hours_and_more_stress() -> void:
	campus.set_travel(&"B1", &"B2", 12.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B2", 10, 0, 60.0),
	] as Array[ClassSession])
	# 60 min in the first class, 48 min in the second (12 min late).
	assert_almost_eq(student.hours_put_in(&"FIT0001"), 1.8, 0.0001)
	assert_almost_eq(student.stress, StateEffects.START_STRESS
		+ 1.8 * _effect(StateEffects.ATTENDED_CLASS_HOUR, &"stress")
		+ _effect(StateEffects.ARRIVED_LATE, &"stress")
		+ _effect(StateEffects.BACK_TO_BACK_CLASS, &"stress"), 0.0001)


func test_too_late_to_enter_gives_no_hours_and_no_rest() -> void:
	campus.set_travel(&"B1", &"B2", 30.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
		_session(2, &"B2", 10, 0, 60.0),
	] as Array[ClassSession])
	assert_almost_eq(student.hours_put_in(&"FIT0001"), 1.0, 0.0001)
	var expected_energy: float = (StateEffects.START_ENERGY
		+ (5.0 + 30.0) * _effect(StateEffects.WALKED_MINUTE, &"energy")
		+ _effect(StateEffects.ATTENDED_CLASS_HOUR, &"energy"))
	assert_almost_eq(student.energy, expected_energy, 0.0001)
	assert_almost_eq(student.stress, StateEffects.START_STRESS
		+ _effect(StateEffects.ATTENDED_CLASS_HOUR, &"stress")
		+ _effect(StateEffects.ARRIVED_LATE, &"stress"), 0.0001)


func test_skipping_gives_no_hours_and_no_stress() -> void:
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 60.0),
	] as Array[ClassSession], FixedDecision.new(DecisionModel.Action.SKIP_NEXT))
	assert_eq(student.hours_put_in(&"FIT0001"), 0.0)
	assert_eq(student.stress, StateEffects.START_STRESS)
	assert_eq(student.energy, StateEffects.START_ENERGY)


func test_back_to_back_classes_cost_extra() -> void:
	var back_to_back: Student = _run([
		_session(1, &"B1", 9, 0, 50.0),
		_session(2, &"B1", 10, 0, 50.0),
	] as Array[ClassSession])
	var with_a_break: Student = _run([
		_session(1, &"B1", 9, 0, 50.0),
		_session(2, &"B1", 11, 0, 50.0),
	] as Array[ClassSession])
	assert_almost_eq(back_to_back.stress - with_a_break.stress,
		_effect(StateEffects.BACK_TO_BACK_CLASS, &"stress"), 0.0001)
	assert_almost_eq(back_to_back.energy - with_a_break.energy,
		_effect(StateEffects.BACK_TO_BACK_CLASS, &"energy"), 0.0001)


func test_energy_is_restored_overnight_but_stress_carries_over() -> void:
	Params.set_value(&"days_to_simulate", 2)
	var tuesday: ClassSession = ClassSession.new(2, &"FIT0001", ClassSession.Kind.LECTURE, &"R2", &"B1",
		SimTime.at(1, 9, 0), 60.0, 100)
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0), tuesday] as Array[ClassSession])
	var one_day_energy: float = (StateEffects.START_ENERGY
		+ 5.0 * _effect(StateEffects.WALKED_MINUTE, &"energy")
		+ _effect(StateEffects.ATTENDED_CLASS_HOUR, &"energy"))
	assert_almost_eq(student.energy, one_day_energy, 0.0001)
	assert_almost_eq(student.stress,
		StateEffects.START_STRESS + 2.0 * _effect(StateEffects.ATTENDED_CLASS_HOUR, &"stress"), 0.0001)


func test_commute_costs_energy_before_the_first_class() -> void:
	var sessions: Array[ClassSession] = [_session(1, &"B1", 9, 0, 60.0)]
	var near: Student = _run(sessions, DecisionModel.new(), 0.0)
	var far: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession], DecisionModel.new(), 60.0)
	assert_almost_eq(far.energy - near.energy,
		60.0 * _effect(StateEffects.COMMUTED_MINUTE, &"energy"), 0.0001)


func test_early_first_class_costs_energy() -> void:
	var early: Student = _run([_session(1, &"B1", 7, 0, 60.0)] as Array[ClassSession])
	var normal: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession])
	var hours_early: float = FixedSettings.EARLY_START_REFERENCE_HOUR - 7.0
	assert_almost_eq(early.energy - normal.energy,
		hours_early * _effect(StateEffects.EARLY_START_HOUR, &"energy"), 0.0001)


func test_student_with_no_class_today_pays_no_commute() -> void:
	var student: Student = _run([] as Array[ClassSession], DecisionModel.new(), 60.0)
	assert_eq(student.energy, StateEffects.START_ENERGY)

# --- Weeks, assessments and grades ------------------------------------------------

func test_timetable_repeats_every_week() -> void:
	Params.set_value(&"days_to_simulate", 14)
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession])
	assert_eq(student.attended_count, 2)
	assert_almost_eq(student.hours_put_in(&"FIT0001"), 2.0, 0.0001)


func test_run_shorter_than_a_week_does_not_repeat() -> void:
	Params.set_value(&"days_to_simulate", 5)
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession])
	assert_eq(student.attended_count, 1)


func test_week_ended_is_emitted_once_per_full_week() -> void:
	Params.set_value(&"days_to_simulate", 14)
	var weeks: Array[int] = []
	var on_week_ended: Callable = func(week: int) -> void: weeks.append(week)
	EventBus.week_ended.connect(on_week_ended)
	_run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession])
	EventBus.week_ended.disconnect(on_week_ended)
	assert_eq(weeks, [1, 2] as Array[int])


func test_assessment_is_marked_from_hours_put_in() -> void:
	Params.set_value(&"days_to_simulate", 7)
	var due: Array[Assessment] = [Assessment.new(0, &"FIT0001", 1, 1.0)]
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession],
		DecisionModel.new(), 0.0, due)
	# One hour put in against the hours expected in week 1.
	var expected: float = Grades.MAX_MARK * 1.0 / FixedSettings.EXPECTED_HOURS_PER_UNIT_WEEK
	assert_almost_eq(student.unit_grade(&"FIT0001"), expected, 0.0001)
	assert_almost_eq(student.grade(), expected, 0.0001)


func test_skipping_every_class_gives_a_zero_mark() -> void:
	Params.set_value(&"days_to_simulate", 7)
	var due: Array[Assessment] = [Assessment.new(0, &"FIT0001", 1, 1.0)]
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession],
		FixedDecision.new(DecisionModel.Action.SKIP_NEXT), 0.0, due)
	assert_eq(student.grade(), Grades.MIN_MARK)


func test_no_grade_before_an_assessment_is_due() -> void:
	Params.set_value(&"days_to_simulate", 7)
	var due: Array[Assessment] = [Assessment.new(0, &"FIT0001", 2, 1.0)]
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession],
		DecisionModel.new(), 0.0, due)
	assert_eq(student.grade(), Grades.NO_GRADE)


func test_assessment_in_another_unit_is_not_marked() -> void:
	Params.set_value(&"days_to_simulate", 7)
	var due: Array[Assessment] = [Assessment.new(0, &"FIT9999", 1, 1.0)]
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession],
		DecisionModel.new(), 0.0, due)
	assert_eq(student.grade(), Grades.NO_GRADE)


func test_near_deadline_raises_stress_every_day() -> void:
	Params.set_value(&"days_to_simulate", 7)
	var due: Array[Assessment] = [Assessment.new(0, &"FIT0001", 1, 1.0)]
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession],
		FixedDecision.new(DecisionModel.Action.SKIP_NEXT), 0.0, due)
	assert_almost_eq(student.stress,
		StateEffects.START_STRESS + 7.0 * _effect(StateEffects.DEADLINE_NEAR, &"stress"), 0.0001)


func test_deadline_more_than_a_week_away_adds_no_stress() -> void:
	Params.set_value(&"days_to_simulate", 7)
	var due: Array[Assessment] = [Assessment.new(0, &"FIT0001", 3, 1.0)]
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession],
		FixedDecision.new(DecisionModel.Action.SKIP_NEXT), 0.0, due)
	assert_eq(student.stress, StateEffects.START_STRESS)


func test_two_near_deadlines_add_twice_the_stress() -> void:
	Params.set_value(&"days_to_simulate", 1)
	var due: Array[Assessment] = [Assessment.new(0, &"FIT0001", 1, 0.5), Assessment.new(1, &"FIT0001", 1, 0.5)]
	var student: Student = _run([_session(1, &"B1", 9, 0, 60.0)] as Array[ClassSession],
		FixedDecision.new(DecisionModel.Action.SKIP_NEXT), 0.0, due)
	assert_almost_eq(student.stress,
		StateEffects.START_STRESS + 2.0 * _effect(StateEffects.DEADLINE_NEAR, &"stress"), 0.0001)


func test_student_in_an_overcrowded_room_still_attends_but_is_stressed() -> void:
	var session: ClassSession = ClassSession.new(1, &"FIT0001", ClassSession.Kind.LECTURE, &"R1", &"B1",
		SimTime.at(0, 9, 0), 60.0, 1)
	var first: Student = Student.new(1)
	var second: Student = Student.new(2)
	for student: Student in [first, second]:
		student.set_timetable([session] as Array[ClassSession])
		session.enrolled_ids.append(student.id)
	var engine: SimEngine = SimEngine.new()
	engine.setup(campus, [session] as Array[ClassSession], [first, second] as Array[Student], DecisionModel.new())
	engine.run_to_end()
	assert_eq(first.attended_count, 1)
	assert_eq(second.attended_count, 1)
	assert_almost_eq(second.hours_put_in(&"FIT0001"), 1.0, 0.0001)
	assert_almost_eq(second.stress - first.stress, _effect(StateEffects.OVERCROWDED_ROOM, &"stress"), 0.0001)
	assert_almost_eq(second.energy - first.energy, _effect(StateEffects.OVERCROWDED_ROOM, &"energy"), 0.0001)
