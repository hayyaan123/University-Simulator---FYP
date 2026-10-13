class_name RuleDecision
extends DecisionModel
## Rule-based decisions for Semester 1 (rule 3 in docs/STUDENT_MODEL.md).
##
## A student's energy changes their choices: the lower it is, the more likely
## they are to skip, and a student with no energy left cannot come to class. A
## tired student who has already been to class today goes home instead of
## skipping one class. Stress does not change choices in v1 (decision #20).
##
## Energy only changes the choice here. It never changes another state.

## Chance of skipping a class at full energy, for reasons the sim doesn't model.
## Assumption: there is no source for this number yet.
const BASE_SKIP_CHANCE: float = 0.03
## How sharply the skip chance rises as energy falls. 2 = with the square of the
## energy lost: a little tiredness changes little, and the chance reaches 1 at
## zero energy. With StateEffects.EARLY_START_HOUR, this gives the 10-point drop
## in attendance at 08:00 classes measured by Yeo et al. (2023).
const SKIP_CURVE_POWER: float = 2.0
## Below this energy, a student who has already been to class today goes home.
## Assumption: half of a rested student's energy.
const LOW_ENERGY: float = 50.0


func decide(student: Student, context: DecisionContext, rng: RandomNumberGenerator) -> Action:
	if rng.randf() >= skip_chance(student):
		return Action.ATTEND_NEXT
	if student.energy < LOW_ENERGY and context.attended_today > 0:
		return Action.LEAVE_CAMPUS
	return Action.SKIP_NEXT


## Chance (0 to 1) that this student skips their next class.
func skip_chance(student: Student) -> float:
	var energy_lost: float = 1.0 - student.energy / StateEffects.STATE_MAX
	return BASE_SKIP_CHANCE + (1.0 - BASE_SKIP_CHANCE) * pow(energy_lost, SKIP_CURVE_POWER)


func model_name() -> String:
	return "Rules"
