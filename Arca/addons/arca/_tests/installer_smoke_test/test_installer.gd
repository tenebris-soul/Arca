extends ArcaInstaller

const TestSingletonService = preload("res://addons/arca/_tests/installer_smoke_test/test_singleton_service.gd")
const TestTransientService = preload("res://addons/arca/_tests/installer_smoke_test/test_transient_service.gd")

func install(binder: ArcaBinder) -> void:
	binder.bind(TestSingletonService).as_singleton()
	binder.bind(TestTransientService).as_transient()
