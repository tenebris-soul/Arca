extends Node
class_name ArcaLifecycleRunner

var _tickable: Array[Object] = []
var _physics_tickable: Array[Object] = []
var _unhandled_input_receivers: Array[Object] = []
var _input_receivers: Array[Object] = []
var _shortcut_input_receivers: Array[Object] = []
var _unhandled_key_input_receivers: Array[Object] = []

func add(item: Object) -> void:
	if item == null:
		return

	if item.has_method("tick"):
		_add_unique(_tickable, item)

	if item.has_method("physics_tick"):
		_add_unique(_physics_tickable, item)

	if item.has_method("input"):
		_add_unique(_input_receivers, item)

	if item.has_method("unhandled_input"):
		_add_unique(_unhandled_input_receivers, item)

	if item.has_method("shortcut_input"):
		_add_unique(_shortcut_input_receivers, item)

	if item.has_method("unhandled_key_input"):
		_add_unique(_unhandled_key_input_receivers, item)

func remove(item: Object) -> void:
	_tickable.erase(item)
	_physics_tickable.erase(item)
	_input_receivers.erase(item)
	_unhandled_input_receivers.erase(item)
	_shortcut_input_receivers.erase(item)
	_unhandled_key_input_receivers.erase(item)

func _process(delta: float) -> void:
	_run_tick(_tickable, "tick", delta)

func _physics_process(delta: float) -> void:
	_run_tick(_physics_tickable, "physics_tick", delta)

func _unhandled_input(event: InputEvent) -> void:
	for receiver in _unhandled_input_receivers.duplicate():
		if not is_instance_valid(receiver):
			_unhandled_input_receivers.erase(receiver)
			continue
		
		receiver.unhandled_input(event)

func _input(event: InputEvent) -> void:
	for receiver in _input_receivers.duplicate():
		if not is_instance_valid(receiver):
			_input_receivers.erase(receiver)
			continue
		
		receiver.input(event)

func _shortcut_input(event: InputEvent) -> void:
	for receiver in _shortcut_input_receivers.duplicate():
		if not is_instance_valid(receiver):
			_shortcut_input_receivers.erase(receiver)
			continue
		
		receiver.shortcut_input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	for receiver in _unhandled_key_input_receivers.duplicate():
		if not is_instance_valid(receiver):
			_unhandled_key_input_receivers.erase(receiver)
			continue
		
		receiver.unhandled_key_input(event)

func _run_tick(items: Array[Object], method: StringName, delta: float) -> void:
	for item in items.duplicate():
		if not is_instance_valid(item):
			items.erase(item)
			continue

		item.call(method, delta)

func _add_unique(items: Array[Object], item: Object) -> void:
	if not items.has(item):
		items.append(item)
