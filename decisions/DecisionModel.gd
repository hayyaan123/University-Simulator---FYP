class_name DecisionModel
extends RefCounted
## Base class for every student decision model.
##
## SimEngine asks the model what a student does about their next class. The engine
## then works out *when* to leave and *how long* the walk takes. Rule-based models
## (Semester 1) and ML models (Semester 2) both extend this class, so switching
## between them is a one-line change.
##
## This base class is the baseline "always attend" model. It is useful for tests
## and as a comparison point in experiments.

enum Action {
	ATTEND_NEXT,   ## Go to the next class (leave in time if possible).
	SKIP_NEXT,     ## Skip the next class; decide again when it ends.
	LEAVE_CAMPUS,  ## Go home and skip the rest of today's classes.
}


## Returns the action for this student. Use `rng` for all randomness so runs are repeatable.
func decide(_student: Student, _context: DecisionContext, _rng: RandomNumberGenerator) -> Action:
	return Action.ATTEND_NEXT


## Short name shown in the UI and saved in logs.
func model_name() -> String:
	return "Always attend"
