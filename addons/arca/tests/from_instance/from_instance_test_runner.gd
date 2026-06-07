extends Control

const BaseService := preload("res://addons/arca/tests/from_instance/fixtures/from_instance_base_service.gd")
const ChildService := preload("res://addons/arca/tests/from_instance/fixtures/from_instance_child_service.gd")
const UnrelatedService := preload("res://addons/arca/tests/from_instance/fixtures/from_instance_unrelated_service.gd")

var _failures := 0
var _lines: PackedStringArray = []
var _label: RichTextLabel


func _ready() -> void:
	_build_ui()
	_run()
	_render_results()


func _run() -> void:
	_log("Arca from_instance tests")

	_test_resolve_returns_exact_bound_instance()
	_test_resolve_keeps_instance_as_singleton()
	_test_child_instance_can_be_bound_to_base_script()
	_test_unrelated_instance_is_rejected()
	_test_from_instance_registers_object_in_lifecycle_tracking()

	if _failures == 0:
		_log("OK: all from_instance tests passed.")
	else:
		_log("FAILED: %d from_instance test(s) failed." % _failures)

	_write_results()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_label = RichTextLabel.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = true
	_label.add_theme_font_size_override("normal_font_size", 18)
	_label.add_theme_font_size_override("mono_font_size", 18)
	_label.text = "[code]Running Arca from_instance tests...[/code]"
	add_child(_label)


func _render_results() -> void:
	var color = "green" if _failures == 0 else "red"
	var title = "PASSED" if _failures == 0 else "FAILED"
	_label.text = "[b][color=%s]%s[/color][/b]\n\n[code]%s[/code]" % [
		color,
		title,
		"\n".join(_lines),
	]


func _test_resolve_returns_exact_bound_instance() -> void:
	var container = ArcaContainer.new()
	var service = BaseService.new()
	service.value = "existing"

	container.bind(BaseService).from_instance(service)

	var resolved = container.resolve(BaseService)
	var resolved_value = resolved.value if resolved != null else ""

	_assert_true(resolved == service, "resolve returns the exact instance passed to from_instance")
	_assert_true(resolved_value == "existing", "from_instance preserves existing instance state")


func _test_resolve_keeps_instance_as_singleton() -> void:
	var container = ArcaContainer.new()
	var service = BaseService.new()

	container.bind(BaseService).from_instance(service)

	var first = container.resolve(BaseService)
	var second = container.resolve(BaseService)

	_assert_true(first == second, "from_instance behaves as singleton")
	_assert_true(first == service, "from_instance never creates another instance")


func _test_child_instance_can_be_bound_to_base_script() -> void:
	var container = ArcaContainer.new()
	var child = ChildService.new()

	container.bind(BaseService).from_instance(child)

	var resolved = container.resolve(BaseService)

	_assert_true(resolved == child, "child script instance can be bound to base script")
	_assert_true(resolved is ArcaFromInstanceChildService, "resolved base binding keeps child runtime type")


func _test_unrelated_instance_is_rejected() -> void:
	var container = ArcaContainer.new()
	var unrelated = UnrelatedService.new()

	container.bind(BaseService).from_instance(unrelated)

	var resolved = container.resolve(BaseService)

	_assert_true(resolved == null, "from_instance rejects unrelated script instances")


func _test_from_instance_registers_object_in_lifecycle_tracking() -> void:
	var container = ArcaContainer.new()
	var service = BaseService.new()

	container.bind(BaseService).from_instance(service)
	container.resolve(BaseService)

	_assert_true(container._instances.has(service), "resolved from_instance object is tracked by container")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_log("PASS: %s" % message)
		return

	_failures += 1
	_log("FAIL: %s" % message)


func _log(message: String) -> void:
	print(message)
	_lines.append(message)


func _write_results() -> void:
	var file = FileAccess.open("res://addons/arca/tests/from_instance/from_instance_test_results.txt", FileAccess.WRITE)
	if file == null:
		push_error("Unable to write from_instance test results.")
		return

	for line in _lines:
		file.store_line(line)
