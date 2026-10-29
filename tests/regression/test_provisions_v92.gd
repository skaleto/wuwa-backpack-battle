extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const BASE=preload("res://scripts/battle/battle_v60.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const DESC=preload("res://scripts/ui/items/item_description.gd")
const ICONS=preload("res://scripts/ui/ability_icons.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func board(kind:String)->Dictionary:
 var r=inv.new_run("aemeath",19);r.items=[];r.stash=[];r.primary="";r.shop=[{},{},{},{},{},{}]
 var p=inv.make_piece(kind,"supply");p.paid_cost=C.items[kind].price;r.items.append(p)
 r.stash.append(inv.make_piece(kind,"stored"));return r
func activate(b,r,enemy):
 var ctx=b.begin(r,enemy,31)
 ctx.states[0].hp=ctx.states[0].max_hp*.4;ctx.states[0].stamina=2
 ctx.states[0].debuff_seen=true;ctx.states[0].noise=2;ctx.states[0].noise_until=20
 b.step(ctx,.1);b.step(ctx,6.1)
 return ctx
func test():
 # Frozen prior rules; V125 replacements covered by ecosystem suites.
 preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
 var old=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/catalog-v88.json"))
 var supplies=old.items.keys().filter(func(k):return "consumable" in old.items[k].tags)
 ck(supplies.size()==15,"all published current and legacy supplies covered")
 ck(ICONS.supports("provision") and ICONS.label("provision")=="补给","permanent category has existing food icon")
 var b=B.new();var enemy=inv.new_run("aemeath",7);enemy.items=[]
 for kind in supplies:
  ck(C.is_tag(kind,"provision") and not C.is_tag(kind,"consumable"),"permanent category "+kind)
  var r=board(kind);ck(inv.validate_run(r),"legal fixture "+kind)
  var before=r.items.duplicate(true);var stored=r.stash.duplicate(true)
  for fight in range(2):
   var ctx=activate(b,r,enemy)
   ck(ctx.events.filter(func(e):return e.side==0 and e.uid=="supply" and e.kind=="supply").size()==1,"one supply activation each battle "+kind)
   ck(not ctx.events.any(func(e):return e.kind=="consume"),"activation never requests disappearance "+kind)
   ck(not b.frame(6.1,ctx).progress[0].has("supply"),"nonperiodic supply has no fake cooling mask "+kind)
   ck(not ctx.events.any(func(e):return e.side==0 and e.uid=="stored"),"stash stays inactive "+kind)
   ck(r.items==before and r.stash==stored,"battle does not edit ownership "+kind)
   r.phase="result";r.combat={"used":ctx.used};inv.finish(r,1)
   ck(r.items==before and r.stash==stored,"used and unused pieces persist through settlement "+kind)
  ck(INFO.type_chips(kind).any(func(chip):return chip[0]=="provision"),"detail type chip "+kind)
 # Both sides execute exactly the same permanent rules, and duplicate calls cannot rearm a provision.
 var r=board("salt_tea");var ctx=activate(b,r,r);var count=ctx.events.filter(func(e):return e.side==0 and e.kind=="shield" and e.uid=="supply").size()
 ctx.states[0].hp=20;b.step(ctx,6.2)
 ck(ctx.events.filter(func(e):return e.side==0 and e.kind=="shield" and e.uid=="supply").size()==count,"low HP does not retrigger every frame")
 r=board("daily_tea");ctx=b.begin(r,r,31)
 ck(ctx.states[0].haste==2 and ctx.states[1].haste==2,"player and opponent share opening rules")
 # Capability matching must use the new category, including distant supply stars.
 r=board("aero_coin");var food=inv.make_piece("daily_tea","tea");food.y=1;r.items.append(food)
 ck(inv.star_links(r.items[0],r.items,r).any(func(p):return p.uid=="tea"),"new supply category lights eligible star")
 ctx=b.begin(r,enemy,31)
 ck(ctx.events.any(func(e):return e.kind=="star_trigger" and e.get("source_uid","")=="supply"),"permanent supply still fires supply-star effect")
 # Removing inventory consumption must not rename shield/noise resource spending.
 var kind="qa_v92_shield_spend";C.items[kind]=C.items.w_sword.duplicate(true)
 C.items[kind].erase("v75");C.items[kind].cooldown=99;C.items[kind].stamina=0
 C.items[kind].v60={"active":true,"activation":"cooldown","actions":[{"type":"damage","value":10}],"special":{"shield_strike":{"consume":3,"multiplier":2}}}
 r=board(kind);r.primary="supply";r.stash=[]
 var legacy=BASE.new();ctx=legacy.begin(r,enemy,31);ctx.states[0].shield=10;ctx.states[0].charge=0
 legacy.activate(ctx,0,r.items[0],1);legacy.commit_pending(ctx,1)
 ck(is_equal_approx(ctx.states[0].shield,7) and is_equal_approx(ctx.totals[0].damage,16),"nondefault shield-spend cost still executes exactly")
 C.items.erase(kind)
 print("PROVISIONS_V92 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
