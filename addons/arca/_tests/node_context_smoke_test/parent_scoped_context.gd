extends ArcaNodeContext

const TestParentSingletonService = preload("res://addons/arca/_tests/node_context_smoke_test/test_parent_singleton_service.gd")
const TestParentTransientService = preload("res://addons/arca/_tests/node_context_smoke_test/test_parent_transient_service.gd")

func _init() -> void:
	scope_mode = ArcaScopes.ScopeMode.SCOPED

func install(binder: ArcaBinder) -> void:
	binder.bind(TestParentSingletonService).as_singleton()
	binder.bind(TestParentTransientService).as_transient()
