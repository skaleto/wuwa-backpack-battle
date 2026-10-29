extends SceneTree
const I=preload("res://tests/fixtures/recruitment_fixture_v113.gd")
const S=preload("res://scripts/run/run_session.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run_tests")
# Frozen against the pre-V78 source copy before extraction; never regenerated
# from the implementation under test. JSON normalization matches fixture numbers.
func observations()->Array:
	var out:Array=[]
	for leader in I.C.characters:
		for seed_value in [19,8765]:
			var run=inv.new_run(leader,seed_value);run.gold=200
			out.append(run.duplicate(true))
			for index in 3:
				out.append(inv.toggle_lock(run,index));out.append(run.duplicate(true))
			out.append(inv.refresh(run,true));out.append(run.duplicate(true))
			for index in 5:
				out.append(inv.buy(run,index));out.append(run.duplicate(true))
			if not run.stash.is_empty():
				var piece=run.stash[0].duplicate(true)
				piece.x=0;piece.y=0
				out.append(inv.placement_preview(run,piece))
				out.append(inv.place(run,piece));out.append(run.duplicate(true))
			out.append(inv.stash_preview(run,run.bags[0]));out.append(inv.stash(run,run.bags[0]));out.append(run.duplicate(true))
			if not run.stash.is_empty():out.append(inv.sell(run,run.stash[0]));out.append(run.duplicate(true))
			for winner in [1,0,-1,1]:
				run.phase="result";run.combat={"used":[["i2"],[]]}
				out.append(inv.finish(run,winner));out.append(run.duplicate(true))
				var candidates=I.SUP.candidates(run)
				if not candidates.is_empty():out.append(inv.recruit(run,candidates[0]));out.append(run.duplicate(true))
				out.append(inv.set_supports(run,run.roster.slice(0,1)));out.append(run.duplicate(true))
				out.append(inv.refresh(run,true));out.append(run.duplicate(true))
	return out
