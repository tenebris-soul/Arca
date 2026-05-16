extends RefCounted
class_name ArcaBindingBuilder

const Lifetimes = ArcaBindingLifetimes.Lifetime

var _container: ArcaContainer
var _binding: ArcaBinding
var _concrete: Script

var _lifetime_set: bool = false

func _init(container: ArcaContainer, binding: ArcaBinding, concrete: Script) -> void:
	_container = container
	_binding = binding
	_concrete = concrete
	_binding.set_concrete(concrete)


func as_single(factory: Callable = Callable()) -> ArcaBindingBuilder:
	if _lifetime_set:
		push_error("ArcaBindingBuilder: Lifetime cycle is already set!")
		return self

	_binding.set_lifetime(Lifetimes.SINGLETON)
	if factory.is_valid():
		_binding.set_factory(factory)

	_lifetime_set = true

	return self

func as_transient(factory: Callable = Callable()) -> ArcaBindingBuilder:
	if _lifetime_set:
		push_error("ArcaBindingBuilder: Lifetime cycle is already set!")
		return self

	_binding.set_lifetime(Lifetimes.TRANSIENT)
	if factory.is_valid():
		_binding.set_factory(factory)

	_lifetime_set = true

	return self
