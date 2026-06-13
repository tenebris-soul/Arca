@abstract
extends Node
class_name ArcaNodeContext

const ScopeModes = ArcaScopeModes.ScopeMode

@export var scope_mode: ScopeModes = ScopeModes.SCOPED

@export_file("*.gd") var installers_path: Array[String] = []

var container: ArcaContainer = null
var parent_context: Node = null
var _runner: ArcaLifecycleRunner = null
var _is_initialized: bool = false
var _owns_container: bool = false

func _enter_tree() -> void:
	_is_initialized = false
	_setup_container()

func _exit_tree() -> void:
	if _owns_container and container != null:
		container.dispose()

	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()

	_runner = null
	container = null
	parent_context = null
	_owns_container = false

func _setup_container() -> void:
	parent_context = _get_parent_context()
	var parent_container = _get_context_container(parent_context)
	_owns_container = false

	match scope_mode:
		ScopeModes.INHERITED:
			container = parent_container
			_owns_container = false
		ScopeModes.SCOPED:
			_runner = ArcaLifecycleRunner.new()
			_runner.name = "%sLifecycleRunner" % name
			add_child(_runner)

			container = ArcaContainer.new(_runner, parent_container)
			_owns_container = true

	if container != null and not _is_initialized:
		_install_when_needed()
		_is_initialized = true

func _get_parent_context() -> Node:
	var current_node = get_parent()
	while current_node != null:
		if current_node is ArcaNodeContext:
			return current_node

		if current_node == get_tree().root:
			return ArcaProjectContextNode

		current_node = current_node.get_parent()
	return null

func _get_context_container(context: Node) -> ArcaContainer:
	if context is ArcaNodeContext:
		return (context as ArcaNodeContext).container

	if context is ArcaProjectContext:
		return (context as ArcaProjectContext).container

	return null

func _install_when_needed() -> void:
	for path in installers_path:
		var script := load(path) as Script
		if script == null:
			push_error("ArcaNodeContext: Failed to load installer: %s" % path)
			continue

		var installer := script.new() as ArcaInstaller
		if installer == null:
			push_error("ArcaNodeContext: Installer must extend ArcaInstaller: %s" % path)
			continue

		installer.install(container, self)