func run_tests():
	var observed=JSON.parse_string(JSON.stringify(observations()))
	var expected=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/operations_v77_behavior.json"))
	ck(observed.size()==expected.size(),"frozen operation count")
	for n in mini(observed.size(),expected.size()):ck(JSON.stringify(observed[n])==JSON.stringify(expected[n]),"V77 operation equivalence %d"%n)
	if inv.has_method("plan_buy"):boundaries()
	print("OPERATIONS_V78: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
var saves=0
func saved(snapshot:Dictionary):
	saves+=1
	snapshot.gold=-777 # Persistence receives isolated data.
func base()->Dictionary:
	var run=inv.new_run("aemeath",19);run.gold=100
	return run
func exercise(label:String,run:Dictionary,prepare:Callable,legacy:Callable,allowed:bool=true):
	var before=run.duplicate(true)
	var plan:Dictionary=prepare.call(run)
	ck(plan.ok==allowed,label+" planned availability")
	ck(run==before,label+" preview leaves all state unchanged")
	var expected=before.duplicate(true)
	var legacy_value=legacy.call(expected)
	ck(plan.run==expected and plan.value==legacy_value,label+" shares exact legacy rules and result")
	var stale=before.duplicate(true);stale.gold+=1
	var stale_before=stale.duplicate(true);var count=saves
	ck(not S.commit(stale,plan,inv.validate_run,saved).ok and stale==stale_before and saves==count,label+" stale rejects atomically")
	var bad=plan.duplicate(true);bad.run.gold=-1
	ck(not S.commit(run,bad,inv.validate_run,saved).ok and run==before and saves==count,label+" invalid candidate never saves")
	var result=S.commit(run,plan,inv.validate_run,saved)
	ck(result.ok==allowed and run==expected and saves==count+(1 if allowed else 0),label+" commits once and saves isolated snapshot")
	var committed=run.duplicate(true)
	plan.run.gold=-2
	if result.get("value") is Dictionary:result.value.clear()
	if result.get("piece") is Dictionary:result.piece.clear()
	ck(run==committed,label+" plan and event data cannot mutate committed state")
	ck(not S.commit(run,plan,inv.validate_run,saved).ok and run==committed and saves==count+(1 if allowed else 0),label+" repeated confirmation cannot spend or save again")
func boundaries():
	var run=base()
	exercise("buy",run,func(r):return inv.plan_buy(r,0),func(r):return inv.buy(r,0))
	run=base();run.shop[0]={"kind":"mat_43020011","locked":false}
	var piece=inv.make_piece("mat_43020011","preview")
	exercise("direct purchase displaces",run,func(r):return inv.plan_purchase_at(r,0,piece,"board"),func(r):return inv.purchase_at(r,0,piece,"board"))
	run=base();run.shop[0]={"kind":"mat_43020011","locked":false}
	exercise("stash purchase",run,func(r):return inv.plan_purchase_at(r,0,piece,"stash"),func(r):return inv.purchase_at(r,0,piece,"stash"))
	run=base();var bag=run.bags[0].duplicate(true);bag.x=1;bag.rotation=1
	exercise("bag transport",run,func(r):return inv.plan_place(r,bag),func(r):return inv.place(r,bag))
	run=base();bag=run.bags[0].duplicate(true)
	exercise("bag stash",run,func(r):return inv.plan_stash(r,bag),func(r):return inv.stash(r,bag))
	run=base();var sold=run.items[-1].duplicate(true)
	exercise("sell",run,func(r):return inv.plan_sell(r,sold),func(r):return inv.sell(r,sold))
	run=base();run.items=[];run.primary="";run.bags[0].paid_cost=10;run.shop[5]={"kind":"pouch","locked":false}
	exercise("replacement",run,func(r):return inv.plan_replace_bag(r,"b1","pouch",0),func(r):return inv.replace_bag(r,"b1","pouch",0))
	run=base();run.refreshes=1
	exercise("refresh",run,func(r):return inv.plan_refresh(r,true),func(r):return inv.refresh(r,true))
	run=base()
	exercise("lock",run,func(r):return inv.plan_toggle_lock(r,0),func(r):return inv.toggle_lock(r,0))
	run=base();run.shop[5]={"kind":"strip","locked":false}
	exercise("bag offer",run,func(r):return inv.plan_set_bag_offer(r,"pouch"),func(r):return inv.set_bag_offer(r,"pouch"),false)
	run=base();run.round=2;var role=I.SUP.candidates(run)[0]
	exercise("recruit",run,func(r):return inv.plan_recruit(r,role),func(r):return inv.recruit(r,role))
	run=base();run.round=2;inv.recruit(run,role)
	exercise("supports",run,func(r):return inv.plan_set_supports(r,[]),func(r):return inv.set_supports(r,[]))
	run=base();run.serial=3;run.pending_gifts=[inv.make_piece("nutrition","i3")]
	exercise("pending gift",run,func(r):return inv.plan_claim_pending(r),func(r):inv.claim_pending(r);return null)
	run=base();run.phase="result";run.combat={"used":[["i2"],[]]}
	exercise("round finish",run,func(r):return inv.plan_finish(r,1),func(r):return inv.finish(r,1))
	# Operation rejection returns the complete original snapshot and spends no UID.
	run=base();run.gold=0;var before=run.duplicate(true)
	var denied=inv.plan_buy(run,0)
	ck(not denied.ok and denied.run==before and run==before,"unaffordable purchase plan rolls back")
	var count=saves
	ck(not S.commit(run,denied,inv.validate_run,saved).ok and saves==count and run==before,"rejected purchase never persists")
	run=base();run.serial=inv.MAX_SERIAL;before=run.duplicate(true)
	ck(not inv.plan_buy(run,0).ok and run==before,"exhausted UID counter is untouched")
	# Partial construction snapshots retain the historical refresh contract.
	var partial={"phase":"shop","leader":"aemeath","round":1,"gold":9,"seed":19,"items":[],"bags":[],"stash":[],"shop":[],"roster":[],"supports":[]}
	before=partial.duplicate(true);var preview=inv.plan_refresh(partial)
	ck(preview.ok and partial==before,"partial helper preview remains pure")
	ck(inv.refresh(partial) and partial==preview.run,"partial construction still refreshes")
