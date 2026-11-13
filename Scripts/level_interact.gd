extends StaticBody2D

@onready var interactable = $Interactable
@onready var sprite_2d = $Sprite2D

func _ready():
	interactable.interact = _on_interact

func _on_interact():
	if !%Player.key_acquired and get_parent().name == "Key":
		%Player.key_acquired = true
		get_parent().queue_free()
	elif %Player.key_acquired and get_parent().name == "Door":
		for child in get_parent().get_children():
			child.queue_free()
		get_parent().queue_free()
	else:
		pass

func _on_interactable_area_entered(_area):
	pass

func _on_interactable_area_exited(_area):
	pass
