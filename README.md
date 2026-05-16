# Arca

Arca is a small dependency injection addon for Godot. It is inspired by Zenject, but the API stays close to Godot scenes and scripts.

In short:

- installers register services;
- contexts decide where services live;
- `resolve()` creates or returns objects;
- `get_dependencies()` describes constructor dependencies;
- `with_arguments(...)` adds manual constructor arguments;
- `non_lazy()` forces creation during installer setup;
- `tick`, `physics_tick`, and `dispose` are handled by the lifecycle runner.

---

## Русский

### 1. Глобальные инсталлеры для контекста проекта

Глобальный контекст - это контейнер, который живет весь runtime проекта. Он создается как autoload:

```gdscript
ArcaProjectContextNode
```

Контейнер доступен так:

```gdscript
ArcaProjectContextNode.container
```

Сюда обычно кладут сервисы уровня проекта: сохранения, конфиги, общий game state, аудио, аналитика, общие менеджеры.

Глобальный installer - это обычный `ArcaInstaller`:

```gdscript
extends ArcaInstaller

const SaveService := preload("res://game/services/save_service.gd")
const GameState := preload("res://game/services/game_state.gd")

func install(container: ArcaContainer, ctx) -> void:
	container.bind(SaveService).as_single()
	container.bind(GameState).as_single()
```

Installer нужно добавить в Project Settings:

```text
arca/project/global_installers
```

На старте проекта `ArcaProjectContext` загрузит все scripts из этой настройки и вызовет:

```gdscript
installer.install(container, self)
```

После этого сервис можно получить из любого места:

```gdscript
var save_service = ArcaProjectContextNode.container.resolve(SaveService)
```

Простое правило: если сервис должен жить весь проект, регистрируй его в global installer.

### 2. Нодовые контексты

`ArcaNodeContext` нужен, когда зависимости должны жить не весь проект, а только внутри конкретной сцены или ветки scene tree.

Например:

```text
BattleScene
  BattleContext
  Player
  Enemies
```

У боя могут быть свои сервисы: `BattleState`, `EnemySpawner`, `DamageService`. Они не нужны в меню и должны исчезнуть вместе со сценой боя. Для этого и нужен `ArcaNodeContext`.

Минимальный context:

```gdscript
extends ArcaNodeContext
class_name BattleContext
```

Повесь этот скрипт на node. В инспекторе будут доступны:

- `scope_mode`;
- `installers_path`.

#### 2.1. Scope Mode и Inherited Mode

`SCOPED` значит: "создай новый контейнер здесь".

```text
BattleContext SCOPED
  own container
  own lifecycle runner
```

Такой context сам владеет своими сервисами. Когда node выходит из tree, контейнер вызывает `dispose()` у созданных объектов, если этот метод есть.

Используй `SCOPED` для самостоятельных частей игры:

```text
BattleScene
InventoryScreen
DialogScene
LevelScene
```

`INHERITED` значит: "не создавай контейнер, возьми ближайший родительский".

```text
BattleContext SCOPED
  PlayerContext INHERITED
  EnemyContext INHERITED
```

Это удобно для вложенных сцен. Например, `Player` может быть отдельной сценой, но использовать сервисы боя, а не создавать свой контейнер.

Коротко:

- `SCOPED` - эта сцена создает свой DI-мир;
- `INHERITED` - эта сцена подключается к DI-миру родителя.

Если родительского `ArcaNodeContext` нет, inherited context возьмет контейнер проекта.

#### 2.2. Локальные инсталлеры

Локальные installers указываются в `installers_path` у `ArcaNodeContext`.

```gdscript
extends ArcaInstaller

const BattleState := preload("res://game/battle/battle_state.gd")
const EnemySpawner := preload("res://game/battle/enemy_spawner.gd")

func install(container: ArcaContainer, ctx) -> void:
	container.bind(BattleState).as_single()
	container.bind(EnemySpawner).as_transient()
```

Второй аргумент `ctx` - это текущий context. Он полезен, когда installer-у нужны node-ссылки или export-поля context-а:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var battle_context = ctx as BattleContext
	var spawn_points = battle_context.spawn_points

	container.bind(EnemySpawner).as_single(func():
		return EnemySpawner.new(spawn_points)
	)
