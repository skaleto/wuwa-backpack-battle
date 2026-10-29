extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const B=preload("res://scripts/battle/battle.gd")
const C=preload("res://scripts/data/catalog.gd")
const A=preload("res://scripts/party/crew_abilities.gd")
const R=preload("res://scripts/battle/battle_review.gd")
const SUP=preload("res://scripts/party/supports.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const OLD=preload("res://scripts/compat/migration_pre_v113_inventory.gd")
const CAP=preload("res://tests/fixtures/capacity_fixture_v111.gd")
var inv=I.new()
func build(kinds:Array,roles:Array=[])->Dictionary:
 var r=inv.new_run("aemeath",19);r.round=8;r.gold=0;r.items=[];r.stash=[];r.bags=CAP.full_bags(inv);r.serial=500
 r.roster=roles.duplicate();r.supports=roles.duplicate();r.recruited_round=8 if not roles.is_empty() else 0
 for kind in kinds:
  var fit=inv.first_fit(inv.make_piece(kind,"i%d"%r.items.size()),r.items,r.bags)
  assert(not fit.is_empty());r.items.append(fit)
 r.primary=r.items[0].uid if not r.items.is_empty() else ""
 assert(inv.validate_run(r));return r
func _initialize()->void:
 var battle=B.new();var cases={
  "多武器":[["w_sword","w_sword","w_sword","whiff"],"role_1510","role_1108"],
  "武器声骸":[["w_sword","whiff","echo_glacio"],"role_1105","role_1506"],
  "护盾反击":[["w_sword","bellborne"],"role_1405","role_1108"],
  "治疗充能":[["w_sword","turtle","medical"],"role_1503","role_1108"],
  "霜渐":[["weapon_21020086","w_broadblade","echo_glacio"],"role_1108","role_1506"],
  "双队友":[["w_sword","w_sword","w_sword","whiff","turtle"],"role_1510","role_1410"]}
 var combat_rows=[]
 var opponent=build(["w_sword","w_sword","whiff","bellborne"])
 for title in cases:
  var spec=cases[title]
  var variants={"原配置":build(spec[0]),"匹配队友":build(spec[0],[spec[1]]),"另一队友":build(spec[0],[spec[2]])}
  # Same 5-gold marginal investment (two-item alternative has public price 2+3).
  if SUP.price(C.roster[spec[1]])==5:variants["5币买物品"]=build(spec[0]+["whiff","medical"])
  if title=="双队友":variants["两人上阵"]=build(spec[0],[spec[1],spec[2]])
  for variant in variants:
   var own=variants[variant];var ctx=battle.begin(own,opponent,113)
   for side in 2:ctx.states[side].hp=9000;ctx.states[side].max_hp=10000
   for tick in 300:battle.step(ctx,(tick+1)*.1)
   var crew_rows=R.rows({"events":ctx.events},[own,opponent],0,30).filter(func(row):return str(row.uid).begins_with("crew:"))
   var result=battle.simulate(own,opponent,113,false)
   combat_rows.append({"case":title,"variant":variant,"seconds":30,"damage":ctx.totals[0].damage,"wait_seconds":ctx.totals[0].stamina_wait_seconds,"crew":crew_rows,"actual_duel":{"winner":result.winner,"duration":result.duration},"extra_cost":own.supports.reduce(func(n,role):return n+SUP.price(C.roster[role]),0)+(5 if variant=="5币买物品" else 0)})
 var supply=[];var historical=OLD.new()
 for leader in C.selectable_leaders():
  for round_number in range(1,5):
   var current=inv.new_run(leader,19);current.round=round_number
   for version in ["before","after"]:
    var source=historical if version=="before" else inv
    var facts=SHOP.facts(current,source);var missing=SHOP.missing_from(facts);var no_partner=1.0
    for slot in 5:
     var pool=SHOP.pool(facts,slot);var p=0.0
     for kind in missing:p+=float(pool.get(kind,0))
     no_partner*=1-p
    var rng=RandomNumberGenerator.new();rng.seed=113;var hits=0
    for draw in 200:
     var offers=SHOP.roll(facts,[],[],rng)
     if offers.any(func(o):return o.get("kind","") in missing):hits+=1
    supply.append({"leader":leader,"round":round_number,"version":version,"partners":missing,"at_least_one_probability":1-no_partner,"sample_hits":hits,"sample_size":200})
 FileAccess.open("res://build/qa/recruitment-v113/measurements.json",FileAccess.WRITE).store_string(JSON.stringify({"combat":combat_rows,"supply":supply,"note":"30秒高生命控制窗口用于贡献测量；actual_duel 为正常生命同对手战果。空间位置由 first_fit 固定，无主动调优。"},"\t"))
 print("V113 measurements: ",combat_rows.size()," combat comparisons, ",supply.size()," shop distributions × 200 draws")
 quit()
