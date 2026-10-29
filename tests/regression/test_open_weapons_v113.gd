extends SceneTree
const C=preload("res://scripts/data/catalog.gd")
const I=preload("res://tests/fixtures/recruitment_fixture_v113.gd")
const F=preload("res://scripts/crafting/craft.gd")
const SUP=preload("res://scripts/party/supports.gd")
const RULES=preload("res://scripts/crafting/craft_rules.gd")
const PB=preload("res://scripts/shop/practice_budget.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const V74=preload("res://scripts/compat/migration_v74_inventory.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 frozen_validation()
 recruitment()
 weapons()
 crafting()
 print("OPEN_WEAPONS_V113 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
func recruitment()->void:
 for leader in C.selectable_leaders():
  var run=inv.new_run(leader,113);run.round=2;run.gold=100
  var before=run.duplicate(true);var candidates=SUP.candidates(run)
  var expected=C.roster.keys().filter(func(id):return C.roster[id].released and id!=C.characters[leader].roster_id)
  ck(candidates.size()==expected.size() and expected.all(func(id):return id in candidates),"all released partners offered to "+leader)
  ck(SUP.candidates(run)==candidates and run==before,"candidate query deterministic and pure "+leader)
  var cross=expected.filter(func(id):return C.roster[id].element!=C.characters[leader].element)[0]
  var plan=inv.plan_recruit(run,cross)
  ck(plan.ok and run==before,"cross-element recruitment has a pure valid plan "+leader)
  if plan.ok:
   ck(inv.commit_operation(run,plan).ok,"cross-element recruitment commits "+leader)
   ck(run.gold==100-SUP.price(C.roster[cross]) and run.supports==[cross] and inv.validate_run(run),"recruitment retains public cost and support assignment "+leader)
   ck(not run.has("pending_carrier_type"),"recruitment does not create an unlock-carrier obligation "+leader)
   before=run.duplicate(true)
   ck(not inv.recruit(run,cross) and run==before,"duplicate recruitment atomic "+leader)
   ck(not inv.recruit(run,expected.filter(func(id):return id!=cross)[0]) and run==before,"one recruitment per round preserved "+leader)
  run=inv.new_run(leader,113);run.round=4;run.roster=expected.slice(0,3);run.supports=run.roster.slice(0,2);run.recruited_round=4
  ck(SUP.valid_team(run) and inv.validate_run(run),"mixed crew supports exactly two active slots "+leader)
  before=run.duplicate(true)
  ck(not inv.set_supports(run,run.roster) and run==before,"third active support rejected atomically "+leader)
  ck(inv.set_supports(run,[run.roster[2],run.roster[0]]) and run.supports==[run.roster[2],run.roster[0]],"two mixed supports can be reordered "+leader)
  before=run.duplicate(true)
  ck(not inv.set_supports(run,[run.roster[0],run.roster[0]]) and run==before,"duplicate support rejected atomically "+leader)
func weapons()->void:
 var definitions=C.items.duplicate(true)
 var types=[]
 for kind in C.items:
  if C.is_tag(kind,"weapon") and C.items[kind].weapon_type not in types:types.append(C.items[kind].weapon_type)
 for leader in C.selectable_leaders():
  var run=inv.new_run(leader,113)
  ck(types.all(func(type):return type in SUP.unlocked_types(run)),"all weapon types available at start "+leader)
  for kind in C.items:
   if not C.is_tag(kind,"weapon"):continue
   var d=C.items[kind];var facts=inv.craft_requirements(run,kind)
   ck(inv.craft_unlocked(run,kind) and facts.unlocked and facts.owner_met and facts.type_met and facts.owners.is_empty(),"weapon qualification has no character or type gate: "+leader+" / "+kind)
   ck(inv.signature_owned(run,kind) and PB.target_unlocked(run,kind),"practice and compatibility queries share open weapons: "+leader+" / "+kind)
   var owned=inv.make_piece(kind,"foreign_weapon");run.stash.append(owned)
   ck(inv.validate_run(run),"foreign owned weapon validates: "+leader+" / "+kind)
   run.stash.pop_back()
   ck(inv.element(owned,run)==C.characters[leader].element,"every weapon uses leader element: "+leader+" / "+kind)
   var hint=RULES.recruitment_hint(d,C.roster,C.characters[leader].element,[])
   ck(hint.compatible and hint.text=="已解锁","signature is not presented as a recruitment requirement: "+kind)
   var spec=d.get("v75",{})
   if spec.is_empty() or not spec.active or spec.craft_only:continue
   run.round=maxi(1,int(spec.shop_round))
   ck(inv.shop_eligible(run,kind),"scheduled weapon supply independent of leader: "+leader+" / "+kind)
   if int(spec.shop_round)>1:
    run.round=int(spec.shop_round)-1
    ck(not inv.shop_eligible(run,kind),"weapon supply round preserved: "+kind)
   run.round=1
  var pool=SHOP.distribution(run,0,inv)
  ck(types.all(func(type):return pool.keys().any(func(kind):return C.items[kind].weapon_type==type)),"first shelf weapon pool covers every type "+leader)
 ck(C.items==definitions,"open eligibility leaves all item prices and effects unchanged")
func arena(leader:String,recipe:Dictionary)->Dictionary:
 var run=inv.new_run(leader,113);run.items=[];run.stash=[];run.bags=[];run.shop=[{},{},{},{},{},{}];run.primary="";run.serial=2
 for y in range(0,6,2):
  for x in range(0,8,2):
   var bag=inv.make_piece("pouch","b%d_%d"%[x,y]);bag.x=x;bag.y=y;run.bags.append(bag)
 var base=inv.make_piece(recipe.base,"i1");base.paid_cost=2
 var mat=inv.make_piece(recipe.materials[0],"i2");mat.paid_cost=3
 run.items=[base];run.stash=[mat]
 run.primary=base.uid if C.is_tag(base.kind,"weapon") else ""
 run.golden_acquired=C.is_tag(base.kind,"golden") or C.is_tag(mat.kind,"golden")
 return run
func crafting()->void:
 for leader in C.selectable_leaders():
  for recipe in C.combinations:
   var run=arena(leader,recipe);var label=leader+" / "+recipe.id
   ck(inv.validate_run(run),"foreign recipe fixture validates "+label)
   var before=run.duplicate(true)
   ck(not F.transact(run,recipe.target,"i1",inv).ok and run==before,"stashed input cannot bypass adjacency "+label)
   ck(F.place_material(run,recipe.target,"i1",recipe.materials[0],inv).ok,"exact inputs can be placed "+label)
   before=run.duplicate(true)
   var preview=F.preview(run,recipe.target,"i1",inv)
   ck(preview.ok and run==before,"all recipes preview in round one for any leader "+label)
   var result=F.transact(run,recipe.target,"i1",inv)
   ck(result.ok,"all recipes craft without recruiting "+label)
   if result.ok:
    ck(result.consumed.size()==2 and "i1" in result.consumed and "i2" in result.consumed,"only exact inputs consumed "+label)
    ck(result.output.paid_cost==5 and run.gold==before.gold and inv.validate_run(run),"costs conserved and output legal "+label)
    before=run.duplicate(true)
    ck(not F.transact(run,recipe.target,"i1",inv).ok and run==before,"duplicate craft remains atomic "+label)

func frozen_validation()->void:
 var old_inv=V74.new()
 var run=inv.new_run("jiyan",113);run.round=2;run.catalogue_hash=V74.HASH;run.simulation_version="resonance-v60";run.shop=[{},{},{},{},{},{}]
 ck(old_inv.validate_run(run),"frozen V74 valid baseline remains accepted")
 ck(not old_inv.shop_eligible(run,"w_sword"),"frozen V74 shop still requires historical weapon type")
 var cross=C.roster.keys().filter(func(id):return C.roster[id].released and C.roster[id].element!=C.characters[run.leader].element)[0]
 run.roster=[cross];run.supports=[cross];run.recruited_round=2
 ck(not old_inv.validate_run(run),"frozen V74 rejects historically illegal cross-element recruitment")
 run.roster=[];run.supports=[];run.recruited_round=0;run.pending_carrier_type="sword"
 ck(not old_inv.validate_run(run),"frozen V74 carrier metadata requires a historically unlocked type")
