extends TextureButton
tool

const ICONSIZE = 25
const atlas = preload("Assets/icons.png")

# Called when the node enters the scene tree for the first time.
func _init(toolType : int):
	toolType -= 1 #NONE is 0
	toggle_mode = true
	var baseTexture = AtlasTexture.new()
	baseTexture.set_atlas(atlas)
	texture_normal = baseTexture.duplicate()
	texture_hover = baseTexture.duplicate()
	texture_pressed = baseTexture.duplicate()
	texture_disabled = baseTexture.duplicate()
	
	texture_normal.region = Rect2(0*ICONSIZE, toolType*ICONSIZE, ICONSIZE, ICONSIZE)
	texture_hover.region = Rect2(1*ICONSIZE, toolType*ICONSIZE, ICONSIZE, ICONSIZE)
	texture_pressed.region = Rect2(2*ICONSIZE, toolType*ICONSIZE, ICONSIZE, ICONSIZE)
	texture_disabled.region = Rect2(3*ICONSIZE, toolType*ICONSIZE, ICONSIZE, ICONSIZE)
	
