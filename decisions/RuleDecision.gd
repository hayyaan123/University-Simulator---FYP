class_name RuleDecision
extends DecisionModel
## Rule-based decisions for Semester 1 (rule 3 in docs/STUDENT_MODEL.md).
##
## A student's states change their choices: the lower their energy, the more
## likely they are to skip, and a burned-out student (stress above their
## resilience) skips far more. A tired student who has already been to class
## today goes home instead of skipping one class.
##
## The states only change the choice here. They never change each other.

# PLACEHOLDER numbers: each needs a source or a stated assumption (Arya).
## Chance of skipping a class for reasons the sim doesn't model.
const BASE_SKIP_CHANCE: float = 0.03
## Below this energy, tiredness starts to make skipping more likely.
const LOW_ENERGY: float = 50.0
## Extra skip chance at zero energy. It grows evenly from 0 at LOW_ENERGY.
const MAX_LOW_ENERGY_SKIP_CHANCE: float = 0.4
## Extra skip chance while the student is burned out.
const BURNOUT_SKIP_CHANCE: float = 0.4


func decide(student: Student, context: DecisionContext, rng: RandomNumberGenerator) -> Action:
	if rng.randf() >= skip_chance(student):
		return Action.ATTEND_NEXT
	if student.energy < LOW_ENERGY and context.attended_today > 0:
		return Action.LEAVE_CAMPUS
	return Action.SKIP_NEXT


## Chance (0 to 1) that this student skips their next class.
func skip_chance(student: Student) -> float:
	var chance: float = BASE_SKIP_CHANCE
	if student.energy < LOW_ENERGY:
		chance += MAX_LOW_ENERGY_SKIP_CHANCE * (1.0 - student.energy / LOW_ENERGY)
	if student.is_burned_out():
		chance += BURNOUT_SKIP_CHANCE
	return minf(chance, 1.0)


func model_name() -> String:
	return "Rules"
