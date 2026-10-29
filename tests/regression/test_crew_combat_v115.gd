extends SceneTree
const I=preload('res://scripts/inventory/inventory.gd')
const B=preload('res://scripts/battle/battle.gd')
const FIX=preload('res://tests/fixtures/capacity_fixture_v111.gd')
var inv=I.new();var battle=B.new();var checks=0;var failures=0
var rules
var combat
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func board(kinds:Array,roles:Array=[])->Dictionary:
 var r=inv.new_run('aemeath',115);r.round=8;r.items=[];r.stash=[];r.bags=FIX.full_bags(inv);r.serial=100
 r.roster=roles.duplicate();r.supports=roles.duplicate();r.recruited_round=7 if roles.size()>0 else 0
 r.recruitment={'version':115};r.primary=''
 for kind in kinds:
  var p=inv.make_piece(kind,'i'+str(r.items.size()));var fit=inv.first_fit(p,r.items,r.bags)
  ck(not fit.is_empty(),'fixture fits '+kind)
  if not fit.is_empty():r.items.append(fit)
 return r
func context(kinds:Array,roles:Array=[])->Dictionary:
 var ctx=battle.begin(board(kinds,roles),board(['w_sword','w_sword']),17)
 for state in ctx.states:state.hp=9000;state.max_hp=10000
 return ctx
func run_for(ctx:Dictionary,seconds:float)->void:
 for n in int(seconds*10):battle.step(ctx,(n+1)*.1)
func crew_events(ctx:Dictionary,role:String,ability:String='')->Array:
 return ctx.events.filter(func(e):return e.kind=='crew_trigger' and e.get('role_id','')==role and (ability.is_empty() or e.get('ability','')==ability))
func _initialize()->void:
 var exists=ResourceLoader.exists('res://scripts/party/crew_abilities_v115.gd')
 ck(exists,'independent automatic ability specification exists')
 var cases={
  'role_1509':['dual_charge',['w_sword','whiff']],
  'role_1207':['triple_charge',['w_sword']],
  'role_1302':['echo_relay',['w_sword','whiff']],
  'role_1211':['weapon_relay',['w_sword','whiff']],
  'role_1209':['timed_stamina',['w_sword','w_sword','w_sword']],
  'role_1410':['spent_stamina',['w_sword','w_sword','w_sword']],
  'role_1505':['timed_heal',['w_sword']],
  'role_1607':['echo_heal',['whiff']],
  'role_1506':['weapon_noise',['w_sword']],
  'role_1110':['weapon_frost',['w_sword']]}
 for role in cases:
  var ctx=context(cases[role][1],[role]);var before=ctx.builds[0].duplicate(true);run_for(ctx,24)
  ck(not crew_events(ctx,role,cases[role][0]).is_empty(),'ordinary items activate independent ability '+role)
  ck(ctx.builds[0]==before,'combat preserves build '+role)
 if exists:
  rules=load('res://scripts/party/crew_abilities_v115.gd');combat=load('res://scripts/party/crew_battle_v115.gd')
  detailed_contracts()
 print('CREW_COMBAT_V115 ',checks,' checks, ',failures,' failures')
 quit(1 if failures else 0)
func detailed_contracts()->void:
 ck(rules.ROLES.size()==12,'twelve explicit independent companion profiles')
 for role in rules.ROLES:
  var spec=rules.profile(role)
  for field in ['role_id','name','ability_id','family','ability_name','base_text','base_short','tradeoff','supply_group','icon_id','bond_name','bond_text','bond_short']:
   ck(spec.has(field),'profile field '+role+' '+field)
 var plain=board(['w_sword','whiff'])
 for role in rules.ROLES:ck(rules.ready(role,plain),'ordinary weapon and echo make base ability usable '+role)
 ck(not rules.ready('role_1302',board(['w_sword','violet'])),'counter-only echo cannot receive clock advance')
 ck(rules.full_team(board([],['role_1106'])).is_empty(),'one recruited teammate has no full-team effect')
 for role in rules.ROLES:
  var other='role_1504' if role!='role_1504' else 'role_1106'
  ck(rules.full_team(board([], [other,role])).family==rules.profile(role).family,'second recruit chooses full-team family '+role)
 test_precise_spending();test_heal_overflow();test_root_boundaries();test_full_team();test_symmetry();test_review_edges();test_revised_strength();test_continuous_remainders();test_noise_pacing()
