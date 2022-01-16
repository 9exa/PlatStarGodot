extends EditorProperty
tool
const GraphProps = preload("GraphEditorProp.gd")
var lab = Label.new()
var but = Button.new()
var cont = VBoxContainer.new()
var thing
#	var main = CanvasLayer.new()
#can't add edges through inspector
func _init(t):
	read_only = true
	add_child(cont)
	cont.add_child(lab)
	add_focusable(lab)
	
	thing = t
	if thing == "Nodes":
		label=("Nodes/Surfaces")
		but.set_text("add Node/Surface")
		cont.add_child(but)
		but.connect("pressed", self, "_addRequest")
	elif thing == "Edges":
		label = ("Edges")
	

func getList() : return get_edited_object()[get_edited_property()]

func _addRequest():
	var list = getList()
	if thing == "Nodes":
		var newSurf = {"start": Vector2(), "end": Vector2()}
		list.append(newSurf)
	emit_changed(get_edited_property(), list)

func update_property():
	#first empty the container
	freeChildren(cont)
	
	var newVals = getList()
	#we know they're dicts (or nulls)
	var text = ""
	if thing == "Nodes":
		for dict in newVals:
			if dict == null:
				continue
			cont.add_child(GraphProps.NodeProp.new(dict))
	else:
		for dict in newVals:
			if dict == null:
				continue
			text += (str(dict.type) + " From: " + str(dict.from)+ 
					" To: " + str(dict.to) + 
					" Exit: " + " Entrance: ")
	lab.set_text(text + "\b")

#frees all children of a node
static func freeChildren(node):
	for c in node.get_children():
		c.queue_free()
