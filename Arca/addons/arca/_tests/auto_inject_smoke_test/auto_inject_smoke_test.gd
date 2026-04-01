extends Node

const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")
const ArcaBinder = preload("res://addons/arca/core/arca_binder.gd")

const TestDependencyService = preload("res://addons/arca/_tests/auto_inject_smoke_test/test_dependency_service.gd")
const TestSelfInjectedService = preload("res://addons/arca/_tests/auto_inject_smoke_test/test_self_injected_service.gd")
const TestFactoryInjectedService = preload("res://addons/arca/_tests/auto_inject_smoke_test/test_factory_injected_service.gd")

var _failed_checks: int = 0


func _ready() -> void:
	print("")
	print("=== Arca Auto Inject Smoke Test ===")

	var container = ArcaContainer.new()
	var binder = ArcaBinder.new(container)

	binder.bind(TestDependencyService).as_singleton()
	binder.bind(TestSelfInjectedService).as_singleton()
	binder.bind(TestFactoryInjectedService).from_factory(
		func() -> Variant:
			return TestFactoryInjectedService.new()
	).as_transient()

	var dependency: RefCounted = container.resolve(TestDependencyService)
	var self_service_a: RefCounted = container.resolve(TestSelfInjectedService)
	var self_service_b: RefCounted = container.resolve(TestSelfInjectedService)
	var factory_service_a: RefCounted = container.resolve(TestFactoryInjectedService)
	var factory_service_b: RefCounted = container.resolve(TestFactoryInjectedService)

	print("dependency id: ", _instance_id_or_null(dependency))
	print("self_service_a id: ", _instance_id_or_null(self_service_a))
	print("self_service_b id: ", _instance_id_or_null(self_service_b))
	print("factory_service_a id: ", _instance_id_or_null(factory_service_a))
	print("factory_service_b id: ", _instance_id_or_null(factory_service_b))

	_check("dependency is bound", dependency != null)
	_check(
		"bind_self auto-injects dependency",
		self_service_a != null and self_service_a.dependency == dependency
	)
	_check(
		"bind_self passes the current container into inject_dependencies",
		self_service_a != null and self_service_a.injected_with == container
	)
	_check(
		"bind_self singleton returns the same injected instance",
		self_service_a != null
			and self_service_b != null
			and self_service_a.get_instance_id() == self_service_b.get_instance_id()
	)
	_check(
		"from_factory auto-injects dependency without manual inject call in factory",
		factory_service_a != null and factory_service_a.dependency == dependency
	)
	_check(
		"from_factory passes the current container into inject_dependencies",
		factory_service_a != null and factory_service_a.injected_with == container
	)
	_check(
		"from_factory transient returns a new injected instance on each resolve",
		factory_service_a != null
			and factory_service_b != null
			and factory_service_a.get_instance_id() != factory_service_b.get_instance_id()
	)
	_check(
		"each transient factory result receives the dependency",
		factory_service_b != null and factory_service_b.dependency == dependency
	)

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
