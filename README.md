# SimpleComponentSystem

Simple, duck-typed, inheritance-aware component lookup for Godot 4.x.

```gdscript
var damage_component: Damageable = Component.of(thing, Damageable)       # null if absent
var health := Component.require(thing, Health)      # error if absent
for r in Component.all(thing, Resistance): r.calculate_damage(value)
Component.attach(thing, Damageable)
```

## Install

Copy `addons/simple_component_system/` into your project.

## Motivating Idea

An *entity* can be any node. A *component* is any direct child whose script
matches the class you ask for. Two ways to write a component:

```gdscript
class_name Heatable
extends Component

@export var temperature := 20.0
```
or:

```gdscript
class_name Hurtbox
extends Area2D
```

Extending `Component` isn't necessary. You can use any base class.
The `Component` base class just provides some syntactic sugar (as noted below)

## API

Static, works on any `Node`:

| Function | Behavior |
|---|---|
| `Component.of(node, T) -> Node` | First direct child matching `T`, else `null` |
| `Component.all(node, T) -> Array[Node]` | Every matching child, in child order |
| `Component.has(node, T) -> bool` | Presence check |
| `Component.require(node, T) -> Node` | Like `of`, but `push_error`s when missing |
| `Component.attach(node, T) -> Node` | `T.new()`, added as child, returned; satisfies `_requires()` first |
| `Component.detach(node, T) -> bool` | Removes + frees first match; `true` if found |

If you want `thing.get_component(T)`: make the node an
`Entity` (or `Entity2D` / `Entity3D`), which forwards
`get_component` / `get_components` / `has_component` / `add_component` /
`remove_component` to the statics and declares the `component_added` /
`component_removed` signals.

`Component` subclasses also get:

- `entity`: the parent node (alias for `get_parent()`).
- `enabled`: exported toggle driving `process_mode`; disabled components
  stop processing but are **still found by lookups** (Unity semantics:
  being found and being active are different things).
- `_requires()`: overrideable function that checks for a set of components
  on the entity the component is being added to. If any are missing, they
  get added.

## Semantics worth knowing

- **Matching is inheritance-aware.** `of(thing, Damageable)` finds a
  `LavaDamageable`. 
- **First in child order wins** when several children match.
- **Direct children only.** A child entity's components never leak into its
  parent's lookups.
- **Native classes work as queries and attachments**: `of(thing, Area2D)`,
  `attach(thing, Node3D)`. 
- **`detach` is immediate for lookups, deferred for memory**: the node leaves
  the tree at once, freeing happens end-of-frame (`queue_free`).
- **`component_added` / `component_removed` are duck-typed too**: `attach`
  and `detach` emit them on the target node *if it declares them*. The
  `Entity` classes do, and any node of yours can. Emission is API-scoped on
  purpose: a manual `add_child` doesn't emit (use `child_entered_tree` for
  raw tracking), and entity teardown never sprays `component_removed` the
  way a `child_exiting_tree` relay would. `component_removed` fires after
  removal, the component gets queued for deletion but the reference is still valid.

## Required components

A component declares what it needs on the same entity by overriding
`_requires()`:

```gdscript
class_name Sprinter
extends Component

func _requires() -> Array:
    return [Movement, Stamina]   # script or native classes
```

`Component.attach(thing, Sprinter)` satisfies the whole requirement tree
before anything mounts: missing requirements are instantiated with default
values and added first (recursively, each emitting `component_added`), so a
component's `_ready` can rely on its requirements existing. Details:

- A requirement is skipped when the entity already has a matching component,
  inheritance-aware.
- Each component mounted once.
- Atomic: if anything in the requirement tree fails to instantiate, nothing
  is mounted and `attach` returns `null`.
- Duck-typed: any script can declare `_requires()`, and native classes work
  as requirements (`return [AudioStreamPlayer]`).
- `detach` never auto-removes requirements.

## License

MIT.
