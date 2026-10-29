extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
const P=preload("res://scripts/online/async_pvp.gd")
const N=preload("res://scripts/online/async_pool_client.gd")
const A=preload("res://scripts/online/async_run_application.gd")
const B=preload("res://scripts/battle/battle.gd")
var failures=0
var checks=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	var args=OS.get_cmdline_user_args()
	if args.size()==2 and args[0]=="--pool-file":
		FileAccess.open(args[1],FileAccess.WRITE).store_string(P.pool_id(I.new().new_run("aemeath",19)));quit();return
	call_deferred("test")
func test():
	var args=OS.get_cmdline_user_args()
	if args.size()!=2 or args[0]!="--fixture":printerr("Requires local test fixture");quit(2);return
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var inv=I.new();var a=N.new();var b=N.new();root.add_child(a);root.add_child(b)
	var sa=S.new("user://qa-v134-pair-a-"+P.random_id()+"/");var sb=S.new("user://qa-v134-pair-b-"+P.random_id()+"/")
	a.configure(sa);b.configure(sb)
	ck((await a.activate(fixture.base_url,fixture.invite_a)).ok,"Alice activates real service")
	ck((await b.activate(fixture.base_url,fixture.invite_b)).ok,"Bob activates real service")
	ck(a.config.player_id!=b.config.player_id and not a.config.has("activation"),"identities independent and activation secret removed")
	if failures:quit(1);return
	var app=A.new(inv,sa,B.new());var run=app.start("aemeath",19).run
	ck(app.prepare_match(run,a.config.player_id).ok and a.enqueue(run),"freeze and durable queue")
	ck((await a.flush_one()) and a.outbox.is_empty(),"POST exact snapshot bytes")
	ck(a.enqueue(run) and (await a.flush_one()),"lost upload response: 409 plus hash-verified GET completes")
	# A second same-account snapshot plus Bob forces actual XML pagination (2/page).
	var other=A.new(inv,sb,B.new());var peer=other.start("hsin",23).run
	ck(other.prepare_match(peer,b.config.player_id).ok and b.enqueue(peer) and (await b.flush_one()),"Bob publishes different layout")
	var extra=app.start("lynae",27).run
	ck(app.prepare_match(extra,a.config.player_id).ok and a.enqueue(extra) and (await a.flush_one()),"same player may publish another run")
	var selected=await a.find_opponent(inv,run)
	ck(selected.ok and selected.opponent.owner==b.config.player_id and selected.opponent.items==peer.items,"paged list matches Bob and retains all item positions")
	var reverse=await b.find_opponent(inv,peer)
	ck(reverse.ok and reverse.opponent.owner==a.config.player_id,"Bob independently retrieves Alice")
	ck(app.lock_opponent(run,selected.opponent,"player").ok and app.begin(run,selected.opponent).ok,"real API result enters existing simulation")
	var resumed=sa.resume()
	ck(resumed.phase=="result" and JSON.parse_string(JSON.stringify(resumed.opponent))==JSON.parse_string(JSON.stringify(run.opponent)),"restart reuses stored combat and exact opponent")
	ck(app.finish_replay(run).ok and app.advance(run,run.combat).ok,"settlement and archive use existing application plans")
	var history=sa.battle_history(run)
	ck(not history.is_empty() and history[0].get("pvp_source")=="player","history retains real player provenance")
	var record=sa.battle_record(history[0].id)
	ck(record.builds[0].get("mode")=="async" and not record.builds[0].has("pvp") and not JSON.stringify(record).contains(a.config.token),"replay contains provenance, never token or upload bytes")
	var empty=await a.find_opponent(inv,run)
	ck(not empty.ok and empty.error=="empty_pool","separate round has no invented player opponent")
	# Same-round nearest win count, not lifetime win rate.
	var low=other.start("hsin",31).run;low.round=2;low.wins=0;low.losses=1
	ck(other.prepare_match(low,b.config.player_id).ok and b.enqueue(low) and (await b.flush_one()),"publish lower win layer")
	var high=other.start("lynae",33).run;high.round=2;high.wins=1;high.losses=0
	ck(other.prepare_match(high,b.config.player_id).ok and b.enqueue(high) and (await b.flush_one()),"publish higher win layer")
	var target=run.duplicate(true);target.wins=1;target.losses=0
	var nearest=await a.find_opponent(inv,target)
	ck(nearest.ok and nearest.opponent.leader=="lynae","nearest win layer chosen before account deduplication")
	var old_id=a.config.player_id
	ck((await a.ensure_identity()).ok and a.config.player_id==old_id and a.config.device.bound,"legacy migration keeps player")
	var token=a.config.token;a.config.expires_at=0
	ck((await a.ensure_identity()).ok and a.config.token==token,"session retry returns same active credential")
	var anon=N.new();root.add_child(anon);anon.configure(S.new("user://qa-v138-anon-"+P.random_id()+"/"));anon.config.url=fixture.base_url
	ck((await anon.ensure_identity()).ok and anon.ready_for_online(),"fresh install needs no invitation")
	var again=N.new();root.add_child(again);again.configure(anon.files)
	ck((await again.ensure_identity()).ok and again.config.player_id==anon.config.player_id,"restart retains installation identity")
	anon.queue_free();again.queue_free()
	a.queue_free();b.queue_free();print("async integration ",checks," checks, failures ",failures);quit(1 if failures else 0)
