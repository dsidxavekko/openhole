class_name Edible
extends RigidBody3D
## Anything a hole can swallow.

var kind := ""
var extent := 1.0
var height := 1.0
var points := 1
var falling_into: Node3D = null
var cell := Vector2i.ZERO
