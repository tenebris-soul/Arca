@abstract 
class_name ArcaNodeContext
extends Node

const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")
const ArcaScopes = preload("res://addons/arca/context/arca_scope_modes.gd")
const ArcaBinder = preload("res://addons/arca/core/arca_binder.gd")

@export var scope_mode: ArcaScopes.ScopeMode = ArcaScopes.ScopeMode.INHERITED

var _container: ArcaContainer = null
var _is_initialized: bool = false

func _enter_tree() -> void:
    _setup_container()

func _setup_container() -> void:
    var parent_container = _get_parent_container()
    var has_own_container: bool = false;

    match scope_mode:
        ArcaScopes.ScopeMode.INHERITED:
            _container = parent_container
        ArcaScopes.ScopeMode.SCOPED:
            _container = ArcaContainer.new(parent_container, self)
            has_own_container = true

    if has_own_container and not _is_initialized:
        _install_when_needed()
        _is_initialized = true

func _install_when_needed() -> void:
    match scope_mode:
        ArcaScopes.ScopeMode.INHERITED:
            if _overrides_install():
                push_warning("ArcaNodeContext: install() is overridden but scope mode is INHERITED, install() will not be called. Consider changing scope mode to SCOPED.")

        ArcaScopes.ScopeMode.SCOPED:
            var binder = ArcaBinder.new(_container)
            install(binder) 

func _get_parent_container() -> ArcaContainer:
    var current_node = get_parent()
    while current_node != null:
        if current_node is ArcaNodeContext:
            var parent_context = current_node as ArcaNodeContext
            if parent_context._container != null:
                return parent_context._container

        if current_node == get_tree().root:
            push_warning("ArcaNodeContext: reached scene root without finding a parent context with a container, returning global container")
            return ArcaProjectContext._container

        current_node = current_node.get_parent()
    return null

func _overrides_install() -> bool:
    var script := get_script() as Script
    if script == null:
        return false

    return (
        _script_defines_method(script, "install") and 
        _ancestor_defines_method(script, "install")
    )

func _script_defines_method(script: Script, method_name: StringName) -> bool:
    for method_info in script.get_script_method_list():
        if method_info["name"] == method_name:
            return true
    return false

func _ancestor_defines_method(script: Script, method_name: StringName) -> bool:
    var base_script = script.get_base_script()
    while base_script != null:
        if _script_defines_method(base_script, method_name):
            return true
        base_script = base_script.get_base_script()
    return false

func install(binder: ArcaBinder) -> void:
    pass