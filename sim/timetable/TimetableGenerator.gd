class_name TimetableGenerator
extends RefCounted
## Builds a weekly timetable: students, their units, and class sessions in rooms.
##
## Rules it guarantees:
## - no room is double-booked
## - no student has two classes at the same time
## - every class is inside the teaching day (Params.day_start_hour to day_end_hour)
##
## Classes start on the hour. A class takes whole hours on the grid and ends
## Params.slot_gap_minutes before its last hour is up, so a 120-minute lecture with a
## 10-minute gap runs 09:00-10:50. That gap is the time students have to walk to
## their next class.
##
## Method: greedy with random order. Lectures are placed first (largest units first) in
## the slot with the fewest clashes; students who still clash get a repeat lecture
## stream at another time, as big units do in real timetables. Tutorial and lab
## groups are then created as needed while students are added one by one, so every
## student fits a group that doesn't clash with their other classes.

## Classes start on the hour (the timetable grid).
const SLOT_MINUTES: int = 60
## Monday to Friday.
const TEACHING_DAYS: int = 5
## Shortest class we allow after taking off the gap.
const MIN_SESSION_MINUTES: int = 10
## Placeholder group sizes until the "tutors per unit" parameter exists (docs/PARAMETERS.md).
const TUTORIAL_GROUP_SIZE: int = 25
const LAB_GROUP_SIZE: int = 20
## How much more likely a student is to take a unit from their own year level.
const SAME_YEAR_WEIGHT: float = 6.0
## Most repeat streams a lecture can have before clashing students are left unplaced.
const MAX_LECTURE_STREAMS: int = 3
const MAX_YEAR: int = 3

## Students who could not be given a class (because no room or slot fitted), per run.
var unplaced: int = 0

var _campus: Campus
var _rng: RandomNumberGenerator
var _slots_per_day: int = 0
var _week_len: int = 0
# Busy flags, one byte per hour of the teaching week, stored flat: owner * _week_len + slot.
var _student_busy: PackedByteArray = PackedByteArray()
var _room_busy: PackedByteArray = PackedByteArray()
var _room_index: Dictionary = {}     # StringName -> int
var _sessions: Array[ClassSession] = []


## Returns {"sessions": Array[ClassSession], "students": Array[Student]} using Params.
## `units` is the "units" array from units.json.
func generate(campus: Campus, units: Array, rng: RandomNumberGenerator) -> Dictionary:
	_campus = campus
	_rng = rng
	_slots_per_day = maxi(0, Params.day_end_hour - Params.day_start_hour)
	_week_len = TEACHING_DAYS * _slots_per_day
	_sessions.clear()
	_room_index.clear()
	for room: StringName in campus.room_ids():
		_room_index[room] = _room_index.size()
	_room_busy = PackedByteArray()
	_room_busy.resize(_room_index.size() * _week_len)
	_room_busy.fill(0)
	unplaced = 0

	var chosen_units: Array = units
	var students: Array[Student] = _make_students()
	var enrolled: Array[Array] = _enrol(students, chosen_units)

	var order: Array = range(chosen_units.size())
	order.sort_custom(func(a: int, b: int) -> bool: return enrolled[a].size() > enrolled[b].size())
	for u: int in order:
		var unit: Dictionary = chosen_units[u]
		var ids: Array = enrolled[u]
		for i: int in range(int(unit.get("lectures_per_week", 1))):
			_place_lecture(unit, ids)
		for i: int in range(int(unit.get("tutorials_per_week", 0))):
			_place_groups(unit, ids, ClassSession.Kind.TUTORIAL, &"tutorial_room", TUTORIAL_GROUP_SIZE, Params.tutorial_minutes)
		for i: int in range(int(unit.get("labs_per_week", 0))):
			_place_groups(unit, ids, ClassSession.Kind.LAB, &"lab", LAB_GROUP_SIZE, Params.tutorial_minutes)

	var timetables: Array[Array] = []
	for student: Student in students:
		timetables.append([])
	for session: ClassSession in _sessions:
		for id: int in session.enrolled_ids:
			timetables[id].append(session)
	for student: Student in students:
		var own: Array[ClassSession] = []
		own.assign(timetables[student.id])
		student.set_timetable(own)
	if unplaced > 0:
		push_warning("TimetableGenerator: %d student-classes could not be placed" % unplaced)
	return {"sessions": _sessions.duplicate(), "students": students}


