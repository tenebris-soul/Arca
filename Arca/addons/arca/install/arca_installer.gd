@abstract
class_name ArcaInstaller
extends RefCounted

const ArcaBinder = preload("res://addons/arca/core/arca_binder.gd")

@abstract func install(binder: ArcaBinder) -> void