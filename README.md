# Arca

[English](#english) · [Русский](#русский)

Arca is a lightweight dependency-injection addon for **Godot 4.6+**. It is inspired by Zenject, while keeping the workflow native to Godot: installers declare bindings, contexts define their lifetime, and the container resolves or injects objects.

**Current version:** 0.4.0<br>
**License:** [MIT](LICENSE.gnumeric)

---

<a id="english"></a>

## English

### What Arca provides

- Project-wide and scene-local containers.
- Singleton and transient bindings.
- Constructor dependency resolution through `get_dependencies()`.
- Injection into objects Godot has already created, such as nodes.
- Explicit factories, existing-instance bindings, and eager creation.
- Lifecycle forwarding for `tick`, `physics_tick`, input callbacks, and `dispose`.
- Circular-dependency detection and parent-container lookup.

### Installation

1. Copy `addons/arca` into your Godot project.
2. Enable **Arca** in **Project → Project Settings → Plugins**.
3. Enabling the plugin adds the `ArcaProjectContextNode` autoload and the project setting `arca/project/global_installers`.

> Keep the autoload enabled. It owns the project container and its lifecycle runner.

### Quick start

Create a service and declare its constructor dependencies explicitly:

```gdscript
# res://game/services/game_service.gd
extends RefCounted
class_name GameService

var save_service: SaveService

static func get_dependencies() -> Array:
	return [SaveService]

func _init(dependency: SaveService) -> void:
	save_service = dependency
```

Register it in an installer:

```gdscript
# res://game/installers/game_installer.gd
extends ArcaInstaller

const SaveService := preload("res://game/services/save_service.gd")
const GameService := preload("res://game/services/game_service.gd")

func install(container: ArcaContainer, _ctx) -> void:
	container.bind(SaveService).as_single()
	container.bind(GameService).as_single()
```

Add this installer script to **Project Settings → Arca → Project → Global Installers**, then resolve the service:

```gdscript
var game_service: GameService = ArcaProjectContextNode.container.resolve(GameService)
```

### Contexts and scopes

Every container belongs to a context. A child container searches its own bindings first, then its parent, all the way to the project container.

| Context | Container | Suitable for |
| --- | --- | --- |
| `ArcaProjectContextNode` | One project-wide container | save data, configuration, audio, global state |
| `ArcaNodeContext` with `SCOPED` | A new child container | a level, battle, menu, or other self-contained scene |
| `ArcaNodeContext` with `INHERITED` | The closest parent context's container | nested scenes that share their parent's scope |

To create a scene context, attach a script such as:

```gdscript
extends ArcaNodeContext
class_name BattleContext
```

On the node in the Inspector, set:

- **Scope Mode** to `SCOPED` or `INHERITED`;
- **Installers Path** to an array of installer scripts for that context.

`SCOPED` creates a container and a lifecycle runner. When the node leaves the scene tree, Arca disposes objects tracked by that container.

`INHERITED` creates neither: its installers add bindings directly to the inherited container. This is useful for a reusable child scene, but beware of duplicate bindings—binding the same script again replaces the earlier binding in that container.

If no parent `ArcaNodeContext` exists, an inherited context uses the project container.

### Installers

An installer is a script extending `ArcaInstaller`:

```gdscript
extends ArcaInstaller

func install(container: ArcaContainer, ctx) -> void:
	pass
```

Use global installers for app-lifetime bindings. Use **Installers Path** on an `ArcaNodeContext` for scene bindings. The `ctx` argument is the current context, so an installer may safely read its exported fields or node references:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var battle := ctx as BattleContext
	container.bind(EnemySpawner).as_single(func():
		return EnemySpawner.new(battle.spawn_points)
	)
```

### Binding and resolving

#### Lifetimes

```gdscript
container.bind(AudioService).as_single()
container.bind(BulletService).as_transient()
```

`as_single()` creates one instance on its first resolution and returns that instance thereafter. `as_transient()` creates a new instance for every `resolve()` call. Bindings are keyed by the exact script supplied to `bind`; a new binding for that script replaces the previous one.

Resolve from the appropriate context:

```gdscript
var audio = ArcaProjectContextNode.container.resolve(AudioService)
var battle_state = container.resolve(BattleState)
```

Resolving an unbound script reports an error and returns `null`.

#### Constructor dependencies

Arca does not infer `_init` parameters. List the scripts it must resolve, in constructor order:

```gdscript
extends RefCounted
class_name PlayerService

static func get_dependencies() -> Array:
	return [InventoryService, SaveService]

func _init(inventory: InventoryService, save: SaveService) -> void:
	pass
```

With a normal `as_single()` or `as_transient()` binding, resolving `PlayerService` is equivalent to resolving `InventoryService` and `SaveService` first, then calling `PlayerService.new(inventory, save)`.

Arca detects a cycle such as `A → B → A`, reports it, and returns `null` for the circular resolution.

#### `from_instance()`

Use an existing object instead of letting the container construct it:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var battle := ctx as BattleContext
	container.bind(PlayerCameraService).from_instance(battle.camera_service)
```

This always behaves as a singleton and returns the exact supplied object. A child-script instance may be bound under one of its base scripts. The instance must match the bound script; `null` and unrelated instances are rejected.

#### Factories

Use a factory when construction needs custom logic. A factory accepts either zero arguments or one `ArcaContainer` argument:

```gdscript
container.bind(ConfigService).as_single(func():
	return ConfigService.new("local")
)

container.bind(PlayerService).as_single(func(c: ArcaContainer):
	return PlayerService.new(
		c.resolve(InventoryService),
		c.resolve(SaveService)
	)
)
```

The factory owns construction: Arca does not invoke `get_dependencies()` for that binding.

#### `with_arguments(...)`

`with_arguments(...)` supplies constructor arguments directly:

```gdscript
container.bind(PlayerMotionService)\
	.with_arguments(camera, body)\
	.as_single()
```

In version 0.4.0, this calls `PlayerMotionService.new(camera, body)` directly. It does **not** combine these values with `get_dependencies()`. If a service needs both resolved dependencies and manual values, use a one-argument factory:

```gdscript
container.bind(PlayerMotionService).as_single(func(c: ArcaContainer):
	return PlayerMotionService.new(c.resolve(JoystickService), camera, body)
)
```

Call `with_arguments(...)` before setting the lifetime. It cannot be combined with `from_instance()`.

#### `non_lazy()`

Bindings are lazy by default. Add `non_lazy()` after the lifetime to resolve the service during installation:

```gdscript
container.bind(InputService).as_single().non_lazy()
```

This is useful for services that need immediate setup, signal subscriptions, or lifecycle callbacks from the start of the context.

### Injecting existing objects

Use `inject()` for scene nodes and other objects that already exist. Declare the required scripts in `get_inject_dependencies()` and receive them in `inject_dependencies(...)`, in the same order:

```gdscript
extends CharacterBody3D
class_name Player

var motion: PlayerMotionService
var inventory: InventoryService

static func get_inject_dependencies() -> Array:
	return [PlayerMotionService, InventoryService]

func inject_dependencies(
	motion_service: PlayerMotionService,
	inventory_service: InventoryService
) -> void:
	motion = motion_service
	inventory = inventory_service
```

```gdscript
container.inject(player)
```

Optional extra values follow resolved dependencies:

```gdscript
container.inject(player, [spawn_point, team_id])
# player.inject_dependencies(motion, inventory, spawn_point, team_id)
```

If dependencies are declared but `inject_dependencies(...)` is missing, Arca reports an error. `inject()` returns the same object and registers it with the context lifecycle runner.

### Lifecycle

Every object obtained through `resolve()` and every object passed to `inject()` is tracked by its resolving/injecting container. When available, Arca forwards these methods:

```gdscript
func tick(delta: float) -> void:
	pass # called from _process

func physics_tick(delta: float) -> void:
	pass # called from _physics_process

func input(event: InputEvent) -> void:
	pass # called from _input

func unhandled_input(event: InputEvent) -> void:
	pass # called from _unhandled_input

func shortcut_input(event: InputEvent) -> void:
	pass # called from _shortcut_input

func unhandled_key_input(event: InputEvent) -> void:
	pass # called from _unhandled_key_input

func dispose() -> void:
	pass # called when the owning container is disposed
```

Use `dispose()` to disconnect signals, stop timers, close resources, and release external state. The project context is disposed when its autoload exits; a scoped node context is disposed when that node exits the tree.

### Practical notes

- Use explicit script constants (usually `preload`) as binding keys.
- Only registered scripts can be resolved; Arca does not scan the project or use type annotations to select services.
- Services with no arguments may use a normal binding. Services with custom construction should use a factory.
- Place an `INHERITED` context below the context whose bindings it needs.
- Context installers run during `_enter_tree`; make sure required ancestor/project bindings are installed before injecting scene objects.

---

<a id="русский"></a>

## Русский

### Что даёт Arca

Arca — лёгкий аддон для внедрения зависимостей в **Godot 4.6+**. Его подход близок к Zenject, но API остаётся привычным для Godot: инсталлеры объявляют биндинги, контексты определяют время жизни, а контейнер создаёт или внедряет объекты.

- Глобальный контейнер проекта и локальные контейнеры сцен.
- Singleton- и transient-биндинги.
- Создание через зависимости, объявленные в `get_dependencies()`.
- Внедрение зависимостей в уже созданные Godot-объекты, например `Node`.
- Фабрики, биндинг существующего экземпляра и немедленное создание.
- Вызовы `tick`, `physics_tick`, input-методов и `dispose` по жизненному циклу.
- Поиск в родительских контейнерах и обнаружение циклических зависимостей.

### Установка

1. Скопируйте папку `addons/arca` в проект Godot.
2. Включите **Arca** в **Project → Project Settings → Plugins**.
3. При включении аддон добавит autoload `ArcaProjectContextNode` и настройку `arca/project/global_installers`.

> Не отключайте autoload: он владеет контейнером проекта и его lifecycle runner.

### Быстрый старт

Создайте сервис и явно опишите его зависимости конструктора:

```gdscript
# res://game/services/game_service.gd
extends RefCounted
class_name GameService

var save_service: SaveService

static func get_dependencies() -> Array:
	return [SaveService]

func _init(dependency: SaveService) -> void:
	save_service = dependency
```

Зарегистрируйте сервисы в инсталлере:

```gdscript
# res://game/installers/game_installer.gd
extends ArcaInstaller

const SaveService := preload("res://game/services/save_service.gd")
const GameService := preload("res://game/services/game_service.gd")

func install(container: ArcaContainer, _ctx) -> void:
	container.bind(SaveService).as_single()
	container.bind(GameService).as_single()
```

Добавьте скрипт инсталлера в **Project Settings → Arca → Project → Global Installers**, затем получите сервис:

```gdscript
var game_service: GameService = ArcaProjectContextNode.container.resolve(GameService)
```

### Контексты и области видимости

Каждый контейнер принадлежит контексту. Дочерний контейнер сначала ищет биндинг у себя, затем у родителя и далее до контейнера проекта.

| Контекст | Контейнер | Для чего подходит |
| --- | --- | --- |
| `ArcaProjectContextNode` | Один контейнер на весь проект | сохранения, конфигурация, аудио, глобальное состояние |
| `ArcaNodeContext` с `SCOPED` | Новый дочерний контейнер | уровень, бой, меню или другая самостоятельная сцена |
| `ArcaNodeContext` с `INHERITED` | Контейнер ближайшего родительского контекста | вложенная сцена, разделяющая область видимости родителя |

Для контекста сцены создайте, например, такой скрипт:

```gdscript
extends ArcaNodeContext
class_name BattleContext
```

На ноде в Inspector настройте:

- **Scope Mode**: `SCOPED` или `INHERITED`;
- **Installers Path**: массив скриптов-инсталлеров для этого контекста.

`SCOPED` создаёт собственные контейнер и lifecycle runner. Когда нода покидает дерево сцены, Arca вызывает очистку у отслеживаемых объектов этого контейнера.

`INHERITED` ничего нового не создаёт: его инсталлеры добавляют биндинги прямо в унаследованный контейнер. Это удобно для переиспользуемых вложенных сцен, но учитывайте дублирование: новый биндинг того же скрипта заменяет предыдущий биндинг в контейнере.

Если родительского `ArcaNodeContext` нет, унаследованный контекст использует контейнер проекта.

### Инсталлеры

Инсталлер — скрипт, наследующий `ArcaInstaller`:

```gdscript
extends ArcaInstaller

func install(container: ArcaContainer, ctx) -> void:
	pass
```

Глобальные инсталлеры используйте для сервисов на всё время работы приложения. Для сервисов сцены укажите инсталлеры в **Installers Path** у `ArcaNodeContext`. Аргумент `ctx` — текущий контекст; через него можно читать экспортированные поля и ссылки на ноды:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var battle := ctx as BattleContext
	container.bind(EnemySpawner).as_single(func():
		return EnemySpawner.new(battle.spawn_points)
	)
```

### Биндинги и получение объектов

#### Время жизни

```gdscript
container.bind(AudioService).as_single()
container.bind(BulletService).as_transient()
```

`as_single()` создаёт объект при первом `resolve()` и далее возвращает тот же экземпляр. `as_transient()` создаёт новый объект при каждом `resolve()`. Ключом является именно скрипт, переданный в `bind`; новый биндинг для того же скрипта заменяет старый.

Получайте объект из нужного контекста:

```gdscript
var audio = ArcaProjectContextNode.container.resolve(AudioService)
var battle_state = container.resolve(BattleState)
```

Если скрипт не зарегистрирован, Arca выведет ошибку и вернёт `null`.

#### Зависимости конструктора

Arca не определяет параметры `_init` автоматически. Укажите скрипты, которые надо получить из контейнера, в порядке параметров конструктора:

```gdscript
extends RefCounted
class_name PlayerService

static func get_dependencies() -> Array:
	return [InventoryService, SaveService]

func _init(inventory: InventoryService, save: SaveService) -> void:
	pass
```

При обычном биндинге `as_single()` или `as_transient()` Arca сначала получит `InventoryService` и `SaveService`, а затем вызовет `PlayerService.new(inventory, save)`.

Цикл наподобие `A → B → A` обнаруживается: Arca сообщит об ошибке и вернёт `null` для циклического разрешения.

#### `from_instance()`

Используйте уже существующий объект, если контейнер не должен создавать его сам:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var battle := ctx as BattleContext
	container.bind(PlayerCameraService).from_instance(battle.camera_service)
```

Такой биндинг всегда singleton и возвращает тот же экземпляр. Экземпляр дочернего скрипта можно зарегистрировать как один из его базовых скриптов. `null` и объект несвязанного скрипта будут отклонены.

#### Фабрики

Используйте фабрику, когда объект нужно создавать особым образом. Фабрика принимает либо ноль аргументов, либо один аргумент `ArcaContainer`:

```gdscript
container.bind(ConfigService).as_single(func():
	return ConfigService.new("local")
)

container.bind(PlayerService).as_single(func(c: ArcaContainer):
	return PlayerService.new(
		c.resolve(InventoryService),
		c.resolve(SaveService)
	)
)
```

Фабрика полностью отвечает за создание объекта: для такого биндинга Arca не вызывает `get_dependencies()`.

#### `with_arguments(...)`

`with_arguments(...)` передаёт аргументы напрямую в конструктор:

```gdscript
container.bind(PlayerMotionService)\
	.with_arguments(camera, body)\
	.as_single()
```

В версии 0.4.0 это приведёт к вызову `PlayerMotionService.new(camera, body)`. Значения из `with_arguments(...)` **не** объединяются с результатом `get_dependencies()`. Если нужны и зависимости контейнера, и ручные аргументы, используйте фабрику с `ArcaContainer`:

```gdscript
container.bind(PlayerMotionService).as_single(func(c: ArcaContainer):
	return PlayerMotionService.new(c.resolve(JoystickService), camera, body)
)
```

Вызывайте `with_arguments(...)` до выбора времени жизни. Его нельзя сочетать с `from_instance()`.

#### `non_lazy()`

По умолчанию биндинги ленивые. Добавьте `non_lazy()` после времени жизни, чтобы создать объект ещё во время установки:

```gdscript
container.bind(InputService).as_single().non_lazy()
```

Это нужно сервисам, которым требуется ранняя инициализация, подписка на сигналы или lifecycle-вызовы с самого начала жизни контекста.

### Внедрение в существующие объекты

Для нод сцены и других уже созданных объектов используйте `inject()`. Перечислите необходимые скрипты в `get_inject_dependencies()` и примите их в `inject_dependencies(...)` в том же порядке:

```gdscript
extends CharacterBody3D
class_name Player

var motion: PlayerMotionService
var inventory: InventoryService

static func get_inject_dependencies() -> Array:
	return [PlayerMotionService, InventoryService]

func inject_dependencies(
	motion_service: PlayerMotionService,
	inventory_service: InventoryService
) -> void:
	motion = motion_service
	inventory = inventory_service
```

```gdscript
container.inject(player)
```

Дополнительные ручные значения передаются после разрешённых зависимостей:

```gdscript
container.inject(player, [spawn_point, team_id])
# player.inject_dependencies(motion, inventory, spawn_point, team_id)
```

Если зависимости объявлены, но метода `inject_dependencies(...)` нет, Arca выведет ошибку. `inject()` вернёт тот же объект и добавит его в lifecycle runner контекста.

### Жизненный цикл

Каждый объект, полученный через `resolve()`, и каждый объект, переданный в `inject()`, отслеживается контейнером. Если методы существуют, Arca вызывает их так:

```gdscript
func tick(delta: float) -> void:
	pass # _process

func physics_tick(delta: float) -> void:
	pass # _physics_process

func input(event: InputEvent) -> void:
	pass # _input

func unhandled_input(event: InputEvent) -> void:
	pass # _unhandled_input

func shortcut_input(event: InputEvent) -> void:
	pass # _shortcut_input

func unhandled_key_input(event: InputEvent) -> void:
	pass # _unhandled_key_input

func dispose() -> void:
	pass # при уничтожении владеющего контейнера
```

В `dispose()` удобно отключать сигналы, останавливать таймеры, закрывать ресурсы и освобождать внешнее состояние. Контейнер проекта очищается при выходе его autoload из дерева, а контейнер `SCOPED`-контекста — при выходе соответствующей ноды.

### Практические рекомендации

- Используйте явные константы скриптов (обычно `preload`) как ключи биндингов.
- Можно получить только зарегистрированный скрипт: Arca не сканирует проект и не выбирает сервисы по аннотациям типов.
- Для сервисов без особой логики создания достаточно обычного биндинга; для сложного создания выбирайте фабрику.
- Располагайте `INHERITED`-контекст ниже контекста, чьи биндинги ему нужны.
- Инсталлеры контекста запускаются в `_enter_tree`; нужные биндинги родителя или проекта должны быть установлены до внедрения объектов сцены.
