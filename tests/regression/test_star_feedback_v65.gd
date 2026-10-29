extends SceneTree
const G=preload("res://scripts/game.gd")
var checks=0
var failures=0
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
	var game=G.new()
	check(game.has_method("_effect_star_state"),"star visual state reads actual placement conditions")
	if failures:game.free();quit(1);return
	game.run=game.inventory.new_run("aemeath",19)
	var source=game.inventory.make_piece("w_rectifier","source")
	game.run.items=[source]
	var target=game.inventory.make_piece("whiff","target");target.x=0;target.y=2
	var at=Vector2i(0,2)
	check(game._effect_star_state(source,[],at,game.run)=="unlit","unbought star cell is not shown as usable")
	var bag=game.inventory.make_piece("satchel","added");bag.y=2;game.run.bags.append(bag)
	check(game._effect_star_state(source,[source],at,game.run)=="available","empty owned star cell appears ready")
	check(game._effect_star_state(source,[source,target],at,game.run)=="lit","matching echo lights real rectifier star")
	var wrong=game.inventory.make_piece("daily_tea","wrong");wrong.x=0;wrong.y=2
	check(game._effect_star_state(source,[source,wrong],at,game.run)=="unlit","wrong category does not light the star")
	var future=game.run.duplicate(true);future.items=[source,target]
	var before=future.duplicate(true)
	check(game._effect_star_state(source,future.items,at,future)=="lit","drag preview uses its future occupants")
	check(future==before,"visual query never mutates the build")
	check(game._effect_star_state(source,[source,target],Vector2i(7,5),game.run)=="unlit","unrelated cell cannot show a lit star")
	source.rotation=1;source.x=2;source.y=0
	var rotated=game.inventory.stars(source)[0];target.x=rotated.x;target.y=rotated.y
	check(game._effect_star_state(source,[source,target],rotated,game.run)=="lit","rotation moves the same real effect star")
	print("STAR_FEEDBACK_V65: ",checks," checks, ",failures," failures")
	game.free();quit(1 if failures else 0)
