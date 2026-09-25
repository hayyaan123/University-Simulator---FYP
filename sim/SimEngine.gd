class_name SimEngine
extends RefCounted
## The discrete-event simulation core.
##
## Holds the event queue and the clock, and applies the rules for travel, lateness
## and attendance. It has no visuals and no Node dependency, so it runs the same in
## the game, in headless data-logging runs and in unit tests.
##
## Flow for one student on one day:
##   DAY_START -> STUDENT_DECIDE (timed so they can arrive early by arrival_buffer)
##   -> ATTEND: walk (travel_minutes) -> STUDENT_ARRIVE -> on time / late / too late
##   -> CLASS_END -> STUDENT_DECIDE for the next class ... -> no classes left: go home.
##
## Usage:
##   var engine := SimEngine.new()
##   engine.setup(campus, sessions, students, DecisionModel.new())
##   engine.advance_to(engine.now + 30.0)   # or engine.run_to_end()

## Current simulation time in minutes from Monday 00:00.
var now: float = 0.0
## The run stops here (midnight after the last simulated day).
var end_time: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var campus: Campus
var decision_model: DecisionModel
var students: Array[Student] = []
var sessions: Array[ClassSession] = []
var events_processed: int = 0

var _queue: EventQueue = EventQueue.new()
var _students_by_id: Dictionary = {}   # int -> Student
var _sessions_by_id: Dictionary = {}   # int -> ClassSession
var _attended_today: Dictionary = {}   # student id -> int
var _finished_emitted: bool = false


## Prepares a new run. Reads Params (seed, days, buffers) at this moment.
func setup(
	p_campus: Campus,
	p_sessions: Array[ClassSession],
	p_students: Array[Student],
	p_model: DecisionModel,
) -> void:
	campus = p_campus
	sessions = p_sessions
	students = p_students
	decision_model = p_model
	rng.seed = Params.random_seed
	now = 0.0
	events_processed = 0
	end_time = SimTime.at(Params.days_to_simulate, 0)
	_finished_emitted = false
	_queue.clear()
	_attended_today.clear()

	_students_by_id.clear()
	for student: Student in students:
		_students_by_id[student.id] = student
		student.state = Student.State.OFF_CAMPUS
		student.location = campus.entrance_id()
		student.target_session = null

	_sessions_by_id.clear()
	for session: ClassSession in sessions:
		_sessions_by_id[session.id] = session
		session.present_ids.clear()
		if session.start < end_time:
			schedule(SimEvent.new(session.start, SimEvent.Type.CLASS_START, session.id))
			schedule(SimEvent.new(session.end, SimEvent.Type.CLASS_END, session.id))

	for day: int in range(Params.days_to_simulate):
		schedule(SimEvent.new(SimTime.at(day, 0), SimEvent.Type.DAY_START, day))

	EventBus.run_started.emit(Params.random_seed)


func schedule(event: SimEvent) -> void:
	assert(event.time >= now, "Cannot schedule an event in the past: %s < %s" % [event.time, now])
	_queue.push(event)


## Processes every event up to and including `target_time`, then moves the clock there.
## Returns the number of events processed.
func advance_to(target_time: float) -> int:
	var target: float = minf(target_time, end_time)
	var processed: int = 0
	while not _queue.is_empty() and _queue.peek_time() <= target:
		var event: SimEvent = _queue.pop()
		now = event.time
		_dispatch(event)
		processed += 1
	events_processed += processed
	now = maxf(now, target)
	EventBus.sim_time_changed.emit(now)
	if is_finished() and not _finished_emitted:
		_finished_emitted = true
		EventBus.run_finished.emit()
	return processed


func run_to_end() -> void:
	advance_to(end_time)


func is_finished() -> bool:
	return now >= end_time


func pending_events() -> int:
	return _queue.size()


func get_student(student_id: int) -> Student:
	return _students_by_id.get(student_id)


func get_session(session_id: int) -> ClassSession:
	return _sessions_by_id.get(session_id)


# --- Event handlers -----------------------------------------------------------

func _dispatch(event: SimEvent) -> void:
	match event.type:
		SimEvent.Type.DAY_START:
			_on_day_start(event.subject_id)
		SimEvent.Type.CLASS_START:
			EventBus.class_started.emit(_sessions_by_id[event.subject_id])
		SimEvent.Type.CLASS_END:
			_on_class_end(_sessions_by_id[event.subject_id])
		SimEvent.Type.STUDENT_DECIDE:
			_on_student_decide(_students_by_id[event.subject_id], _sessions_by_id[event.payload.session_id])
		SimEvent.Type.STUDENT_ARRIVE:
			_on_student_arrive(_students_by_id[event.subject_id], _sessions_by_id[event.payload.session_id])
		_:
			push_error("SimEngine: unhandled event type %s" % event.type)


