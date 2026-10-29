extends SceneTree
## Reproducible star-only comparison. No Storage instance or real player data.
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
var inv=I.new()
func board(kind:String,partner_kind:String)->Dictionary:
 var r=inv.new_run("aemeath",19);r.items=[];r.stash=[];r.bags=[];r.primary="source"
 for y in range(0,6,2):
  for x in range(0,8,2):
   var bag=inv.make_piece("pouch","b%d%d"%[x,y]);bag.x=x;bag.y=y;r.bags.append(bag)
 var source=inv.make_piece(kind,"source");source.x=2;source.y=2;r.items.append(source)
 var partner=inv.make_piece(partner_kind,"partner")
 for turn in range(4):
  partner.rotation=turn
  for y in range(6):
   for x in range(8):
    partner.x=x;partner.y=y
    if inv.can_place(partner,r.items,r.bags) and inv.star_links(source,[source,partner],r).size()==1:
     r.items.append(partner);return r
 return r
func metrics(events:Array)->Dictionary:
 var m={"source_damage":0.0,"star_triggers":0,"prepared_attacks":0,"partner_advance_seconds":0.0,"frost_layers":0,"freezes":0,"shared_charge_spent":0}
 for e in events:
  if int(e.side)!=0:continue
  if e.kind=="star_trigger" and e.source_uid=="source":m.star_triggers+=1
  if e.kind=="cooldown_advance" and e.source_uid=="source" and e.target_uid=="partner":m.partner_advance_seconds+=float(e.value)
  if e.uid!="source":continue
  if e.kind in ["attack","derived","noise_tick","counter"]:m.source_damage+=float(e.value)
  if e.kind=="attack" and e.get("prepared",false):m.prepared_attacks+=1
  if e.kind=="frost" and e.value>0:m.frost_layers+=int(e.value)
  if e.kind=="freeze":m.freezes+=1
  if e.kind=="charge" and e.value<0:m.shared_charge_spent-=int(e.value)
 m.source_damage=snappedf(m.source_damage,.001);m.partner_advance_seconds=snappedf(m.partner_advance_seconds,.001)
 return m
func run_case(build:Dictionary,enemy:Dictionary)->Dictionary:
 var full=B.new().simulate(build,enemy,31,true)
 var battle=B.new();var ctx=battle.begin(build,enemy,31)
 for state in ctx.states:state.hp=9900;state.max_hp=10000
 for tick in range(1,201):battle.step(ctx,float(tick)/10.0)
 return {"battle":{"winner":full.winner,"duration":full.duration,"metrics":metrics(full.events)},"fixed_20_seconds":metrics(ctx.events)}
func _initialize():
 var current=C.items;var frozen=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v93.json")).items
 var report={"seed":31,"method":"Identical synthetic boards. Frozen V93 catalog and V101 catalog run through the current scheduler; controlled 20s traces only raise initial/max HP to prevent early deaths. No saved match is recomputed.","cases":[]}
 var enemy=inv.new_run("aemeath",31)
 for pair in [["weapon_21020076","whiff"],["weapon_21020045","w_gauntlet"],["weapon_21020086","w_gauntlet"]]:
  var build=board(pair[0],pair[1]);var before_build=build.duplicate(true)
  C.items=frozen
  var before=run_case(build,enemy)
  C.items=current
  var after=run_case(build,enemy)
  assert(build==before_build)
  report.cases.append({"weapon":pair[0],"name":current[pair[0]].name,"partner":pair[1],"board":build.items,"before":before,"after":after})
 var file=FileAccess.open("res://build/qa/feedback-v101/star-battle-comparison.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print(JSON.stringify(report));quit()
