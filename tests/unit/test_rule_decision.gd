extends GutTest
## RuleDecision: low energy makes skipping more likely. Stress does not.

const TRIALS: int = 2000

var model: RuleDecision
var rng: RandomNumberGenerator


func before_each() -> void:
	model = RuleDecision.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 42


func _context(attended_today: int) -> DecisionContext:
	var session: ClassSession = ClassSession.new(1, &"FIT0001", ClassSession.Kind.LECTURE, &"R1", &"B1",
		SimTime.at(0, 9, 0), 60.0, 100)
	return DecisionContext.new(SimTime.at(0, 8, 50), session, 5.0, 1, attended_today)


func _count(student: Student, attended_today: int, action: DecisionModel.Action) -> int:
	var count: int = 0
	var context: DecisionContext = _context(attended_today)
	for i: int in range(TRIALS):
		if model.decide(student, context, rng) == action:
			count += 1
	return count


func test_rested_student_has_only_the_base_skip_chance() -> void:
	var student: Student = Student.new(1)
	assert_almost_eq(model.skip_chance(student), RuleDecision.BASE_SKIP_CHANCE, 0.0001)


func test_skip_chance_rises_faster_as_energy_falls() -> void:
	var student: Student = Student.new(1)
	student.energy = 75.0
	var a_little_tired: float = model.skip_chance(student)
	student.energy = 50.0
	var tired: float = model.skip_chance(student)
	student.energy = 25.0
	var very_tired: float = model.skip_chance(student)
	assert_gt(a_little_tired, RuleDecision.BASE_SKIP_CHANCE)
	assert_gt(tired, a_little_tired)
	assert_gt(very_tired, tired)
	# A curve, not a straight line: each 25 points lost adds more than the last.
	assert_gt(very_tired - tired, tired - a_little_tired)


func test_student_with_no_energy_always_skips() -> void:
	var student: Student = Student.new(1)
	student.energy = StateEffects.STATE_MIN
	assert_almost_eq(model.skip_chance(student), 1.0, 0.0001)
	assert_eq(_count(student, 0, DecisionModel.Action.ATTEND_NEXT), 0)


func test_stress_does_not_change_the_skip_chance() -> void:
	var calm: Student = Student.new(1)
	var stressed: Student = Student.new(2)
	stressed.stress = StateEffects.STATE_MAX
	assert_eq(model.skip_chance(stressed), model.skip_chance(calm))


func test_an_8am_start_costs_about_ten_points_of_attendance() -> void:
	# Yeo et al. (2023): attendance at 08:00 classes was about 10 percentage points
	# lower than at later classes. Checked at the default commute.
	Params.reset_to_defaults()
	var commute: float = float(Params.average_commute_minutes)
	var at_nine: Student = Student.new(1)
	StateEffects.apply(at_nine, StateEffects.COMMUTED_MINUTE, commute)
	var at_eight: Student = Student.new(2)
	StateEffects.apply(at_eight, StateEffects.COMMUTED_MINUTE, commute)
	StateEffects.apply(at_eight, StateEffects.EARLY_START_HOUR, 1.0)
	assert_almost_eq(model.skip_chance(at_eight) - model.skip_chance(at_nine), 0.10, 0.02)


func test_rested_student_nearly_always_attends() -> void:
	var student: Student = Student.new(1)
	var attended: int = _count(student, 0, DecisionModel.Action.ATTEND_NEXT)
	assert_gt(attended, int(TRIALS * 0.94))
	assert_lt(attended, TRIALS)


func test_tired_student_skips_more_than_a_rested_one() -> void:
	var rested: Student = Student.new(1)
	var tired: Student = Student.new(2)
	tired.energy = 40.0
	var rested_attends: int = _count(rested, 0, DecisionModel.Action.ATTEND_NEXT)
	var tired_attends: int = _count(tired, 0, DecisionModel.Action.ATTEND_NEXT)
	assert_lt(tired_attends, rested_attends)
	assert_gt(tired_attends, 0)


func test_tired_student_who_has_been_to_class_goes_home() -> void:
	var student: Student = Student.new(1)
	student.energy = 0.0
	assert_eq(_count(student, 1, DecisionModel.Action.SKIP_NEXT), 0)
	assert_gt(_count(student, 1, DecisionModel.Action.LEAVE_CAMPUS), 0)


func test_tired_student_with_no_class_yet_skips_one_class() -> void:
	var student: Student = Student.new(1)
	student.energy = 0.0
	assert_eq(_count(student, 0, DecisionModel.Action.LEAVE_CAMPUS), 0)
	assert_gt(_count(student, 0, DecisionModel.Action.SKIP_NEXT), 0)


func test_same_seed_gives_the_same_decisions() -> void:
	var student: Student = Student.new(1)
	student.energy = 20.0
	var first: int = _count(student, 0, DecisionModel.Action.ATTEND_NEXT)
	rng.seed = 42
	var second: int = _count(student, 0, DecisionModel.Action.ATTEND_NEXT)
	assert_eq(first, second)


func test_deciding_does_not_change_the_states() -> void:
	var student: Student = Student.new(1)
	student.energy = 20.0
	student.stress = 30.0
	_count(student, 1, DecisionModel.Action.ATTEND_NEXT)
	assert_eq(student.energy, 20.0)
	assert_eq(student.stress, 30.0)
