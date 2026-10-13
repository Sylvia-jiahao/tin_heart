extends Node2D

const ART = preload("res://scripts/chapter_art.gd")
var grip: float = 0.0

func _ready() -> void:
	name = "ChildHand"
	# A continuous silhouette preserves wrist and finger anatomy.
	# Pinch contact matches the cinematic carried toy anchor (0, 142).
	var picture := ART.sprite("child_hand_pinch",Vector2(150,520))
	picture.position = Vector2(-88,-355)
	add_child(picture)

func _process(_delta: float) -> void:
	rotation = lerpf(-0.025,0.015,grip)
