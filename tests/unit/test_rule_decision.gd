extends GutTest
## RuleDecision: low energy and burnout make skipping more likely.

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
	assert_eq(model.skip_chance(student), RuleDecision.BASE_SKIP_CHANCE)


func test_skip_chance_rises_as_energy_falls() -> void:
	var student: Student = Student.new(1)
	student.energy = RuleDecision.LOW_ENERGY
	var at_threshold: float = model.skip_chance(student)
	student.energy = RuleDecision.LOW_ENERGY / 2.0
	var half_way: float = model.skip_chance(student)
	student.energy = 0.0
	var exhausted: float = model.skip_chance(student)
	assert_eq(at_threshold, RuleDecision.BASE_SKIP_CHANCE)
	assert_gt(half_way, at_threshold)
	assert_gt(exhausted, half_way)
	assert_almost_eq(exhausted,
		RuleDecision.BASE_SKIP_CHANCE + RuleDecision.MAX_LOW_ENERGY_SKIP_CHANCE, 0.0001)


func test_burnout_adds_to_the_skip_chance() -> void:
	var student: Student = Student.new(1)
	student.stress = student.resilience + 1.0
	assert_almost_eq(model.skip_chance(student),
		RuleDecision.BASE_SKIP_CHANCE + RuleDecision.BURNOUT_SKIP_CHANCE, 0.0001)


func test_skip_chance_never_goes_above_one() -> void:
	var student: Student = Student.new(1)
	student.energy = 0.0
	student.stress = StateEffects.STATE_MAX
	student.resilience = 0.0
	assert_lte(model.skip_chance(student), 1.0)


func test_rested_student_nearly_always_attends() -> void:
	var student: Student = Student.new(1)
	var attended: int = _count(student, 0, DecisionModel.Action.ATTEND_NEXT)
	assert_gt(attended, int(TRIALS * 0.94))
	assert_lt(attended, TRIALS)


func test_exhausted_student_skips_more_than_a_rested_one() -> void:
	var rested: Student = Student.new(1)
	var exhausted: Student = Student.new(2)
	exhausted.energy = 0.0
	var rested_attends: int = _count(rested, 0, DecisionModel.Action.ATTEND_NEXT)
	var exhausted_attends: int = _count(exhausted, 0, DecisionModel.Action.ATTEND_NEXT)
	assert_lt(exhausted_attends, rested_attends)


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
	assert_eq(student.satisfaction, StateEffects.START_SATISFACTION)
