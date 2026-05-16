extends RefCounted
class_name ArcaBindingBuilder

const Lifetimes = ArcaBindingLifetimes.Lifetime

var _container: ArcaContainer
var _binding: ArcaBinding
var _concrete: Script

var _lifetime_set: bool = false
var _non_lazy_set: bool = false
var _arguments_set: bool = false

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
	else:
		var default_factory = _make_default_factory()
		if default_factory.is_valid():
			_binding.set_factory(default_factory)

	_lifetime_set = true

	return self

func as_transient(factory: Callable = Callable()) -> ArcaBindingBuilder:
	if _lifetime_set:
		push_error("ArcaBindingBuilder: Lifetime cycle is already set!")
		return self

	_binding.set_lifetime(Lifetimes.TRANSIENT)
	
	if factory.is_valid():
		_binding.set_factory(factory)
	else:
		var default_factory = _make_default_factory()
		if default_factory.is_valid():
			_binding.set_factory(default_factory)

	_lifetime_set = true

	return self

func non_lazy() -> ArcaBindingBuilder:
	if _non_lazy_set:
		push_error("ArcaBindingBuilder: NonLazy is already set!")
		return self

	_container.resolve(_concrete)
	return self

func with_arguments(...args) -> ArcaBindingBuilder:
	if _arguments_set:
		push_error("ArcaBindingBuilder: Arguments are already set!")
		return self
	
	_binding.set_args(args)
	_arguments_set = true
	return self
	
### helpers
func _make_default_factory() -> Callable:
	if not _arguments_set:
		return Callable()

	return func():
		return _concrete.new.callv(_binding._args)