## Loads the "units" array from units.json.
static func load_units(path: String) -> Array:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TimetableGenerator: can't open %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("units"):
		push_error("TimetableGenerator: %s has no units list" % path)
		return []
	return parsed["units"]


func _make_students() -> Array[Student]:
	var students: Array[Student] = []
	for id: int in range(Params.student_count):
		var student: Student = Student.new(id, _rng.randi_range(1, MAX_YEAR))
		student.commute_minutes = float(Params.average_commute_minutes) * _rng.randf_range(
			1.0 - FixedSettings.COMMUTE_SPREAD, 1.0 + FixedSettings.COMMUTE_SPREAD)
		students.append(student)
	_student_busy = PackedByteArray()
	_student_busy.resize(students.size() * _week_len)
	_student_busy.fill(0)
	return students


## Picks Params.units_per_student units for each student, weighted by the unit's
## usual enrolment and by year level. Returns student ids per unit.
func _enrol(students: Array[Student], units: Array) -> Array[Array]:
	var enrolled: Array[Array] = []
	for u: int in range(units.size()):
		enrolled.append([])
	var per_student: int = mini(Params.units_per_student, units.size())
	for student: Student in students:
		var weights: PackedFloat32Array = PackedFloat32Array()
		for unit: Dictionary in units:
			var weight: float = maxf(1.0, float(unit.get("enrolment", 100)))
			if int(unit.get("year", 1)) == student.year:
				weight *= SAME_YEAR_WEIGHT
			weights.append(weight)
		for pick: int in range(per_student):
			var u: int = _rng.rand_weighted(weights)
			enrolled[u].append(student.id)
			weights[u] = 0.0  # Can't take the same unit twice.
	return enrolled


## Places one weekly lecture, adding repeat streams for students who clash.
func _place_lecture(unit: Dictionary, student_ids: Array) -> void:
	var remaining: Array = student_ids
	for stream: int in range(MAX_LECTURE_STREAMS):
		if remaining.is_empty():
			return
		remaining = _place_lecture_stream(unit, remaining)
	unplaced += remaining.size()


## Books the lecture slot with the fewest clashes. Returns the students who clash.
func _place_lecture_stream(unit: Dictionary, student_ids: Array) -> Array:
	var slots: int = _slots_for(Params.lecture_minutes)
	var best_start: int = -1
	var best_room: StringName = &""
	var best_clashes: int = student_ids.size() + 1
	for start: int in _shuffled_starts(slots):
		var room: StringName = _free_room(&"lecture_hall", start, slots, student_ids.size())
		if room == &"":
			room = _free_room(&"", start, slots, student_ids.size())  # Any room if no hall is free.
		if room == &"":
			continue
		var clashes: int = 0
		for id: int in student_ids:
			if not _student_free(id, start, slots):
				clashes += 1
		if clashes < best_clashes:
			best_start = start
			best_room = room
			best_clashes = clashes
			if clashes == 0:
				break
	if best_start == -1 or best_clashes == student_ids.size():
		return student_ids
	var session: ClassSession = _book(unit, ClassSession.Kind.LECTURE, best_room, best_start, slots, Params.lecture_minutes)
	var clashing: Array = []
	for id: int in student_ids:
		if _student_free(id, best_start, slots):
			_join(session, id, best_start, slots)
		else:
			clashing.append(id)
	return clashing


