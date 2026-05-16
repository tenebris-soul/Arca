# Arca

Arca is a small dependency injection addon for Godot. It is inspired by Zenject, but tries to stay simple and close to how Godot scenes usually work.

The short version:

- installers register services;
- contexts decide where those services live;
- the container creates objects when you call `resolve()`;
- services can receive dependencies through `_init`;
- services with `tick`, `physics_tick`, or `dispose` are handled by the lifecycle runner.

---

## Русский

### 1. Глобальные инсталлеры для контекста проекта

Глобальный контекст - это контейнер на весь проект. Он создается как autoload:

```gdscript
ArcaProjectContextNode
```

У него есть контейнер:

```gdscript
ArcaProjectContextNode.container
```

Сюда стоит класть сервисы, которые должны жить все время игры: сохранения, конфиг, общий game state, аудио-сервис, сервис аналитики и так далее.

Регистрация делается через installer:

```gdscript
extends ArcaInstaller

const SaveService := preload("res://game/services/save_service.gd")
const GameState := preload("res://game/services/game_state.gd")

func install(container: ArcaContainer) -> void:
	container.bind(SaveService).as_single()
	container.bind(GameState).as_single()
```

После этого installer нужно добавить в Project Settings:

```text
arca/project/global_installers
```

При старте игры `ArcaProjectContext` сам загрузит эти scripts и вызовет у каждого:

```gdscript
installer.install(container)
```

Потом сервис можно получить из любого скрипта:

```gdscript
var save_service = ArcaProjectContextNode.container.resolve(SaveService)
```

Идея простая: если зависимость нужна всему проекту, регистрируй ее в global installer.

### 2. Нодовые контексты

`ArcaNodeContext` нужен, когда контейнер должен жить не весь проект, а только внутри конкретной сцены или части дерева.

Например:

```text
BattleScene
  BattleContext
  Player
  Enemies
```

У боя могут быть свои сервисы: `BattleState`, `EnemySpawner`, `DamageService`. Они не нужны в главном меню и должны исчезнуть вместе со сценой боя. Для такого случая подходит `ArcaNodeContext`.

Минимальный context:

```gdscript
extends ArcaNodeContext
class_name BattleContext
```

Повесь этот скрипт на node в сцене. В инспекторе появятся:

- `scope_mode`;
- `installers_path`.

#### 2.1. Scope Mode и Inherited Mode

`SCOPED` значит: “создай новый контейнер здесь”.

```text
BattleContext SCOPED
  own container
  own lifecycle runner
```

Такой context сам владеет своими сервисами. Когда node выходит из tree, контейнер чистится, а у созданных сервисов вызывается `dispose()`, если этот метод есть.

Используй `SCOPED` для больших самостоятельных частей игры:

```text
BattleScene
InventoryScreen
DialogScene
LevelScene
```

`INHERITED` значит: “не создавай контейнер, возьми ближайший родительский”.

```text
BattleContext SCOPED
  PlayerContext INHERITED
  EnemyContext INHERITED
```

Это удобно для вложенных сцен. Например, `Player` может быть отдельной сценой и иметь свой `ArcaNodeContext`, но ему не нужен отдельный контейнер. Он просто хочет пользоваться сервисами боя.

Правило:

- `SCOPED` - эта сцена создает свой DI-мир;
- `INHERITED` - эта сцена подключается к DI-миру родителя.

Если родительского `ArcaNodeContext` нет, inherited context возьмет контейнер проекта.

#### 2.2. Локальные инсталлеры

Локальные installers указываются в `installers_path` у `ArcaNodeContext`.

Пример installer-а для боя:

```gdscript
extends ArcaInstaller

const BattleState := preload("res://game/battle/battle_state.gd")
const EnemySpawner := preload("res://game/battle/enemy_spawner.gd")

func install(container: ArcaContainer) -> void:
	container.bind(BattleState).as_single()
	container.bind(EnemySpawner).as_transient()
```

Когда context входит в tree, он:

1. выбирает контейнер по `scope_mode`;
2. создает lifecycle runner, если scope свой;
3. запускает installers;
4. после этого зависимости можно резолвить.

### 3. Примеры использования

#### Singleton и transient

