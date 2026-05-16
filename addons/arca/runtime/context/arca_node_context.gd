@abstract
extends Node
class_name ArcaNodeContext

const ScopeModes = ArcaScopeModes.ScopeMode

@export var scope_mode: ScopeModes = ScopeModes.SCOPED

@export_file("*.gd") var installers_path: Array[String] = []

var container: ArcaContainer = null
var _runner: ArcaLifecycleRunner = null
var _is_initialized: bool = false

func _enter_tree() -> void:
	_is_initialized = false
	_setup_container()

func _exit_tree() -> void:
	if container != null:
		container.dispose()

	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()

	_runner = null
	container = null

func _setup_container() -> void:
	var parent_container = _get_parent_container()
	var has_own_container: bool = false;

	match scope_mode:
		ScopeModes.INHERITED:
			container = parent_container
		ScopeModes.SCOPED:
			_runner = ArcaLifecycleRunner.new()
			_runner.name = "%sLifecycleRunner" % name
			add_child(_runner)

			container = ArcaContainer.new(_runner)
			has_own_container = true

	if has_own_container and not _is_initialized:
		_install_when_needed()
		_is_initialized = true

func _get_parent_container() -> ArcaContainer:
	var current_node = get_parent()
	while current_node != null:
		if current_node is ArcaNodeContext:
			var parent_context = current_node as ArcaNodeContext
			if parent_context.container != null:
				return parent_context.container

		if current_node == get_tree().root:
			return ArcaProjectContextNode.container

		current_node = current_node.get_parent()
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

		installer.install(container)
