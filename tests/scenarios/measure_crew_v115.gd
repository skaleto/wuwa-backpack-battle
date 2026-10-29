extends SceneTree
## Diagnostic experiment, not a pass/fail balance guarantee. Never touches Storage.
const I=preload('res://scripts/inventory/inventory.gd')
const B=preload('res://scripts/battle/battle.gd')
const C=preload('res://scripts/data/catalog.gd')
const A=preload('res://scripts/party/crew_abilities_v115.gd')
const REVIEW=preload('res://scripts/battle/battle_review.gd')
const LOADOUTS={
 'multi_weapon':['w_sword','w_sword','w_pistol','w_broadblade','whiff','daily_tea'],
 'echo_relay':['w_broadblade','w_pistol','whiff','whiff','echo_glacio','echo_glacio','turtle','daily_tea'],
 'sustain_slow':['w_broadblade','rocksteady','medical','turtle','salt_tea','tea','rations']
}
const FAMILY_REPRESENTATIVES={'charge':'role_1207','relay':'role_1302','stamina':'role_1410','guard':'role_1505','affliction':'role_1506'}
const SEEDS=[115,661,2026]
var inv=I.new();var battle=B.new();var checks=0;var failures=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr('MEASURE ERROR ',label)
func board(key:String,roles:Array=[])->Dictionary:
 var run=inv.new_run('aemeath',115);run.round=7;run.items=[];run.stash=[];run.bags=[];run.serial=100
 # Identical neutral bags avoid changing a role's value through pocket bonuses.
 for y in [0,2]:
  for x in [0,3,6]:
   var bag=inv.make_piece('satchel','bag_%s_%s'%[x,y]);bag.x=x;bag.y=y;run.bags.append(bag)
 run.roster=roles.duplicate();run.supports=roles.duplicate();run.recruited_round=7 if roles.size()>0 else 0
 run.recruitment={'version':115};run.primary=''
 for kind in LOADOUTS[key]:
  var p=inv.make_piece(kind,'i'+str(run.items.size()));var fit=inv.first_fit(p,run.items,run.bags)
  ck(not fit.is_empty(),'fixture fits '+key+' '+kind)
  if not fit.is_empty():run.items.append(fit)
 return run
func cost(run:Dictionary)->int:
 return run.items.reduce(func(total,p):return total+int(C.items[p.kind].price),0)
func overview(run:Dictionary)->Dictionary:
 return {'leader':run.leader,'item_cost':cost(run),'bag_cost':run.bags.reduce(func(total,p):return total+int(C.items[p.kind].price),0),'items':run.items.map(func(p):return {'uid':p.uid,'kind':p.kind,'name':C.items[p.kind].name,'price':C.items[p.kind].price,'x':p.x,'y':p.y,'rotation':p.rotation,'links':inv.star_links(p,run.items,run).map(func(other):return other.uid)}),'supports':run.supports}
func measure(ours:Dictionary,theirs:Dictionary,seed_value:int)->Dictionary:
 var before=[ours.duplicate(true),theirs.duplicate(true)]
 var result=battle.simulate(ours,theirs,seed_value,false)
 ck(ours==before[0] and theirs==before[1],'simulation leaves builds unchanged')
 var frame=result.frames[-1];var rows=REVIEW.rows(result,[ours,theirs],0,result.duration)
 var crew_rows=rows.filter(func(row):return str(row.uid).begins_with('crew:'))
 var triggers=result.events.filter(func(e):return e.side==0 and e.kind=='crew_trigger')
 var first={};var abilities={}
 for event in triggers:
  if not first.has(event.ability):first[event.ability]=event.time
  abilities[event.ability]=int(abilities.get(event.ability,0))+1
 return {'winner':result.winner,'duration':result.duration,'own_hp':frame.sides[0].hp,'enemy_hp':frame.sides[1].hp,'own_shield':frame.sides[0].shield,'damage':result.totals[0].damage,'healing':result.totals[0].heal,'shielding':result.totals[0].shield,'stamina_wait':result.totals[0].stamina_wait_seconds,'enemy_natural_attacks':result.events.filter(func(e):return e.side==1 and e.kind=='trigger' and e.get('ordinary',false)).size(),'crew_freezes':result.events.filter(func(e):return e.side==0 and e.kind=='freeze' and str(e.uid).begins_with('crew:')).size(),'enemy_stamina_wait':result.totals[1].stamina_wait_seconds,'natural_attacks':result.events.filter(func(e):return e.side==0 and e.kind=='trigger' and e.get('ordinary',false)).size(),'crew_rows':crew_rows,'triggers':abilities,'first_trigger':first,'damage_received':result.totals[1].damage,'hp_margin':float(frame.sides[0].hp)-float(frame.sides[1].hp)}
