@abstract
@icon("res://addons/simple_component_system/icons/component.svg")
class_name Component
extends Node
## Base class for components
##
## Extending [Component] isn't necessary to get the component system functionality,
## it just adds extra ergonomic sugar with [member entity], [member enabled], and
## added / removed signals.
## 
## Component queries are duck typed.
## [code]class_name Hurtbox extends Area2D[/code] child is found the same as
## a [Component] subclass.
## 
## Component queries are static and work on any [Node]:
## [codeblock]
## var damage_component: Damageable = Component.of(thing, Damageable)
## if Component.has(thing, Damageable):
##     Component.require(thing, Health).current_health -= 10.0
## [/codeblock]
##
## Matching is inheritance-aware: [code]of(thing, Damageable)[/code] finds a
## [code]LavaDamageable[/code] child. When several children match, the first
## in child order wins. Native classes work as queries too:
## [code]of(thing, Area2D)[/code].

## The node this component is attached to. Alias for [method Node.get_parent].
var entity: Node:
	get:
		return get_parent()

## Toggles processing (process, physics, input) for this component and its
## children via [member Node.process_mode]. Disabled components are still
## found by lookups — being found and being active are different things.
@export var enabled: bool = true:
	set(value):
		enabled = value
		process_mode = PROCESS_MODE_INHERIT if value else PROCESS_MODE_DISABLED

## Override to declare components this one needs on the same entity. Return
## class values, script classes ([code][Movement, Stamina][/code]) or native
## classes ([code][AudioStreamPlayer][/code]). [method attach] satisfies the
## whole requirement tree before mounting: missing requirements are
## instantiated with default values and added first, so they are ready before
## this component's [method Node._ready] runs. Duck-typed like everything
## else: any script can declare this method.
func _requires() -> Array:
	return []

## Returns the first child of [param node] matching [param type], or
## [code]null[/code]. [param type] is a script class (e.g.
## [code]Damageable[/code]) or a native class (e.g. [code]Area2D[/code]).
static func of(node: Node, type: Variant) -> Node:
	for child in node.get_children():
		if is_instance_of(child, type):
			return child
	return null

## Returns every direct child of [param node] matching [param type], in child
## order.
static func all(node: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if is_instance_of(child, type):
			found.append(child)
	return found

## Returns [code]true[/code] if [param node] has a direct child matching
## [param type].
static func has(node: Node, type: Variant) -> bool:
	return of(node, type) != null

## Like [method of], but pushes an error when nothing matches. Use for hard
## dependencies so a missing component registers an error directly, instead of
## somewhere downstream.
static func require(node: Node, type: Variant) -> Node:
	var found := of(node, type)
	if found == null:
		push_error("Missing required component %s on %s" % [_type_name(type), node])
	return found

## Instantiates [param type], adds it as a child of [param node], and returns
## it. Script classes get their global class name as node name when they have
## one. Returns [code]null[/code] (with an error) for non-Node types. Emits
## [code]component_added[/code] on [param node] if it declares that signal.
##
## Requirements declared via [method _requires] are satisfied first,
## recursively: missing ones are instantiated and mounted before their
## dependents (each emitting [code]component_added[/code]), so a component's
## [method Node._ready] can rely on them. A requirement is skipped when the
## entity already has a matching component (inheritance-aware). Requirement
## cycles terminate; mount order within a cycle is unspecified. Atomic: if
## anything in the requirement tree fails to instantiate, nothing is mounted
## and [code]null[/code] is returned.
static func attach(node: Node, type: Variant) -> Node:
	var planned: Array[Node] = []
	var mount_order: Array[Node] = []
	var instance := _plan(node, type, planned, mount_order)
	if instance == null:
		for orphan in planned:
			orphan.free()
		return null
	for component in mount_order:
		node.add_child(component)
		if node.has_signal(&"component_added"):
			node.emit_signal(&"component_added", component)
	return instance

## Removes and frees the first component matching [param type]. Returns
## [code]true[/code] if one was found. The component leaves the tree (and all
## lookups) immediately; memory is freed at the end of the frame via
## [method Node.queue_free]. Emits [code]component_removed[/code] on
## [param node] if it declares that signal,
## the component is queued for deletion but the reference is still valid.
static func detach(node: Node, type: Variant) -> bool:
	var found := of(node, type)
	if found == null:
		return false
	node.remove_child(found)
	found.queue_free()
	if node.has_signal(&"component_removed"):
		node.emit_signal(&"component_removed", found)
	return true

static func _plan(node: Node, type: Variant, planned: Array[Node], mount_order: Array[Node]) -> Node:
	var instance: Object = type.new()
	if instance is not Node:
		push_error("Cannot attach %s: not a Node-derived type" % _type_name(type))
		if instance != null and instance is not RefCounted:
			instance.free()
		return null
	var component := instance as Node
	if type is Script:
		var global_name := (type as Script).get_global_name()
		if not global_name.is_empty():
			component.name = global_name
	planned.append(component)
	if component.has_method(&"_requires"):
		var requirements: Variant = component.call(&"_requires")
		if requirements is Array:
			for requirement in requirements:
				if of(node, requirement) != null:
					continue
				if _planned_match(planned, requirement) != null:
					continue
				if _plan(node, requirement, planned, mount_order) == null:
					return null
		else:
			push_error("%s._requires() must return an Array" % _type_name(type))
	mount_order.append(component)
	return component


static func _planned_match(planned: Array[Node], type: Variant) -> Node:
	for component in planned:
		if is_instance_of(component, type):
			return component
	return null

static func _type_name(type: Variant) -> String:
	if type is Script:
		var script := type as Script
		if not script.get_global_name().is_empty():
			return script.get_global_name()
		return script.resource_path if not script.resource_path.is_empty() else str(script)
	return str(type)
