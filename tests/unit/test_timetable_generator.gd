extends GutTest
## TimetableGenerator rules: no room double-booking, no student clashes, days respected.

var campus: Campus
var units: Array


func before_all() -> void:
	campus = Campus.new()
	campus.load_from_file("res://data/campus.json")
	units = TimetableGenerator.load_units("res://data/units.json")


func before_each() -> void:
	Params.reset_to_defaults()
	Params.set_value(&"student_count", 300)


func after_all() -> void:
	Params.reset_to_defaults()


func _generate(seed_value: int = 1) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return TimetableGenerator.new().generate(campus, units, rng)


func _overlaps(a: ClassSession, b: ClassSession) -> bool:
	return a.start < b.end and b.start < a.end


func test_no_room_is_double_booked() -> void:
	var sessions: Array[ClassSession] = _generate()["sessions"]
	for i: int in range(sessions.size()):
		for j: int in range(i + 1, sessions.size()):
			if sessions[i].room_id == sessions[j].room_id:
				assert_false(_overlaps(sessions[i], sessions[j]), "%s vs %s" % [sessions[i], sessions[j]])


func test_no_student_has_two_classes_at_once() -> void:
	var students: Array[Student] = _generate()["students"]
	for student: Student in students:
		for i: int in range(student.timetable.size() - 1):
			assert_true(student.timetable[i].end <= student.timetable[i + 1].start,
				"student %d: %s then %s" % [student.id, student.timetable[i], student.timetable[i + 1]])


func test_classes_stay_inside_the_teaching_day() -> void:
	for session: ClassSession in _generate()["sessions"]:
		var start: float = SimTime.minute_of_day(session.start)
		assert_gte(start, Params.day_start_hour * 60.0)
		assert_lte(start + session.duration, Params.day_end_hour * 60.0)
		assert_lt(session.day(), TimetableGenerator.TEACHING_DAYS)


func test_every_student_gets_their_units() -> void:
	var generator: TimetableGenerator = TimetableGenerator.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var students: Array[Student] = generator.generate(campus, units, rng)["students"]
	assert_eq(generator.unplaced, 0, "every class found a room and slot")
	for student: Student in students:
		var codes: Dictionary = {}
		for session: ClassSession in student.timetable:
			codes[session.unit_code] = true
		assert_eq(codes.size(), Params.units_per_student, "student %d" % student.id)


func test_gap_leaves_time_to_walk() -> void:
	Params.set_value(&"slot_gap_minutes", 10)
	Params.set_value(&"lecture_minutes", 120)
	for session: ClassSession in _generate()["sessions"]:
		if session.kind == ClassSession.Kind.LECTURE:
			assert_eq(session.duration, 110.0, "a 2-hour lecture ends 10 minutes early")
			assert_eq(fmod(session.start, 60.0), 0.0, "classes start on the hour")


func test_same_seed_gives_the_same_timetable() -> void:
	var first: Array[ClassSession] = _generate(7)["sessions"]
	var second: Array[ClassSession] = _generate(7)["sessions"]
	assert_eq(first.size(), second.size())
	for i: int in range(first.size()):
		assert_eq(str(first[i]), str(second[i]))
		assert_eq(first[i].enrolled_ids, second[i].enrolled_ids)


func test_students_get_their_own_commute_and_resilience() -> void:
	Params.set_value(&"average_commute_minutes", 40)
	Params.set_value(&"resilience", 60.0)
	var students: Array[Student] = _generate()["students"]
	var commute_total: float = 0.0
	var resilience_total: float = 0.0
	var commutes: Dictionary = {}
	for student: Student in students:
		assert_gte(student.commute_minutes, 40.0 * (1.0 - FixedSettings.COMMUTE_SPREAD))
		assert_lte(student.commute_minutes, 40.0 * (1.0 + FixedSettings.COMMUTE_SPREAD))
		assert_gte(student.resilience, StateEffects.STATE_MIN)
		assert_lte(student.resilience, StateEffects.STATE_MAX)
		commute_total += student.commute_minutes
		resilience_total += student.resilience
		commutes[student.commute_minutes] = true
	assert_gt(commutes.size(), 1, "students differ from each other")
	assert_almost_eq(commute_total / students.size(), 40.0, 3.0)
	assert_almost_eq(resilience_total / students.size(), 60.0, 3.0)