func test_precise_spending()->void:
 var ctx=context([],['role_1410']);ctx.states[0].stamina=3
 combat.record_spent(ctx,0,4.0,1,'paid')
 combat.process(battle,ctx,1)
 ck(is_equal_approx(float(ctx.states[0].stamina),3.8),'refund follows exact gross payment')
 combat.process(battle,ctx,1)
 ck(is_equal_approx(float(ctx.states[0].stamina),3.8),'processed spending cannot refund twice')
 ctx.states[0].stamina=1;combat.process(battle,ctx,4)
 ck(is_equal_approx(float(ctx.states[0].stamina),1),'balance drop alone is not proof of spending')
 combat.record_spent(ctx,0,3.9,4,'paid');combat.process(battle,ctx,4)
 ck(is_equal_approx(float(ctx.states[0].stamina),1),'fractional spending threshold is exact')
 combat.record_spent(ctx,0,.1,4.1,'paid');combat.process(battle,ctx,4.1)
 ck(is_equal_approx(float(ctx.states[0].stamina),1.8),'actual fourth point refunds exactly 0.8')
 var r=board(['w_sword','w_sword','w_sword'],['role_1410']);ctx=battle.begin(r,board([]));run_for(ctx,12)
 ck(not crew_events(ctx,'role_1410','spent_stamina').is_empty(),'natural weapon payment feeds exact spending hook')
func test_heal_overflow()->void:
 var ctx=context([],['role_1505']);ctx.states[0].hp=10000;ctx.states[0].shield=0
 combat.process(battle,ctx,4)
 ck(is_equal_approx(float(ctx.states[0].shield),1),'full-health two-heal converts only one shield')
 ck(not ctx.events.any(func(e):return e.kind=='heal' and e.uid=='crew:role_1505'),'full health has no fictional heal statistic')
 ctx.states[0].hp=9999;ctx.states[0].shield=0;combat.process(battle,ctx,8)
 ck(is_equal_approx(float(ctx.states[0].hp),10000) and is_equal_approx(float(ctx.states[0].shield),.5),'actual deficit and overflow split exactly')
func test_root_boundaries()->void:
 var ctx=context(['w_sword','whiff'],['role_1207']);ctx.states[0].charge=0
 for n in 6:battle.activate(ctx,0,ctx.builds[0].items[0],float(n+1),false)
 battle.commit_pending(ctx,6);combat.process(battle,ctx,6)
 ck(crew_events(ctx,'role_1207').is_empty(),'derived attacks cannot charge natural-attack counter')
 for n in 3:
  combat.record_attack(ctx,0,ctx.builds[0].items[0],float(n+7),{})
  combat.record_attack(ctx,0,ctx.builds[0].items[0],float(n+7),{})
 combat.process(battle,ctx,9)
 ck(crew_events(ctx,'role_1207','triple_charge').size()==1,'one multi-segment natural activation counts once')
 ck(is_equal_approx(float(ctx.states[0].charge),2),'three natural attacks grant two charge')
 combat.process(battle,ctx,10)
 ck(crew_events(ctx,'role_1207').size()==1,'crew output cannot self-retrigger')
 var both=context(['w_sword'],['role_1106','role_1207']);both.states[0].charge=0
 for n in 3:combat.record_attack(both,0,both.builds[0].items[0],float(n+7),{})
 combat.process(battle,both,9)
 ck(is_equal_approx(float(both.states[0].charge),2),'same base ability works unchanged in second slot')
func test_full_team()->void:
 var roles={'charge':'role_1207','relay':'role_1302','stamina':'role_1410','guard':'role_1505','affliction':'role_1506'}
 for family in roles:
  var ctx=context(['w_sword','whiff'],['role_1106',roles[family]])
  ctx.states[1].noise=1;ctx.states[0].shield=20
  var source=ctx.builds[0].items[0]
  match family:
   'charge':combat.record_attack(ctx,0,source,1,{'charged':true})
   'relay':
    combat.record_attack(ctx,0,source,1,{})
    combat.record_attack(ctx,0,ctx.builds[0].items[1],1,{})
   'stamina':combat.record_spent(ctx,0,6,1,source.uid)
   'guard':combat.record_blocked(ctx,0,12,1,'enemy')
   'affliction':combat.record_attack(ctx,0,source,1,{})
  combat.process(battle,ctx,1);battle.commit_pending(ctx,1)
  ck(crew_events(ctx,roles[family],'full_'+family).size()==1,'ordinary build activates full-team '+family)
  combat.process(battle,ctx,1);battle.commit_pending(ctx,1)
  ck(crew_events(ctx,roles[family],'full_'+family).size()==1,'full-team fact consumed once '+family)
 # A status applied by this very attack cannot be its own already-afflicted trigger.
 var fresh=context(['w_sword'],['role_1106','role_1506']);fresh.states[1].noise=0
 for n in 4:combat.record_attack(fresh,0,fresh.builds[0].items[0],float(n+1),{})
 combat.process(battle,fresh,4);battle.commit_pending(fresh,4)
 ck(crew_events(fresh,'role_1506','weapon_noise').size()==1 and crew_events(fresh,'role_1506','full_affliction').is_empty(),'new noise is not retroactive afflicted eligibility')
