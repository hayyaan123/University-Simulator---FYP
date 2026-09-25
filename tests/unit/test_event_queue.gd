extends GutTest


func test_pops_in_time_order() -> void:
	var queue: EventQueue = EventQueue.new()
	for t: float in [30.0, 10.0, 20.0, 5.0, 25.0]:
		queue.push(SimEvent.new(t, SimEvent.Type.CLASS_START))
	var times: Array[float] = []
	while not queue.is_empty():
		times.append(queue.pop().time)
	assert_eq(times, [5.0, 10.0, 20.0, 25.0, 30.0] as Array[float])


func test_same_time_keeps_insertion_order() -> void:
	var queue: EventQueue = EventQueue.new()
	for i: int in range(10):
		queue.push(SimEvent.new(60.0, SimEvent.Type.STUDENT_DECIDE, i))
	for i: int in range(10):
		assert_eq(queue.pop().subject_id, i)


func test_empty_queue() -> void:
	var queue: EventQueue = EventQueue.new()
	assert_true(queue.is_empty())
	assert_null(queue.pop())
	assert_null(queue.peek())
	assert_eq(queue.peek_time(), INF)


func test_random_order_matches_sort() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var queue: EventQueue = EventQueue.new()
	var expected: Array[float] = []
	for i: int in range(2000):
		var t: float = float(rng.randi_range(0, 500))
		expected.append(t)
		queue.push(SimEvent.new(t, SimEvent.Type.CLASS_END))
	expected.sort()
	var last_time: float = -1.0
	var last_seq: int = -1
	for t: float in expected:
		var event: SimEvent = queue.pop()
		assert_eq(event.time, t)
		if event.time == last_time:
			assert_gt(event.seq, last_seq, "ties keep insertion order")
		last_time = event.time
		last_seq = event.seq
	assert_true(queue.is_empty())


func test_clear() -> void:
	var queue: EventQueue = EventQueue.new()
	queue.push(SimEvent.new(1.0, SimEvent.Type.CLASS_START))
	queue.clear()
	assert_eq(queue.size(), 0)
