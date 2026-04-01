extends RefCounted

const TestDependencyService = preload("res://addons/arca/_tests/auto_inject_smoke_test/test_dependency_service.gd")

var dependency: RefCounted = null
var injected_with = null

func inject_dependencies(container) -> void:
	injected_with = container
	dependency = container.resolve(TestDependencyService)
