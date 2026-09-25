extends GutTest
## SimEngine rules: travel time, lateness, too-late skips, decisions, going home.


var campus: FakeCampus


func before_each() -> void:
	Params.reset_to_defaults()
	Params.set_value(&"days_to_simulate", 1)
	Params.set_value(&"arrival_buffer_minutes", 5.0)
	Params.set_value(&"late_grace_minutes", 5.0)
	Params.set_value(&"skip_threshold_minutes", 20.0)
	campus = FakeCampus.new()
	campus.set_travel(&"ENTRANCE", &"B1", 5.0)
	campus.set_travel(&"ENTRANCE", &"B2", 5.0)


func after_all() -> void:
	Params.reset_to_defaults()


func _session(id: int, building: StringName, hour: int, minute: int, duration: float) -> ClassSession:
	return ClassSession.new(id, &"FIT0001", ClassSession.Kind.LECTURE, &"R%d" % id, building,
		SimTime.at(0, hour, minute), duration, 100)


func _run(sessions: Array[ClassSession], model: DecisionModel = DecisionModel.new()) -> Student:
	var student: Student = Student.new(1)
	student.set_timetable(sessions)
	for session: ClassSession in sessions:
		session.enrolled_ids.append(student.id)
	var engine: SimEngine = SimEngine.new()
	engine.setup(campus, sessions, [student] as Array[Student], model)
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
	# 40 min late is under the 60 min threshold, but the 30 min class is already over.
	Params.set_value(&"skip_threshold_minutes", 60.0)
	campus.set_travel(&"B1", &"B2", 40.0)
	var student: Student = _run([
		_session(1, &"B1", 9, 0, 30.0),
		_session(2, &"B2", 9, 30, 30.0),
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
