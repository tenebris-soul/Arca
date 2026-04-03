extends Node2D

const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")
const ArcaLifetimes = preload("res://addons/arca/core/arca_binding_lifetimes.gd")

var _failed_checks: int = 0


class SingletonService:
	extends RefCounted

	var created_at_usec: int = Time.get_ticks_usec()


class TransientService:
	extends RefCounted

	var created_at_usec: int = Time.get_ticks_usec()


func _ready() -> void:
	print("")
	print("=== ArcaContainer Smoke Test ===")

	var container = ArcaContainer.new()

	container.bind_self(SingletonService)
	container.bind_factory(
		TransientService,
		func() -> Variant:
			return TransientService.new(),
		ArcaLifetimes.Lifetime.TRANSIENT
	)

	var singleton_a: SingletonService = container.resolve(SingletonService)
	var singleton_b: SingletonService = container.resolve(SingletonService)
	var transient_a: TransientService = container.resolve(TransientService)
	var transient_b: TransientService = container.resolve(TransientService)

	print("singleton_a id: ", singleton_a.get_instance_id())
	print("singleton_b id: ", singleton_b.get_instance_id())
	print("transient_a id: ", transient_a.get_instance_id())
	print("transient_b id: ", transient_b.get_instance_id())

	_check("bind_self returns a SingletonService", singleton_a is SingletonService)
	_check(
		"bind_self uses singleton lifetime by default",
		singleton_a.get_instance_id() == singleton_b.get_instance_id()
	)
	_check("bind_factory returns a TransientService", transient_a is TransientService)
	_check(
		"transient factory returns a new instance on each resolve",
		transient_a.get_instance_id() != transient_b.get_instance_id()
	)

	if _failed_checks == 0:
		print("[RESULT] all checks passed")
	else:
		push_error("[RESULT] %d check(s) failed" % _failed_checks)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[PASS] ", label)
		return

	_failed_checks += 1
	push_error("[FAIL] %s" % label)
