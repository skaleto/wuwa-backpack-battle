extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
var failures=0
func ck(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():call_deferred("test")
func test():
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var before=g.run.duplicate(true);g.game_mode="async";g.run.pvp={"stage":"pending"}
 g._action("settings");g._settings_action("settings:updates");ck(g.overlay=="updates","frozen run can inspect updates")
 var e=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=true;g._input(e)
 ck(g.overlay=="settings","Escape leaves update overlay while online run frozen")
 g._settings_action("settings:updates")
 g.buttons=[{"rect":Rect2(900,160,100,60),"action":"updates:back","enabled":true,"modal":true}]
 var click=InputEventMouseButton.new();click.position=Vector2(950,190);click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;g._input(click)
 ck(g.overlay=="settings","back button works during frozen preparation")
 ck(not g._update_restart_safe(),"cannot restart during frozen run")
 g.run.erase("pvp");ck(g.run==before,"update UI leaves gameplay untouched")
 g.screen="camp";g.camp_saves={"practice":{"phase":"shop"},"async":{}};ck(not g._update_restart_safe(),"camp with resumable run cannot activate")
 g.camp_saves={"practice":{"phase":"ending"},"async":{}};ck(g._update_restart_safe(),"camp after run permits activation")
 g.queue_free();await process_frame;print("UPDATE_UI failures=",failures);quit(1 if failures else 0)
