# Arca

Arca is a small dependency injection addon for Godot. It is inspired by Zenject, but the API stays close to Godot scenes and scripts.

In short:

- installers register services;
- contexts decide where services live;
- `resolve()` creates or returns objects;
- `get_dependencies()` describes constructor dependencies;
- `inject()` passes dependencies into an already existing object;
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

Если у inherited context-а указаны `installers_path`, они тоже будут запущены. Но важно понимать, куда попадут bindings: не в отдельный контейнер `PlayerContext`, а прямо в унаследованный контейнер родителя.

То есть в такой структуре:

```text
BattleContext SCOPED
  PlayerContext INHERITED
```

installer у `PlayerContext` будет вызываться с контейнером `BattleContext`.

Это полезно, когда дочерняя сцена хочет добавить свои bindings в общий scope родителя:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	container.bind(PlayerAttackService).as_single()
```

После этого `PlayerAttackService` живет в контейнере боя, потому что `PlayerContext` только унаследовал этот контейнер.

С этим нужно быть аккуратным для повторяющихся сцен. Если два inherited context-а забиндят один и тот же script в один parent container, последний binding перезапишет предыдущий.

Коротко:

- `SCOPED` - эта сцена создает свой DI-мир;
- `INHERITED` - эта сцена подключается к DI-миру родителя и может добавить bindings в этот родительский контейнер.

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
3. запускает installers, если container найден;
4. после этого зависимости можно резолвить.

Для `SCOPED` installers пишут в новый локальный контейнер context-а.

Для `INHERITED` installers пишут в уже существующий контейнер родителя или проекта. Это не локальный scope, а расширение унаследованного scope-а.

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

#### Inject в уже созданный объект

`resolve()` хорош, когда объект создает сам контейнер. Но в Godot много объектов уже живут в сцене: `Node`, UI-контролы, игрок, камера, зоны, спавнеры. Их не надо пересоздавать через DI-контейнер. Для этого есть:

```gdscript
container.inject(instance)
```

`inject()` берет уже существующий объект, смотрит его script и, если там есть `get_inject_dependencies()`, резолвит эти зависимости из контейнера.

Потом контейнер вызывает у объекта:

```gdscript
inject_dependencies(...)
```

Пример:

```gdscript
extends CharacterBody3D
class_name Player

var motion_service: PlayerMotionService
var inventory_service: InventoryService

static func get_inject_dependencies() -> Array:
	return [PlayerMotionService, InventoryService]

func inject_dependencies(
	motion: PlayerMotionService,
	inventory: InventoryService
) -> void:
	motion_service = motion
	inventory_service = inventory
```

Вызов:

```gdscript
container.inject(player)
```

Внутри это примерно то же самое, что:

```gdscript
var motion = container.resolve(PlayerMotionService)
var inventory = container.resolve(InventoryService)

player.inject_dependencies(motion, inventory)
```

Порядок в `get_inject_dependencies()` ОЧЕНЬ ВАЖЕН. Он должен совпадать с порядком аргументов в `inject_dependencies(...)`.

Если объекту нужны еще и ручные аргументы, их можно передать вторым параметром:

```gdscript
container.inject(player, [spawn_point, team_id])
```

Тогда итоговый вызов будет таким:

```gdscript
player.inject_dependencies(motion, inventory, spawn_point, team_id)
```

Сначала идут зависимости из `get_inject_dependencies()`, потом значения из `extra_args`.

Еще один важный момент: после `inject()` объект попадает в lifecycle контейнера. Если у него есть `tick(delta)`, `physics_tick(delta)` или `dispose()`, они будут обрабатываться так же, как у объектов, созданных через `resolve()`.

Если у script есть `get_inject_dependencies()`, но у объекта нет метода `inject_dependencies(...)`, Arca выдаст ошибку. Это специально: контейнер понял, что зависимости нужны, но не знает, куда их положить.

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

#### from_instance()

`from_instance()` нужен, когда объект уже существует, и ты хочешь положить именно его в контейнер.

Частый случай - node или сервис, который создается не контейнером, а сценой:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var player_context = ctx as PlayerContext

	container.bind(PlayerCameraService).from_instance(player_context.camera_service)
```

После этого:

```gdscript
var camera_service = container.resolve(PlayerCameraService)
```

вернет тот же самый instance, который был передан в `from_instance()`.

`from_instance()` всегда ведет себя как singleton. Контейнер не будет создавать новый объект.

Можно биндинть child instance как base script:

