extends SceneTree
const I=preload('res://tests/fixtures/recruitment_fixture_v114.gd')
const R=preload('res://scripts/party/recruitment_v114.gd')
const C=preload('res://scripts/data/catalog.gd')
const S=preload('res://scripts/storage/storage.gd')
const PB=preload('res://scripts/shop/practice_budget.gd')
var checks=0;var failures=0
func ck(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 var inv=I.new();var storage=S.new('/tmp/resonance-v114-migration-'+str(Time.get_ticks_usec()))
 var original=inv.new_run('jiyan',114);original.erase('recruitment');original.catalogue_hash=C.common_hash;original.simulation_version='resonance-v113';original.round=4;original.gold=17;original.phase='result'
 original.history=[{'round':3,'winner':1,'totals':{'damage':30.5}}];original.combat={'winner':1,'duration':8.4,'frames':[{'t':1}],'totals':[{},{}]}
 original.roster=['role_1302','role_1105'];original.supports=original.roster.duplicate();original.recruited_round=4
 storage.write_json(storage.root_path+'run.json',original);var bytes=FileAccess.get_file_as_bytes(storage.root_path+'run.json');var migrated=storage.resume()
 ck(not migrated.is_empty() and migrated.get('recruitment_legacy',false) and not R.enabled(migrated),'old run explicitly keeps earned V113 rules until ending')
 if not migrated.is_empty():
  for key in ['items','stash','bags','gold','history','combat','wins','losses','round','shop','seed']:
   ck(JSON.parse_string(JSON.stringify(migrated[key]))==JSON.parse_string(JSON.stringify(original[key])),'migration preserves '+key)
  ck(migrated.simulation_version=='resonance-v113','earned simulation provenance unchanged')
  ck(FileAccess.get_file_as_bytes(storage.root_path+'run-before-v114-backup.json')==bytes,'migration preserves exact source backup')
  ck(storage.resume()==migrated,'migration is restart idempotent')
  var legacy_enemy=storage.opponent(migrated)
  ck(not R.enabled(legacy_enemy) and legacy_enemy.simulation_version==C.SIMULATION_VERSION+'-crew113','legacy run receives original crew with current spatial-rule opponent')
  ck(migrated.roster==original.roster and migrated.supports==original.supports,'historical purchased crew preserved without silent downgrades')
 var legacy=inv.new_run('aemeath',114);legacy.erase('recruitment');legacy.simulation_version='resonance-v113'
 var exported=inv.snapshot(legacy,'old-export');exported.catalogue_hash=C.common_hash
 var export_path=storage.root_path+'v113-export.json';storage.write_json(export_path,exported)
 var export_bytes=FileAccess.get_file_as_bytes(export_path)
 var imported=storage.import_ghost(export_path)
 ck(not imported.is_empty() and imported.get('recruitment_legacy',false) and imported.simulation_version=='resonance-v113','V113 file import uses same migration as saved ghost pool')
 if not imported.is_empty():
  ck(imported.items==exported.items and imported.roster==exported.roster and imported.supports==exported.supports,'import migration preserves owned inventory and crew')
 ck(FileAccess.get_file_as_bytes(export_path)==export_bytes,'import never rewrites original exported file')
 var early=inv.new_run('jiyan',114);early.erase('recruitment');early.recruitment_legacy=true;early.simulation_version='resonance-v113'
 var application=preload('res://scripts/run/run_application.gd').new(inv,storage,null)
 var resumed=application.resume(early)
 ck(not R.enabled(resumed.opponent) and resumed.opponent.simulation_version==C.SIMULATION_VERSION+'-crew113','application resume keeps early legacy crew while using current spatial rules')
 var r=inv.new_run('jiyan',114);r.round=3;r.phase='result';r.wins=1;r.losses=1;r=inv.plan_finish(r,1).run;storage.save(r);var loaded=storage.resume()
 ck(loaded==r and loaded.recruitment.candidates==r.recruitment.candidates,'draft candidates persist unchanged across restart')
 for seed in 8:
  var ai=PB.make_run(inv,7,seed)
  ck(ai.supports.size()==2 and ai.roster==ai.supports,'AI recruits two free active seats at same nodes '+str(seed))
  var recruit=ai.practice_ledger.filter(func(e):return e.purpose=='recruit')
  ck(recruit.size()==2 and recruit[0].node==3 and recruit[1].node==6 and recruit.all(func(e):return e.gold==0),'AI ledger records exact free node choices '+str(seed))
  ck(ai.practice_spend+ai.gold==ai.practice_budget,'AI spending and explicit rewards conserve budget '+str(seed))
 # JSON numbers are floats on reload; completed-node membership must remain valid.
 for role in R.PRIMARY_ROLES:
  var confirmed=inv.new_run('aemeath',114);confirmed.round=4
  R.open_draft(inv,confirmed,3)
  if role not in confirmed.recruitment.candidates:confirmed.recruitment.candidates[0]=role
  var commit=inv.commit_operation(confirmed,R.plan_confirm(inv,confirmed,role))
  ck(commit.ok,'first draft confirmation fixture '+role)
  var parsed=JSON.parse_string(JSON.stringify(confirmed))
  ck(inv.validate_run(parsed),'post-confirm serialized state validates before normalization '+role)
  storage.save(confirmed)
  ck(storage.resume()==confirmed,'post-confirm specialty shop survives restart '+role)
  var invalid=parsed.duplicate(true);invalid.recruitment.done=[3.5]
  ck(not inv.validate_run(invalid),'fractional completed node remains invalid '+role)
  invalid=parsed.duplicate(true);invalid.recruitment.done=[3,3.0]
  ck(not inv.validate_run(invalid),'mixed numeric representations cannot duplicate completed node '+role)
  confirmed.round=7;R.open_draft(inv,confirmed,6)
  var second=R.card_models(inv,confirmed)[0]
  var gift=second.reward_choices[0].kind if not second.reward_choices.is_empty() else 'gold' if second.gold_fallback else ''
  commit=inv.commit_operation(confirmed,R.plan_confirm(inv,confirmed,second.role_id,gift))
  ck(commit.ok and inv.validate_run(JSON.parse_string(JSON.stringify(confirmed))),'two completed nodes survive JSON validation '+role)
  storage.save(confirmed)
  ck(storage.resume()==confirmed,'second companion and actual gift survive restart '+role)
 var supplier=inv.new_run('aemeath',114);supplier.round=4;supplier.roster=['role_1504'];supplier.supports=supplier.roster.duplicate();supplier.recruited_round=4;supplier.gold=20;supplier.practice_ledger=[]
 var supply_before=int(supplier.gold)
 ck(PB.directed_refresh(inv,supplier) and supplier.gold==supply_before-1,'AI supply policy uses the same paid targeted transaction')
 ck(supplier.practice_ledger.size()==1 and supplier.practice_ledger[0].gold==1 and supplier.practice_ledger[0].has('offer'),'AI targeted refresh is explicitly recorded without unpaid grants')
 ck(not PB.directed_refresh(inv,supplier),'AI cannot target twice in the same round')
 print('MIGRATION_RECRUITMENT_V114 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
