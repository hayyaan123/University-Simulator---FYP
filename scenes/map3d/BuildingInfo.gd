class_name BuildingInfo
extends PanelContainer
## The panel shown when a building is clicked in the 3D map: its name, what kind of
## building it is, its rooms (with capacity) and how many students are inside now.
## Read-only: it never changes the simulation.

signal focus_requested(building_id: StringName)
## Asks to look inside the building (or, when already inside, to step back out).
signal inside_requested(building_id: StringName)
signal closed()

const ROOM_NAMES: Dictionary = {
	&"lecture_hall": "Lecture halls", &"tutorial_room": "Tutorial rooms", &"lab": "Labs",
}
const PANEL_WIDTH_PX: float = 280.0

var campus: Campus
var _id: StringName = &""
var _title: Label
var _body: Label
var _inside_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH_PX, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override(&"font_size", 18)
	header.add_child(_title)
	var close: Button = Button.new()
	close.text = "×"
	close.flat = true
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_body)
	var buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(buttons)
	var focus: Button = Button.new()
	focus.text = "Fly to building"
	focus.pressed.connect(func() -> void: focus_requested.emit(_id))
	buttons.add_child(focus)
	_inside_button = Button.new()
	_inside_button.text = "Look inside"
	_inside_button.pressed.connect(func() -> void: inside_requested.emit(_id))
	buttons.add_child(_inside_button)
	hide()


## Shows (or refreshes) the panel for a building. `info` is a CampusWorld.buildings entry.
## `seated` is how many students are drawn in the open interior (-1 when not inside).
func show_building(id: StringName, info: Dictionary, students_inside: int, seated: int = -1) -> void:
	_inside_button.text = "Back outside" if seated >= 0 else "Look inside"
	_id = id
	_title.text = String(info.get("name", id))
	var lines: PackedStringArray = PackedStringArray()
	if campus != null and campus.building_ids().has(id):
		lines.append("Type: %s" % String(campus.building_kind(id)).capitalize())
		lines.append_array(_room_lines(id))
	lines.append("Height: %d m" % int(round(float(info.get("top_m", 0.0)))))
	lines.append("")
	lines.append("Students inside now: %d" % students_inside)
	if seated >= 0:
		lines.append("Showing one floor: %d seated here" % seated)
	_body.text = "\n".join(lines)
	show()


func _room_lines(id: StringName) -> PackedStringArray:
	var counts: Dictionary = {}  # StringName room type -> [count, seats]
	for room: StringName in campus.room_ids():
		if campus.room_building(room) != id:
			continue
		var kind: StringName = campus.room_type(room)
		var entry: Array = counts.get(kind, [0, 0])
		counts[kind] = [entry[0] + 1, entry[1] + campus.room_capacity(room)]
	var lines: PackedStringArray = PackedStringArray()
	if counts.is_empty():
		lines.append("No teaching rooms")
	for kind: StringName in counts:
		lines.append("%s: %d (%d seats)" % [ROOM_NAMES.get(kind, String(kind)), counts[kind][0], counts[kind][1]])
	return lines