func test_symmetry()->void:
 var a=board(['w_sword','whiff'],['role_1207','role_1506']);var before=a.duplicate(true)
 var ctx=battle.begin(a,a.duplicate(true),3)
 for state in ctx.states:state.hp=10000;state.max_hp=10000
 run_for(ctx,16)
 for key in ['hp','shield','charge','stamina','noise','frost']:
  ck(is_equal_approx(float(ctx.states[0][key]),float(ctx.states[1][key])),'mirrored teams remain symmetric '+key)
 ck(a==before,'all companion state stays local to battle')
 for ev in ctx.events.filter(func(e):return e.kind=='crew_trigger'):
  ck(ev.uid=='crew:'+ev.role_id and float(ev.actual_value)>0,'real benefit has explicit crew provenance')
func test_review_edges()->void:
 var ctx=context(['w_sword'],['role_1106','role_1505']);ctx.states[0].shield=30
 battle.remove_shield(ctx,0,12);combat.process(battle,ctx,1)
 ck(crew_events(ctx,'role_1505','full_guard').is_empty(),'self-spent shield cannot become blocked damage')
 battle.deal_v75_damage(ctx,1,{'kind':'w_sword','uid':'i0'},12,2,true,'attack')
 combat.process(battle,ctx,2);battle.commit_pending(ctx,2)
 var rows=preload('res://scripts/battle/battle_review.gd').timeline({'events':ctx.events},ctx.builds,0)
 ck(rows.any(func(r):return r.event_kind=='crew_trigger' and r.source_uid=='crew:role_1505' and r.partner_uid=='i0' and r.partner_side==1),'counter timeline names enemy trigger, even when UIDs match own inventory')
 var before=crew_events(ctx,'role_1505','full_guard').size()
 ctx.states[0].shield=30;battle.deal_v75_damage(ctx,1,{'kind':'','uid':'crew:role_1505'},12,6,false,'counter')
 combat.process(battle,ctx,6);battle.commit_pending(ctx,6)
 ck(crew_events(ctx,'role_1505','full_guard').size()==before,'crew counter cannot charge an opposing crew counter')
 ctx=context(['w_sword','whiff'],['role_1302'])
 ctx.progress[0].i1=1.0-.01/battle.cooldown(ctx,0,ctx.builds[0].items[1])
 for n in 2:combat.record_attack(ctx,0,ctx.builds[0].items[0],float(n+1),{})
 combat.process(battle,ctx,2)
 var advances=ctx.events.filter(func(e):return e.kind=='cooldown_advance' and e.get('source_uid','')=='crew:role_1302')
 ck(advances.size()==1 and is_equal_approx(float(advances[0].actual_value),.01),'partial cooldown advancement keeps exact value')
 var review=preload('res://scripts/battle/battle_review.gd').rows({'events':ctx.events},ctx.builds,0,2)
 ck(review.any(func(r):return r.uid=='crew:role_1302' and is_equal_approx(float(r.advance),.01)),'review credits precise advancement to correct role')
 ctx=context(['w_sword'],['role_1110']);ctx.states[1].frost_immune_until=5
 for n in 3:combat.record_attack(ctx,0,ctx.builds[0].items[0],float(n+1),{})
 combat.process(battle,ctx,3)
 ck(crew_events(ctx,'role_1110').is_empty(),'frost immunity does not generate fake successful crew trigger')
 combat.record_attack(ctx,0,ctx.builds[0].items[0],6,{});combat.process(battle,ctx,6)
 ck(crew_events(ctx,'role_1110','weapon_frost').size()==1,'prepared frost survives a zero-benefit attempt')
func test_revised_strength()->void:
 for row in [['role_1302',0,1],['role_1211',1,0]]:
  var ctx=context(['w_sword','whiff'],[row[0]])
  ctx.progress[0][ctx.builds[0].items[row[2]].uid]=0.0
  for n in 2:combat.record_attack(ctx,0,ctx.builds[0].items[row[1]],float(n+1),{})
  combat.process(battle,ctx,2)
  var advances=ctx.events.filter(func(e):return e.kind=='cooldown_advance' and e.get('source_uid','')=='crew:'+row[0])
  ck(advances.size()==1 and is_equal_approx(float(advances[0].actual_value),.9),'revised relay advances exactly 0.9 seconds '+row[0])
 var ctx=context(['w_sword','whiff'],['role_1106','role_1302'])
 ctx.progress[0].i0=0.0
 for item in ctx.builds[0].items:combat.record_attack(ctx,0,item,1,{})
 combat.process(battle,ctx,1)
 var advances=ctx.events.filter(func(e):return e.kind=='cooldown_advance' and e.get('source_uid','')=='crew:role_1302')
 ck(advances.size()==1 and is_equal_approx(float(advances[0].actual_value),.6),'revised full-team relay advances exactly 0.6 seconds')
 ctx=context(['w_sword'],['role_1110'])
 for n in 2:combat.record_attack(ctx,0,ctx.builds[0].items[0],float(n+1),{})
 combat.process(battle,ctx,2)
 ck(int(ctx.states[1].frost)==2,'two natural weapons apply exactly two frost layers')
