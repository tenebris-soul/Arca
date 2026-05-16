extends Node
class_name ArcaLifecycleRunner

var _tickable: Array[Object] = []
var _physics_tickable: Array[Object] = []

func add(item: Object) -> void:
	if item == null:
		return

	if item.has_method("tick"):
		_add_unique(_tickable, item)

	if item.has_method("physics_tick"):
		_add_unique(_physics_tickable, item)

func remove(item: Object) -> void:
	_tickable.erase(item)
	_physics_tickable.erase(item)

func _process(delta: float) -> void:
	_run_tick(_tickable, "tick", delta)

func _physics_process(delta: float) -> void:
	_run_tick(_physics_tickable, "physics_tick", delta)

func _run_tick(items: Array[Object], method: StringName, delta: float) -> void:
	for item in items.duplicate():
		if not is_instance_valid(item):
			items.erase(item)
			continue

		item.call(method, delta)

func _add_unique(items: Array[Object], item: Object) -> void:
	if not items.has(item):
		items.append(item)
