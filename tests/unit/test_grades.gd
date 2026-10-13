extends GutTest
## Grades: a mark is hours put in against hours expected. Nothing else changes it.


func test_hours_expected_grow_with_the_week() -> void:
	assert_eq(Grades.hours_expected(0), 0.0)
	assert_almost_eq(Grades.hours_expected(1), FixedSettings.EXPECTED_HOURS_PER_UNIT_WEEK, 0.0001)
	assert_almost_eq(Grades.hours_expected(12), 12.0 * FixedSettings.EXPECTED_HOURS_PER_UNIT_WEEK, 0.0001)


func test_mark_rises_in_a_straight_line_with_hours() -> void:
	assert_almost_eq(Grades.mark(0.0, 60.0), 0.0, 0.0001)
	assert_almost_eq(Grades.mark(15.0, 60.0), 25.0, 0.0001)
	assert_almost_eq(Grades.mark(30.0, 60.0), 50.0, 0.0001)
	assert_almost_eq(Grades.mark(60.0, 60.0), 100.0, 0.0001)


func test_extra_hours_do_not_go_above_full_marks() -> void:
	assert_eq(Grades.mark(90.0, 60.0), Grades.MAX_MARK)


func test_zero_hours_is_a_zero_mark() -> void:
	# The 0% extreme case: no class hours and no study hours.
	assert_eq(Grades.mark(0.0, Grades.hours_expected(12)), Grades.MIN_MARK)


func test_full_hours_is_a_full_mark() -> void:
	# The 100% extreme case: every expected hour put in by the due date.
	assert_eq(Grades.mark(Grades.hours_expected(12), Grades.hours_expected(12)), Grades.MAX_MARK)


func test_unit_grade_is_the_weighted_average_of_marks() -> void:
	assert_almost_eq(Grades.unit_grade([40.0, 80.0], [0.5, 0.5]), 60.0, 0.0001)
	assert_almost_eq(Grades.unit_grade([40.0, 80.0], [0.25, 0.75]), 70.0, 0.0001)


func test_unit_with_no_marks_has_no_grade() -> void:
	assert_eq(Grades.unit_grade([], []), Grades.NO_GRADE)


func test_student_grade_is_the_average_over_marked_units() -> void:
	var student: Student = Student.new(1)
	assert_eq(student.grade(), Grades.NO_GRADE)
	student.add_mark(&"FIT0001", 60.0, 0.5)
	student.add_mark(&"FIT0001", 80.0, 0.5)
	student.add_mark(&"FIT0002", 30.0, 1.0)
	assert_almost_eq(student.unit_grade(&"FIT0001"), 70.0, 0.0001)
	assert_almost_eq(student.unit_grade(&"FIT0002"), 30.0, 0.0001)
	assert_eq(student.unit_grade(&"FIT0003"), Grades.NO_GRADE)
	assert_almost_eq(student.grade(), 50.0, 0.0001)


func test_class_hours_and_study_hours_count_the_same() -> void:
	var attends: Student = Student.new(1)
	attends.add_hours_attended(&"FIT0001", 3.0)
	var studies: Student = Student.new(2)
	studies.hours_studied[&"FIT0001"] = 3.0
	assert_eq(attends.hours_put_in(&"FIT0001"), studies.hours_put_in(&"FIT0001"))
