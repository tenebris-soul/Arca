extends RefCounted

const LIFETIME = ArcaLifetimes.Lifetime;
const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")

var key: Variant
var provider: Variant
var lifetime: LIFETIME = LIFETIME.SINGLETON

var _container: ArcaContainer

var _cached_instance: Variant = null
var _has_cached_instance: bool = false

var _should_auto_inject: bool = true

func _init(p_key: Variant, 
           p_provider: Variant, 
           p_container: ArcaContainer,
           p_lifetime: LIFETIME = LIFETIME.SINGLETON,
           p_should_auto_inject: bool = false) -> void:
    key = p_key
    provider = p_provider
    lifetime = p_lifetime
    _container = p_container
    _should_auto_inject = p_should_auto_inject

func get_instance() -> Variant:
    match lifetime:
        LIFETIME.SINGLETON:
            if _has_cached_instance:
                return _cached_instance

            _cached_instance = _provide()
            _has_cached_instance = true
            return _cached_instance
        
        LIFETIME.TRANSIENT:
            return _provide()

        _:
            push_error("ArcaBinding: unknown lifetime '%s' for key '%s'" % [lifetime, str(key)])
            return null;
        
func _provide() -> Variant:
    var value: Variant

    if provider is Callable:
        value = provider.call()
    else:
        value = provider

    if _should_auto_inject:
        _inject_if_needed(value)

    if value is Node:
        _attach_node_if_needed(value)

    return value

func _inject_if_needed(value: Variant) -> void:
    if value is Object and value.has_method("inject_dependencies"):
        value.inject_dependencies(_container)

func _attach_node_if_needed(node: Node) -> void:
    if node.get_parent() != null:
        return

    if _container.host_node == null:
        push_error("ArcaBinding: cannot auto-attach node '%s' to container because container has no host node" % str(node))
        return

    _container.host_node.add_child(node)