func _on_day_start(day: int) -> void:
	_attended_today.clear()
	EventBus.day_started.emit(day)
	for student: Student in students:
		_schedule_next_decision(student, now)


func _on_class_end(session: ClassSession) -> void:
	EventBus.class_ended.emit(session)
	for student_id: int in session.present_ids:
		var student: Student = _students_by_id[student_id]
		student.target_session = null
		_set_state(student, Student.State.WAITING)
		_schedule_next_decision(student, now)
	session.present_ids.clear()


func _on_student_decide(student: Student, session: ClassSession) -> void:
	if now >= session.end:
		# The class is already over (e.g. a long earlier class ran past it).
		_skip(student, session, &"too_late")
		_schedule_next_decision(student, now)
		return

	var travel: float = campus.travel_minutes(student.location, session.building_id)
	var sessions_left: int = _sessions_left_today(student, session)
	var context: DecisionContext = DecisionContext.new(
		now, session, travel, sessions_left, int(_attended_today.get(student.id, 0))
	)
	var action: DecisionModel.Action = decision_model.decide(student, context, rng)
	EventBus.student_decided.emit(student, context.to_features(student), action)

	match action:
		DecisionModel.Action.ATTEND_NEXT:
			_depart(student, session, travel)
		DecisionModel.Action.SKIP_NEXT:
			_skip(student, session, &"decided")
			_schedule_next_decision(student, session.end)
		DecisionModel.Action.LEAVE_CAMPUS:
			for later: ClassSession in student.sessions_on_day(session.day()):
				if later.start >= session.start:
					_skip(student, later, &"left_campus")
			_go_home(student)


func _on_student_arrive(student: Student, session: ClassSession) -> void:
	student.location = session.building_id
	EventBus.student_arrived.emit(student, session.building_id)

	var minutes_late: float = maxf(0.0, now - session.start)
	if minutes_late > Params.skip_threshold_minutes:
		student.target_session = null
		_set_state(student, Student.State.WAITING)
		_skip(student, session, &"too_late")
		_schedule_next_decision(student, session.end)
		return

	var is_late: bool = minutes_late > Params.late_grace_minutes
	student.attended_count += 1
	if is_late:
		student.late_count += 1
	_attended_today[student.id] = int(_attended_today.get(student.id, 0)) + 1
	session.present_ids.append(student.id)
	_set_state(student, Student.State.IN_CLASS)
	EventBus.student_attended.emit(student, session, minutes_late, is_late)


# --- Helpers ------------------------------------------------------------------

## Schedules the student's decision about their next class today (after `from_time`),
## timed so they can arrive `arrival_buffer_minutes` early. No class left: go home.
func _schedule_next_decision(student: Student, from_time: float) -> void:
	var next: ClassSession = student.next_session_today(from_time)
	if next == null:
		_go_home(student)
		return
	var travel: float = campus.travel_minutes(student.location, next.building_id)
	var decide_at: float = maxf(now, next.start - travel - Params.arrival_buffer_minutes)
	if student.state != Student.State.OFF_CAMPUS:
		_set_state(student, Student.State.WAITING)
	schedule(SimEvent.new(decide_at, SimEvent.Type.STUDENT_DECIDE, student.id, {"session_id": next.id}))


func _depart(student: Student, session: ClassSession, travel: float) -> void:
	var arrive_time: float = now + travel
	student.target_session = session
	_set_state(student, Student.State.TRAVELLING)
	EventBus.student_departed.emit(student, student.location, session.building_id, arrive_time)
	schedule(SimEvent.new(arrive_time, SimEvent.Type.STUDENT_ARRIVE, student.id, {"session_id": session.id}))


func _skip(student: Student, session: ClassSession, reason: StringName) -> void:
	student.skipped_count += 1
	EventBus.student_skipped.emit(student, session, reason)


func _go_home(student: Student) -> void:
	if student.state == Student.State.OFF_CAMPUS:
		return
	var entrance: StringName = campus.entrance_id()
	var arrive_time: float = now + campus.travel_minutes(student.location, entrance)
	EventBus.student_departed.emit(student, student.location, entrance, arrive_time)
	student.location = entrance
	student.target_session = null
	_set_state(student, Student.State.OFF_CAMPUS)


func _sessions_left_today(student: Student, from_session: ClassSession) -> int:
	var count: int = 0
	for session: ClassSession in student.sessions_on_day(from_session.day()):
		if session.start >= from_session.start:
			count += 1
	return count


func _set_state(student: Student, new_state: Student.State) -> void:
	if student.state == new_state:
		return
	var old_state: Student.State = student.state
	student.state = new_state
	EventBus.student_state_changed.emit(student, old_state, new_state)