```gdscript
func install(container: ArcaContainer) -> void:
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

#### Зависимости через `_init`

Arca не пытается угадывать зависимости по аргументам `_init`. Вместо этого класс явно говорит контейнеру, что ему нужно.

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

Когда ты вызовешь:

```gdscript
var player_service = container.resolve(PlayerService)
```

контейнер сделает примерно это:

```gdscript
var inventory = container.resolve(InventoryService)
var save = container.resolve(SaveService)
var player_service = PlayerService.new(inventory, save)
```

#### Factory

Иногда объект нужно создать руками. Для этого можно передать factory.

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

#### Циклические зависимости

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

The project context is the container that lives for the whole game. It is created as an autoload:

```gdscript
ArcaProjectContextNode
```

It owns the global container:

```gdscript
ArcaProjectContextNode.container
```

Put long-living services here: save systems, config, global game state, audio service, analytics, and similar project-level dependencies.

Registration is done through an installer:

```gdscript
extends ArcaInstaller

const SaveService := preload("res://game/services/save_service.gd")
const GameState := preload("res://game/services/game_state.gd")

func install(container: ArcaContainer) -> void:
	container.bind(SaveService).as_single()
	container.bind(GameState).as_single()
```

Add the installer to Project Settings:

```text
arca/project/global_installers
```

When the game starts, `ArcaProjectContext` loads these scripts and calls:

```gdscript
installer.install(container)
```

After that, the service can be resolved from any script:

```gdscript
var save_service = ArcaProjectContextNode.container.resolve(SaveService)
```

Simple rule: if a dependency belongs to the whole project, register it in a global installer.

### 2. Node Contexts

`ArcaNodeContext` is for dependencies that should live only inside one scene or one branch of the scene tree.

Example:

```text
BattleScene
  BattleContext
  Player
  Enemies
```

A battle may have its own `BattleState`, `EnemySpawner`, or `DamageService`. These services are not needed in the main menu, and they should disappear with the battle scene. This is where `ArcaNodeContext` fits.

Minimal context:

```gdscript
extends ArcaNodeContext
class_name BattleContext
```

Attach this script to a node. In the inspector you will see:

- `scope_mode`;
- `installers_path`.

#### 2.1. Scope Mode and Inherited Mode

`SCOPED` means: “create a new container here”.

```text
BattleContext SCOPED
  own container
  own lifecycle runner
```

This context owns its services. When the node leaves the tree, the container is disposed, and created services get `dispose()` called if they have that method.

Use `SCOPED` for larger self-contained parts of the game:

```text
BattleScene
InventoryScreen
DialogScene
LevelScene
```

`INHERITED` means: “do not create a container, use the nearest parent one”.

```text
BattleContext SCOPED
  PlayerContext INHERITED
  EnemyContext INHERITED
```

This is useful for nested scenes. For example, `Player` can be a separate scene and still use the battle services instead of creating its own container.

Rule of thumb:

- `SCOPED` - this scene creates its own DI world;
- `INHERITED` - this scene joins the parent DI world.

If there is no parent `ArcaNodeContext`, an inherited context uses the project container.

#### 2.2. Local Installers

Local installers are assigned through `installers_path` on `ArcaNodeContext`.

Battle installer example:

```gdscript
extends ArcaInstaller

const BattleState := preload("res://game/battle/battle_state.gd")
const EnemySpawner := preload("res://game/battle/enemy_spawner.gd")

func install(container: ArcaContainer) -> void:
	container.bind(BattleState).as_single()
	container.bind(EnemySpawner).as_transient()
```

When the context enters the tree, it:

1. chooses a container based on `scope_mode`;
2. creates a lifecycle runner if it owns the scope;
3. runs installers;
4. makes dependencies available for resolving.

### 3. Usage Examples

#### Singleton and Transient

```gdscript
func install(container: ArcaContainer) -> void:
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

Arca does not try to guess dependencies from `_init` arguments. Instead, the class explicitly tells the container what it needs.

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
var player_service = container.resolve(PlayerService)
```

the container roughly does this:

```gdscript
var inventory = container.resolve(InventoryService)
var save = container.resolve(SaveService)
var player_service = PlayerService.new(inventory, save)
```

#### Factory

Sometimes you need to create an object manually. Use a factory for that.

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

This is useful for disconnecting signals, stopping timers, closing connections, and general cleanup.

#### Circular Dependencies

If you accidentally create this:

```text
A depends on B
B depends on A
```

the container will not recurse forever. It will print an error like:

```text
Circular dependency detected: A -> B -> A
```
