extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
const A=preload("res://scripts/online/async_run_application.gd")
const P=preload("res://scripts/online/async_pvp.gd")
const C=preload("res://scripts/data/catalog.gd")
const B=preload("res://scripts/battle/battle.gd")
var failures=0
var checks=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
	var inv=I.new();var s=S.new("user://qa-v134-storage-"+P.random_id()+"/");var app=A.new(inv,s,B.new());var run=app.start("aemeath",19).run
	app.prepare_match(run,"alice");var pending=s.resume()
	ck(not pending.is_empty() and pending.pvp.frozen==run.pvp.frozen,"frozen bytes survive JSON reload")
	ck(typeof(pending.recruitment.version)==TYPE_INT,"recruitment integers normalized on resume")
	var broken=run.duplicate(true);broken.pvp.sha256="a".repeat(64);s.write_json(s.root_path+"run.json",broken)
	ck(s.resume().is_empty(),"corrupt frozen snapshot rejected")
	broken=run.duplicate(true);broken.catalogue_hash=C.v128_hash;s.write_json(s.root_path+"run.json",broken)
	ck(s.resume().is_empty() and s.read_json(s.root_path+"run.json",{}).catalogue_hash==C.v128_hash,"online run never silently migrated to new rules pool")
	var final_run=app.start("aemeath",71).run;final_run.round=4;final_run.wins=0;final_run.losses=3
	app.prepare_match(final_run,"alice");var bot=inv.practice(4,11,"full",int(final_run.supply_version))
	app.lock_opponent(final_run,bot,"bot","empty_pool");app.begin(final_run,bot)
	final_run.combat.winner=-1;app.finish_replay(final_run);app.advance(final_run,final_run.combat)
	app.preserve_result(final_run);var reloaded=s.resume();app.preserve_result(reloaded)
	var history=s.battle_history(reloaded)
	ck(history.size()==1 and history[0].pvp_source=="bot","ending archive remains one record with source after reload")
	# Force wins only to exercise both draft nodes; this is not a balance test.
	var campaign=app.start("hsin",31).run;var drafts=0
	for round_number in range(1,9):
		if campaign.phase=="recruit":
			campaign=s.resume();var cards=preload("res://scripts/party/recruitment.gd").card_models(inv,campaign)
			ck(app.confirm_recruit(campaign,cards[0].role_id).ok,"recruit after restart at round "+str(round_number));drafts+=1
		ck(app.prepare_match(campaign,"alice").ok,"later-round freeze")
		campaign=s.resume();var peer=inv.snapshot(campaign,"bob")
		ck(app.lock_opponent(campaign,peer,"player").ok,"later-round peer lock")
		campaign=s.resume();ck(app.begin(campaign,campaign.opponent).ok,"locked restart then simulation")
		campaign.combat.winner=1;app.finish_replay(campaign);campaign=s.resume()
		ck(app.advance(campaign,campaign.combat).ok,"later-round durable settlement")
	ck(drafts==2 and campaign.phase=="ending" and campaign.wins==8,"both recruitment nodes complete with restarts")
	print("async storage ",checks," checks, failures ",failures);quit(1 if failures else 0)
