extends EditorProperty

var nav
var graphLoader
var graphSaver

func _init(theNav, loader, saver):
	
	#create buttons to bring up file windows
	var container = HBoxContainer.new()
	var loadBut = Button.new()
	var saveBut = Button.new()
	loadBut.set_text("Load Graph")
	saveBut.set_text("Save Graph")
	
	container.add_child(loadBut)
	container.add_child(saveBut)
	
	
	loadBut.connect("pressed", loader, "popup")
	saveBut.connect("pressed", saver, "popup")
	
	nav = theNav
	graphLoader = loader
	graphSaver = saver	
	add_child(container)

func _enter_tree():
	#connect file windows to load/save graph, if it isn't already
	if not graphLoader.is_connected("file_selected", nav, "loadGraph"):
		graphLoader.connect("file_selected", nav, "loadGraph")
	if not graphSaver.is_connected("file_selected", nav, "saveGraph"):
		graphSaver.connect("file_selected", nav, "saveGraph")

func _exit_tree():
	#clean up the loader and savers connection to the nav
	if graphLoader.is_connected("file_selected", nav, "loadGraph"):
		graphLoader.disconnect("file_selected", nav, "loadGraph")
	if graphSaver.is_connected("file_selected", nav, "saveGraph"):
		graphSaver.disconnect("file_selected", nav, "saveGraph")
	
