extends SceneTree
const I=preload("res://scripts/inventory/inventory.gd")
const NEW=preload("res://scripts/battle/battle.gd")
const OLD=preload("res://build/qa/feedback-v112/before/scripts/battle/battle_v75.gd")
const P=preload("res://scripts/shop/practice_budget.gd")
var inv=I.new()
func _initialize()->void:
 var rows=[];var a=NEW.new();var old=OLD.new()
 for rn in [1,3,6,10]:
  var builds=[]
  for seed_value in 6:builds.append(P.make_run(inv,rn,seed_value,"full"))
  for index in 6:
   var player=builds[index];var other=builds[(index+1)%6];var before=player.duplicate(true)
   var prior=old.simulate(player,other,23,false);var now=a.simulate(player,other,23,false)
   var reversed=a.simulate(other,player,23,false)
   assert(now.winner==-reversed.winner);assert(player==before)
   rows.append({"round":rn,"leader":player.leader,"opponent":other.leader,"old_winner":prior.winner,"new_winner":now.winner,"old_duration":prior.duration,"new_duration":now.duration,"old_wait":prior.totals.map(func(t):return t.stamina_wait_seconds),"new_wait":now.totals.map(func(t):return t.stamina_wait_seconds),"symmetry":true})
  print("MATCHUPS round ",rn," complete")
 FileAccess.open("res://build/qa/feedback-v112/matchups.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"));print("MATCHUPS ",rows.size()," compared; ",rows.filter(func(r):return r.old_winner!=r.new_winner).size()," outcomes changed");quit()
