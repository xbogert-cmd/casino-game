extends Node3D
## An object you can interact with. It opens the story dialogue for `who`.

var who := ""
var label := ""


func prompt() -> String:
	return label


func interact() -> void:
	Game.talk.emit(who)
