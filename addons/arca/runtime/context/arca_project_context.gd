extends Node
class_name ArcaProjectContext

const INSTALLERS_SETTING := "arca/project/global_installers"

var container: ArcaContainer

var _is_initialized: bool = false

func _init() -> void:
	var runner = ArcaLifecycleRunner.new()
	runner.name = "ProjectLifecycleRunner"
	add_child(runner)

	container = ArcaContainer.new(runner)

func _exit_tree() -> void:
	if container != null:
		container.dispose()

func _enter_tree() -> void:
	if not _is_initialized:
		_install_global_installers()
		_is_initialized = true

func _install_global_installers() -> void:
	var installer_paths: Array = ProjectSettings.get_setting(INSTALLERS_SETTING, [])

	for installer_path in installer_paths:
		var script = load(installer_path)
		if script == null:
			push_error("ArcaProjectContext: Failed to load global installer: %s" % installer_path)
			continue

		var installer = script.new()
		if not installer is ArcaInstaller:
			push_error("ArcaProjectContext: Global installer must extend ArcaInstaller: %s" % installer_path)
			continue

		installer.install(container, self)
