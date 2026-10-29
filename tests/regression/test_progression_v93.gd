extends SceneTree
const I=preload("res://tests/fixtures/recruitment_fixture_v113.gd")
const C=preload("res://scripts/data/catalog.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
var inv=I.new();var checks=0;var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func settled(wins:int,losses:int,winner:int)->Dictionary:
 var r=inv.new_run("aemeath",19,"focused")
 r.wins=wins;r.losses=losses;r.round=wins+losses+1;r.phase="result"
 r.combat={"winner":winner,"used":[[],[]]}
 inv.finish(r,winner)
 return r
func _initialize():
 var six=settled(5,0,1)
 ck(six.wins==6 and six.phase=="shop" and six.round==7,"sixth win continues")
 ck(six.gold==9+15+1,"entering round seven grants fifteen plus win bonus")
 var eight=settled(7,0,1)
 ck(eight.wins==8 and eight.phase=="ending" and eight.gold==9,"eighth win ends without unused grant")
 var three=settled(0,2,-1)
 ck(three.losses==3 and three.phase=="shop" and three.round==4,"third loss continues")
 var four=settled(0,3,-1)
 ck(four.losses==4 and four.phase=="ending" and four.gold==9,"fourth loss ends")
 var last=settled(6,3,1)
 ck(last.wins==7 and last.losses==3 and last.round==11 and last.phase=="shop","seven wins three losses enters eleventh round")
 ck(inv.validate_run(last),"eleventh round valid run")
 last.round=11
 ck(inv.validate_ghost(inv.snapshot(last,"qa")),"eleventh round valid ghost")
 var invalid=last.duplicate(true);invalid.round=12
 ck(not inv.validate_run(invalid),"twelfth round rejected")
 var before=last.duplicate(true);inv.finish(last,1)
 ck(last==before,"repeated settlement cannot grant money or progress")
 ck(I.ECONOMY.budget(3)==30 and I.ECONOMY.budget(8)==100 and I.ECONOMY.budget(11)==153,"public cumulative economy")
 var practice=P.make_run(inv,11,3,"focused")
 ck(practice.round==11 and practice.practice_budget==153,"practice shares round limit and grants")
 ck(practice.practice_spend+practice.gold==153,"procurement ledger reconciles")
 print("PROGRESSION_V93 ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
