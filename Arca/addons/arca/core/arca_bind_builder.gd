extends RefCounted

const ArcaLifetimes = preload("res://addons/arca/core/arca_binding_lifetimes.gd")
const ArcaBindBuilder = preload("res://addons/arca/core/arca_bind_builder.gd")
const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")

enum SourceKind {
    SELF,
    FACTORY,
    INSTANCE
}

var _container: ArcaContainer = null
var _concrete: Variant = null

var _source_kind: SourceKind = SourceKind.SELF
var _factory: Callable = Callable()
var _instance: Object = null

func _init(container: ArcaContainer, concrete: Variant) -> void:
    _container = container
    _concrete = concrete

func from_factory(factory: Callable) -> ArcaBindBuilder:
    _source_kind = SourceKind.FACTORY
    _factory = factory
    return self

func from_instance(instance: Object) -> ArcaBindBuilder:
    _source_kind = SourceKind.INSTANCE
    _instance = instance
    return self

func as_singleton() -> void:
    match _source_kind:
        SourceKind.SELF:
            _container.bind_self(_concrete)

        SourceKind.FACTORY:
            _container.bind_factory(_concrete, _factory, ArcaLifetimes.Lifetime.SINGLETON)

        SourceKind.INSTANCE:
            _container.bind_instance(_concrete, _instance)

func as_transient() -> void:
    match _source_kind:
        SourceKind.SELF:
            _container.bind_self(_concrete, ArcaLifetimes.Lifetime.TRANSIENT)

        SourceKind.FACTORY:
            _container.bind_factory(_concrete, _factory, ArcaLifetimes.Lifetime.TRANSIENT)

        SourceKind.INSTANCE:
            push_error("ArcaBindBuilder: cannot bind an instance with transient lifetime")