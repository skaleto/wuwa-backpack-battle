extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const C=preload('res://scripts/data/catalog.gd')
const R=preload('res://scripts/party/recruitment_v115.gd')
const F=preload('res://scripts/party/recruitment.gd')
const A=preload('res://scripts/party/crew_abilities_v115.gd')
const S=preload('res://scripts/storage/storage.gd')
var inv=I.new();var checks=0;var errors=0
func ck(ok,label):
 checks+=1
 if not ok:errors+=1;printerr('FAIL ',label)
func selected(role:String)->Dictionary:
 var r=inv.new_run('aemeath',115);r.round=4;R.open_draft(inv,r,3)
 r.recruitment.candidates=[role]+R.pool(r).filter(func(p):return p!=role).slice(0,2)
 var p=R.plan_confirm(inv,r,role)
 ck(p.get('ok',false),'candidate transaction '+role)
 return p.get('run',r)
func _initialize():
 ck(C.selectable_leaders()==['aemeath','hsin','jingran','zani','lynae'],'five starters')
 var weapons=[]
 for id in C.selectable_leaders():
  var run=inv.new_run(id,115);weapons.append(C.characters[id].weapon_type)
  ck(run.recruitment.version==115 and inv.validate_run(run),'new run '+id)
  ck(R.pool(run).size()==(11 if id=='lynae' else 12),'shared pool excludes only self')
  for k in ['w_sword','w_pistol','w_broadblade','w_gauntlet','w_rectifier']:ck(inv.craft_unlocked(run,k),'all weapons remain open')
  run.round=3;run.phase='result';run.wins=1;run.losses=1
  var plan=inv.plan_finish(run,1)
  ck(plan.ok and plan.run.phase=='recruit' and plan.run.round==4,'round3 lifecycle')
  run=plan.run;var before=run.duplicate(true)
  var cards=R.card_models(inv,run)
  ck(cards.size()==3 and run==before,'pure three cards')
  ck(cards.any(func(c):return c.usable),'at least one usable candidate')
  var restored=JSON.parse_string(JSON.stringify(run))
  ck(inv.validate_run(restored) and restored.recruitment.candidates==run.recruitment.candidates,'draft survives JSON')
  var card=cards[0];var confirm=R.plan_confirm(inv,run,card.role_id)
  ck(confirm.ok and confirm.run.supports==[card.role_id],'single choice')
  ck(confirm.run.gold==run.gold+(2 if card.family=='economy' else 0),'recruit free, explicit economic gift')
  ck(not R.plan_confirm(inv,confirm.run,card.role_id).get('ok',false),'duplicate rejected')
  var changed=run.duplicate(true);changed.gold+=1;var unchanged=changed.duplicate(true)
  ck(not inv.commit_operation(changed,confirm).ok and changed==unchanged,'stale preserves whole state')
  run=confirm.run;run.round=7
  ck(R.open_draft(inv,run,6),'round6 offers')
  ck(run.recruitment.candidates.all(func(role):return role not in run.roster and role!=C.characters[id].roster_id),'no duplicate identities')
  var second=R.plan_confirm(inv,run,run.recruitment.candidates[0]);ck(second.ok,'second accepted')
  run=second.run;ck(inv.validate_run(run) and run.supports.size()==2 and not R.full_team(run).is_empty(),'full team')
  ck(F.crew_setup_choices(inv,run).values().all(func(v):return v.is_empty()) and not F.plan_configure(inv,run,{'volley':['i1','i2']}).ok,'no targeting steps')
  ck(A.profile(run.supports[0])==A.profile(confirm.run.supports[0]),'first base remains same')
 ck(weapons.size()==5 and weapons.all(func(w):return weapons.count(w)==1),'one weapon type each')
 var economy=selected('role_1504');economy.refreshes=0
 for n in 3:
  var gold=economy.gold;var ok=inv.refresh(economy,true)
  ck(ok and economy.gold==gold-(1 if n==2 else 0),'Dengdeng two free then paid')
 var crafts=selected('role_1106');var base=crafts.duplicate(true)
 base.stash.append(inv.make_piece('mat_43020011','i50'));base.serial=50
 var next=base.duplicate(true);next.stash=[]
 R.after_craft(inv,base,next,['i50'],{})
 ck(next.stash.size()==1 and int(next.recruitment.return_round)==4,'automatic consumed-material return')
 var once=next.duplicate(true);R.after_craft(inv,once,next,['i50'],{})
 ck(next==once,'return only once per round')
 var same=selected('role_1509');same.round=7;R.open_draft(inv,same,6);same.recruitment.candidates=['role_1207','role_1209','role_1505']
 ck(R.plan_confirm(inv,same,'role_1207').ok,'same-family substitutions may team freely')
 var frozen=same.duplicate(true);frozen.recruitment.config={'volley':['i1','i2']};ck(not inv.validate_run(frozen),'new manual state rejected')
 var legacy=preload('res://tests/fixtures/recruitment_fixture_v114.gd').new().new_run('jiyan',114)
 var old=legacy.duplicate(true);old.catalogue_hash=C.v114_hash
 var path='user://qa-v115-migration-'+str(OS.get_process_id())+'/';var storage=S.new(path)
 storage.write_json(path+'run.json',old);var loaded=storage.resume()
 ck(not loaded.is_empty() and loaded.recruitment==old.recruitment and loaded.items==old.items and loaded.seed==old.seed,'old run preserved')
 ck(FileAccess.file_exists(path+'run-before-v115-backup.json'),'old run backed up')
 ck(F.simulation_version(loaded)==C.SIMULATION_VERSION+'-crew114','old crew abilities retain a distinct current battle version')
 var bad=old.duplicate(true);bad.recruitment.version=999;ck(storage.migrate_v115(bad).is_empty(),'invalid source refused')
 # A real craft returns its exact consumed material through the unified transaction.
 var real=selected('role_1106');real.stash=real.items.filter(func(p):return p.kind!='w_sword')
 real.items=real.items.filter(func(p):return p.kind=='w_sword')
 var material=inv.make_piece('mat_43020011','i50');material.x=0;material.y=1;material.paid_cost=3
 real.items.append(material);real.serial=50
 var recipe=C.combinations.filter(func(r):return r.base=='w_sword' and r.materials[0]=='mat_43020011')[0]
 var craft=preload('res://scripts/crafting/craft.gd').transact(real,recipe.target,'i1',inv)
 ck(craft.ok and craft.crew_rewards.size()==1 and craft.crew_rewards[0].kind=='mat_43020011','actual fusion returns consumed ingredient')
 ck(craft.crew_rewards[0].paid_cost==0 and inv.validate_run(real),'free returned material creates no paid resale basis')
 # Current and historical opponents remain separate even on manual import.
 var app=preload('res://scripts/run/run_application.gd').new(inv,storage,null)
 var live=inv.new_run('aemeath',115);live.round=4
 legacy.round=4
 var historical=inv.snapshot(legacy,'other-owner','historical');historical.catalogue_hash=C.v114_hash
 storage.write_json(path+'historical.json',historical)
 storage.write_json(path+'ghosts.json',[])
 var preserved=live.duplicate(true)
 ck(app.import_opponent(live,path+'historical.json').status=='version' and live==preserved and storage.pool().is_empty(),'mixed-version import rejects without publishing or run mutation')
 var matching=app.import_opponent(legacy,path+'historical.json')
 ck(matching.status=='version' and storage.pool().is_empty(),'old crew cannot mix historical pocket rules with current battles')
 var compatible=inv.snapshot(legacy,'other-current-owner','current crew114');compatible.simulation_version=F.simulation_version(legacy)
 storage.write_json(path+'current-crew114.json',compatible)
 matching=app.import_opponent(legacy,path+'current-crew114.json')
 ck(matching.status=='ready' and storage.pool().size()==1,'same-version current crew114 import accepted')
 var chosen=storage.opponent(legacy)
 ck(chosen.source=='saved' and chosen.simulation_version==C.SIMULATION_VERSION+'-crew114','old crew uses actual player ghosts with matching current combat rules')
 var current_enemy=storage.opponent(live)
 ck(current_enemy.simulation_version==C.SIMULATION_VERSION and current_enemy.source=='practice','new run ignores different-crew player ghost')
 var resumed=app.resume(legacy)
 ck(resumed.opponent.simulation_version==C.SIMULATION_VERSION+'-crew114','application resume retains original crew ability version')
 print('RECRUITMENT_V115 ',checks,' checks, ',errors,' failures');quit(1 if errors else 0)
