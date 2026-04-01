extends Node

const TestSingletonService = preload("res://addons/arca/_tests/installer_smoke_test/test_singleton_service.gd")
const TestTransientService = preload("res://addons/arca/_tests/installer_smoke_test/test_transient_service.gd")

const INSTALLERS_SETTING := "arca/project/global_installers"
const TEST_INSTALLER_PATH := "res://addons/arca/_tests/installer_smoke_test/test_installer.gd"

var _failed_checks: int = 0

func _ready() -> void:
	print("")
	print("=== ArcaInstaller Smoke Test ===")

	var previous_installers: Array = []
	var previous_value = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	if previous_value is Array:
		previous_installers = previous_value.duplicate()

	ProjectSettings.set_setting(INSTALLERS_SETTING, [TEST_INSTALLER_PATH])

	var project_context = ArcaProjectContext

	await get_tree().process_frame

	var singleton_a: RefCounted = project_context._container.resolve(TestSingletonService)
	var singleton_b: RefCounted = project_context._container.resolve(TestSingletonService)
	var transient_a: RefCounted = project_context._container.resolve(TestTransientService)
	var transient_b: RefCounted = project_context._container.resolve(TestTransientService)

	print("singleton_a id: ", _instance_id_or_null(singleton_a))
	print("singleton_b id: ", _instance_id_or_null(singleton_b))
	print("transient_a id: ", _instance_id_or_null(transient_a))
	print("transient_b id: ", _instance_id_or_null(transient_b))

	_check("installer creates project container", project_context._container != null)
	_check("installer binds singleton service", singleton_a != null and singleton_b != null)
	_check(
		"as_singleton returns the same instance",
		singleton_a != null
			and singleton_b != null
			and singleton_a.get_instance_id() == singleton_b.get_instance_id()
	)
	_check("installer binds transient service", transient_a != null and transient_b != null)
	_check(
		"as_transient returns a new instance on each resolve",
		transient_a != null
			and transient_b != null
			and transient_a.get_instance_id() != transient_b.get_instance_id()
	)

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)
	project_context.queue_free()

	if _failed_checks == 0:
		print("[RESULT] all checks passed")
	else:
		push_error("[RESULT] %d check(s) failed" % _failed_checks)

func _check(label: String, condition: bool) -> void:
	if condition:
		print("[PASS] ", label)
		return

	_failed_checks += 1
	push_error("[FAIL] %s" % label)

func _instance_id_or_null(instance: Object) -> Variant:
	if instance == null:
		return null

	return instance.get_instance_id()
