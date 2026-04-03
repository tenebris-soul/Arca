extends RefCounted

const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")
const ArcaBinding = preload("res://addons/arca/core/arca_binding.gd")

const LIFETIME = ArcaLifetimes.Lifetime;

var host_node: Node

var parent: ArcaContainer = null
var _bindings: Dictionary = {}

func _init(p_parent: ArcaContainer = null, p_host_node: Node = null) -> void:
	parent = p_parent
	host_node = p_host_node

func bind_self(
	concrete: Variant,
	lifetime: LIFETIME = LIFETIME.SINGLETON
) -> void:
	var script := _as_script(concrete)
	if script == null:
		push_error("ArcaContainer: bind_self() expects a script/class reference")
		return

	bind_factory(
		concrete,
		func() -> Variant:
			return script.new(),
		lifetime
	)

func bind_instance(
	concrete: Variant,
	instance: Object
) -> void:
	var concrete_script := _as_script(concrete)
	if concrete_script == null:
		push_error("ArcaContainer: bind_instance() expects a script/class reference")
		return

	var instance_script := _as_script(instance)
	if instance_script == null:
		push_error("ArcaContainer: bind_instance() expects an object with an attached script")
		return

	if concrete_script != instance_script:
		push_error("ArcaContainer: bind_instance() expects the instance's script to match the concrete script")
		return

	_register_binding(
		concrete,
		ArcaBinding.new(concrete_script, instance, self, LIFETIME.SINGLETON, false)
	)

func bind_factory(
	concrete: Variant,
	factory: Callable,
	lifetime: LIFETIME = LIFETIME.TRANSIENT
) -> void:
	var script = _as_script(concrete)
	if script == null:
		push_error("ArcaContainer: bind_factory() expects a script/class reference")
		return

	if not factory.is_valid():
		push_error("ArcaContainer: invalid factory for '%s'" % str(script))
		return

	_register_binding(
		script,
		ArcaBinding.new(script, factory, self, lifetime, true)
	)
	
func resolve(concrete: Variant) -> Variant:
	var script := _as_script(concrete)
	if script == null:
		push_error("ArcaContainer: resolve() expects a script/class reference")
		return null

	var binding := _find_binding(script)
	if binding == null:
		push_error("ArcaContainer: binding not found for '%s'" % str(script))
		return null

	return binding.get_instance()

func _register_binding(key: Variant, binding: ArcaBinding) -> void:
	if _bindings.has(key):
		push_error("ArcaContainer: binding already exists for '%s'" % str(key))
		return

	_bindings[key] = binding

func _find_binding(key: Variant) -> ArcaBinding:
	if _bindings.has(key):
		return _bindings[key]

	if parent != null:
		return parent._find_binding(key)

	return null

func _as_script(value: Variant) -> Script:
	if value is Script:
		return value
	
	if value is Object:
		return value.get_script()

	return null
