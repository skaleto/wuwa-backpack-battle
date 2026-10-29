extends SceneTree
const B=preload("res://scripts/battle/battle.gd")
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://scripts/inventory/inventory.gd")
const INFO=preload("res://scripts/ui/items/item_presentation_v75.gd")
var b=B.new();var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func p(k,id=""):return inv.make_piece(k,k if id=="" else id)
func build(items,primary=""):return {"leader":"aemeath","round":2,"items":items,"primary":primary,"bags":[],"roster":[],"supports":[]}
func advance(ctx,t):
 while ctx.time+.00001<t:b.step(ctx,minf(t,ctx.time+.1))
func _initialize():
 # Frozen prior rules; V125 replacements covered by ecosystem suites.
 preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
 call_deferred("test")
func test():
 var a=p("w_sword","a");var z=p("weapon_21020104","z");z.y=1
 var enemy=build([p("w_gauntlet"),p("zig")])
 var reference=b.simulate(build([a,z],"a"),enemy,31,false)
 for rank in ["z","", "obsolete"]:
  ck(b.simulate(build([a,z],rank),enemy,31,false)==reference,"old primary metadata cannot alter combat "+rank)
 var ctx=b.begin(build([a,z],"a"),enemy)
 ck(b.weapon_damage_weight(ctx,0,a)==1 and b.weapon_damage_weight(ctx,0,z)==1,"both weapons deal full damage")
 # Exact spend: a shared pool is consumed once, never copied to every ready weapon.
 ctx.states[0].charge=6;ctx.progress[0][z.uid]=1;b.step(ctx,.01)
 ck(ctx.events.any(func(e):return e.side==0 and e.kind=="heavy" and e.uid==z.uid),"formerly additional weapon can charge")
 ck(ctx.events.filter(func(e):return e.side==0 and e.kind=="charge" and e.value<0).size()==1,"one pool spent exactly once")
 # V124 replaces Wing's post-charge buff with charge from each third natural
 # attack. Keep the real shared-pool spend checks above and exercise its new gain.
 var wing_ctx=b.begin(build([z]),build([]));wing_ctx.states[0].charge=0
 for index in 3:
  b.activate(wing_ctx,0,z,float(index+1));b.commit_pending(wing_ctx,float(index+1))
  ck(wing_ctx.states[0].charge==(2 if index==2 else 0),"wing gains exactly two charge on the third natural attack "+str(index+1))
 ck(wing_ctx.events.filter(func(e):return e.kind=="charge" and e.uid==z.uid and e.value==2).size()==1,"wing emits one real charge gain")
 # Both roles in a legacy support team use full weight too.
 ctx.builds[0].supports=["role_1403"]
 ck(b.weapon_damage_weight(ctx,0,z)==1,"recruit assignment never discounts damage")
 var specs=JSON.parse_string(FileAccess.get_file_as_string("res://data/compat/design/v86.json")).materials
 ck(specs.size()==19,"all nineteen formerly inert materials covered")
 for kind in specs:
  var item=p(kind);var spec=specs[kind].effect;var target=p("w_sword" if spec.category=="weapon" else "zig","target")
  if not spec.category.is_empty():
   var star=inv.stars(item)[0];target.x=star.x;target.y=star.y
   ck(inv.star_eligible(item,target),"star filter matches promised material target "+kind)
  ctx=b.begin(build([item,target]),enemy)
  ctx.states[0].hp=30;ctx.states[0].stamina=0;ctx.states[0].charge=0;ctx.states[1].shield=30
  b.apply_noise(ctx,1,p("thundering"),1,0)
  ctx.progress[0].clear();ctx.progress[1].clear()
  if spec.action=="advance":ctx.progress[0][target.uid]=0
  var before=ctx.events.size()
  if spec.trigger=="clock":
   b.MATERIALS.tick(b,ctx,0,item,float(spec.period));b.commit_pending(ctx,float(spec.period))
  if spec.action in ["flat","charged"]:ck(not b.own(ctx,0,target).buffs.is_empty(),"material gives real targeted bonus "+kind)
  elif spec.trigger=="clock":ck(ctx.events.slice(before).any(func(e):return e.uid==item.uid or e.get("source_uid","")==item.uid),"material produces a real event "+kind)
  else:ck(ctx.events.any(func(e):return e.uid==item.uid),"opening material actually fires "+kind)
  ck(not item.uid in ctx.used[0],"craft component persists after battle "+kind)
  ck(not str(INFO.effects(kind)).contains("不参与战斗"),"details show current effect "+kind)
  # Same kind is bounded, but ownership remains two physical items.
  var two=b.begin(build([item,p(kind,"copy"),target]),enemy)
  if spec.trigger=="opening":
   var one=b.begin(build([item,target]),enemy)
   ck(two.states[0]==one.states[0] and two.local[0][target.uid].buffs==one.local[0][target.uid].buffs,"duplicate opening does not double "+kind)
  else:
   two.states[0].hp=30;two.states[0].stamina=0;two.states[0].charge=0;two.states[1].shield=30
   b.MATERIALS.tick(b,two,0,item,float(spec.period));b.commit_pending(two,float(spec.period))
   var prior_events=two.events.duplicate(true);var prior_states=two.states.duplicate(true)
   b.MATERIALS.tick(b,two,0,p(kind,"copy"),float(spec.period));b.commit_pending(two,float(spec.period))
   ck(two.events==prior_events and two.states==prior_states,"duplicate clock cannot double effect "+kind)
 # Heal/shield/noise materials are valid partners for those exact capability stars.
 for kind in ["mat_42310090","mat_43020041","mat_41100011"]:
  var category={"mat_42310090":"heal","mat_43020041":"shield","mat_41100011":"noise"}[kind]
  ck(b.capability(p(kind),category),"material capability recognized by battle "+category)
 # An unlinked copy must not steal a useful linked copy's shared activation.
 var invalid=p("strategy","a-invalid");invalid.x=6
 var valid=p("strategy","z-valid");var target=p("w_sword","target");target.x=inv.stars(valid)[0].x;target.y=inv.stars(valid)[0].y
 ctx=b.begin(build([invalid,valid,target]),enemy)
 ck(not b.own(ctx,0,target).buffs.is_empty() and ctx.events.any(func(e):return e.kind=="star_trigger" and e.uid==valid.uid),"unlinked opening copy cannot block linked material")
 invalid=p("tuner","a-invalid");invalid.x=6;valid=p("tuner","z-valid");target=p("turtle","healer");target.x=inv.stars(valid)[0].x;target.y=inv.stars(valid)[0].y
 ctx=b.begin(build([invalid,valid,target]),build([]));ctx.states[0].hp=30
 advance(ctx,4)
 ck(is_equal_approx(b.frame(4,ctx).cooldown_fractions[0][valid.uid],.5),"material icon shows its real independent clock")
 advance(ctx,8)
 ck(ctx.events.any(func(e):return e.kind=="cooldown_advance" and e.get("source_uid","")==valid.uid and e.uid==target.uid and e.value>0),"tuner advances healing-only echo, unlinked copy cannot steal clock")
 print("WEAPONS_MATERIALS_V86 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
