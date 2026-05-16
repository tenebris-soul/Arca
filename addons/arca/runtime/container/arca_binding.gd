extends RefCounted
class_name ArcaBinding

const Lifetimes = ArcaBindingLifetimes.Lifetime

var _concrete: Script
var _factory: Callable
var _lifetime: Lifetimes
var _instance: Variant
var _has_cached_instance := false

func set_concrete(concrete: Script) -> void:
    _concrete = concrete

func set_lifetime(lifetime: Lifetimes) -> void:
    _lifetime = lifetime

func set_factory(factory: Callable) -> void:
    _factory = factory
                
func get_instance(container: ArcaContainer) -> Variant:
    match _lifetime:
        Lifetimes.SINGLETON:
            if _has_cached_instance:
                return _instance

            _instance = _create(container)
            _has_cached_instance = true
            return _instance
        Lifetimes.TRANSIENT:
            return _create(container)
        _:
            return null
            
func _create(container: ArcaContainer) -> Variant:
    if _factory.is_valid():
        var args_count := _factory.get_argument_count()

        if args_count == 0:
            return _factory.call()

        if args_count == 1:
            return _factory.call(container)

        push_error("ArcaBinding: Factory must accept 0 or 1 argument.")
        return null

    return container.instantiate(_concrete)
