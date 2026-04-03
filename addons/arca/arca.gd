@tool
extends EditorPlugin

const AUTOLOAD_PROJECT_CONTEXT_NAME: String = "ArcaProjectContext"
const AUTOLOAD_PROJECT_CONTEXT_PATH: String = "res://addons/arca/context/arca_project_context.gd"

const INSTALLERS_SETTING := "arca/project/global_installers"
const INSTALLERS_DEFAULT := []

func _enter_tree() -> void:
	_ensure_installers_setting()

func _enable_plugin() -> void:
	_ensure_installers_setting()

	if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_PROJECT_CONTEXT_NAME):
		add_autoload_singleton(AUTOLOAD_PROJECT_CONTEXT_NAME, AUTOLOAD_PROJECT_CONTEXT_PATH)


func _disable_plugin() -> void:
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_PROJECT_CONTEXT_NAME):
		remove_autoload_singleton(AUTOLOAD_PROJECT_CONTEXT_NAME)

func _ensure_installers_setting() -> void:
	var should_save: bool = false

	if not ProjectSettings.has_setting(INSTALLERS_SETTING):
		ProjectSettings.set_setting(INSTALLERS_SETTING, INSTALLERS_DEFAULT)
		ProjectSettings.set_initial_value(INSTALLERS_SETTING, INSTALLERS_DEFAULT)
		should_save = true

	ProjectSettings.add_property_info({
		"name": INSTALLERS_SETTING,
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:*.gd" % [TYPE_STRING, PROPERTY_HINT_FILE],
	})

	ProjectSettings.set_as_basic(INSTALLERS_SETTING, true)

	if should_save:
		ProjectSettings.save()
