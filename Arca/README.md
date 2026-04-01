# Arca

Русский: [README на русском](#русский)

English: [README in English](#english)

## Русский

Arca — это DI-container для Godot-проектов с двумя уровнями контекста:

- `ArcaProjectContext` — глобальный контейнер на всю игру.
- `ArcaNodeContext` — локальный контейнер для конкретной ноды и ее поддерева.

Текущая версия ориентирована на self-binding по concrete-типу. Ключом выступает сам script/class, а не строка.

### Возможности

- Глобальные зависимости через `ArcaProjectContext`.
- Локальные зависимости через `ArcaNodeContext`.
- `bind(...).as_singleton()`
- `bind(...).as_transient()`
- `bind(...).from_factory(...).as_singleton()`
- `bind(...).from_factory(...).as_transient()`
- `bind(...).from_instance(...).as_singleton()`
- Автоинжект через `inject_dependencies(container)` для `bind_self` и `from_factory`.
- Поддержка `RefCounted`-сервисов и `Node`-объектов.
- Автоматический `add_child()` для зарегистрированных `Node`, если контейнер создал их сам.

### Установка

1. Скопируйте `addons/arca` в свой проект.
2. Включите плагин `Arca` в `Project > Project Settings > Plugins`.
3. После включения плагин:
   - создаст autoload `ArcaProjectContext`
   - зарегистрирует project setting `arca/project/global_installers`

### Глобальные installer-ы

Глобальные зависимости регистрируются через installer-скрипты, перечисленные в:

```text
Project Settings > General > arca/project/global_installers
```

Это массив путей до `.gd`-скриптов.

Пример:

```gdscript
[
	"res://di/core_installer.gd",
	"res://di/game_installer.gd"
]
```

### Создание installer-а

```gdscript
extends ArcaInstaller

const SaveService = preload("res://di/save_service.gd")
const RandomService = preload("res://di/random_service.gd")

func install(binder) -> void:
	binder.bind(SaveService).as_singleton()
	binder.bind(RandomService).as_transient()
```

### Резолв зависимостей

Сейчас резолв идет через контейнер контекста.

Глобальный резолв:

```gdscript
var save_service = ArcaProjectContext._container.resolve(SaveService)
```

Резолв внутри `ArcaNodeContext`:

```gdscript
var save_service = _container.resolve(SaveService)
```

### Виды bind

#### 1. Self binding

```gdscript
binder.bind(SaveService).as_singleton()
binder.bind(BulletService).as_transient()
```

#### 2. Factory binding

```gdscript
binder.bind(RandomService).from_factory(
	func():
		return RandomService.new()
).as_transient()
```

#### 3. Instance binding

```gdscript
var save_service = SaveService.new()
binder.bind(SaveService).from_instance(save_service).as_singleton()
```

`from_instance()` регистрирует уже готовый объект и не использует автоинжект.

### Автоинжект

Если объект реализует метод:

```gdscript
func inject_dependencies(container) -> void:
	pass
```

то Arca вызовет его автоматически для:

- `bind(...).as_singleton()`
- `bind(...).as_transient()`
- `bind(...).from_factory(...).as_singleton()`
- `bind(...).from_factory(...).as_transient()`

Пример:

```gdscript
extends RefCounted
class_name EnemyService

const SaveService = preload("res://di/save_service.gd")
const AudioService = preload("res://di/audio_service.gd")

var save_service
var audio_service

func inject_dependencies(container) -> void:
	save_service = container.resolve(SaveService)
	audio_service = container.resolve(AudioService)
```

Теперь можно писать просто:

```gdscript
binder.bind(EnemyService).as_singleton()
```

или:

```gdscript
binder.bind(EnemyService).from_factory(
	func():
		return EnemyService.new()
).as_transient()
```

и не вызывать `inject_dependencies()` вручную внутри фабрики.

### Node binding

Arca умеет регистрировать не только сервисы, но и `Node`.

Если контейнер сам создает `Node`, то Arca:

1. создает объект
2. вызывает `inject_dependencies(container)`, если метод существует
3. автоматически добавляет ноду в `host_node` контейнера

Для `ArcaProjectContext` host-node — сам `ArcaProjectContext`.

Для `ArcaNodeContext` host-node — сам этот `NodeContext`.

Пример:

```gdscript
extends Node
class_name HudRoot

const SaveService = preload("res://di/save_service.gd")

var save_service

func inject_dependencies(container) -> void:
	save_service = container.resolve(SaveService)
```

Регистрация:

```gdscript
binder.bind(HudRoot).as_singleton()
```

Если вам нужна нода из `.tscn`, используйте factory:

```gdscript
const HudScene = preload("res://ui/hud_root.tscn")
const HudRoot = preload("res://ui/hud_root.gd")

func install(binder) -> void:
	binder.bind(HudRoot).from_factory(
		func():
			return HudScene.instantiate()
	).as_singleton()
```

Если нода уже существует в дереве, регистрируйте ее как instance:

```gdscript
binder.bind(PlayerNode).from_instance($Player).as_singleton()
```

### NodeContext

`ArcaNodeContext` нужен для локальных scope-ов в дереве нод.

Сейчас доступны два режима:

- `INHERITED` — собственного контейнера нет, используется ближайший родительский context.
- `SCOPED` — создается собственный контейнер, parent = ближайший родительский context.

Режим задается через экспортируемое поле `scope_mode` в Inspector.

#### Пример scoped context

```gdscript
extends ArcaNodeContext

const EnemyService = preload("res://game/enemy_service.gd")

func install(binder) -> void:
	binder.bind(EnemyService).as_singleton()
```

После этого укажите `scope_mode = SCOPED` в Inspector.

#### Пример inherited context

```gdscript
extends ArcaNodeContext
```

По умолчанию `scope_mode` уже равен `INHERITED`, поэтому для inherited-контекста ничего дополнительно настраивать не нужно.

Важно:

- локальные bind-ы вызываются только для `SCOPED`
- если вы переопределили `install(...)`, но оставили `INHERITED`, Arca выдаст warning

### Текущее ограничение API

- Binding идет по concrete script/class, а не по интерфейсу.
- Constructor injection в `_init(...)` не используется.
- Автоинжект работает через `inject_dependencies(container)`.
- `from_instance()` не делает автоинжект.
- `ISOLATED` пока не включен.

### Рекомендуемый стиль использования

- Регистрируйте глобальные зависимости через `ArcaInstaller`.
- Для локальных scope-ов используйте `ArcaNodeContext`.
- Для обычных сервисов предпочитайте `RefCounted`.
- Для уже существующих нод используйте `from_instance(...)`.
- Для prefab/scene-ноды используйте `from_factory(...instantiate())`.

---

## English

Arca is a DI container for Godot projects with two context levels:

- `ArcaProjectContext` — a global container for the whole game.
- `ArcaNodeContext` — a local container for a specific node and its subtree.

The current version is focused on self-binding by concrete script/class. The binding key is the script itself, not a string.

### Features

- Global dependencies via `ArcaProjectContext`
- Local dependencies via `ArcaNodeContext`
- `bind(...).as_singleton()`
- `bind(...).as_transient()`
- `bind(...).from_factory(...).as_singleton()`
- `bind(...).from_factory(...).as_transient()`
- `bind(...).from_instance(...).as_singleton()`
- Automatic injection via `inject_dependencies(container)` for `bind_self` and `from_factory`
- Support for both `RefCounted` services and `Node` objects
- Automatic `add_child()` for `Node` instances created by the container

### Installation

1. Copy `addons/arca` into your project.
2. Enable the `Arca` plugin in `Project > Project Settings > Plugins`.
3. Once enabled, the plugin will:
   - create the `ArcaProjectContext` autoload
   - register the `arca/project/global_installers` project setting

### Global installers

Global dependencies are registered through installer scripts listed in:

```text
Project Settings > General > arca/project/global_installers
```

This setting is an array of `.gd` script paths.

Example:

```gdscript
[
	"res://di/core_installer.gd",
	"res://di/game_installer.gd"
]
```

### Creating an installer

```gdscript
extends ArcaInstaller

const SaveService = preload("res://di/save_service.gd")
const RandomService = preload("res://di/random_service.gd")

func install(binder) -> void:
	binder.bind(SaveService).as_singleton()
	binder.bind(RandomService).as_transient()
```

### Resolving dependencies

At the moment, resolving goes through the context container.

Global resolve:

```gdscript
var save_service = ArcaProjectContext._container.resolve(SaveService)
```

Resolve inside `ArcaNodeContext`:

```gdscript
var save_service = _container.resolve(SaveService)
```

### Binding styles

#### 1. Self binding

```gdscript
binder.bind(SaveService).as_singleton()
binder.bind(BulletService).as_transient()
```

#### 2. Factory binding

```gdscript
binder.bind(RandomService).from_factory(
	func():
		return RandomService.new()
).as_transient()
```

#### 3. Instance binding

```gdscript
var save_service = SaveService.new()
binder.bind(SaveService).from_instance(save_service).as_singleton()
```

`from_instance()` registers an already created object and does not use auto injection.

### Auto injection

If an object implements:

```gdscript
func inject_dependencies(container) -> void:
	pass
```

Arca will call it automatically for:

- `bind(...).as_singleton()`
- `bind(...).as_transient()`
- `bind(...).from_factory(...).as_singleton()`
- `bind(...).from_factory(...).as_transient()`

Example:

```gdscript
extends RefCounted
class_name EnemyService

const SaveService = preload("res://di/save_service.gd")
const AudioService = preload("res://di/audio_service.gd")

var save_service
var audio_service

func inject_dependencies(container) -> void:
	save_service = container.resolve(SaveService)
	audio_service = container.resolve(AudioService)
```

Now you can simply write:

```gdscript
binder.bind(EnemyService).as_singleton()
```

or:

```gdscript
binder.bind(EnemyService).from_factory(
	func():
		return EnemyService.new()
).as_transient()
```

without manually calling `inject_dependencies()` inside the factory.

### Node binding

Arca can register not only services, but also `Node` objects.

If the container creates a `Node`, Arca will:

1. create the object
2. call `inject_dependencies(container)` if the method exists
3. automatically add the node to the container's `host_node`

For `ArcaProjectContext`, the host node is `ArcaProjectContext` itself.

For `ArcaNodeContext`, the host node is that context node itself.

Example:

```gdscript
extends Node
class_name HudRoot

const SaveService = preload("res://di/save_service.gd")

var save_service

func inject_dependencies(container) -> void:
	save_service = container.resolve(SaveService)
```

Registration:

```gdscript
binder.bind(HudRoot).as_singleton()
```

If you need a node from a `.tscn`, use a factory:

```gdscript
const HudScene = preload("res://ui/hud_root.tscn")
const HudRoot = preload("res://ui/hud_root.gd")

func install(binder) -> void:
	binder.bind(HudRoot).from_factory(
		func():
			return HudScene.instantiate()
	).as_singleton()
```

If the node already exists in the scene tree, register it as an instance:

```gdscript
binder.bind(PlayerNode).from_instance($Player).as_singleton()
```

### NodeContext

`ArcaNodeContext` is used for local scopes in the node tree.

Two modes are currently available:

- `INHERITED` — no local container; uses the nearest parent context.
- `SCOPED` — creates a local container with parent = nearest parent context.

The mode is selected through the exported `scope_mode` property in the Inspector.

#### Scoped context example

```gdscript
extends ArcaNodeContext

const EnemyService = preload("res://game/enemy_service.gd")

func install(binder) -> void:
	binder.bind(EnemyService).as_singleton()
```

Then set `scope_mode = SCOPED` in the Inspector.

#### Inherited context example

```gdscript
extends ArcaNodeContext
```

`scope_mode` defaults to `INHERITED`, so nothing extra is required for an inherited context.

Important:

- local bindings are only executed for `SCOPED`
- if you override `install(...)` but keep `INHERITED`, Arca will emit a warning

### Current API limitations

- Binding is based on concrete script/class, not interfaces.
- Constructor injection into `_init(...)` is not used.
- Auto injection works through `inject_dependencies(container)`.
- `from_instance()` does not auto inject.
- `ISOLATED` is not enabled yet.

### Recommended usage

- Register global dependencies through `ArcaInstaller`.
- Use `ArcaNodeContext` for local scopes.
- Prefer `RefCounted` for regular services.
- Use `from_instance(...)` for nodes that already exist.
- Use `from_factory(...instantiate())` for prefab/scene nodes.
