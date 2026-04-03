extends Node

const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")
const ArcaBinder = preload("res://addons/arca/core/arca_binder.gd")
const ArcaInstaller = preload("res://addons/arca/install/arca_installer.gd")

const INSTALLERS_SETTING := "arca/project/global_installers"

var _container: ArcaContainer

func _enter_tree() -> void:
	_container = ArcaContainer.new(null, self)
	_run_installers()

func _run_installers() -> void:
	var binder = ArcaBinder.new(_container)
	var installer_paths: Array = ProjectSettings.get_setting(INSTALLERS_SETTING, [])

	for path in installer_paths:
		if not _is_valid_installer_path(path):
			continue

		var installer_script = load(path) as Script
		var installer = installer_script.new() as ArcaInstaller

		installer.install(binder)

func _is_valid_installer_path(path: String) -> bool:
	var script := load(path) as Script
	if script == null:
		push_error("ArcaProjectContext: invalid path for installer '%s'" % path)
		return false

	if not script.can_instantiate():
		push_error("ArcaProjectContext: script can not be instantiated")
		return false

	var instance = script.new()
	var is_installer = instance is ArcaInstaller

	if not is_installer:
		push_error("ArcaProjectContext: script is not an installer")
		return false

	return true
