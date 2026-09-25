class_name EventQueue
extends RefCounted
## Priority queue of SimEvents (binary min-heap on time, then seq).
##
## push and pop are O(log n), so the queue stays fast with thousands of students.

var _heap: Array[SimEvent] = []
var _next_seq: int = 0


func push(event: SimEvent) -> void:
	event.seq = _next_seq
	_next_seq += 1
	_heap.append(event)
	_sift_up(_heap.size() - 1)


## Removes and returns the earliest event, or null if the queue is empty.
func pop() -> SimEvent:
	if _heap.is_empty():
		return null
	var top: SimEvent = _heap[0]
	var last: SimEvent = _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		_sift_down(0)
	return top


## Returns the earliest event without removing it, or null if empty.
func peek() -> SimEvent:
	return null if _heap.is_empty() else _heap[0]


## Time of the earliest event, or INF if empty.
func peek_time() -> float:
	return INF if _heap.is_empty() else _heap[0].time


func size() -> int:
	return _heap.size()


func is_empty() -> bool:
	return _heap.is_empty()


func clear() -> void:
	_heap.clear()
	_next_seq = 0


func _sift_up(index: int) -> void:
	var i: int = index
	while i > 0:
		var parent: int = (i - 1) / 2
		if not _heap[i].precedes(_heap[parent]):
			break
		_swap(i, parent)
		i = parent


func _sift_down(index: int) -> void:
	var i: int = index
	var count: int = _heap.size()
	while true:
		var left: int = 2 * i + 1
		var right: int = left + 1
		var smallest: int = i
		if left < count and _heap[left].precedes(_heap[smallest]):
			smallest = left
		if right < count and _heap[right].precedes(_heap[smallest]):
			smallest = right
		if smallest == i:
			return
		_swap(i, smallest)
		i = smallest


func _swap(a: int, b: int) -> void:
	var tmp: SimEvent = _heap[a]
	_heap[a] = _heap[b]
	_heap[b] = tmp