```gdscript
var child_service = ChildService.new()

container.bind(BaseService).from_instance(child_service)
```

Это сработает, если `ChildService` наследуется от `BaseService`.

Если instance не относится к script-у, который ты биндишь, Arca выдаст ошибку:

```gdscript
container.bind(PlayerService).from_instance(InventoryService.new())
```

`from_instance()` нельзя смешивать с `with_arguments(...)`, `as_single(...)`, `as_transient(...)` или factory. Instance уже готов, поэтому arguments и factory тут не участвуют.

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

If an inherited context has `installers_path`, those installers are also executed. The important part is where the bindings go: not into a separate `PlayerContext` container, but directly into the inherited parent container.

In this structure:

```text
BattleContext SCOPED
  PlayerContext INHERITED
```

the installer on `PlayerContext` receives the `BattleContext` container.

This is useful when a child scene wants to add its bindings to the shared parent scope:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	container.bind(PlayerAttackService).as_single()
```

After this, `PlayerAttackService` lives in the battle container, because `PlayerContext` only inherited that container.

Be careful with repeated scenes. If two inherited contexts bind the same script into the same parent container, the last binding overwrites the previous one.

In short:

- `SCOPED` - this scene creates its own DI world;
- `INHERITED` - this scene joins the parent DI world and can add bindings into that parent container.

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
3. runs installers if a container was found;
4. makes dependencies available for resolving.

For `SCOPED`, installers write into the new local context container.

For `INHERITED`, installers write into the existing parent or project container. This is not a local scope; it extends the inherited scope.

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

#### Inject Into An Existing Object

`resolve()` is for objects created by the container. In Godot, many objects already exist in the scene: `Node`s, UI controls, the player, cameras, areas, spawners. You usually do not want to recreate them through the DI container. For that case, use:

```gdscript
container.inject(instance)
```

`inject()` takes an existing object, reads its script, and if the script has `get_inject_dependencies()`, resolves those dependencies from the container.

Then the container calls:

```gdscript
inject_dependencies(...)
```

Example:

```gdscript
extends CharacterBody3D
class_name Player

var motion_service: PlayerMotionService
var inventory_service: InventoryService

static func get_inject_dependencies() -> Array:
	return [PlayerMotionService, InventoryService]

func inject_dependencies(
	motion: PlayerMotionService,
	inventory: InventoryService
) -> void:
	motion_service = motion
	inventory_service = inventory
```

Call it like this:

```gdscript
container.inject(player)
```

Internally, this is roughly the same as:

```gdscript
var motion = container.resolve(PlayerMotionService)
var inventory = container.resolve(InventoryService)

player.inject_dependencies(motion, inventory)
```

The order in `get_inject_dependencies()` is VERY IMPORTANT. It must match the argument order in `inject_dependencies(...)`.

If the object also needs manual arguments, pass them as the second parameter:

```gdscript
container.inject(player, [spawn_point, team_id])
```

The final call will be:

```gdscript
player.inject_dependencies(motion, inventory, spawn_point, team_id)
```

Dependencies from `get_inject_dependencies()` go first. Values from `extra_args` go after them.

One more important detail: after `inject()`, the object is tracked by the container lifecycle. If it has `tick(delta)`, `physics_tick(delta)`, or `dispose()`, they are handled the same way as for objects created through `resolve()`.

If the script has `get_inject_dependencies()`, but the object does not have `inject_dependencies(...)`, Arca reports an error. This is intentional: the container knows the object wants dependencies, but has no method to pass them into.

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

#### from_instance()

`from_instance()` is for cases where the object already exists and you want to put that exact object into the container.

A common case is a node or service created by the scene, not by the container:

```gdscript
func install(container: ArcaContainer, ctx) -> void:
	var player_context = ctx as PlayerContext

	container.bind(PlayerCameraService).from_instance(player_context.camera_service)
```

After that:

```gdscript
var camera_service = container.resolve(PlayerCameraService)
```

returns the same instance that was passed to `from_instance()`.

`from_instance()` always behaves like a singleton. The container will not create another object.

You can bind a child instance as a base script:

```gdscript
var child_service = ChildService.new()

container.bind(BaseService).from_instance(child_service)
```

This works if `ChildService` extends `BaseService`.

If the instance does not belong to the script you bind, Arca reports an error:

```gdscript
container.bind(PlayerService).from_instance(InventoryService.new())
```

Do not mix `from_instance()` with `with_arguments(...)`, `as_single(...)`, `as_transient(...)`, or factory creation. The instance already exists, so arguments and factory are not used.

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