func test_continuous_remainders()->void:
 var ctx=context([],['role_1410']);ctx.states[0].stamina=1
 combat.record_spent(ctx,0,3,1,'w1');combat.record_spent(ctx,0,3,1,'w2');combat.process(battle,ctx,1)
 ck(is_equal_approx(float(ctx.states[0].stamina),1.8),'three plus three pays one four-stamina refund')
 combat.record_spent(ctx,0,2,3,'w3');combat.process(battle,ctx,3)
 ck(is_equal_approx(float(ctx.states[0].stamina),2.6),'two saved stamina plus new two earns next refund')
 combat.process(battle,ctx,10)
 ck(crew_events(ctx,'role_1410','spent_stamina').size()==2,'elapsed time cannot manufacture another spending trigger')
 ctx=context([],['role_1106','role_1410']);ctx.states[0].shield=0;ctx.states[0].stamina=1
 combat.record_spent(ctx,0,4,1,'w1');combat.record_spent(ctx,0,4,1,'w2');combat.process(battle,ctx,1)
 ck(is_equal_approx(float(ctx.states[0].shield),3),'eight spent stamina pays one six-stamina shield')
 combat.record_spent(ctx,0,4,4,'w3');combat.process(battle,ctx,4)
 ck(is_equal_approx(float(ctx.states[0].shield),6),'full-team stamina threshold also preserves two-point remainder')
 ctx=context([],['role_1106','role_1505']);ctx.states[0].shield=100
 battle.deal_v75_damage(ctx,1,{'kind':'w_sword','uid':'enemy'},7,1,true,'attack')
 battle.deal_v75_damage(ctx,1,{'kind':'w_sword','uid':'enemy'},7,1,true,'attack')
 combat.process(battle,ctx,1);battle.commit_pending(ctx,1)
 ck(crew_events(ctx,'role_1505','full_guard').size()==1,'fourteen actual blocked damage produces one counter')
 battle.deal_v75_damage(ctx,1,{'kind':'w_sword','uid':'enemy'},10,4,true,'attack')
 combat.process(battle,ctx,4);battle.commit_pending(ctx,4)
 ck(crew_events(ctx,'role_1505','full_guard').size()==2,'two actual blocked damage remainder combines with next ten')
 ctx=context([],['role_1410']);ctx.states[0].stamina=1
 combat.record_spent(ctx,0,20,1,'burst');combat.process(battle,ctx,1)
 ck(crew_events(ctx,'role_1410','spent_stamina').size()==1,'large payment produces at most one refund per actual input')
 combat.record_spent(ctx,0,.1,1.1,'burst2');combat.process(battle,ctx,1.1)
 ck(crew_events(ctx,'role_1410','spent_stamina').size()==1,'backlog still respects interval')

func test_noise_pacing()->void:
 var ctx=context(['w_sword'],['role_1506'])
 for n in 3:combat.record_attack(ctx,0,ctx.builds[0].items[0],float(n+1),{})
 combat.process(battle,ctx,3)
 ck(int(ctx.states[1].noise)==0,'noise requires four natural weapon attacks')
 combat.record_attack(ctx,0,ctx.builds[0].items[0],4,{});combat.process(battle,ctx,4)
 ck(int(ctx.states[1].noise)==1,'fourth natural attack produces exactly one noise')
 for n in 4:combat.record_attack(ctx,0,ctx.builds[0].items[0],5+float(n)*.1,{})
 combat.process(battle,ctx,5.3)
 ck(int(ctx.states[1].noise)==1,'prepared noise respects six-second interval')
 combat.record_attack(ctx,0,ctx.builds[0].items[0],9,{});combat.process(battle,ctx,9)
 ck(int(ctx.states[1].noise)==1,'five seconds since successful noise is still too early')
 combat.record_attack(ctx,0,ctx.builds[0].items[0],10,{});combat.process(battle,ctx,10)
 ck(int(ctx.states[1].noise)==2,'next real input after six seconds can apply prepared noise')
