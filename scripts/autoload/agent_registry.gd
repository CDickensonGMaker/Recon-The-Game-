## agent_registry.gd - THE live-actor roster. Actors register on _ready and
## unregister on death/tree-exit; every system that needs "who is alive" reads
## these arrays instead of keeping its own copy. WB adds the tier field here.
extends Node

enum Kind { ENEMY, ALLY, CIVILIAN, PROP }

var enemies: Array[Node] = []
var allies: Array[Node] = []
var civilians: Array[Node] = []
## Damageable world objects (traps). Not people: nothing that reads morale, ROE
## or the hearts-and-minds ledger may ever walk this roster.
var props: Array[Node] = []


func register(actor: Node, kind: Kind) -> void:
	var roster: Array[Node] = _roster(kind)
	if actor not in roster:
		roster.append(actor)


## Idempotent: death paths and _exit_tree both call this; erase-on-absent is a no-op.
func unregister(actor: Node) -> void:
	enemies.erase(actor)
	allies.erase(actor)
	civilians.erase(actor)
	props.erase(actor)


func _roster(kind: Kind) -> Array[Node]:
	match kind:
		Kind.ENEMY:
			return enemies
		Kind.ALLY:
			return allies
		Kind.PROP:
			return props
	return civilians
