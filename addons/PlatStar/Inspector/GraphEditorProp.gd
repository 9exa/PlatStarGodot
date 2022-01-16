extends EditorProperty
tool
var lab = Label.new()
var but = Button.new()
var cont = VBoxContainer.new()
var props = []
var thing
#can't add edges through inspector
func _init(t):
	read_only = true
	add_child(cont)
	
	thing = t
	if thing == "Nodes":
		label=("Nodes/Surfaces")
#		but.set_text("add Node/Surface")
#		cont.add_child(but)
#		but.connect("pressed", self, "_addRequest")
	elif thing == "Edges":
		label = "Edges"
		
	
#gets the value of the property being tracks
func getList() : return get_edited_object()[get_edited_property()]

#When the button is pressed to ad a node
func _addRequest():
	var list = getList()
	if thing == "Nodes":
		var newSurf = {"start": Vector2(), "end": Vector2()}
		list.append(newSurf)
	emit_changed(get_edited_property(), list)

func _onNodeChanged(ind):
	var newValues = getList()
	var o = get_edited_object()
	var p = get_edited_property()
	newValues[ind] = props[ind].getValue()
	emit_changed(p, newValues)
	o[p] = newValues
	o.emit_changed()

func _onNodeDelete(ind):
	var graph = get_edited_object()
	graph.removeNode(ind)
	graph.emit_changed()

func _onEdgeChanged(from, ind, propInd):
	var newValues = getList()
	var o = get_edited_object()
	var p = get_edited_property()
	newValues[from][ind] = props[propInd].getValue()
	emit_changed(p, newValues)
	o[p] = newValues
	o.emit_changed()

func _onEdgeDelete(from, ind):
	var graph = get_edited_object()
	graph.removeEdge(ind, from)
	graph.emit_changed()

func update_property():
	#props.clear()
	
	var newVals = getList()
	
	#display the appropriate item
	if thing == "Nodes":
		displayNodes(newVals)
	elif thing == "Edges":
		displayEdges(newVals)

#Optimization. So we don't destroy and create all controls every frame
#array of suface dictionaries and nulls, as from graph.surfaces
func displayNodes(nArray):
	var i := 0
	for nDict in nArray:
		if nDict == null: continue
		if i < len(props):
			#change existing property control
			props[i].setValue(nDict)
		else:
			#create new property control
			var newProp = NodeProp.new(nDict)
			newProp.connect("changed", self, "_onNodeChanged")
			newProp.connect("delete", self, "_onNodeDelete")
			
			cont.add_child(newProp)
			props.append(newProp)
		i += 1
	#delete the execess props
	while i < len(props):
		props.pop_back().queue_free()
	
func displayEdges(eArray):
	#similar to the process of displaying nodes, for each node present outgoing edges
	var f := 0
	var i := 0
	var eDict
	while f < (len(eArray)):
		#expand props if a new node was created
		for ind in range(len(eArray[f])):
			eDict = eArray[f][ind]
			if eDict == null: continue
			if i < len(props):
				#change existing property control
				props[i].setValue(ind, eDict)
			else:
				#create new property control
				var newProp = EdgeProp.new(ind, eDict)
				newProp.connect("changed", self, "_onEdgeChanged", [i])
				newProp.connect("delete", self, "_onEdgeDelete")
				cont.add_child(newProp)
				props.append(newProp)
			i += 1
		f += 1
	#in case nodes were deleted
	while i < len(props):
		props.pop_back().queue_free()

#frees all children of a node
static func freeChildren(node):
	for c in node.get_children():
		c.queue_free()
#frees all items in an array
static func freeArray(array):
	for item in array:
		item.queue_free()

#Control for displaying and inputing vectors
class VectorThing extends VBoxContainer :
	tool
	var xEdit
	var yEdit
	signal changed
	func _init():
		xEdit = LineEdit.new()
		yEdit = LineEdit.new()
		xEdit.placeholder_text = "x"
		yEdit.placeholder_text = "y"
		add_child(xEdit)
		add_child(yEdit)
		
		xEdit.connect("text_entered", self, "_onNumChanged", [xEdit])
		xEdit.connect("focus_exited", self, "_onNumChanged2", [xEdit])
		yEdit.connect("text_entered", self, "_onNumChanged", [yEdit])
		yEdit.connect("focus_exited", self, "_onNumChanged2", [yEdit])
		
	func setVal(v):
		xEdit.text = str(v.x)
		yEdit.text = str(v.y)
	func getVector():
		var x = float(xEdit.text) if xEdit.text.is_valid_float() else 0
		var y = float(yEdit.text) if yEdit.text.is_valid_float() else 0
		return Vector2(x, y)
	func _onNumChanged(newText: String, lineEdit : LineEdit):
		if not newText.is_valid_float():
			lineEdit.menu_option(LineEdit.MENU_UNDO)
		else:
			emit_signal("changed")
	func _onNumChanged2(lineEdit :LineEdit):
		_onNumChanged(lineEdit.text, lineEdit)

