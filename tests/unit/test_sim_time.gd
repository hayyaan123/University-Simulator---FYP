extends GutTest


func test_at() -> void:
	assert_eq(SimTime.at(0, 0), 0.0)
	assert_eq(SimTime.at(1, 9, 30), 2010.0)


func test_day_and_minute_of_day() -> void:
	var t: float = SimTime.at(3, 14, 15)
	assert_eq(SimTime.day_of(t), 3)
	assert_eq(SimTime.minute_of_day(t), 855.0)


func test_format() -> void:
	assert_eq(SimTime.format(SimTime.at(0, 9, 5)), "Mon 09:05")
	assert_eq(SimTime.format(SimTime.at(4, 17, 0)), "Fri 17:00")
