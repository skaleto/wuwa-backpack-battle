extends SceneTree
## Local latency guard + full state/ledger parity against unchanged arrangement.
## V113 uses current open-weapon policy on both sides; the reference inventory
## retains exhaustive placement. Both sides must use the same
## authorized board size; comparing 8x6 and 9x7 would test different layouts.
const I=preload("res://scripts/inventory/inventory.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
const OLD=preload("res://tests/fixtures/data/gameplay-v93/checks/procurement-before-placement.gd")
const PLACEMENT=preload("res://scripts/shop/practice_placement.gd")
const OLD_PLACEMENT=preload("res://tests/fixtures/data/gameplay-v93/before/scripts/practice_placement.gd")
class ReferenceInventory extends I:
 const STASH=6 # Compatibility input for the frozen V93 craft reference only.
 # The original exhaustive first-fit algorithm, on the current logical domain.
 func first_fit(item:Dictionary,items:Array,bags:Array)->Dictionary:
  for rotation in 4:
   for y in HEIGHT:
    for x in WIDTH:
     var next=item.duplicate(true);next.merge({"x":x,"y":y,"rotation":rotation},true)
     if can_place_bag(next,bags,items) if C.is_tag(next.get("kind",""),"bag") else can_place(next,items,bags):return next
  return {}
var old_inv=ReferenceInventory.new();var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 var timings=[]
 for seed_value in [3,19]:
  for rn in [8,11]:
   var start=Time.get_ticks_msec();var expected=P.make_run(old_inv,rn,seed_value,"focused");var old_ms=Time.get_ticks_msec()-start
   start=Time.get_ticks_msec();var actual=P.make_run(inv,rn,seed_value,"focused");var new_ms=Time.get_ticks_msec()-start
   ck(actual==expected,"identical complete build, paid ledger, RNG and placement seed%d round%d"%[seed_value,rn])
   ck(inv.validate_run(actual),"optimized build remains valid")
   if rn==11:ck(new_ms<5000,"local round11 generation under5s; measured %dms"%new_ms)
   timings.append({"seed":seed_value,"round":rn,"before_ms":old_ms,"after_ms":new_ms,"exact_equal":actual==expected})
 # Dense acquired layouts include mixed shapes, rotations and partner directions.
 var report=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/data/gameplay-v93/reports/focused-ui-match-playthrough.json"))
 for n in range(0,report.samples.size(),4):
  var s=report.samples[n];var row=s.rounds[-1];var a=inv.new_run(s.leader,19,"focused")
  a.merge(s.final_snapshot,true);a.items=row.items.duplicate(true);a.bags=row.bags.duplicate(true)
  var b=a.duplicate(true);OLD_PLACEMENT.arrange(inv,a);PLACEMENT.arrange(inv,b)
  ck(a==b,"exact dense layout and equal-score tie result "+str(n))
 FileAccess.open("res://build/qa/gameplay-v93/reports/practice-performance.json",FileAccess.WRITE).store_string(JSON.stringify(timings,"\t"))
 print("PRACTICE_PERFORMANCE_V93 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
