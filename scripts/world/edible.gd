class_name Edible
extends RigidBody3D
## Anything a hole can swallow.

var kind := ""
var extent := 1.0
var height := 1.0
var fit_size := 1.0
## Driving car: kinematic, moved by the game every physics tick.
var moving := false
var move_speed := 0.0
var points := 1
var falling_into: Node3D = null
var cell := Vector2i.ZERO
