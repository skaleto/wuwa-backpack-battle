extends SceneTree
const F=preload("res://scripts/ui/crafting/fusion_view.gd")
var checks=0
var failures=0
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	root.hide();root.unfocusable=true
	AudioServer.set_bus_mute(0,true)
	call_deferred("test")
func sources()->Array:
	var image=Image.create(24,48,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(8,3,8,42),Color(.4,.6,.8,1))
	var texture=ImageTexture.create_from_image(image)
	var a=Transform2D(.6,Vector2(2,2),0,Vector2(80,130))
	var b=Transform2D(-.4,Vector2(1.5,1.5),0,Vector2(260,120))
	return [{"texture":texture,"pose":a,"center":a*Vector2(12,24)},{"texture":texture,"pose":b,"center":b*Vector2(12,24)}]
func test()->void:
	if "--fusion-native-pixels" in OS.get_cmdline_user_args():
		await native_glow_pixels()
		print("FUSION_V102_NATIVE ",checks," checks, ",failures," failures")
		quit(1 if failures else 0);return
	var view=F.new();root.add_child(view)
	var input=sources();var original=input.duplicate(true)
	var destination=Vector2(210,220)
	view.start(input,destination,"result")
	ck(view.parts.size()==2,"two committed inputs remain complete sprite silhouettes")
	var poses=[view.parts[0].sprite.transform,view.parts[1].sprite.transform]
	view.advance(.2)
	for i in 2:
		ck(view.parts[i].sprite.transform==poses[i],"initial whitening preserves full source pose "+str(i))
		ck(view.parts[i].sprite.material.get_shader_parameter("whiten")>0,"source whitens in place "+str(i))
	ck(view.output_alpha("result")==0 and view.output_alpha("other")==1,"only the committed result is hidden")
	view.advance(.42)
	for i in 2:
		var sprite:Sprite2D=view.parts[i].sprite
		var source_center:Vector2=input[i].center
		var center=sprite.transform*input[i].pose.affine_inverse()*source_center
		ck(center.distance_to(destination)<source_center.distance_to(destination),"full silhouette approaches actual destination "+str(i))
		ck(sprite.transform.get_scale().length()/poses[i].get_scale().length()>.90,"silhouette remains full-sized through approach "+str(i))
		ck(sprite.modulate.a==1.0,"material stays visible before result reveal "+str(i))
	ck(input==original,"presentation does not mutate caller render facts")
	var has_projection=view.has_method("effect_projection")
	ck(has_projection,"rendered local spark projection is available for deterministic draw")
	if not has_projection:
		view.free();print("FUSION_V102 ",checks," checks, ",failures," failures");quit(1);return
	var early=view.effect_projection()
	ck(early.sparks.is_empty() and early.gather.size()<=8,"approach has only a few local motes and no premature burst")
	ck(view.foreground is Node2D and view.foreground.z_index>view.parts[0].sprite.z_index,"white embers render above both silhouette sprites")
	for part in view.parts:
		ck(part.glow is Sprite2D and part.glow.texture==part.sprite.texture,"glow follows the full source alpha silhouette")
		ck(part.glow.transform==part.sprite.transform,"halo and full silhouette share the same pose")
	view.advance(F.LAND_AT-view.age)
	ck(view.output_alpha("result")==0,"first burst frame meets the existing output reveal boundary")
	var burst=view.effect_projection()
	ck(burst.sparks.size()>=12 and burst.sparks.size()<=24,"landing releases one bounded white ember burst")
	ck(burst.flash.radius<=28 and burst.flash.alpha>0,"flash is small and local to the landing")
	var first=burst.sparks.duplicate(true)
	view.advance(.10)
	var later=view.effect_projection()
	ck(view.output_alpha("result")>0 and view.output_alpha("result")<1,"new item fades in while consumed silhouettes fade out")
	for i in later.sparks.size():
		var spark=later.sparks[i]
		ck(spark.position.distance_to(destination)>first[i].position.distance_to(destination),"spark travels outward "+str(i))
		ck(spark.position.distance_to(destination)<100 and spark.alpha>0 and spark.alpha<1,"ember stays within the local landing area and fades "+str(i))
	ck(view.parts[0].sprite.modulate.a<.3,"old silhouette clears as result becomes visible")
	var projection=later.duplicate(true)
	seed(102);var expected=randf();seed(102)
	ck(view.effect_projection()==projection and randf()==expected,"repeated projection is stable and consumes no global RNG")
	view.advance(1.0)
	ck(not view.active() and view.get_child_count()==0 and view.parts.is_empty(),"natural completion frees silhouettes, halos, and foreground")
	ck(view.output_alpha("result")==1,"finished presentation restores normal result alpha")
	view.start(input,destination,"old");view.advance(.99)
	var old_children=view.get_children()
	var stash=Vector2(860,510)
	view.start(input,stash,"stored")
	ck(old_children.all(func(node):return not is_instance_valid(node)),"replacement frees every prior effect child immediately")
	view.advance(1.04)
	var stored=view.effect_projection()
	for i in stored.sparks.size():
		ck((stored.sparks[i].position-later.sparks[i].position).is_equal_approx(stash-destination),"burst tracks actual storage destination "+str(i))
	view.finish()
	ck(not view.active() and view.get_child_count()==0,"explicit cancellation frees every effect child")
	view.advance(10)
	ck(view.effect_projection().sparks.is_empty(),"cancelled presentation cannot leave deferred particles")
	view.start(input,destination,"again");view.start(input,destination,"")
	ck(view.get_child_count()==0 and not view.active(),"empty output cannot retain a previous presentation")
	view.free()
	print("FUSION_V102 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func native_frame(viewport:SubViewport)->Image:
	await process_frame
	RenderingServer.force_draw(true);await process_frame
	RenderingServer.force_draw(true);await process_frame
	return viewport.get_texture().get_image()
func native_glow_pixels()->void:
	ck(DisplayServer.get_name()!="headless" and AudioServer.get_driver_name()=="Dummy","isolated pixel check requires native rendering and Dummy audio")
	if DisplayServer.get_name()=="headless" or AudioServer.get_driver_name()!="Dummy":return
	var viewport=SubViewport.new();viewport.size=Vector2i(96,96)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var backdrop=ColorRect.new();backdrop.size=Vector2(96,96);backdrop.color=Color.BLACK;viewport.add_child(backdrop)
	var image=Image.create(64,64,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(28,12,8,40),Color.WHITE)
	var texture=ImageTexture.create_from_image(image)
	var view=F.new();viewport.add_child(view)
	view.start([{"texture":texture,"pose":Transform2D(0,Vector2(16,16)),"center":Vector2(48,48)}],Vector2(48,48),"pixel")
	view.advance(.20)
	# Isolate the actual production halo. The white body is deliberately hidden,
	# so transparent-edge pixels can only be illuminated by the blur shader.
	view.parts[0].sprite.hide()
	view.foreground.hide()
	var frame=await native_frame(viewport)
	var outside=frame.get_pixel(41,48).r
	ck(image.get_pixel(25,32).a==0 and outside>.02,"halo lights a transparent texel three pixels beyond the solid silhouette")
	ck(frame.get_pixel(48,48).r>.10,"halo also covers the source silhouette")
	ck(frame.get_pixel(20,20).r<.005,"distant transparent texels stay dark without a rectangular glow")
	DirAccess.make_dir_recursive_absolute("res://build/qa/feedback-v102/fusion")
	var label="red" if failures else "green"
	frame.save_png("res://build/qa/feedback-v102/fusion/halo-pixels-"+label+".png")
	view.advance(.86)
	var faded=await native_frame(viewport)
	ck(faded.get_pixel(41,48).r<.005,"halo clears when the consumed material finishes fading")
	print("HALO_PIXEL outside=",outside," core=",frame.get_pixel(48,48).r," far=",frame.get_pixel(20,20).r," faded=",faded.get_pixel(41,48).r)
	view.finish();viewport.queue_free();await process_frame
