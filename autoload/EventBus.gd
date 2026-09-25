extends Node
## Global signals (autoload "EventBus").
##
## SimEngine emits these; Stats, MapView, the dashboard and loggers listen.
## The engine never calls UI code directly, so the simulation also runs headless.

signal run_started(seed: int)
signal run_finished()
## Emitted once per advance, not per event, so the UI can update cheaply.
signal sim_time_changed(time: float)

signal day_started(day: int)
signal class_started(session: ClassSession)
signal class_ended(session: ClassSession)

signal student_state_changed(student: Student, old_state: Student.State, new_state: Student.State)
signal student_departed(student: Student, from_building: StringName, to_building: StringName, arrive_time: float)
signal student_arrived(student: Student, building: StringName)
signal student_attended(student: Student, session: ClassSession, minutes_late: float, is_late: bool)
## reason is one of: &"decided", &"too_late", &"left_campus"
signal student_skipped(student: Student, session: ClassSession, reason: StringName)
## Emitted for every decision, with the features the model saw. Used for data logging.
signal student_decided(student: Student, features: Dictionary, action: DecisionModel.Action)
