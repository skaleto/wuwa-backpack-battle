extends SceneTree
## Audit sheet rendered by the game's native item renderer at current board pitch.
const OUT="res://build/qa/feedback-v116/icon-fit/"
const KINDS=["revive","tube","contract","judgment","lamp","cheongsam","glasses","field_notes","rations","echo_butterfly","spicy_meat","contract_echo","echo_bloom","contract_oath"]
var viewport:SubViewport
var after=false
class Sheet:
	extends "res://tests/fixtures/travel_fixture_v64.gd"
	var kinds:Array=[]
	var after=false
	func _draw()->void:
		if font==null:return
		draw_rect(Rect2(0,0,1440,640),Color("e9def3"))
		draw_string(font,Vector2(20,32),"V116 / 非武器占格审计 / "+("修改后" if after else "修改前")+"原生画法 · 实际背包格距",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("412d5b"))
		draw_string(body_font,Vector2(20,56),"原图像素与比例保持；紫色细线为实际占格，百分比为当前长轴覆盖。" if after else "仅审计；14 件均未调整图案、朝向或占格。紫色细线为实际占格，百分比为当前长轴覆盖。",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("624b79"))
		SKIN.begin_frame()
		for index in kinds.size():
			var kind=kinds[index]
			var card=Vector2(12+(index%7)*203,78+(index/7)*272)
			draw_rect(Rect2(card,Vector2(198,264)),Color("fff6e7"))
			draw_string(font,card+Vector2(10,25),C.items[kind].name,HORIZONTAL_ALIGNMENT_LEFT,184,14,Color("412d5b"))
			draw_string(body_font,card+Vector2(10,44),kind,HORIZONTAL_ALIGNMENT_LEFT,184,11,Color("7b6388"))
			var item=piece(kind,"audit_"+kind,0,0)
			var cells=inventory.cells(item);var extent=Vector2.ONE
			for cell in cells:extent=extent.max(Vector2(cell)+Vector2.ONE)
			var fit=_projection_for(kind,0,CELL)
			var pitch=_board_transform().x.length()*CELL
			var origin=card+Vector2(99,143)-extent*pitch*.5
			draw_basis=Transform2D(0,Vector2.ONE*(pitch/CELL),0,origin)
			draw_set_transform_matrix(draw_basis)
			for cell in cells:draw_rect(Rect2(Vector2(cell)*CELL,Vector2.ONE*CELL),Color("e1d5ee"))
			_draw_piece(item,Vector2.ZERO,1,-1,false)
			for cell in cells:draw_rect(Rect2(Vector2(cell)*CELL,Vector2.ONE*CELL),Color("78559c"),false,.7)
			draw_basis=Transform2D.IDENTITY;draw_set_transform_matrix(draw_basis)
			var ratio=fit.bounds.size[0 if extent.x>=extent.y else 1]/(maxf(extent.x,extent.y)*CELL)
			draw_string(body_font,card+Vector2(10,237),"%d×%d / %d%% / %d°"%[extent.x,extent.y,roundi(ratio*100),roundi(rad_to_deg(SKIN.item_angle(kind)))],HORIZONTAL_ALIGNMENT_LEFT,184,14,Color("624b79"))
		SKIN.end_frame()
func _initialize()->void:
	root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
	after="--after" in OS.get_cmdline_user_args()
	call_deferred("capture")
func capture()->void:
	viewport=SubViewport.new();viewport.size=Vector2i(1440,640);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var g=Sheet.new();g.kinds=KINDS.duplicate();g.after=after;viewport.add_child(g);await process_frame
	g.set_process(false);g.set_process_input(false);g.queue_redraw()
	for n in 3:await process_frame
	RenderingServer.force_draw(true);await process_frame
	assert(viewport.get_texture().get_image().save_png(OUT+("nonweapon-native-after.png" if after else "nonweapon-native-audit.png"))==OK)
	g.queue_free();await process_frame
	print("V116 NONWEAPON NATIVE AUDIT 14 items, isolated storage, hidden/unfocusable viewport")
	quit()
