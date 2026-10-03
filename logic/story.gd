extends RefCounted
## Story threads loaded from data files. A thread has:
##   "entries": which node opens when you interact with someone, first match wins
##   "nodes": dialogue nodes with text, optional effects and choices
##   "objectives": the objective line to show, first match wins
##   "jobs": shifts the thread forces on a night
##   "texts": phone messages sent once when their condition becomes true
## Threads are checked in the order of state.threads, so newer threads win.

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


## A job a thread forces on tonight's shift, or {}. Jobs look like
## {"id", "when", "order", "customer", "event", "success": effects, "failure": effects}.
func job(state) -> Dictionary:
	for id in state.threads:
		for j in threads[id].get("jobs", []):
			if state.check(j.get("when", {})):
				return j
	return {}


## Delivers story texts whose condition is now true. Each is sent once.
func send_texts(state) -> void:
	for id in state.threads.duplicate():
		for t in threads[id].get("texts", []):
			if not state.sent.has(t["id"]) and state.check(t.get("when", {})):
				state.sent[t["id"]] = true
				state.text(t["from"], t["text"])
				state.apply(t.get("effects", {}))


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
