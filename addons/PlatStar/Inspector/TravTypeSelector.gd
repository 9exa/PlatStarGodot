extends OptionButton
tool


const Types = ["WALK", "JUMP", "FALL"]
const Colors = [Color.aqua, Color.brown, Color.lime]
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _init():
	for type in Types:
		add_item(type)
func select(ind):
	.select(ind)
	self_modulate = Colors[ind]

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