```

Когда `ArcaNodeContext` входит в tree, он:

1. выбирает контейнер по `scope_mode`;
2. создает lifecycle runner, если scope свой;
3. запускает installers;
4. после этого зависимости можно резолвить.

### 3. Примеры использования

#### Singleton и transient

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	container.bind(PlayerService).as_single()
	container.bind(BulletService).as_transient()
```

`as_single()` создает один instance и переиспользует его.

`as_transient()` создает новый instance на каждый `resolve()`.

#### Resolve

Глобально:

```gdscript
var player_service = ArcaProjectContextNode.container.resolve(PlayerService)
```

Внутри `ArcaNodeContext`:

```gdscript
var player_service = container.resolve(PlayerService)
```

#### Dependencies через `_init`

Arca не угадывает зависимости по аргументам `_init`. Класс явно говорит контейнеру, что нужно создать перед ним.

```gdscript
extends RefCounted
class_name PlayerService

var inventory: InventoryService
var save: SaveService

static func get_dependencies() -> Array:
	return [InventoryService, SaveService]

func _init(inventory_service: InventoryService, save_service: SaveService) -> void:
	inventory = inventory_service
	save = save_service
```

Когда вызывается:

```gdscript
container.resolve(PlayerService)
```

контейнер делает примерно так:

```gdscript
var inventory = container.resolve(InventoryService)
var save = container.resolve(SaveService)
var player_service = PlayerService.new(inventory, save)
```

#### with_arguments(...)

`with_arguments(...)` нужен, когда часть аргументов нельзя или не хочется резолвить из контейнера. Например, это может быть node из сцены, export-поле context-а, конфиг, число, строка.

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var player_context = ctx as PlayerContext

	container.bind(PlayerMotionService)\
		.with_arguments(player_context.player_camera, player_context.player_body)\
		.as_single()
```

`with_arguments(...)` не заменяет `get_dependencies()`. Контейнер складывает аргументы так:

```text
final_args = get_dependencies() results + with_arguments() values
```

То есть сначала идут зависимости из контейнера, потом ручные аргументы.

Очень важно: порядок в `get_dependencies()` и `with_arguments(...)` должен совпадать с порядком аргументов в `_init`.

Пример:

```gdscript
static func get_dependencies() -> Array:
	return [JoystickService]

func _init(joystick: JoystickService, camera: Camera3D, body: CharacterBody3D) -> void:
	pass
```

Binding:

```gdscript
container.bind(PlayerMotionService)\
	.with_arguments(camera, body)\
	.as_single()
```

Итоговый вызов будет таким:

```gdscript
PlayerMotionService.new(joystick, camera, body)
```

Если поменять порядок в `_init`, binding уже будет неправильным.

Повторим главное: порядок в `get_dependencies()` и `with_arguments(...)` ОЧЕНЬ ВАЖЕН.

#### non_lazy()

По умолчанию binding ленивый: объект создается только при первом `resolve()`.

```gdscript
container.bind(AudioService).as_single()
```

В этом случае `AudioService` появится только здесь:

```gdscript
container.resolve(AudioService)
```

`non_lazy()` заставляет контейнер создать объект сразу во время install:

```gdscript
container.bind(AudioService).as_single().non_lazy()
```

Это полезно для сервисов, которые должны начать работать сразу:

- сервисы с `tick(delta)`;
- подписки на сигналы;
- input-сервисы;
- managers, которым нужна ранняя инициализация.

Обычно `non_lazy()` ставят в конце цепочки:

```gdscript
container.bind(PlayerMotionService)\
	.with_arguments(camera, body)\
	.as_single()\
	.non_lazy()
```

Так проще читать: сначала что биндим, потом с какими аргументами, потом lifetime, потом "создай сразу".

#### Factory

Если объект удобнее собрать руками, можно передать factory.

Без контейнера:

```gdscript
container.bind(ConfigService).as_single(func():
	return ConfigService.new("local")
)
```

С контейнером:

```gdscript
container.bind(PlayerService).as_single(func(c: ArcaContainer):
	return PlayerService.new(c.resolve(InventoryService), c.resolve(SaveService))
)
```

Если factory принимает один аргумент, Arca передаст туда текущий контейнер.

Factory полностью берет создание объекта на себя. В этом случае `get_dependencies()` и `with_arguments(...)` для этого binding не участвуют.

#### Lifecycle

Если у сервиса есть `tick(delta)`, он будет вызываться каждый `_process`.

```gdscript
func tick(delta: float) -> void:
	pass