#Delete button Class
class TrashButton extends TextureButton:
	const DIMS = Vector2(15, 30)
	const atlas = preload("bin.png")
	func _init():
		toggle_mode = false
		var baseTexture = AtlasTexture.new()
		baseTexture.set_atlas(atlas)
		
		texture_normal = baseTexture.duplicate()
		texture_hover = baseTexture.duplicate()
		texture_pressed = baseTexture.duplicate()
		texture_disabled = baseTexture.duplicate()
		
		texture_normal.region = Rect2(Vector2(0,0) * DIMS, DIMS)
		texture_hover.region = Rect2(Vector2(1,0) * DIMS, DIMS)
		texture_pressed.region = Rect2(Vector2(0,1) * DIMS, DIMS)
		texture_disabled.region = Rect2(Vector2(1,1) * DIMS, DIMS)
		


#Control Class for displaying a single node/surface
class NodeProp extends HBoxContainer:
	var indText
	
	var startEdit
	var endEdit
	var ind
	signal changed(ind)
	signal delete(ind)
	func _init(nDict):
		indText = Label.new()
		startEdit = VectorThing.new()
		endEdit = VectorThing.new()
		
		setValue(nDict)
		
		startEdit.connect("changed", self, "_onEditChanged")
		endEdit.connect("changed", self, "_onEditChanged")
		
		var startText = Label.new(); startText.set_text("Start: ")
		var endText = Label.new(); endText.set_text("End: ")
		
		var trash = TrashButton.new()
		trash.connect("pressed", self, "_onDelete")
		
		add_child(indText)
		add_child(startText)
		add_child(startEdit)
		add_child(endText)
		add_child(endEdit)
		add_child(trash)
	func _onEditChanged():
		emit_signal("changed", ind)
	func setValue(nDict):
		ind = nDict.ind; indText.set_text("ind: " + str(ind))
		startEdit.setVal(nDict.start)
		endEdit.setVal(nDict.end)
	func getValue():
		return {"ind" : ind, "start" : startEdit.getVector(), "end" : endEdit.getVector()}
	func _onDelete():
		emit_signal("delete", ind)


#Control Class for displaying a single edge
class EdgeProp extends HBoxContainer:
	var ind
	var from
	var to
	var fromText
	var toText
	var exitEdit
	var entranceEdit
	var typeEdit
	var type := 0
	const TravOptions = preload("TravTypeSelector.gd")
	signal changed(from, ind)
	signal delete(from, ind)
	func _init(theInd, eDict):		
		fromText = Label.new()
		toText = Label.new()
		fromText.set_text("From: " + str(eDict["from"]))
		toText.set_text("To: " + str(eDict["to"]))
#		var indText = Label.new()
#		indText.set_text("Ind: " + str(ind))
#		add_child(indText)
		var exitText = Label.new()
		var entranceText = Label.new()
		exitText.set_text("Exit: ")
		entranceText.set_text("Entrance: ")
		exitEdit = LineEdit.new()
		entranceEdit = LineEdit.new()
		typeEdit = TravOptions.new()
		setValue(theInd, eDict)
		
		exitEdit.connect("text_entered", self, "_onLerpChanged", [exitEdit])
		exitEdit.connect("focus_exited", self, "_onLerpChanged2", [exitEdit])
		entranceEdit.connect("text_entered", self, "_onLerpChanged", [entranceEdit])
		entranceEdit.connect("focus_exited", self, "_onLerpChanged2", [entranceEdit])
		typeEdit.connect("item_selected", self, "_typeChanged")
		
		var trash = TrashButton.new()
		trash.connect("pressed", self, "_onDelete")
		
		add_child(fromText)
		add_child(toText)
		add_child(exitText)
		add_child(exitEdit)
		add_child(entranceText)
		add_child(entranceEdit)
		add_child(typeEdit)
		add_child(trash)
	func setValue(theInd, eDict):
		ind = theInd
		from = eDict["from"]
		to = eDict["to"]
		exitEdit.text = str(eDict["exit"])
		entranceEdit.text = str(eDict["entrance"])
		type = eDict.travType
		typeEdit.select(type)
	func getValue():
		return {"from":from, "to": to, "exit" : float(exitEdit.text),
				"entrance" : float(entranceEdit.text), "travType" : type }
	
	func _typeChanged(sel: int):
		type = sel
		emit_signal("changed", from, ind)
	func _onLerpChanged(newText: String, lineEdit : LineEdit):
		if not newText.is_valid_float():
			lineEdit.menu_option(LineEdit.MENU_UNDO)
		else:
			var val = clamp(float(newText), 0, 1)
			emit_signal("changed", from, ind)
	func _onLerpChanged2(lineEdit: LineEdit):
		_onLerpChanged(lineEdit.text, lineEdit)
	func _onDelete():
		emit_signal("delete", from, ind)

## Called when the node enters the scene tree for the first time.
#func _ready():
#	add_child(NodeProp.new(0, {"ind" : 0, "start" : Vector2(), "end": Vector2()}))
#	add_child(NodeProp.new(1, {"ind" : 1, "start" : Vector2(100,7), "end": Vector2(10,70)}))
#	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
