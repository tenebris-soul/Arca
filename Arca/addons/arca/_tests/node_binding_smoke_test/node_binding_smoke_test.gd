extends Node

const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")
const ArcaBinder = preload("res://addons/arca/core/arca_binder.gd")

const TestNodeDependencyService = preload("res://addons/arca/_tests/node_binding_smoke_test/test_node_dependency_service.gd")
const TestSingletonNodeService = preload("res://addons/arca/_tests/node_binding_smoke_test/test_singleton_node_service.gd")
const TestTransientNodeService = preload("res://addons/arca/_tests/node_binding_smoke_test/test_transient_node_service.gd")

var _failed_checks: int = 0


func _ready() -> void:
	print("")
	print("=== Arca Node Binding Smoke Test ===")

	var container = ArcaContainer.new(null, self)
	var binder = ArcaBinder.new(container)

	binder.bind(TestNodeDependencyService).as_singleton()
	binder.bind(TestSingletonNodeService).as_singleton()
	binder.bind(TestTransientNodeService).as_transient()

	var dependency: RefCounted = container.resolve(TestNodeDependencyService)
	var singleton_node_a: Node = container.resolve(TestSingletonNodeService)
	var singleton_node_b: Node = container.resolve(TestSingletonNodeService)
	var transient_node_a: Node = container.resolve(TestTransientNodeService)
	var transient_node_b: Node = container.resolve(TestTransientNodeService)

	print("dependency id: ", _instance_id_or_null(dependency))
	print("singleton_node_a id: ", _instance_id_or_null(singleton_node_a))
	print("singleton_node_b id: ", _instance_id_or_null(singleton_node_b))
	print("transient_node_a id: ", _instance_id_or_null(transient_node_a))
	print("transient_node_b id: ", _instance_id_or_null(transient_node_b))

	_check("singleton node resolved", singleton_node_a != null and singleton_node_b != null)
	_check("transient nodes resolved", transient_node_a != null and transient_node_b != null)
	_check(
		"singleton node gets dependency through auto-inject",
		singleton_node_a != null and singleton_node_a.dependency == dependency
	)
	_check(
		"transient node gets dependency through auto-inject",
		transient_node_a != null and transient_node_a.dependency == dependency
	)
	_check(
		"singleton node receives the current container in inject_dependencies",
		singleton_node_a != null and singleton_node_a.injected_with == container
	)
	_check(
		"transient node receives the current container in inject_dependencies",
		transient_node_a != null and transient_node_a.injected_with == container
	)
	_check(
		"singleton node is attached to host node automatically",
		singleton_node_a != null and singleton_node_a.get_parent() == self
	)
	_check(
		"transient node is attached to host node automatically",
		transient_node_a != null and transient_node_a.get_parent() == self
	)
	_check(
		"singleton node returns the same instance on each resolve",
		singleton_node_a != null
			and singleton_node_b != null
			and singleton_node_a.get_instance_id() == singleton_node_b.get_instance_id()
	)
	_check(
		"transient node returns a new instance on each resolve",
		transient_node_a != null
			and transient_node_b != null
			and transient_node_a.get_instance_id() != transient_node_b.get_instance_id()
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
