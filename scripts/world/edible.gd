class_name Edible
extends RigidBody3D
## Anything a hole can swallow.

var kind := ""
var extent := 1.0
var height := 1.0
## Collider box size (real, scaled model size).
var size := Vector3.ONE
var fit_size := 1.0
## Driving car: kinematic, moved by the game every physics tick.
var moving := false
## Buildings ignore the magnet; they only fall when the hole is under them.
var magnetic := true
var move_speed := 0.0
var points := 1
var falling_into: Node3D = null
var cell := Vector2i.ZERO
## Falls apart into chunks (see Demolition). Set by EdibleFactory.
var breakable := false
## Model used to cut chunks: res path, and how the model sits in the body
## (body-local = model_basis * (model_point - model_center)).
var model_path := ""
var model_basis := Basis.IDENTITY
var model_center := Vector3.ZERO
## Chunks only: points of the whole thing they came from, the other chunks
## this one holds up, and how many chunks still hold this one up.
var whole_points := 0
var supports: Array[Edible] = []
var supporters := 0
var grounded := true
