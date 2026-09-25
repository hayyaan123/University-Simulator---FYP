extends GutTest

const TEMP_SCENARIO: String = "user://test_scenario.json"


func before_each() -> void:
	Params.reset_to_defaults()


func after_all() -> void:
	Params.reset_to_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SCENARIO))


func test_every_spec_has_a_variable() -> void:
	for key: StringName in Params.SPECS:
		assert_true(key in Params, "Params is missing a var for %s" % key)


func test_set_value_clamps() -> void:
	Params.set_value(&"student_count", 999999)
	assert_eq(Params.student_count, 5000)
	Params.set_value(&"walking_speed_m_per_min", 1.0)
	assert_eq(Params.walking_speed_m_per_min, 40.0)


func test_unknown_key_is_rejected() -> void:
	assert_false(Params.set_value(&"not_a_param", 1))


func test_changed_signal() -> void:
	watch_signals(Params)
	Params.set_value(&"late_grace_minutes", 10.0)
	assert_signal_emitted_with_parameters(Params, "changed", [&"late_grace_minutes", 10.0])


func test_scenario_round_trip() -> void:
	Params.set_value(&"student_count", 1200)
	Params.set_value(&"random_seed", 7)
	assert_eq(Params.save_scenario(TEMP_SCENARIO, "test"), OK)
	Params.reset_to_defaults()
	assert_eq(Params.student_count, 500)
	assert_eq(Params.load_scenario(TEMP_SCENARIO), OK)
	assert_eq(Params.student_count, 1200)
	assert_eq(Params.random_seed, 7)


func test_default_scenario_file_matches_defaults() -> void:
	assert_eq(Params.load_scenario("res://data/scenarios/default.json"), OK)
	var loaded: Dictionary = Params.to_dict()
	Params.reset_to_defaults()
	assert_eq(loaded, Params.to_dict())
