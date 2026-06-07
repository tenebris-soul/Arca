extends RefCounted
class_name ArcaContainer

const Lifetimes = ArcaBindingLifetimes.Lifetime

var _container: Dictionary[Script, ArcaBinding] = {}
var _instances: Array[Object] = []

var _resolve_stack: Array[Script] = []

var _runner: ArcaLifecycleRunner
var _parent: ArcaContainer

func _init(runner: ArcaLifecycleRunner = null, parent: ArcaContainer = null) -> void:
	_runner = runner
	_parent = parent

func bind(concrete: Script) -> ArcaBindingBuilder:
	var binding = ArcaBinding.new()
	_container[concrete] = binding

	return ArcaBindingBuilder.new(self, binding, concrete)

func resolve(concrete: Script) -> Variant:
	if _resolve_stack.has(concrete):
		push_error("ArcaContainer: Circular dependency detected: %s" % _format_resolve_stack(concrete))
		return null

	var binding = _container.get(concrete)
	if binding == null:
		if _parent != null:
			return _parent.resolve(concrete)

		push_error("ArcaContainer: Type is not bound: %s" % concrete)
		return null

	_resolve_stack.append(concrete)
	var instance = binding.get_instance(self)
	_resolve_stack.erase(concrete)

	if instance != null:
		if _runner != null:
			_runner.add(instance)

		if instance is Object and not _instances.has(instance):
			_instances.append(instance)

	return instance

func instantiate(concrete: Script, extra_args: Array) -> Variant:
	var deps := []

	if concrete.has_method("get_dependencies"):
		for dep in concrete.get_dependencies():
			deps.append(resolve(dep))

	return concrete.new.callv(deps + extra_args)

func dispose() -> void:
	for instance in _instances.duplicate():
		if not is_instance_valid(instance):
			continue

		if instance.has_method("dispose"):
			instance.dispose()

		if _runner != null:
			_runner.remove(instance)

	_instances.clear()

func inject(instance: Object, extra_args: Array = []) -> Object:
	if instance == null:
		push_error("ArcaContainer: Cannot inject null instance.")
		return null

	var script := instance.get_script()
	if script == null:
		push_error("ArcaContainer: Cannot inject object without script.")
		return instance

	var deps := []

	if script.has_method("get_inject_dependencies"):
		for dep in script.get_inject_dependencies():
			deps.append(resolve(dep))

	if instance.has_method("inject_dependencies"):
		instance.callv("inject_dependencies", deps + extra_args)
	elif deps.size() > 0:
		push_error("ArcaContainer: Object has inject dependencies, but no inject_dependencies() method.")

	if _runner != null:
		_runner.add(instance)

	if not _instances.has(instance):
		_instances.append(instance)

	return instance

### helpers
func _format_resolve_stack(repeated: Script) -> String:
	var names: PackedStringArray = []

	for script in _resolve_stack:
		names.append(_get_script_name(script))

	names.append(_get_script_name(repeated))
	return " -> ".join(names)

func _get_script_name(script: Script) -> String:
	if script.get_global_name() != "":
		return script.get_global_name()

	return script.resource_path
