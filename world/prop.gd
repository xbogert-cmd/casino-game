extends Node3D
## An object you can interact with. It runs `action` if one is set; otherwise it
## opens the story dialogue for `who`.

var who := ""
var label := ""
var action: Callable


func prompt() -> String:
	return label


func interact() -> void:
	if action.is_valid():
		action.call()
	else:
		Game.talk.emit(who)
