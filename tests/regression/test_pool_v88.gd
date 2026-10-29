extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const C=preload("res://scripts/data/catalog.gd")
const POOL=preload("res://scripts/shop/playtest_pool.gd")
const SHOP=preload("res://scripts/shop/shop_v75.gd")
const MATCH=preload("res://scripts/shop/matchmaking.gd")
var inv=I.new()
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():
 preload("res://tests/fixtures/catalog_fixture_v124.gd").apply()
 ck(POOL.design.focused_pool.size()==94,"94 staged direct-shop choices; full catalogue is retained")
 for leader in C.selectable_leaders():
  var r=inv.new_run(leader,19,"focused")
  ck(inv.validate_run(r),"new focused run legal "+leader)
  for rn in [1,3,5]:
   r.round=rn
   var facts=SHOP.facts(r,inv)
   for k in facts.eligible:
    ck(C.is_tag(k,"bag") or k in POOL.design.focused_pool,"focused eligibility "+k)
   for slot in 5:
    var distribution=SHOP.pool(facts,slot)
    ck(not distribution.is_empty(),"no empty shop slots")
    ck(absf(distribution.values().reduce(func(a,b):return a+b,0.0)-1.0)<.001,"probabilities normalized")
  ck(inv.snapshot(r,"qa").pool_mode=="focused","export preserves mode")
 var focused=inv.new_run("aemeath",19,"focused")
 var facts=SHOP.facts(focused,inv);var normal=SHOP.ordinary_pool(facts,3);var assisted=SHOP.pool(facts,3)
 ck(not facts.partners.is_empty(),"focused star-partner slot has candidates")
 ck(facts.partners.all(func(k):return float(assisted.get(k,0))>float(normal.get(k,0))*.5),"one slot boosts legal partners while retaining ordinary opportunities")
 var old=inv.new_run("aemeath",19);old.erase("pool_mode")
 ck(inv.validate_run(old),"old missing mode remains full")
 ck(SHOP.facts(old,inv).eligible.size()>SHOP.facts(inv.new_run("aemeath",19,"focused"),inv).eligible.size(),"full comparison pool remains larger")
 var calls=[]
 var maker=func(rn,seed_value,mode="full"):
  calls.append(mode);var r=inv.new_run("aemeath",seed_value,mode);r.round=rn;return inv.snapshot(r,"qa")
 var mm=MATCH.new(maker,"v88-test")
 var full=mm.practice(1,19);var focus=mm.practice(1,19,"focused");mm.practice(1,19,"focused")
 ck(full.pool_mode=="full" and focus.pool_mode=="focused" and calls.size()==2,"mode-separated practice cache")
 var foreign=full.duplicate(true);foreign.round=4;foreign.owner="other";foreign.simulation_version=C.SIMULATION_VERSION
 var selected=mm.choose(4,19,[foreign],"self","focused")
 ck(selected.pool_mode=="focused","full-pool ghosts never match focused runs")
 var bot=inv.practice(2,7,"focused")
 ck(inv.validate_ghost(bot) and bot.pool_mode=="focused","practice bot buys from identical focused supply")
 ck(int(bot.practice_spend)+int(bot.practice_unspent)==inv.ECONOMY.budget(2),"bot obeys public economy")
 print("POOL_V88 ",checks," checks, ",failures," failures");quit(1 if failures else 0)
