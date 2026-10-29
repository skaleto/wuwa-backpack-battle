extends SceneTree
const I=preload('res://tests/fixtures/recruitment_fixture_v114.gd')
const R=preload('res://scripts/party/recruitment_v114.gd')
const B=preload('res://scripts/battle/battle.gd')
const C=preload('res://scripts/data/catalog.gd')
const FIX=preload('res://tests/fixtures/capacity_fixture_v111.gd')
var inv=I.new();var battle=B.new();var checks=0;var failures=0
func ck(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func board(kinds:Array,roles:Array=[])->Dictionary:
 var r=inv.new_run('aemeath',114);r.round=7;r.items=[];r.stash=[];r.bags=FIX.full_bags(inv);r.serial=100;r.shop=[{},{},{},{},{},{}];r.primary=''
 r.roster=roles.duplicate();r.supports=roles.duplicate();r.recruited_round=7 if not roles.is_empty() else 0
 for k in kinds:
  var p=inv.make_piece(k,'i'+str(r.items.size()+1));p.x=r.items.size()*2;r.items.append(p)
 return r
func _initialize():
 test_links();test_volley();test_guard();test_rewards();test_specialties();test_artisan();test_supply();extended_pairs();upgrade_effects();review_boundaries();remote_event_consumers();leader_accessibility();volley_wait_accounting()
 print('BONDS_V114 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
func test_links():
 var r=board(['electro_coin','w_sword','w_sword'],['role_1302']);r.items[0].x=0;r.items[0].y=0;r.items[1].x=1;r.items[2].x=4;r.items[2].y=2
 ck(inv.star_links(r.items[0],r.items,r).size()==1,'ordinary star local link')
 r.recruitment.config.link={'mode':'star','source':'i1','target':'i3','star':0}
 var links=inv.star_links(r.items[0],r.items,r)
 ck(links.size()==1 and links[0].uid=='i3','remote star replaces original local target')
 r.recruitment.config.link.target='i2';links=inv.star_links(r.items[0],r.items,r)
 ck(links.size()==1,'one UID counted once')
 r.stash.append(r.items.pop_back());r.recruitment.config.link.target='i3'
 ck(R.valid_link(inv,r).is_empty(),'stashed remote target invalidates connection')
func test_volley():
 var r=board(['w_sword','w_sword'],['role_1207']);r.items[1].x=0;r.items[1].y=1;r.recruitment.config.volley=['i1','i2']
 var ctx=battle.begin(r,board([]));ctx.states[0].charge=0
 for bonus in ctx.bonuses[0].values():bonus.multiplier=1.0
 ctx.progress[0].i1=1;ctx.progress[0].i2=.5;ctx.states[0].stamina=8
 battle.step(ctx,.1)
 ck(not ctx.events.any(func(e):return e.kind=='attack' and e.side==0),'fast weapon waits for partner')
 ctx.progress[0].i2=1;ctx.states[0].stamina=1
 battle.step(ctx,.2)
 ck(not ctx.events.any(func(e):return e.kind=='attack' and e.side==0),'pair cannot spend partial stamina')
 ctx.states[0].stamina=8;battle.step(ctx,.3)
 var attacks=ctx.events.filter(func(e):return e.kind=='attack' and e.side==0)
 ck(attacks.size()==2 and is_equal_approx(attacks[0].time,attacks[1].time),'paired natural attacks share ready time')
 ck(is_equal_approx(float(attacks[0].value),4.8) and is_equal_approx(float(attacks[1].value),4.8),'20 percent applies once to base damage')
 ck(is_equal_approx(float(ctx.states[0].stamina),6.4),'both exact stamina costs paid')
 ck(float(ctx.progress[0].i1)==0 and float(ctx.progress[0].i2)==0,'both own cooldowns reset')
 ck(not ctx.events.any(func(e):return e.kind=='crew_trigger' and e.get('ability','')=='shield_counter'),'old V113 passive absent')
func test_guard():
 var r=board(['medical','flower','w_sword','w_sword'],['role_1505','role_1207']);r.items[1].x=1;r.items[2].y=2;r.items[2].x=0;r.items[3].y=3;r.items[3].x=0;r.recruitment.config.guard=['i1','i2'];r.recruitment.config.volley=['i3','i4']
 var ctx=battle.begin(r,board([]));var before=float(ctx.states[0].shield);ctx.states[0].charge=0
 for bonus in ctx.bonuses[0].values():bonus.multiplier=1.0
 battle.heal(ctx,0,r.items[0],20,0,true)
 ck(is_equal_approx(float(ctx.states[0].shield)-before,6),'actual overflow gives shield capped at six')
 battle.heal(ctx,0,r.items[0],20,1,true)
 ck(is_equal_approx(float(ctx.states[0].shield)-before,6),'four second shield budget')
 battle.deal_v75_damage(ctx,1,{'kind':'w_sword','uid':'enemy'},4,1,true,'attack')
 ck(is_equal_approx(float(ctx.crew114[0].counter),4),'only real converted shield absorption loads counter')
 ctx.progress[0].i3=1;ctx.progress[0].i4=1;battle.step(ctx,1.1)
 var shots=ctx.events.filter(func(e):return e.kind=='attack' and e.side==0 and e.uid in ['i3','i4'])
 ck(shots.size()==2 and is_equal_approx(float(shots[0].value),5.8),'counter adds 25 percent absorbed to both shots')
 ck(float(ctx.crew114[0].counter)==0,'counter consumed once')
 var h=board(['medical','flower'],['role_1302','role_1505']);h.items[1].x=5;h.recruitment.config={'guard':['i1','i2'],'link':{'mode':'guard','source':'i1','target':'i2'}}
 ck(R.valid_pair(inv,h,'guard').size()==2 and R.valid_link(inv,h).is_empty(),'remote guard uses connection without false star')
func test_rewards():
 for a in R.PRIMARY_ROLES:
  for b in R.PRIMARY_ROLES:
   if a>=b:continue
   var r=board(['w_sword','medical','flower','tuner'],[a]);r.phase='recruit';r.recruitment.node=6;r.recruitment.candidates=[b]
   var card=R.model_for(inv,r,b,true)
   ck(not card.bond_id.is_empty() and not card.bond_text.is_empty(),'all ten pairs have a concrete rule')
   var reward=card.reward_choices[0].kind if not card.reward_choices.is_empty() else 'gold' if card.gold_fallback else ''
   var before=r.duplicate(true);var p=R.plan_confirm(inv,r,b,reward)
   ck(p.ok and r==before,'pair confirm and reward share pure transaction')
   if p.ok and not reward.is_empty() and reward!='gold':ck(p.value.reward.paid_cost==0 and p.value.reward.cost_basis=='known_free','free reward has zero actual cost')
func test_specialties():
 var common=JSON.parse_string(FileAccess.get_file_as_string('res://data/catalog.json'))
 var specialty=preload('res://scripts/data/specialty_catalog_v114.gd').apply(common)
 ck(specialty.items.size()==231 and specialty.recipes.size()==141,'additive fifteen items / five recipes keep common catalog intact')
 ck(common.items.keys().all(func(kind):return specialty.items[kind]==common.items[kind]) and specialty.recipes.slice(0,common.recipes.size())==common.recipes,'specialty overlay preserves every common item and recipe')
 for a in R.ROLES:
  var r=board([],[]);var role=R.ROLES[a];var pool=R.special_kinds(role)
  ck(pool.size()==3,'two functional items and one upgrade per ability')
  ck(not inv.shop_eligible(r,pool[0]),'natural supply gated only for new item')
  r.roster=[a];r.supports=[a];r.recruited_round=7
  ck(inv.shop_eligible(r,pool[0]) and inv.craft_unlocked(board([]),pool[2]),'crew supply enabled; use and crafting stay open')
func test_artisan():
 var r=board(['tuner','tube'],['role_1106']);var next=r.duplicate(true);next.items=[];var out=inv.make_piece('w_sword','i101');next.items=[out];next.serial=101
 R.after_craft(inv,r,next,['i1','i2'],out)
 ck(next.recruitment.return_pending.size()==2 and next.recruitment.return_round==7,'first real craft locks exact consumed material choices')
 ck(next.serial==101,'multiple-choice return allocates no UID before selection')
 var options=R.crew_setup_choices(inv,next).artisan_return
 var p=R.plan_configure(inv,next,options[0].config)
 ck(p.ok and p.run.stash[-1].paid_cost==0 and p.run.stash[-1].uid=='i102','return is a new free instance')
 ck(not R.plan_configure(inv,p.run,options[0].config).get('ok',false),'return cannot be claimed twice')
 var star=board(['tuner','tube'],['role_1106','role_1302']);next=star.duplicate(true);next.items=[out];next.serial=101
 R.after_craft(inv,star,next,['i1','i2'],out)
 ck(next.recruitment.star_pending=='i101','first star-bearing output has direction choice')
 options=R.crew_setup_choices(inv,next).artisan_star
 ck(not options.is_empty(),'only in-board extra star directions offered')
 p=R.plan_configure(inv,next,options[0].config)
 ck(p.ok and inv.stars(p.run.items[0]).size()==C.items.w_sword.stars.size()+1,'one explicit extra star on crafted output')
func test_supply():
 var r=board(['w_sword','tuner'],['role_1504','role_1106']);r.gold=20;inv.refresh(r)
 var targets=R.supply_targets(inv,r);ck(not targets.is_empty(),'owned recipe starts produce missing targets')
 var p=R.plan_targeted_refresh(inv,r,targets[0]);ck(p.ok and p.run.gold==19,'targeted refresh costs one coin even if ordinary refresh still free')
 ck(not R.plan_targeted_refresh(inv,p.run,targets[0]).get('ok',false),'only one targeted refresh per round')
 r.shop[3].locked=true;r.shop[4].locked=true;var before=r.duplicate(true)
 ck(not R.plan_targeted_refresh(inv,r,targets[0]).get('ok',false) and r==before,'locked mixed slots preserve opportunity and state')
 r.shop[3].locked=false;r.shop[4].locked=false
 var bundles=targets.filter(func(t):return t.get('kinds',[]).size()==2)
 ck(not bundles.is_empty(),'artisan supply offers two different missing pieces')
 if not bundles.is_empty():
  p=R.plan_targeted_refresh(inv,r,bundles[0]);r=p.run;var idx=int(p.value.slot);var count=r.stash.size();var total=int(r.shop[idx].bundle_price);var gold=int(r.gold)
  ck(inv.buy(r,idx) and r.stash.size()==count+2 and int(r.gold)==gold-total,'bundle atomically buys both pieces at eighty percent rounded up')
  ck(int(r.stash[-1].paid_cost)+int(r.stash[-2].paid_cost)==total,'bundle preserves only real paid cost')

func extended_pairs():
 var r=board(['weapon_21020026','w_sword'],['role_1302','role_1207']);r.items[0].x=0;r.items[1].x=5;r.items[1].y=3
 r.recruitment.config={'link':{'mode':'star','source':'i1','target':'i2','star':0},'volley':['i1','i2']}
 ck(R.valid_pair(inv,r,'volley').size()==2,'compatible weapon star enables remote volley')
 r.recruitment.config.link.source='i2';r.recruitment.config.link.target='i1'
 ck(R.valid_pair(inv,r,'volley').is_empty(),'remote volley cannot invent an incompatible weapon star')
 r=board([],['role_1106','role_1207'])
 ck(R.return_eligible(r,{'kind':'w_sword'}) and not R.return_eligible(r,{'kind':'bellborne'}),'artisan volley extends return to actual low-tier weapon, never echo')
 r=board([],['role_1106','role_1505'])
 var candidates=C.items.keys().filter(func(k):return not C.is_tag(k,'weapon') and not C.is_tag(k,'echo') and int(C.items[k].rarity)==3 and int(C.items[k].price)<=8 and (R.functional(k,'heal') or R.functional(k,'shield')))
 ck(not candidates.is_empty() and R.return_eligible(r,{'kind':candidates[0]}),'artisan guard extends one shared return allowance to tier-three support')
 for role in ['role_1302','role_1207','role_1505','role_1106']:
  r=board(['w_sword','tuner','medical','flower'],[role,'role_1504']);inv.refresh(r)
  var targets=R.supply_targets(inv,r)
  var expected='star:' if role=='role_1302' else 'partner' if role=='role_1207' else 'heal' if role=='role_1505' else '+'
  ck(targets.any(func(t):return str(t.id).contains(expected)),'supply pair exposes a real selectable target '+role)
  for t in targets:
   for k in t.get('kinds',t.get('pool',[])):ck(inv.shop_eligible(r,k),'target never bypasses current supply '+k)
 var frozen=C.data.items.duplicate(true)
 for kind in C.items:
  if C.items[kind].get('crew_supply','').is_empty() or C.items[kind].get('craft_only',false):continue
  r=board([kind])
  var ctx=battle.begin(r,board([]));ctx.states[0].stamina=0;ctx.states[0].hp=50
  var category=C.items[kind].get('v75',{}).get('material_effect',{}).get('category','')
  if not category.is_empty():
   var partner=inv.make_piece('w_sword' if category=='weapon' else 'whiff','i9');partner.x=1;r.items.append(partner);ctx=battle.begin(r,board([]));ctx.states[0].stamina=0;ctx.states[0].hp=50
  for tick in 100:battle.step(ctx,(tick+1)*.1)
  ck(ctx.events.any(func(e):return e.uid=='i1' or e.get('source_uid','')=='i1'),'specialty functions without owning corresponding crew '+kind)
 ck(C.items==frozen,'battle does not mutate additive catalogue')

func upgrade_effects():
 var ingredients={}
 for recipe in C.combinations:
  if not str(recipe.id).begins_with('V114_'):continue
  ingredients[recipe.materials[0]]=true
  var d=C.items[recipe.target]
  ck(int(d.v75.cost)==int(C.items[recipe.base].v75.cost)+int(C.items[recipe.materials[0]].v75.cost),'upgrade exact material investment '+recipe.target)
 ck(ingredients.size()==5,'five upgrade branches consume five different existing ingredients')
 for entry in [['crew_relay_pin_plus','w_sword','cooldown_advance',6.0,.6],['crew_pulse_grip_plus','w_sword','stamina',6.0,1.8],['crew_forge_spring_plus','whiff','cooldown_advance',4.0,.4],['crew_reserve_flask_plus','','stamina',6.0,2.0]]:
  var r=board([entry[0]]);r.items[0].x=0;r.items[0].y=0
  if not str(entry[1]).is_empty():
   var partner=inv.make_piece(entry[1],'i9');partner.x=1;partner.y=0;r.items.append(partner)
  var ctx=battle.begin(r,board([]));ctx.states[0].stamina=0;ctx.states[0].charge=0
  for tick in int(float(entry[3])*10):battle.step(ctx,(tick+1)*.1)
  var events=ctx.events.filter(func(e):return e.kind==entry[2] and (e.uid=='i1' or e.get('source_uid','')=='i1'))
  ck(events.size()==1 and is_equal_approx(float(events[0].get('actual_value',events[0].value)),float(entry[4])),'distinct upgrade performs its own exact independent effect '+entry[0])
 var r=board(['crew_dew_vial_plus']);var ctx=battle.begin(r,board([]));var before=float(ctx.states[0].shield)
 for tick in 40:battle.step(ctx,(tick+1)*.1)
 ck(is_equal_approx(float(ctx.states[0].shield)-before,.75),'guard upgrade turns only its real overflow into shield without any recruited role')
 battle.heal(ctx,0,r.items[0],100,4.1,true);battle.heal(ctx,0,r.items[0],100,4.2,true)
 ck(is_equal_approx(float(ctx.states[0].shield)-before,2),'guard specialty overflow has independent bounded two-shield budget')
 ck(R.functional('crew_dew_vial_plus','shield') and battle.capability(r.items[0],'shield'),'specialty shield capability shared by battle and matching')

func review_boundaries():
 var r=board(['medical','flower','echo_wankui'],['role_1505','role_1207']);r.items[1].x=1;r.recruitment.config.guard=['i1','i2']
 var ctx=battle.begin(r,board([]));ctx.states[0].shield=0
 battle.heal(ctx,0,r.items[0],12,0,true)
 ck(is_equal_approx(float(ctx.crew114[0].guard_shield),6),'guard provenance records only generated shield')
 battle.activate(ctx,0,r.items[2],1)
 ck(is_zero_approx(float(ctx.crew114[0].guard_shield)),'self-spent shield removes guard provenance')
 battle.add_shield(ctx,0,6,1.1,'ordinary','ordinary')
 battle.deal_v75_damage(ctx,1,{'kind':'w_sword','uid':'enemy'},6,1.2,true,'attack')
 ck(is_zero_approx(float(ctx.crew114[0].counter)),'replacement ordinary shield cannot earn guard counter')
 var sparse=board(['weapon_21020084','weapon_21020084'],['role_1207']);sparse.items[1].x=0;sparse.items[1].y=3;sparse.recruitment.done=[3];sparse.recruitment.node=3
 for seed in 32:
  var d=sparse.duplicate(true);d.seed=seed
  ck(R.open_draft(inv,d,6),'second sparse draft opens')
  var cards=R.card_models(inv,d)
  ck(cards.any(func(card):return card.usable),'second sparse draft retains immediately useful bond reward')
  ck(cards.any(func(card):return card.ability_id in ['artisan','supply']),'economic guarantee coexists with usable guarantee')
 ck(not R.functional('rations','stamina'),'stamina discount is not stamina recovery')
 ck(R.functional('dragon_food','stamina'),'dragon food actual recovery belongs to stamina class')

func remote_event_consumers():
 var r=board(['whiff','w_sword'],['role_1302']);r.items[1].x=4;r.items[1].y=3
 r.recruitment.config.link={'mode':'star','source':'i1','target':'i2','star':0}
 var enemy=board([]);var ctx=battle.begin(r,enemy)
 for t in range(1,4):battle.activate(ctx,0,r.items[1],float(t))
 var stars=ctx.events.filter(func(e):return e.side==0 and e.kind=='star_trigger')
 ck(stars.size()==1 and stars[0].get('beneficiary_uid','')=='i2','remote star keeps actual item beneficiary despite crew feedback append')
 var pulses=preload('res://scripts/ui/items/star_activation_view.gd').new()
 for e in ctx.events:pulses.record(e)
 ck(pulses.pulses.size()==1 and pulses.pulses[0].beneficiary_uid=='i2','star activation consumer highlights actual remote weapon')
 var timeline=preload('res://scripts/battle/battle_review.gd').timeline({'events':ctx.events},[r,enemy],0,'i2')
 ck(timeline.any(func(row):return row.event_kind=='star_trigger' and row.source_uid=='i1' and row.partner_uid=='i2'),'battle review attributes remote star source and partner correctly')
 ck(ctx.events.filter(func(e):return e.kind=='crew_trigger').all(func(e):return not e.has('beneficiary_uid')),'item event annotations never leak onto crew feedback')

func leader_accessibility():
 for leader in C.characters:
  var reached=[]
  for seed in 16:
   var r=inv.new_run(leader,seed);r.round=4
   ck(R.open_draft(inv,r,3),'all leaders can open first draft')
   var groups=r.recruitment.candidates.map(func(role):return R.ROLES[role])
   ck(groups.size()==3 and groups.count(groups[0])==1 and groups.count(groups[1])==1,'candidate abilities never duplicate')
   ck(C.characters[leader].roster_id not in r.recruitment.candidates,'leader identity never re-recruited')
   for group in groups:
    if group not in reached:reached.append(group)
  ck(reached.size()==5,'leader does not remove an ability direction: '+leader)

 var duplicate=board(['w_sword'],['role_1302','role_1105'])
 ck(not R.valid_state(inv,duplicate),'fallback identity cannot stack the same active ability twice')
 var candidate=board(['w_sword'],['role_1302']);candidate.phase='recruit';candidate.recruitment.node=6;candidate.recruitment.candidates=['role_1105','role_1106','role_1504']
 ck(not R.plan_confirm(inv,candidate,'role_1105').ok,'forged fallback candidate cannot duplicate an owned ability')

func volley_wait_accounting():
 var r=board(['w_sword','w_sword','w_sword'],['role_1207'])
 for n in 3:r.items[n].x=0;r.items[n].y=n
 r.recruitment.config.volley=['i1','i2']
 var ctx=battle.begin(r,board([]));ctx.states[0].stamina=0
 for uid in ctx.progress[0]:ctx.progress[0][uid]=1
 battle.step(ctx,.1)
 ck(is_equal_approx(float(ctx.totals[0].stamina_wait_seconds),.1),'pair and third weapon share one elapsed side-wait interval')
 ck(ctx.totals[0].stamina_wait_by_uid.size()==3 and ctx.totals[0].stamina_wait_by_uid.values().all(func(value):return is_equal_approx(float(value),.1)),'each blocked weapon records exactly its own wait interval')
 battle.step(ctx,.2)
 ck(is_equal_approx(float(ctx.totals[0].stamina_wait_seconds),.2),'side wait accumulates once per distinct step')
 ctx.states[0].stamina=8;battle.step(ctx,.3)
 ck(is_equal_approx(float(ctx.totals[0].stamina_wait_seconds),.2),'ready pair does not retain stale aggregate waiting')
