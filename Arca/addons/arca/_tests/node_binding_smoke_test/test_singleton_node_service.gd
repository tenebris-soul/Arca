extends Node

const TestNodeDependencyService = preload("res://addons/arca/_tests/node_binding_smoke_test/test_node_dependency_service.gd")

var dependency: RefCounted = null
var injected_with = null

func inject_dependencies(container) -> void:
	injected_with = container
	dependency = container.resolve(TestNodeDependencyService)