func delta(result:Dictionary,baseline:Dictionary)->Dictionary:
 var out={}
 for key in ['duration','own_hp','enemy_hp','damage','healing','shielding','stamina_wait','natural_attacks','hp_margin','damage_received']:out[key]=float(result[key])-float(baseline[key])
 out.winner=int(result.winner)-int(baseline.winner)
 return out
func _initialize()->void:
 var report={'simulation_version':C.SIMULATION_VERSION,'catalogue_hash':C.catalogue_hash,'companion_rules':A.profiles(),'full_team_rules':A.BONDS,'scope':'equal 20-coin items; six identical neutral satchels; leader aemeath; round 7; natural full combat; opponent one Shorekeeper companion; no injected combat stats','seeds':SEEDS,'loadouts':{},'baseline':[],'companions':[],'full_team':[],'determinism':{}}
 var roles=A.ROLES.keys().filter(func(role):return A.profile(role).family!='economy')
 for loadout in LOADOUTS:
  var run=board(loadout);ck(cost(run)==20,'all item budgets exactly 20')
  report.loadouts[loadout]=overview(run)
 var deterministic=true
 for ours_key in LOADOUTS:
  for enemy_key in LOADOUTS:
   var enemy=board(enemy_key,['role_1505']);var baseline=measure(board(ours_key),enemy,SEEDS[0])
   report.baseline.append({'loadout':ours_key,'opponent':enemy_key,'result':baseline})
   for role in roles:
    var run=board(ours_key,[role]);var result=measure(run,enemy,SEEDS[0])
    for other_seed in SEEDS.slice(1):
     var repeated=measure(run,enemy,other_seed)
     if repeated!=result:deterministic=false
    report.companions.append({'loadout':ours_key,'opponent':enemy_key,'role':role,'name':A.profile(role).name,'family':A.profile(role).family,'ready':A.ready(role,run),'result':result,'delta_vs_no_companion':delta(result,baseline)})
   for family in FAMILY_REPRESENTATIVES:
    var role=FAMILY_REPRESENTATIVES[family]
    # First teammate's economic benefit is not converted into extra items here;
    # keeping identical boards isolates the extra full-team combat rule.
    var base=measure(board(ours_key,[role]),enemy,SEEDS[0])
    var full=measure(board(ours_key,['role_1106',role]),enemy,SEEDS[0])
    report.full_team.append({'loadout':ours_key,'opponent':enemy_key,'family':family,'role':role,'result':full,'delta_vs_same_base':delta(full,base)})
 for family in FAMILY_REPRESENTATIVES:
  ck(report.full_team.any(func(row):return row.family==family and int(row.result.triggers.get('full_'+family,0))>0),'natural battle activates full-team '+family)
 report.determinism={'identical_across_seeds':deterministic,'unique_item_matchups':9,'single_companion_cases':report.companions.size(),'full_team_cases':report.full_team.size(),'seed_repeats_are_not_independent_balance_samples':true}
 report.checks=checks;report.failures=failures
 var target='res://build/qa/recruitment-v115/crew-value-measurement.json'
 var file=FileAccess.open(target,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(report,'\t'));file.close()
 else:ck(false,'write measurement report')
 print('CREW_MEASUREMENT_V115 ',checks,' checks, ',failures,' failures; 90 companion cases + 45 full-team cases; deterministic=',deterministic)
 quit(1 if failures else 0)
