extends Node

const TestParentSingletonService = preload("res://addons/arca/_tests/node_context_smoke_test/test_parent_singleton_service.gd")
const TestParentTransientService = preload("res://addons/arca/_tests/node_context_smoke_test/test_parent_transient_service.gd")
const TestChildScopedService = preload("res://addons/arca/_tests/node_context_smoke_test/test_child_scoped_service.gd")

var _failed_checks: int = 0

@onready var _parent_context := $ParentScopedContext
@onready var _inherited_child_context := $ParentScopedContext/InheritedChildContext
@onready var _scoped_child_context := $ParentScopedContext/ScopedChildContext


func _ready() -> void:
	print("")
	print("=== ArcaNodeContext Smoke Test ===")

	_check("project context exists", ArcaProjectContext != null)
	_check("parent scoped context has a container", _parent_context._container != null)
	_check(
		"inherited child reuses parent container",
		_inherited_child_context._container == _parent_context._container
	)
	_check(
		"scoped child creates its own container",
		_scoped_child_context._container != null
			and _scoped_child_context._container != _parent_context._container
	)
	_check(
		"scoped child container points to parent container",
		_scoped_child_context._container != null
			and _scoped_child_context._container.parent == _parent_context._container
	)

	var parent_singleton_a: RefCounted = _parent_context._container.resolve(TestParentSingletonService)
	var parent_singleton_b: RefCounted = _inherited_child_context._container.resolve(TestParentSingletonService)
	var inherited_transient_a: RefCounted = _inherited_child_context._container.resolve(TestParentTransientService)
	var inherited_transient_b: RefCounted = _inherited_child_context._container.resolve(TestParentTransientService)
	var scoped_child_parent_singleton: RefCounted = _scoped_child_context._container.resolve(TestParentSingletonService)
	var scoped_child_local_a: RefCounted = _scoped_child_context._container.resolve(TestChildScopedService)
	var scoped_child_local_b: RefCounted = _scoped_child_context._container.resolve(TestChildScopedService)

	print("parent_singleton_a id: ", _instance_id_or_null(parent_singleton_a))
	print("parent_singleton_b id: ", _instance_id_or_null(parent_singleton_b))
	print("inherited_transient_a id: ", _instance_id_or_null(inherited_transient_a))
	print("inherited_transient_b id: ", _instance_id_or_null(inherited_transient_b))
	print("scoped_child_parent_singleton id: ", _instance_id_or_null(scoped_child_parent_singleton))
	print("scoped_child_local_a id: ", _instance_id_or_null(scoped_child_local_a))
	print("scoped_child_local_b id: ", _instance_id_or_null(scoped_child_local_b))

	_check(
		"singleton from inherited child is the same instance as parent singleton",
		parent_singleton_a != null
			and parent_singleton_b != null
			and parent_singleton_a.get_instance_id() == parent_singleton_b.get_instance_id()
	)
	_check(
		"transient from inherited child creates a new instance on each resolve",
		inherited_transient_a != null
			and inherited_transient_b != null
			and inherited_transient_a.get_instance_id() != inherited_transient_b.get_instance_id()
	)
	_check(
		"scoped child inherits parent singleton through container chain",
		parent_singleton_a != null
			and scoped_child_parent_singleton != null
			and parent_singleton_a.get_instance_id() == scoped_child_parent_singleton.get_instance_id()
	)
	_check(
		"scoped child local singleton returns the same instance",
		scoped_child_local_a != null
			and scoped_child_local_b != null
			and scoped_child_local_a.get_instance_id() == scoped_child_local_b.get_instance_id()
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
