class_name FixedDecision
extends DecisionModel
## Decision model for tests: always returns the same action.

var action: DecisionModel.Action


func _init(p_action: DecisionModel.Action) -> void:
	action = p_action


func decide(_student: Student, _context: DecisionContext, _rng: RandomNumberGenerator) -> DecisionModel.Action:
	return action


func model_name() -> String:
	return "Fixed (%s)" % DecisionModel.Action.keys()[action]
