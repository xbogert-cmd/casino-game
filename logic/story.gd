extends RefCounted
## Story threads loaded from data files. A thread has:
##   "entries": which node opens when you interact with someone, first match wins
##   "nodes": dialogue nodes with text, optional effects and choices
##   "objectives": the objective line to show, first match wins

var threads := {}


func load_dir(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			var data = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
			if data is Dictionary:
				add(data)
			else:
				push_error("Bad thread file: " + f)


func add(data: Dictionary) -> void:
	threads[data["id"]] = data


## The dialogue to open for `who`, as {"thread": id, "node": id}, or {} if none.
func entry(who: String, state) -> Dictionary:
	for id in state.threads:
		for e in threads[id].get("entries", []):
			if e["who"] == who and state.check(e.get("when", {})):
				return {"thread": id, "node": e["node"]}
	return {}


func node(thread: String, id: String) -> Dictionary:
	return threads[thread]["nodes"][id]


func choices(thread: String, id: String, state) -> Array:
	return node(thread, id).get("choices", []).filter(
		func(c): return state.check(c.get("when", {})))


func objective(state) -> String:
	for id in state.threads:
		for o in threads[id].get("objectives", []):
			if state.check(o.get("when", {})):
				return o["text"]
	return ""


## Broken links in the data: entries or choices that point at missing nodes.
func problems() -> Array[String]:
	var out: Array[String] = []
	for id in threads:
		var nodes: Dictionary = threads[id].get("nodes", {})
		for e in threads[id].get("entries", []):
			if not nodes.has(e["node"]):
				out.append("%s: entry for %s points at missing node %s" % [id, e["who"], e["node"]])
		for n in nodes:
			for c in nodes[n].get("choices", []):
				if c.has("goto") and not nodes.has(c["goto"]):
					out.append("%s: node %s points at missing node %s" % [id, n, c["goto"]])
	return out
