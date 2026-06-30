class_name Teleporter
extends Interactable

@export_file("*.tscn") var path: String
@export var entry_point: String

func interact() -> void:
	super() #繼承，讓父類別的程式也會執行，否則不執行
	Game.change_scene(path, entry_point)
