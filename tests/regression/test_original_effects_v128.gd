extends 'res://tests/regression/test_families_effects_v127.gd'
func _initialize()->void:
 spec=preload('res://scripts/data/original_catalog_v128.gd').spec
 var b=B.new();var enemy=simple('w_sword')
 for k in spec.new_items:
  var n=C.profile(k);var targets=['whiff','zig'] if n.get('star_categories',[])==['echo'] else ['w_sword']
  var r=linked_run(k,targets) if not n.stars.is_empty() else simple(k)
  if n.stars.is_empty():put(r,'w_broadblade','ally');put(r,'w_pistol','ally2')
  var unchanged=r.duplicate(true)
  for side in 2:
   var ctx=b.begin(r,enemy,128) if side==0 else b.begin(enemy,r,128)
   ctx.states[side].max_hp=300;ctx.states[side].hp=120;ctx.states[side].stamina=0
   ctx.states[1-side].max_hp=300;ctx.states[1-side].hp=300
   # Create actual opportunities for cleanse, shield and charged preparation.
   b.apply_noise_internal(ctx,1-side,enemy.items[0],3,0,false);ctx.states[side].charge=6
   for tick in range(1,201):b.step(ctx,float(tick)/10)
   var useful=ctx.events.any(func(e):return int(e.side)==side and ((e.uid=='part' and float(e.value)>0 and e.kind in ['heal','shield','charge','haste','stamina','cleanse','noise','frost','derived','break_shield']) or (e.kind=='star_trigger' and e.get('source_uid','')=='part') or (e.kind=='cooldown_advance' and e.get('source_uid','')=='part')))
   ck(useful,'actual attributed combat benefit side '+str(side)+' '+k)
   ck(r==unchanged,'permanent item and owned state unchanged '+k)
   ck(ctx.events.size()<1600 and ctx.pending.is_empty(),'bounded natural/derived output '+k)
 # The ice voice needs an echo and real pre-existing frost; one natural root pays once.
 for side in 2:
  var r=linked_run('mat_41400074',['whiff']);var ctx=b.begin(r,enemy,128) if side==0 else b.begin(enemy,r,128)
  ctx.events=[];b.activate(ctx,side,r.items[1],1);b.commit_pending(ctx,1)
  ck(events(ctx,'part','derived').is_empty(),'ice voice does not pay without frost')
  b.apply_frost_internal(ctx,side,r.items[0],2,2,false)
  b.activate(ctx,side,r.items[1],3);b.natural(ctx,side,r.items[1],'attack',3);b.commit_pending(ctx,3)
  ck(sum_event(ctx,'part','derived')==2,'ice voice pays one exact derived root')
  b.queue_hit(ctx,side,r.items[1],5,4);b.commit_pending(ctx,4)
  ck(sum_event(ctx,'part','derived')==2,'derived echo damage cannot feed ice voice')
 # Rock fist explicitly distinguishes shielded targets from exposed targets.
 var r=linked_run('mat_41400054');var ctx=b.begin(r,enemy,128);ctx.events=[];ctx.states[1].shield=100
 b.activate(ctx,0,r.items[1],1);b.commit_pending(ctx,1)
 ck(events(ctx,'part','derived').is_empty() and not ctx.icd[0].has('mat_41400054:family'),'shielded target preserves conditional gate')
 ctx.states[1].shield=0;b.activate(ctx,0,r.items[1],2);b.natural(ctx,0,r.items[1],'attack',2);b.commit_pending(ctx,2)
 ck(sum_event(ctx,'part','derived')==2,'rock fist exposed target pays exactly once')
 # Pastry only spends its +4 preparation on the next real charged attack.
 r=linked_run('provision_snow_lotus_pastry');ctx=b.begin(r,enemy,128);ctx.events=[]
 M.tick(b,ctx,0,r.items[0],8)
 var key='provision_snow_lotus_pastry:charged'
 ck(b.own(ctx,0,r.items[1]).buffs.has(key),'pastry creates one bounded charged preparation')
 M.tick(b,ctx,0,r.items[0],16)
 ck(ctx.events.filter(func(e):return e.kind=='star_trigger' and e.get('source_uid','')=='part').size()==1,'unused pastry preparation does not emit a second success')
 b.activate(ctx,0,r.items[1],16.1);b.commit_pending(ctx,16.1)
 ck(b.own(ctx,0,r.items[1]).buffs.has(key),'ordinary attack keeps charged preparation')
 ctx.states[0].charge=6;b.activate(ctx,0,r.items[1],17);b.commit_pending(ctx,17)
 ck(not b.own(ctx,0,r.items[1]).buffs.has(key),'charged attack consumes pastry exactly once')
 # Real food preparation is a supply cycle; an absent target or an unused
 # identical preparation never tells linked lunchboxes that food was served.
 r=linked_run('provision_jinzhou_stew');ctx=b.begin(r,enemy,128);ctx.events=[]
 M.tick(b,ctx,0,r.items[0],7)
 ck(events(ctx,'part','supply').size()==1,'stew publishes a real prepared-food cycle')
 M.tick(b,ctx,0,r.items[0],14)
 ck(events(ctx,'part','supply').size()==1,'unused preparation publishes no duplicate food cycle')
 b.activate(ctx,0,r.items[1],14.1);b.commit_pending(ctx,14.1)
 M.tick(b,ctx,0,r.items[0],21)
 ck(events(ctx,'part','supply').size()==2,'consumed preparation allows the next true food cycle')
 r=simple('provision_jinzhou_stew');ctx=b.begin(r,enemy,128);ctx.events=[];M.tick(b,ctx,0,r.items[0],7)
 ck(events(ctx,'part','supply').is_empty(),'stew without a linked weapon creates no phantom cycle')
 r=empty()
 for entry in [['relic_lunchbox','box',1,1,0],['provision_jinzhou_stew','part',3,1,1],['w_sword','partner',2,2,1],['cool_tea','tea',1,0,0]]:
  var piece=inv.make_piece(entry[0],entry[1]);piece.x=entry[2];piece.y=entry[3];piece.rotation=entry[4];r.items.append(piece)
 ck(r.items.all(func(i):return inv.can_place(i,r.items,r.bags)),'stew/lunchbox integration uses a legal physical layout')
 ck(inv.star_links(r.items[0],r.items,r).size()==2 and inv.star_links(r.items[1],r.items,r).any(func(i):return i.uid=='partner'),'both food links and the stew weapon link are real')
 ctx=b.begin(r,enemy,128);ctx.states[0].hp-=20;ctx.states[0].stamina=0;ctx.events=[]
 M.tick(b,ctx,0,r.items[0],6);b.support_heal(ctx,0,r.items[3],3,6)
 M.tick(b,ctx,0,r.items[1],7)
 ck(is_equal_approx(float(b.own(ctx,0,r.items[0]).material_next),10) and sum_event(ctx,'box','cooldown_advance')==2,'two distinct real food cycles advance lunchbox by exactly two seconds')
 if '--measure' in OS.get_cmdline_user_args():measure_original_recipes()
 print('ORIGINAL_EFFECTS_V128 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)

func measure_original_recipes()->void:
 var enemy=empty()
 for k in ['w_sword','w_broadblade','w_pistol','relic_layered_guard']:put(enemy,k,'enemy_'+k)
 for recipe in spec.recipes:
  var before=original_measure_build([recipe.base]+recipe.materials);var after=original_measure_build([recipe.target])
  var row={'recipe':recipe.id,'inputs':[C.items[recipe.base].name,C.items[recipe.materials[0]].name],'target':C.items[recipe.target].name,'input_price':C.profile(recipe.base).cost+C.profile(recipe.materials[0]).cost,'cells_before':C.items[recipe.base].shape.size()+C.items[recipe.materials[0]].shape.size(),'cells_after':C.items[recipe.target].shape.size(),'before':{},'after':{}}
  for label in ['before','after']:
   var run=before if label=='before' else after;var unchanged=run.duplicate(true)
   var left=original_probe(run,enemy,0);var right=original_probe(run,enemy,1)
   for key in left:row[label][key]=snappedf((left[key]+right[key])*.5,.01)
   ck(run==unchanged,'full-input comparison preserves state')
  print('W128_COMPARE ',JSON.stringify(row))

func original_measure_build(kinds:Array)->Dictionary:
 # Identical supporting equipment on both sides of the conversion. No helper
 # is also one of the recipe inputs, so same-kind gates cannot mask a loss.
 var r=empty()
 for entry in [['w_sword',0,0],['w_broadblade',0,2],['w_pistol',0,4],['whiff',6,3],['zig',8,4]]:
  var p=inv.make_piece(entry[0],'common_'+entry[0]);p.x=entry[1];p.y=entry[2];r.items.append(p)
 for k in ['relic_capacitor','mat_42500030']:useful_place(r,k,'common_'+k)
 for index in kinds.size():useful_place(r,str(kinds[index]),'part' if index==0 else 'ingredient'+str(index))
 ck(inv.collection_legal(r.items,r.leader) and r.items.all(func(i):return inv.can_place(i,r.items,r.bags)),'full-input comparison uses legal nonoverlapping board')
 return r

func original_probe(r:Dictionary,enemy:Dictionary,side:int)->Dictionary:
 var b=B.new();var ctx=b.begin(r,enemy,128) if side==0 else b.begin(enemy,r,128)
 # Add equal longevity while preserving tea's real opening HP gain.
 for state in ctx.states:state.hp+=200;state.max_hp+=200
 var starting_hp=float(ctx.states[side].hp)
 for tick in range(1,201):b.step(ctx,float(tick)/10)
 var out={'dealt':0.0,'lost':starting_hp-float(ctx.states[side].hp),'starting_hp':starting_hp,'remaining_hp':float(ctx.states[side].hp),'shield':float(ctx.states[side].shield),'heal':0.0,'stamina':0.0,'noise':0.0,'frost':0.0,'counter':0.0,'wait':float(ctx.totals[side].stamina_wait_seconds),'charged':0.0}
 for e in ctx.events:
  if int(e.side)!=side:continue
  var v=float(e.get('actual_value',e.value))
  if e.kind in ['attack','derived','counter','noise_tick']:out.dealt+=v
  if e.kind in ['heal','stamina','noise','frost','counter']:out[e.kind]+=v
  if e.kind=='trigger' and e.get('charged',false):out.charged+=1
 return out
