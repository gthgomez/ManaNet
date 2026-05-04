extends SceneTree

func _init():
	print("Loading autoloads...")
	var prog = load("res://autoloads/Progression.gd").new()
	prog.name = "Progression"
	root.add_child(prog)
	
	var fm = load("res://autoloads/FocusManager.gd").new()
	fm.name = "FocusManager"
	root.add_child(fm)
	
	print("Loading SettingsScreen...")
	var scene = load("res://scenes/SettingsScreen.tscn")
	if scene == null:
		print("Failed to load scene")
	else:
		var instance = scene.instantiate()
		root.add_child(instance)
		print("SettingsScreen loaded successfully.")
	quit()
