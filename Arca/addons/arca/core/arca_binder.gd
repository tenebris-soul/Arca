extends RefCounted

const ArcaContainer = preload("res://addons/arca/core/arca_container.gd")
const ArcaBindBuilder = preload("res://addons/arca/core/arca_bind_builder.gd")

var _container: ArcaContainer

func _init(container: ArcaContainer) -> void:
	_container = container

func bind(concrete: Variant) -> ArcaBindBuilder:
	return ArcaBindBuilder.new(_container, concrete)