```

Если есть `physics_tick(delta)`, он будет вызываться каждый `_physics_process`.

```gdscript
func physics_tick(delta: float) -> void:
	pass
```

Если есть `dispose()`, контейнер вызовет его при уничтожении context.

```gdscript
func dispose() -> void:
	pass
```

Это удобно для отписок от сигналов, остановки таймеров, закрытия соединений и другой очистки.

#### Circular Dependencies

Если случайно сделать так:

```text
A зависит от B
B зависит от A
```

контейнер не уйдет в бесконечную рекурсию. Он выведет ошибку вида:

```text
Circular dependency detected: A -> B -> A
```

---

## English

### 1. Global Installers for Project Context

The project context is the container that lives for the whole game runtime. It is created as an autoload:

```gdscript
ArcaProjectContextNode
```

The container is available here:

```gdscript
ArcaProjectContextNode.container
```

Use it for project-level services: saves, config, global game state, audio, analytics, shared managers.

A global installer is a regular `ArcaInstaller`:

```gdscript
extends ArcaInstaller

const SaveService := preload("res://game/services/save_service.gd")
const GameState := preload("res://game/services/game_state.gd")

func install(container: ArcaContainer, ctx) -> void:
	container.bind(SaveService).as_single()
	container.bind(GameState).as_single()
```

Add the installer to Project Settings:

```text
arca/project/global_installers
```

On startup, `ArcaProjectContext` loads every script from this setting and calls:

```gdscript
installer.install(container, self)
```

After that, services can be resolved from anywhere:

```gdscript
var save_service = ArcaProjectContextNode.container.resolve(SaveService)
```

Simple rule: if a service should live for the whole project, register it in a global installer.

### 2. Node Contexts

`ArcaNodeContext` is for dependencies that should live only inside one scene or one scene-tree branch.

Example:

```text
BattleScene
  BattleContext
  Player
  Enemies
```

A battle may have its own `BattleState`, `EnemySpawner`, or `DamageService`. These services are not needed in menus and should disappear with the battle scene. This is where `ArcaNodeContext` fits.

Minimal context:

```gdscript
extends ArcaNodeContext
class_name BattleContext
```

Attach this script to a node. The inspector will show:

- `scope_mode`;
- `installers_path`.

#### 2.1. Scope Mode and Inherited Mode

`SCOPED` means: "create a new container here".

```text
BattleContext SCOPED
  own container
  own lifecycle runner
```

This context owns its services. When the node leaves the tree, the container calls `dispose()` on created objects if they implement it.

Use `SCOPED` for self-contained parts of the game:

```text
BattleScene
InventoryScreen
DialogScene
LevelScene
```

`INHERITED` means: "do not create a container, use the nearest parent one".

```text
BattleContext SCOPED
  PlayerContext INHERITED
  EnemyContext INHERITED
```

This is useful for nested scenes. For example, `Player` can be a separate scene while still using battle services instead of creating its own container.

In short:

- `SCOPED` - this scene creates its own DI world;
- `INHERITED` - this scene joins the parent DI world.

If there is no parent `ArcaNodeContext`, an inherited context uses the project container.

#### 2.2. Local Installers

Local installers are assigned through `installers_path` on `ArcaNodeContext`.

```gdscript
extends ArcaInstaller

const BattleState := preload("res://game/battle/battle_state.gd")
const EnemySpawner := preload("res://game/battle/enemy_spawner.gd")

func install(container: ArcaContainer, ctx) -> void:
	container.bind(BattleState).as_single()
	container.bind(EnemySpawner).as_transient()
```

The second argument, `ctx`, is the current context. Use it when an installer needs node references or exported context fields:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var battle_context = ctx as BattleContext
	var spawn_points = battle_context.spawn_points

	container.bind(EnemySpawner).as_single(func():
		return EnemySpawner.new(spawn_points)
	)
```

When `ArcaNodeContext` enters the tree, it:

1. chooses a container based on `scope_mode`;
2. creates a lifecycle runner if it owns the scope;
3. runs installers;
4. makes dependencies available for resolving.

### 3. Usage Examples

