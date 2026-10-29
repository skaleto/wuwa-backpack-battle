extends SceneTree
const G=preload("res://scripts/game.gd")
const S=preload("res://scripts/storage/storage.gd")
const P=preload("res://scripts/online/async_pvp.gd")
var failures=0
class FailQueue:
	extends RefCounted
	var config={"player_id":"test-owner"}
	func ready_for_online():return true
	func enqueue(_run):return false
func ck(ok:bool,label:String):
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	var g=G.new();g.storage=S.new("user://qa-v134-ui-"+P.random_id()+"/");root.add_child(g)
	if not g.has_method("_switch_mode"):
		ck(false,"mode selector exists");g.queue_free();quit(1);return
	var offline=g.storage
	g._action("start");var original=g.run.duplicate(true);g._action("home")
	g._switch_mode("async")
	ck(g.saved.is_empty() and g.storage!=offline,"online has independent save")
	g._action("start")
	ck(g.run.get("mode")=="async" and g.opponent.is_empty(),"async start defers matching")
	g._application().prepare_match(g.run,"test-owner")
	g.overlay="forge";g.forge_base=g.run.items[0].uid;var frozen=g.run.duplicate(true)
	g._action("reroll")
	ck(g.run==frozen,"all preparation actions blocked while pending")
	ck(g.has_method("_preparation_frozen") and g.call("_preparation_frozen"),"frozen input gate independent of in-flight request")
	var original_client=g.online_client;g.online_client=FailQueue.new()
	await g._start_battle()
	ck(g.run.phase=="shop" and g.run.pvp.stage=="pending","failed durable enqueue does not discard frozen round")
	g.online_client=original_client
	g.overlay=""
	await g._start_battle()
	ck(g.run.phase=="battle" and g.run.pvp.source=="bot" and g.run.pvp.reason=="unconfigured","unconfigured service visibly classified as bot fallback")
	g._application().finish_replay(g.run);g._action("home")
	g._switch_mode("practice")
	ck(g.storage==offline and g.saved==original,"switch retains exact old practice save")
	g.queue_free();print("async UI failures ",failures);quit(1 if failures else 0)