## Adds each student to a group that fits their week, creating groups as needed.
func _place_groups(unit: Dictionary, student_ids: Array, kind: ClassSession.Kind,
		room_type: StringName, group_size: int, minutes: int) -> void:
	var slots: int = _slots_for(minutes)
	var groups: Array[ClassSession] = []
	var group_starts: PackedInt32Array = PackedInt32Array()
	var order: Array = student_ids.duplicate()
	_shuffle(order)
	for id: int in order:
		var placed: bool = false
		for g: int in range(groups.size()):
			var group: ClassSession = groups[g]
			if group.enrolled_ids.size() < mini(group_size, group.capacity) \
					and _student_free(id, group_starts[g], slots):
				_join(group, id, group_starts[g], slots)
				placed = true
				break
		if placed:
			continue
		for start: int in _shuffled_starts(slots):
			if not _student_free(id, start, slots):
				continue
			var room: StringName = _free_room(room_type, start, slots, group_size)
			if room == &"":
				continue
			var group: ClassSession = _book(unit, kind, room, start, slots, minutes)
			groups.append(group)
			group_starts.append(start)
			_join(group, id, start, slots)
			placed = true
			break
		if not placed:
			unplaced += 1


func _book(unit: Dictionary, kind: ClassSession.Kind, room: StringName, start: int, slots: int, minutes: int) -> ClassSession:
	_mark_room(room, start, slots)
	var day: int = start / _slots_per_day
	var slot: int = start % _slots_per_day
	var begins: float = SimTime.at(day, Params.day_start_hour) + slot * SLOT_MINUTES
	var capacity: int = int(_campus.room_capacity(room) * Params.room_capacity_multiplier)
	var session: ClassSession = ClassSession.new(_sessions.size(), StringName(unit["code"]), kind,
		room, _campus.room_building(room), begins, _duration_for(minutes), capacity)
	_sessions.append(session)
	return session


func _join(session: ClassSession, student_id: int, start: int, slots: int) -> void:
	session.enrolled_ids.append(student_id)
	_mark_student(student_id, start, slots)


## Smallest free room of this type that seats `size`, else the biggest free one. "" = any type.
## Rooms are checked from a random starting point, so equally good rooms share the load
## instead of the first building in the file filling up first.
func _free_room(room_type: StringName, start: int, slots: int, size: int) -> StringName:
	var best: StringName = &""
	var best_capacity: int = -1
	var rooms: Array[StringName] = _campus.room_ids() if room_type == &"" else _campus.rooms_of_type(room_type)
	if rooms.is_empty():
		return best
	var offset: int = _rng.randi_range(0, rooms.size() - 1)
	for k: int in range(rooms.size()):
		var room: StringName = rooms[(k + offset) % rooms.size()]
		if not _is_free(_room_busy, int(_room_index[room]) * _week_len + start, slots):
			continue
		var capacity: int = _campus.room_capacity(room)
		var better: bool
		if best_capacity < size:
			better = capacity > best_capacity
		else:
			better = capacity >= size and capacity < best_capacity
		if better:
			best = room
			best_capacity = capacity
	return best


## Every start slot (day * slots_per_day + hour) where a class of `slots` hours fits in the day.
func _shuffled_starts(slots: int) -> Array:
	var starts: Array = []
	for day: int in range(TEACHING_DAYS):
		for slot: int in range(_slots_per_day - slots + 1):
			starts.append(day * _slots_per_day + slot)
	_shuffle(starts)
	return starts


func _slots_for(minutes: int) -> int:
	return maxi(1, ceili(float(minutes) / SLOT_MINUTES))


## Nominal length, cut short so it ends slot_gap_minutes before the next hour.
func _duration_for(minutes: int) -> float:
	var room_time: int = _slots_for(minutes) * SLOT_MINUTES - Params.slot_gap_minutes
	return float(maxi(MIN_SESSION_MINUTES, mini(minutes, room_time)))


func _student_free(student_id: int, start: int, slots: int) -> bool:
	return _is_free(_student_busy, student_id * _week_len + start, slots)


func _is_free(busy: PackedByteArray, offset: int, slots: int) -> bool:
	for i: int in range(offset, offset + slots):
		if busy[i] != 0:
			return false
	return true


func _mark_student(student_id: int, start: int, slots: int) -> void:
	var offset: int = student_id * _week_len + start
	for i: int in range(offset, offset + slots):
		_student_busy[i] = 1


func _mark_room(room: StringName, start: int, slots: int) -> void:
	var offset: int = int(_room_index[room]) * _week_len + start
	for i: int in range(offset, offset + slots):
		_room_busy[i] = 1


## Fisher-Yates shuffle using the run's RNG, so timetables repeat with the same seed.
func _shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