#### Singleton and Transient

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	container.bind(PlayerService).as_single()
	container.bind(BulletService).as_transient()
```

`as_single()` creates one instance and reuses it.

`as_transient()` creates a new instance for every `resolve()`.

#### Resolve

Globally:

```gdscript
var player_service = ArcaProjectContextNode.container.resolve(PlayerService)
```

Inside `ArcaNodeContext`:

```gdscript
var player_service = container.resolve(PlayerService)
```

#### Dependencies Through `_init`

Arca does not guess dependencies from `_init` arguments. A class explicitly tells the container what it needs.

```gdscript
extends RefCounted
class_name PlayerService

var inventory: InventoryService
var save: SaveService

static func get_dependencies() -> Array:
	return [InventoryService, SaveService]

func _init(inventory_service: InventoryService, save_service: SaveService) -> void:
	inventory = inventory_service
	save = save_service
```

When you call:

```gdscript
container.resolve(PlayerService)
```

the container roughly does:

```gdscript
var inventory = container.resolve(InventoryService)
var save = container.resolve(SaveService)
var player_service = PlayerService.new(inventory, save)
```

#### with_arguments(...)

`with_arguments(...)` is for constructor arguments that should not be resolved from the container: scene nodes, exported context fields, config values, numbers, strings.

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var player_context = ctx as PlayerContext

	container.bind(PlayerMotionService)\
		.with_arguments(player_context.player_camera, player_context.player_body)\
		.as_single()
```

`with_arguments(...)` does not replace `get_dependencies()`. The container combines arguments like this:

```text
final_args = get_dependencies() results + with_arguments() values
```

Dependencies resolved from the container go first. Manual arguments go after them.

Very important: the order in `get_dependencies()` and `with_arguments(...)` must match the order of `_init` arguments.

Example:

```gdscript
static func get_dependencies() -> Array:
	return [JoystickService]

func _init(joystick: JoystickService, camera: Camera3D, body: CharacterBody3D) -> void:
	pass
```

Binding:

```gdscript
container.bind(PlayerMotionService)\
	.with_arguments(camera, body)\
	.as_single()
```

The final call will be:

```gdscript
PlayerMotionService.new(joystick, camera, body)
```

If `_init` has another order, the binding is wrong.

Again: the order in `get_dependencies()` and `with_arguments(...)` is VERY IMPORTANT.

#### non_lazy()

Bindings are lazy by default. The object is created only on the first `resolve()`.

```gdscript
container.bind(AudioService).as_single()
```

`AudioService` appears only when someone calls:

```gdscript
container.resolve(AudioService)
```

`non_lazy()` forces creation during install:

```gdscript
container.bind(AudioService).as_single().non_lazy()
```

Use it for services that should start immediately:

- services with `tick(delta)`;
- signal subscriptions;
- input services;
- managers that need early initialization.

Usually `non_lazy()` goes at the end of the chain:

```gdscript
container.bind(PlayerMotionService)\
	.with_arguments(camera, body)\
	.as_single()\
	.non_lazy()
```

This reads as: bind this service, pass these arguments, make it singleton, create it now.

#### Factory

If manual construction is clearer, use a factory.

Without the container:

```gdscript
container.bind(ConfigService).as_single(func():
	return ConfigService.new("local")
)
```

With the container:

```gdscript
container.bind(PlayerService).as_single(func(c: ArcaContainer):
	return PlayerService.new(c.resolve(InventoryService), c.resolve(SaveService))
)
```

If the factory accepts one argument, Arca passes the current container into it.

Factory takes full responsibility for creating the object. For that binding, `get_dependencies()` and `with_arguments(...)` are not used.

#### Lifecycle

If a service has `tick(delta)`, it is called every `_process`.

```gdscript
func tick(delta: float) -> void:
	pass
```

If it has `physics_tick(delta)`, it is called every `_physics_process`.

```gdscript
func physics_tick(delta: float) -> void:
	pass
```

If it has `dispose()`, the container calls it when the context is destroyed.

```gdscript
func dispose() -> void:
	pass
```

This is useful for disconnecting signals, stopping timers, closing connections, and cleanup.

#### Circular Dependencies

If you accidentally create this:

```text
A depends on B
B depends on A
```

the container will not recurse forever. It prints an error like:

```text
Circular dependency detected: A -> B -> A
```
