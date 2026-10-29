extends SceneTree
const S=preload("res://scripts/ui/visual_skin.gd")
func _initialize():call_deferred("measure")
func measure():
	var start=Time.get_ticks_usec();var results=[]
	for name in ["board_frame","shop_tray","stash","background","button","price_ribbon","detail_panel","paper_texture","bag_suede"]:
		var at=Time.get_ticks_usec();var path=S.ui_path(name);S.texture(path)
		results.append({"asset":name,"ms":(Time.get_ticks_usec()-at)/1000.0})
	var at=Time.get_ticks_usec();S.texture(S.portrait_path("aemeath"))
	results.append({"asset":"aemeath","ms":(Time.get_ticks_usec()-at)/1000.0})
	print(JSON.stringify({"total_ms":(Time.get_ticks_usec()-start)/1000.0,"parts":results}))
	quit()
