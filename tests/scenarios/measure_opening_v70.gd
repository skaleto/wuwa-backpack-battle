extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const S=preload("res://scripts/storage/storage.gd")
const PB=preload("res://scripts/shop/practice_budget.gd")
const OLD=preload("res://tests/fixtures/practice_before_v70.gd")
func _initialize():call_deferred("measure")
func measure():
	var inv=I.new();var rows=[]
	var s=S.new("/tmp/resonance-v70-timing-%d"%OS.get_process_id())
	for seed_value in [2,13,30]:
		var start=Time.get_ticks_usec();var run=inv.new_run("aemeath",seed_value)
		var new_ms=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();var old=OLD.make_run(inv,1,int(run.seed)%31)
		var old_ms=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();var enemy=s.opponent(run)
		var new_opponent_ms=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();s.save(run)
		var save_ms=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();s.opponent(run)
		var cached_ms=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();var old_r3=OLD.make_run(inv,3,int(run.seed)%31)
		var old_r3_ms=(Time.get_ticks_usec()-start)/1000.0
		start=Time.get_ticks_usec();var new_r3=PB.make_run(inv,3,int(run.seed)%31)
		var new_r3_ms=(Time.get_ticks_usec()-start)/1000.0
		var arrangement=old_r3.duplicate(true)
		start=Time.get_ticks_usec();OLD.arrange(inv,arrangement)
		var arrange_old_ms=(Time.get_ticks_usec()-start)/1000.0
		arrangement=old_r3.duplicate(true)
		start=Time.get_ticks_usec();PB.arrange(inv,arrangement)
		var arrange_new_ms=(Time.get_ticks_usec()-start)/1000.0
		var row={"seed":seed_value,"new_run_ms":new_ms,"cached_ms":cached_ms,"old_r3_ms":old_r3_ms,"new_r3_ms":new_r3_ms,"arrange_old_ms":arrange_old_ms,"arrange_new_ms":arrange_new_ms,"old_opponent_ms":old_ms,"opponent_ms":new_opponent_ms,"save_ms":save_ms,"old_items":old.items.map(func(v):return v.kind),"items":enemy.items.map(func(v):return v.kind)}
		print(JSON.stringify(row));rows.append(row)
	var f=FileAccess.open("res://build/qa/ui-v70/checks/timing.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"\t"));f.close()
	quit()
