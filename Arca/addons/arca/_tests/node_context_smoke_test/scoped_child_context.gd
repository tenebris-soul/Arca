extends ArcaNodeContext

const TestChildScopedService = preload("res://addons/arca/_tests/node_context_smoke_test/test_child_scoped_service.gd")

func _init() -> void:
	scope_mode = ArcaScopes.ScopeMode.SCOPED

func install(binder: ArcaBinder) -> void:
	binder.bind(TestChildScopedService).as_singleton()
