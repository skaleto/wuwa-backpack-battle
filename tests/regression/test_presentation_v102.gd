extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const QUALITY=preload("res://scripts/ui/items/item_quality.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	AudioServer.set_bus_mute(0,true);call_deferred("test")
func test()->void:
	var game=G.new();root.add_child(game);await process_frame
	game.set_process(false);game.set_process_input(false)
	var r=game.run
	var sword=game.piece("weapon_21020024","source",1,3);sword.rotation=2
	var echo=game.piece("heron","target",3,1)
	r.items=[sword,echo,game.piece("zig","other",2,2)];r.primary="source";r.bags=[];r.shop=[{},{},{},{},{},{}]
	for y in range(0,6,2):
		for x in range(0,8,2):r.bags.append(game.piece("pouch","b%d%d"%[x,y],x,y))
	ck(game.inventory.validate_run(r),"test construction uses legal distinct items")
	var before=JSON.stringify(r)
	var selected=game._effect_star_markers(echo,r.items,r)
	var preview=game._drag_star_markers({"ok":true,"piece":echo,"run":r})
	ck(preview==selected,"holding/clicking a recipient shows only that item's own stars")
	ck(preview.all(func(m):return m.target_uid!=echo.uid),"incoming source stars cannot appear on selected recipient")
	ck(game._drag_star_markers({"ok":false}).is_empty(),"invalid preview cannot show successful stars")
	for turn in 4:
		var candidate=r.duplicate(true);candidate.items[1].rotation=turn
		var held=candidate.items[1]
		var shown=game._drag_star_markers({"ok":true,"piece":held,"run":candidate})
		ck(shown==game._effect_star_markers(held,candidate.items,candidate),"own stars share rotated geometry %d"%turn)
	var mixed=game._effect_star_markers(sword,r.items,r)
	ck(mixed.filter(func(m):return m.state=="lit" and m.target_uid==echo.uid).size()==1,"multiple covered cells count the echo only once")
	ck(JSON.stringify(r)==before,"star visibility never changes the run")
	var quality=QUALITY.new()
	# V117 replaces bounding-box motes with alpha-masked surface light.
	ck(quality.has_method("surface_bands"),"high rarity motion has a pure bounded projection")
	if quality.has_method("surface_bands"):
		var size=Vector2(280,56)
		for kind in ["w_sword","weapon_21020024","mat_43020031","satchel"]:
			ck(quality.surface_bands(kind,size,2.0).is_empty(),"low rarity and bags have no surface sweep: "+kind)
		for kind in ["heron","weapon_21020076"]:
			var seen=false;var changed=false;var previous=[]
			for n in 30:
				var at=quality.surface_bands(kind,size,n*.15)
				seen=seen or not at.is_empty();changed=changed or at!=previous
				ck(at.size()<=16,"bounded surface draw count")
				ck(at==quality.surface_bands(kind,size,n*.15),"same display time yields same surface light")
				previous=at
			ck(seen and changed,"gold/red surface light actually moves")
	ck(game.has_method("_item_fx_clock"),"quality animations share a pause-aware presentation clock")
	if game.has_method("_item_fx_clock"):
		r.phase="battle";game.paused=true;game.combat_time=4
		var frozen=game._item_fx_clock();game._process(.5)
		ck(game._item_fx_clock()==frozen,"pausing battle freezes rarity effects")
		r.phase="shop";var moving=game._item_fx_clock();game._process(.5)
		ck(game._item_fx_clock()>moving,"preparation keeps ambient quality motion")
	quality=null;game.queue_free();await process_frame
	# Both music tracks were exercised; let the audio mixer release Ogg playback.
	await create_timer(1.0).timeout
	print("PRESENTATION_V102 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
