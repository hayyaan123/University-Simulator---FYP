class_name SimTime
extends RefCounted
## Helpers for simulation time.
##
## Time is measured in minutes (float) from Monday 00:00 of the simulated week.
## Example: Tuesday 09:30 = 1 * 1440 + 9 * 60 + 30 = 2010.0

const MINUTES_PER_HOUR: int = 60
const MINUTES_PER_DAY: int = 1440
const DAY_NAMES: PackedStringArray = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


## Builds an absolute minute from a day index (0 = Monday), hour and minute.
static func at(day: int, hour: int, minute: int = 0) -> float:
	return float(day * MINUTES_PER_DAY + hour * MINUTES_PER_HOUR + minute)


## Day index (0 = Monday) of an absolute minute.
static func day_of(time: float) -> int:
	return int(floor(time / MINUTES_PER_DAY))


## Minutes since midnight of an absolute minute.
static func minute_of_day(time: float) -> float:
	return fposmod(time, MINUTES_PER_DAY)


## Formats an absolute minute as "Mon 09:05".
static func format(time: float) -> String:
	var day: int = day_of(time)
	var of_day: int = int(floor(minute_of_day(time)))
	var day_name: String = DAY_NAMES[day % DAY_NAMES.size()]
	return "%s %02d:%02d" % [day_name, of_day / MINUTES_PER_HOUR, of_day % MINUTES_PER_HOUR]
