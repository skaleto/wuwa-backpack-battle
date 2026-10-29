extends Node2D

const APPLICATION=preload("res://scripts/run/run_application.gd")
const ASYNC_APPLICATION=preload("res://scripts/online/async_run_application.gd")
const ASYNC_PROTOCOL=preload("res://scripts/online/async_pvp.gd")
var game_mode="practice"
var practice_storage
var online_storage
var online_client
var camp_saves:Dictionary={}
var matching=false
const PROGRESSION=preload("res://scripts/run/run_progression.gd")
const PREPARATION=preload("res://scripts/inventory/preparation_rules.gd")
const BATTLE_FEEDBACK=preload("res://scripts/ui/battle/battle_feedback.gd")
const BATTLE_REVIEW=preload("res://scripts/battle/battle_review.gd")
const REVIEW_VIEW=preload("res://scripts/ui/battle/battle_review_view.gd")
const ABILITY_ICONS=preload("res://scripts/ui/ability_icons.gd")
const RECRUITMENT=preload("res://scripts/party/recruitment.gd")
const RECRUITMENT_PRESENTER=preload("res://scripts/ui/party/recruitment_presenter.gd")
const RECRUITMENT_ART=preload("res://scripts/ui/party/recruitment_art.gd")
var recruitment_view=preload("res://scripts/ui/party/recruitment_view.gd").new()
var crew_setup_view=preload("res://scripts/ui/party/crew_setup_view.gd").new()
var recruitment_arrival_ability=""

const Q_BATTLE=preload("res://scripts/ui/battle/chibi_battle_view.gd")
const Q_STAR=preload("res://scripts/ui/items/chibi_effect_star.gd")
const STAR_FEEDBACK=preload("res://scripts/ui/items/star_feedback.gd")
var placement_stars=preload("res://scripts/ui/items/placement_star_feedback.gd").new()
var star_activations=preload("res://scripts/ui/items/star_activation_view.gd").new()
const QL=preload("res://scripts/ui/chibi_layout.gd")
const SKIN=preload("res://scripts/ui/visual_skin.gd")
const FEATURES=preload("res://scripts/run/demo_features.gd")
const INFO=preload("res://scripts/ui/items/item_info.gd")
const ITEM_HIT=preload("res://scripts/ui/items/item_hit.gd")
const AUDIO=preload("res://scripts/ui/audio/event_audio.gd")
const MUSIC=preload("res://scripts/ui/audio/music_audio.gd")
const ACTION_BUTTON=preload("res://scripts/ui/chibi_action_button.gd")
const ITEM_PANEL=preload("res://scripts/ui/items/item_panel.gd")
const C = preload("res://scripts/data/catalog.gd")
const FORGE = preload("res://scripts/crafting/craft.gd")
const FORGE_VIEW = preload("res://scripts/ui/crafting/forge_view.gd")
const GLINTS=preload("res://scripts/ui/items/item_glints.gd")
const QUALITY = preload("res://scripts/ui/items/item_quality.gd")
const ITEM_SHADOW = preload("res://scripts/ui/items/item_shadow.gd")
const RELAY_VIEW = preload("res://scripts/ui/battle/relay_view.gd")
const I = preload("res://scripts/inventory/inventory.gd")
const B = preload("res://scripts/battle/battle.gd")
const S = preload("res://scripts/storage/storage.gd")
const SUP = preload("res://scripts/party/supports.gd")
const M = preload("res://scripts/ui/presentation.gd")
const GRID = preload("res://scripts/ui/pockets/frequency_grid.gd")
const POCKETS=preload("res://scripts/inventory/pocket_profiles_v129.gd")
const POCKET_VIEW=preload("res://scripts/ui/pockets/pocket_view.gd")
const TERMINAL=preload("res://scripts/ui/pockets/terminal_grid.gd")
const ART_GEOMETRY=preload("res://scripts/ui/items/art_geometry.gd")
const PROJECTION = preload("res://scripts/ui/items/icon_projection.gd")
const COOLDOWN = preload("res://scripts/ui/items/icon_cooldown.gd")
const ART = preload("res://scripts/ui/items/item_art.gd")
const ITEM_DISPLAY = preload("res://scripts/ui/items/item_display.gd")
const STAGE = preload("res://scripts/ui/battle/frequency_stage.gd")
const T = preload("res://scripts/ui/ui_theme.gd")
const PORTRAIT_LIGHT = preload("res://scripts/ui/portraits/portrait_lighting.gd")
const RIG_VIEW = preload("res://scripts/ui/portraits/portrait_rig_view.gd")
const COMBAT_VFX = preload("res://scripts/ui/battle/combat_vfx.gd")
const BOARD = Vector2(60,440)
const ENEMY_BOARD = Vector2(932,440)
const CELL = 56.0
const BATTLE_ENTRY_DURATION = 0.32
const ITEM_SELECTION_DURATION = 0.20
const PREPARATION_PITCH = CELL*1.35
const PREPARATION_ORIGIN = Vector2(357.6,245.2)
const BAG_STYLE_BUTTON = Rect2(712,164,158,36)
const INK = T.INK
const CREAM = T.PAPER
const GOLD = T.BRASS
const GREEN = T.JADE
# The catalogue retains researched source images and hashes for save compatibility.
# Game and documentation share original-source display selections.
static var ART_ASSETS: Dictionary = ART.paths()
# Each original-source selection has its own orientation.
static var ART_ANGLES: Dictionary = ART.angles()

var portrait_light = PORTRAIT_LIGHT.new()
var portrait_lighting_enabled = true
var native_rigs_enabled = true
var readable_icons_enabled = false
var portrait_rigs: Dictionary = {}
var motion = M.new()
var fusion_view=preload("res://scripts/ui/crafting/fusion_view.gd").new()
var inline_craft = preload("res://scripts/crafting/inline_craft.gd").new()
var carry_replacement=false
var stash_transfer = preload("res://scripts/inventory/stash_transfer.gd").new()
var combat_vfx = COMBAT_VFX.new()
var transition_image: Texture2D
var battle_entry_age=1.0
var battle_entry_from=Transform2D.IDENTITY
var chibi_paper_surfaces:Array=[]
var paint_alpha = 1.0
var paint_offset = Vector2.ZERO
var shape_cache: Dictionary = {}
var projection_cache: Dictionary = {}
var descriptor_cache: Dictionary = {}
var phase_age = 1.0
var reroll_age = 1.0
var old_shop: Array = []
var inventory = I.new()
var engine = B.new()
var storage = null
var font: Font
var body_font: Font
var selection_age=1.0
var camp_age=0.0
var camp_previous_leader=""
var camp_loadouts: Dictionary = {}
var draw_basis=Transform2D.IDENTITY
var lock_animation:Dictionary={}
const SHOP_PRESENTATION=preload("res://scripts/ui/shop_presentation.gd")
var capacity_pan=Vector2.ZERO
var capacity_pan_left=0.0
var hit_pause=0.0
var hit_pause_cooldown=0.0
var attack_left=[0.0,0.0]
var gear_flights: Array=[]
var pending_impacts: Array=[]
var skip_requested=false
var icons: Dictionary = {}
var portraits: Dictionary = {}
var crew_portraits: Dictionary = {}
var crew_busts: Dictionary = {}
var leader_illustrations: Dictionary = {}
var leader_art_bounds: Dictionary = {}
var camp_page = 0
var forge_base = ""
var forge_index = 0
var forge_cache_key = ""
var forge_options: Array=[]
var forge_output: Dictionary={}
var chase_cues: Array=[]
var advance_cues: Array=[]
var item_sways: Dictionary={}
var crew_page = 0
var crew_filter = ""
var crew_tab = "recruit"
var crew_focus = ""
var crew_skill_kind = "intro"
var crew_skill_page = 0
var crew_text_cache: Dictionary = {}
var support_flights: Array = []
var audio
var music
var muted = false
var run: Dictionary = {}
var saved: Dictionary = {}
var opponent: Dictionary = {}
var combat: Dictionary = {}
var combat_time = 0.0
var speed = 1.0
var paused = false
var event_cursor = 0
var review=BATTLE_REVIEW.new()
var review_panel=true
var review_side=0
var review_metric="damage"
var review_focus=""
var review_all_events=true
var review_timeline_side=-1
var review_item_page=0
var review_event_offset=0
var review_selected_event=-1
var review_scrubbing=false
var review_resume_after_scrub=false
var review_buttons:Array=[]
var review_timeline:Array=[]
var review_markers:Array=[]
const HISTORY_VIEW=preload("res://scripts/ui/battle/battle_history_view.gd")
var history_rows:Array=[]
var history_buttons:Array=[]
var history_page=0
var history_selected=0
var history_record:Dictionary={}
var history_parent_overlay=""
var history_return:Dictionary={}
var review_tail=0.0
var review_pose_time=0.0
var screen = "camp"
var selected_leader = "aemeath"
var buttons: Array = []
var mouse = Vector2.ZERO
var hovered: Dictionary = {}
var hover_time = 0.0
var dragging: Dictionary = {}
var drag_pressed=false
var drag_press_at=Vector2.ZERO
var drag_distance=0.0
var drag_rotated=false
var drag_fraction=Vector2.ONE*.5
var item_hit=ITEM_HIT.new()
var detail_anchor=Rect2()
var detail_parent_overlay=""
var rejection_piece:Dictionary={}
var rejection_rect=Rect2()
var rejection_left=0.0
var detail_item:Dictionary={}
var detail_origin=""
var detail_offer_index=-1
var detail_page=0
var detail_history:Array=[]
var detail_recipe_index=0
var detail_base_index=0
var star_click_uid=""
var star_click_origin=""
var star_click_elapsed=Q_STAR.CLICK_DURATION
var item_selection_age=ITEM_SELECTION_DURATION
var drag_origin = ""
var drag_offset = Vector2i.ZERO
var drag_offer_index = -1
var drag_turn_remaining = 0.0
const DRAG_TURN_DURATION = .2
var drag_source:Dictionary={}
var drag_source_center=Vector2.ZERO
var drag_center_offset=Vector2.ZERO
var drag_target_angle=0.0
var drag_turn_from=0.0
var drag_turn_age=DRAG_TURN_DURATION
var bag_mode = false
const STASH_PAGE_SIZE = 6
var stash_cursor = 0
var stash_page = 0
var stash_page_pressed = false
var relay_mode = false
var relay_draft: Array = []
var material_page = 0
var replacement_kind = ""
var replacement_target = ""
var replacement_rotation = 0
var material_uid = ""
var material_target = ""
var material_choice = "strong"
var catalogue_page = 0
var catalogue_focus = 0
var floats: Array = []
var projectiles: Array = []
var flashes: Dictionary = {}
var lunge = [0.0,0.0]
var burst_text = ""
var burst_timer = 0.0
var toast = ""
var toast_timer = 0.0
var overlay = ""
var dialog: FileDialog
var exporting = false
var age = 0.0

func _init() -> void:
	add_child(fusion_view)
	add_child(recruitment_view)
	add_child(crew_setup_view)
	crew_setup_view.visible=false
	fusion_view.sound_cue.connect(func(key:String):_sound(key))
	fusion_view.stopped.connect(_stop_fusion_audio)

func _ready() -> void:
	if DisplayServer.get_name()!="headless":get_window().title="索拉里斯大乱斗 · V138"
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Test scenes supply their isolated store before entering the tree.
	var live_start=storage==null and SKIN.profile_root(OS.get_cmdline_user_args())=="user://"
	if storage==null:storage=S.new(SKIN.profile_root(OS.get_cmdline_user_args()))
	practice_storage=storage
	online_storage=S.new(storage.root_path+"async/")
	online_client=preload("res://scripts/online/async_pool_client.gd").new();add_child(online_client);online_client.configure(online_storage)
	if live_start:online_client.call_deferred("start_identity")
	SKIN.configure(OS.get_cmdline_user_args(),storage.root_path)
	_update_bag_style_title()
	var font_weight=FontVariation.new()
	font_weight.base_font=load("res://assets/fonts/body.ttf")
	font_weight.variation_opentype={2003265652:550.0}
	font=font_weight
	var regular=FontVariation.new()
	regular.base_font=font_weight.base_font
	regular.variation_opentype={2003265652:400.0}
	body_font=regular
	for leader in C.characters:
		camp_loadouts[leader]=inventory.new_run(leader,19).items
	audio=AUDIO.new();add_child(audio)
	audio.set_muted(muted)
	music=MUSIC.new();add_child(music)
	_update_music()
	saved=storage.resume()
	_refresh_camp_saves()
	dialog=FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.filters=PackedStringArray(["*.json ; 行囊影像"])
	dialog.use_native_dialog=true
	dialog.file_selected.connect(_file_selected)
	add_child(dialog)
	queue_redraw()


func _process(delta: float) -> void:
	_sync_recruitment()
	recruitment_view.advance(delta)
	crew_setup_view.advance(delta)
	if recruitment_view.active and recruitment_view.arrived:
		recruitment_view.clear()
		_sound("drop")
		if recruitment_arrival_ability in ["link","volley","guard"] and RECRUITMENT.crew_setup_choices(inventory,run).get(recruitment_arrival_ability,[]).size()>1:
			_open_crew_setup(recruitment_arrival_ability)
		recruitment_arrival_ability=""
	if screen!="game" or run.get("phase","")!="shop" or not overlay.is_empty():
		if fusion_view.active():fusion_view.finish()
		else:_stop_fusion_audio()
	else:fusion_view.advance(delta)
	stash_transfer.update(delta,run.get("stash",[]).map(func(v):return v.uid),str(dragging.get("uid","")))
	var battle_view=screen=="game" and run.get("phase","")=="battle"
	var feedback_delta=delta
	if battle_view:feedback_delta=0.0 if paused or _blocking_overlay() else delta*speed*(.12 if hit_pause>0 else 1.0)
	if review.active:feedback_delta=delta*review.speed if review.playing or review_tail>0 else 0.0
	if review.active and review_tail>0:review_pose_time+=feedback_delta
	var entering_battle=battle_view and battle_entry_age<1.0
	if entering_battle:battle_entry_age=minf(1.0,battle_entry_age+feedback_delta/BATTLE_ENTRY_DURATION)
	selection_age+=delta
	camp_age=camp_age+delta if screen=="camp" else 0.0
	rejection_left=maxf(0.0,rejection_left-delta)
	item_selection_age=minf(ITEM_SELECTION_DURATION,item_selection_age+delta)
	star_click_elapsed=minf(Q_STAR.CLICK_DURATION,star_click_elapsed+delta)
	capacity_pan_left=maxf(0.0,capacity_pan_left-delta)
	age+=delta
	motion.set_modal("" if overlay=="item_details" else overlay)
	motion.update(delta,feedback_delta)
	star_activations.update(feedback_delta)
	placement_stars.update(delta)
	combat_vfx.update(feedback_delta)
	reroll_age+=delta
	drag_turn_age=minf(DRAG_TURN_DURATION,drag_turn_age+delta)
	drag_turn_remaining=drag_turn_from*(1.0-smoothstep(0.0,DRAG_TURN_DURATION,drag_turn_age))
	phase_age+=delta
	if motion.transition_left<=0.0:
		transition_image=null
	hover_time+=delta
	toast_timer=maxf(0.0,toast_timer-delta)
	burst_timer=maxf(0.0,burst_timer-feedback_delta)
	if not battle_view or (not paused and not _blocking_overlay()):
		hit_pause=maxf(0.0,hit_pause-delta)
		hit_pause_cooldown=maxf(0.0,hit_pause_cooldown-delta)
	for key in item_sways.keys():
		item_sways[key]-=feedback_delta
		if item_sways[key]<=0:item_sways.erase(key)
	for side in range(2):attack_left[side]=maxf(0.0,attack_left[side]-feedback_delta)
	for impact in pending_impacts:impact.delay-=feedback_delta
	for impact in pending_impacts:
		if impact.delay<=0:_apply_impact(impact.event)
	pending_impacts=pending_impacts.filter(func(v):return v.delay>0)
	for flight in gear_flights:flight.life-=feedback_delta
	gear_flights=gear_flights.filter(func(f):return f.life>0)
	for flight in support_flights:
		flight.life-=feedback_delta
	support_flights=support_flights.filter(func(f):return f.life>0)
	for cue in chase_cues:
		cue.life-=feedback_delta
		if cue.life<=0:_launch_chase(cue.event)
	chase_cues=chase_cues.filter(func(v):return v.life>0)
	for cue in advance_cues:
		cue.life-=feedback_delta
		if cue.life<=0:
			motion.pulse(str(cue.event.side)+str(cue.event.target_uid))
			motion.emit("trigger",_battle_item_position(int(cue.event.side),str(cue.event.target_uid)),Color("d7bd79"))
	advance_cues=advance_cues.filter(func(v):return v.life>0)
	for side in range(2):
		lunge[side]=maxf(0.0,lunge[side]-feedback_delta*5.0)
	for key in flashes.keys():
		flashes[key]=maxf(0.0,flashes[key]-feedback_delta*3.0)
	for value in floats:
		value.life-=feedback_delta
	floats=floats.filter(func(v): return v.life>0.0)
	for value in projectiles:
		value.life-=feedback_delta
	projectiles=projectiles.filter(func(v): return v.life>0.0)
	if battle_view and not entering_battle and not paused and not _blocking_overlay():
		combat_time=minf(_replay_end(),combat_time+feedback_delta)
		while event_cursor<combat.events.size() and float(combat.events[event_cursor].time)<=combat_time:
			_play_event(combat.events[event_cursor])
			event_cursor+=1
		if skip_requested:
			_clear_feedback()
		if combat_time>=_replay_end() and pending_impacts.is_empty():
			if run.phase=="battle":
				match int(combat.get("winner",0)):
					1:_sound("win")
					-1:_sound("lose")
			_transition()
			_application().finish_replay(run)

	if review.active:
		var was_playing=review.playing
		for event in review.advance(delta):_play_event(event)
		if was_playing:review_pose_time=review.time
		if was_playing and not review.playing:
			review_tail=1.75
		elif review_tail>0:
			review_tail=maxf(0,review_tail-feedback_delta)
			if review_tail==0:_clear_feedback()
		combat_time=review.time
	_update_music()
	queue_redraw()

func _draw() -> void:
	_craft_frame_open=true;_craft_frame_model={}
	SKIN.begin_frame();icons.clear();chibi_paper_surfaces.clear()
	buttons=[]
	_basis()
	if recruitment_view.active or crew_setup_view.active:
		_craft_frame_open=false;_craft_frame_model={};SKIN.end_frame();return
	# These views paint an opaque full-canvas backdrop once their transition ends.
	var covered=overlay in ["crew","catalogue","opponent"] and motion.modal_value>=.9999
	if not covered:
		if screen!="camp":STAGE.backdrop(self,str(run.get("phase","shop")),age)
		if screen=="camp":_draw_camp()
		else:_draw_game()
	if dragging.is_empty():inline_craft.draw_links(self,_craft_view_model(),_craft_paint())
	inline_craft.draw(self,_craft_view_model(),_craft_paint())
	if toast_timer>0.0:
		var width=minf(480.0,font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+48)
		var two_lines=font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x>width-48
		var r=Rect2(720-width/2,100 if run.get("phase","")=="shop" else 876,width,66 if two_lines else 43)
		_panel(r,T.tone(T.SHELL),T.tone(T.EDGE),1,6)
		_wrapped(toast,r.position+Vector2(24,28),width-48,18,CREAM)
	if not forge_output.is_empty():_draw_forge_output()
	elif not dragging.is_empty():
		_draw_drag()
		inline_craft.draw_links(self,_craft_view_model(),_craft_paint())
	if rejection_left>0 and not rejection_piece.is_empty():
		_basis(_board_transform())
		GRID.footprint(self,BOARD+Vector2(rejection_piece.x,rejection_piece.y)*CELL,inventory.cells(rejection_piece),CELL,Color("df8177",.42*rejection_left/.28),false)
		_basis()
	if rejection_left>0 and rejection_rect.has_area():draw_rect(rejection_rect,Color("df8177",.34*rejection_left/.28))
	_draw_effects()
	if not overlay.is_empty() or motion.modal_value>0:_draw_overlay()
	_draw_effects(true)
	if transition_image and motion.transition_left>0:
		draw_texture_rect(transition_image,Rect2(-24*(1-motion.transition_alpha()),0,1440,960),false,Color(1,1,1,motion.transition_alpha()))
	if review.active:
		_basis();paint_alpha=1;paint_offset=Vector2.ZERO
		review_buttons=REVIEW_VIEW.draw(self,_review_snapshot(),font,_draw_icon)
	if matching:
		_basis();draw_rect(Rect2(0,0,1440,960),Color("292348",.32))
		_panel(Rect2(566,421,308,94),Color("f3e6fd"),Color("b69acf"),2,18)
		_text("寻找对手"+"·".repeat(1+int(age*3)%3),Vector2(620,477),27,SKIN.PLUM)
	elif screen=="game" and game_mode=="async" and not review.active and not run.get("pvp",{}).get("source","").is_empty():
		_basis();_text("玩家阵容" if run.pvp.source=="player" else "练习对手补位",Vector2(910,88),16,CREAM)

	_basis();paint_offset=Vector2.ZERO;paint_alpha=1.0
	# Only the registry owns persistent item textures. Aliases serve this draw.
	icons.clear();SKIN.end_frame()
	_craft_frame_open=false;_craft_frame_model={}

func set_visual_skin(value:String,persist:bool=true)->void:
	if not SKIN.set_skin(value,persist):return
	stash_transfer.clear()
	# Cancel only uncommitted gestures. Never save/reseed/rebuild a live run.
	dragging={};drag_pressed=false;drag_origin="";drag_offer_index=-1;_clear_held_pose()
	forge_output={}
	icons.clear();portraits.clear();crew_portraits.clear();crew_busts.clear()
	leader_illustrations.clear();leader_art_bounds.clear()
	descriptor_cache.clear();projection_cache.clear()
	transition_image=null
	queue_redraw()

func _ensure_icon(kind:String)->bool:
	if not SKIN.frame_open:icons.clear()
	var texture=SKIN.texture(SKIN.item_path(kind))
	if texture==null:return false
	icons[kind]=texture
	return true

func _ensure_portrait(role:String,view:String="avatar")->Texture2D:
	return SKIN.texture(SKIN.portrait_path(role,view))

func _missing_art(rect:Rect2)->void:
	var center=rect.get_center()+paint_offset
	draw_circle(center,12,Color(SKIN.CORAL,.7*paint_alpha))
	_text("?",rect.get_center()+Vector2(-5,6),17,SKIN.PLUM)

func _chibi_portrait(role:String,rect:Rect2,alpha:float=1.0,face_only:bool=false,flip:bool=false,side:int=-1)->void:
	var path=SKIN.portrait_path(role);var texture=SKIN.texture(path)
	if texture==null:_missing_art(rect);return
	var source=SKIN.bounds(path)
	if face_only and rect.size.x>=40:
		T.surface(self,Rect2(rect.position+paint_offset,rect.size),"portrait_frame",alpha*paint_alpha)
		rect=rect.grow(-4)
	if face_only:
		source=preload("res://scripts/ui/portraits/portrait_framing.gd").head_source(source)
	var ratio=minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
	var size=source.size*ratio
	var clock_value=_portrait_clock()
	var bob=0.0 if face_only else sin(clock_value*2.2)*2.4
	var hurt=0.0 if side<0 else clampf(float(motion.hit[side])/.22,0,1)
	var shift=Vector2.ZERO if side<0 else Vector2(sin(hurt*PI)*8*(-1 if side==0 else 1),0)
	var lean=0.0 if side<0 else lunge[side]*.035*(1 if side==0 else -1)
	var pose=Transform2D(lean,Vector2(-1 if flip else 1,1),0,Vector2(rect.get_center().x,rect.end.y+bob)+paint_offset+shift)
	draw_set_transform_matrix(draw_basis*pose)
	var tint=Color.WHITE.lerp(Color("ffd7c5"),pow(hurt,2)*.65);tint.a=alpha*paint_alpha
	if face_only:preload("res://scripts/ui/portraits/portrait_framing.gd").draw(self,texture,Rect2(Vector2(-size.x*.5,-size.y),size),source,tint)
	else:draw_texture_rect_region(texture,Rect2(Vector2(-size.x*.5,-size.y),size),source,tint)
	draw_set_transform_matrix(draw_basis)

func _draw_camp() -> void:
	preload("res://scripts/ui/chibi_camp_view.gd").draw(self)

func _element_label(value: String) -> String:
	return {"aero":"气动","electro":"导电","spectro":"衍射","fusion":"热熔","glacio":"冷凝","havoc":"湮灭"}.get(value,"")

func _camp_tag_rect(index: int) -> Rect2:
	return preload("res://scripts/ui/chibi_camp_view.gd").tag_rect(index)

func _draw_game() -> void:
	if run.phase=="recruit":return
	_draw_hud()
	if run.phase=="shop":
		_draw_prep_host()
		if not relay_mode:_draw_crew_slots()
		_text("背包" if forge_output.is_empty() else C.items[forge_output.kind].name,Vector2(337,158) if SKIN.is_chibi() else Vector2(337,193),25,T.tone(T.PAPER))
		if SKIN.is_chibi() and forge_output.is_empty():
			var stamina=preload("res://scripts/battle/stamina_rules.gd")
			preload("res://scripts/ui/ability_icons.gd").draw(self,"stamina",Rect2(724,137,23,23))
			_text("体力 %d · +%s/秒"%[int(stamina.MAXIMUM),str(int(stamina.RECOVERY_PER_SECOND))],Vector2(752,156),15,SKIN.PLUM)
		if not SKIN.is_chibi() or not forge_output.is_empty():
			_text(str(inventory.coverage(run.bags).size()) if forge_output.is_empty() else "取消 · Esc",Vector2(843,155) if SKIN.is_chibi() else Vector2(876 if not forge_output.is_empty() else 909,193),17,T.tone(T.MUTED))
		_basis(_board_transform(0))
		_draw_board(run,BOARD,0)
		_draw_relay(run,BOARD,0)
		_draw_placement_stars()
		if dragging.is_empty():
			if overlay=="item_details" and detail_origin=="board":_draw_stars(detail_item,run.items,BOARD)
			elif hovered.get("origin","")=="board":_draw_stars(hovered.item,run.items,BOARD,false,{},true)
		_basis()
		_draw_shop()
		_draw_stash()
		_draw_stash_transfers()
		_button(QL.SORT if SKIN.is_chibi() else Rect2(355,853,66,58),"整理","bag_mode")
		if FEATURES.CONCERTO_ENABLED:_button(Rect2(457,853,66,58),"接力","relay_mode")
		_button(QL.FORGE if SKIN.is_chibi() else Rect2(668,861,177,43),"合成","forge",true,true,GOLD)
		_button(_sell_rect(),"卖出","sell_area")
		_button(QL.BATTLE if SKIN.is_chibi() else Rect2(1070,849,310,55),"开战","battle",not run.items.is_empty() and dragging.is_empty(),true,GOLD)
		_button(Rect2(225,282,40,40) if SKIN.is_chibi() else Rect2(255,155,56,56),"对手影像","opponent",not opponent.is_empty())
		if relay_mode:_text("依次点击武器、相邻声骸，再选相邻信物",Vector2(597,936),15,CREAM)
		if FEATURES.CONCERTO_ENABLED:RELAY_VIEW.draw(self)
	else:
		if battle_entry_age>=.2:_draw_arena()
		if battle_entry_age<.2:
			# Retiring shop surfaces are real draws, with their interaction removed.
			var battle_buttons=buttons.duplicate()
			_draw_prep_host()
			_draw_crew_slots()
			var retreat=smoothstep(0.0,.2,battle_entry_age)
			_basis(Transform2D(0,Vector2(400*retreat,0)))
			_draw_shop()
			_basis(Transform2D(0,Vector2(0,210*retreat)))
			_draw_stash()
			_basis();buttons=battle_buttons
			_draw_battle_controls()
		for side in range(2):
			if side==1 and battle_entry_age<.65:continue
			_basis(_board_transform(side))
			var build=run if side==0 else opponent
			_draw_board(build,BOARD if side==0 else ENEMY_BOARD,side)
			_draw_relay(build,BOARD if side==0 else ENEMY_BOARD,side)
			_basis()
		if run.phase=="battle" and battle_entry_age>=1.0:_draw_battle_center()
		elif run.phase!="battle" and not review.active:_draw_result()
	_draw_support_flights()
	for flight in gear_flights:
		var progress=1.0-flight.life/.48
		var target=_actor_center(int(flight.side))+Vector2(50 if flight.side==0 else -50,-12)
		var pos=flight.from.lerp(target,1-pow(1-progress,3))+Vector2(0,-sin(progress*PI)*62)
		draw_circle(pos,30,Color(GOLD,(1-progress)*.22))
		_draw_icon(flight.kind,Rect2(pos-Vector2.ONE*24,Vector2.ONE*48),0,1-progress*.75)
	for projectile in projectiles:
		var from=projectile.get("from",_actor_center(int(projectile.side))+Vector2(60 if projectile.side==0 else -60,-16))
		var to=_actor_center(1-int(projectile.side))+Vector2(0,-20)
		COMBAT_VFX.projectile(self,projectile,from,to)
	for cue in chase_cues:
		var from=_battle_mark_position(int(cue.event.side),str(cue.event.source_uid))
		var to=_battle_item_position(int(cue.event.side),str(cue.event.trigger_uid))
		var progress=clampf(1.0-float(cue.life)/.18,0,1)
		var lift=Vector2(28 if int(cue.event.side)==0 else -28,0)
		if int(cue.event.consumed_marks)>0:
			var path=PackedVector2Array()
			for k in range(13):
				var step=k/12.0
				path.append(from.lerp(to,step)+lift*sin(step*PI))
			draw_polyline(path,Color(.85,.64,.98,.5),1.6,true)
		for n in range(int(cue.event.consumed_marks)):
			var at=(from+Vector2(n*7*_board_transform().get_scale().x,0)).lerp(to,progress)+(lift+Vector2(0,(n-1)*12))*sin(progress*PI)
			draw_circle(at,4,Color("dfbaec"));draw_circle(at,8,Color(.82,.65,.95,.16));draw_circle(at,1.5,Color.WHITE)
	for pulse in star_activations.pulses:
		var from=_battle_item_position(int(pulse.side),str(pulse.target_uid))
		var to=_battle_item_position(int(pulse.side),str(pulse.source_uid))
		var progress=clampf(1.0-float(pulse.life)/.28,0,1)
		var beneficiary=str(pulse.get("beneficiary_uid",pulse.source_uid))
		if beneficiary!=str(pulse.source_uid) and beneficiary!=str(pulse.target_uid):
			if progress<.5:progress*=2
			else:from=to;to=_battle_item_position(int(pulse.side),beneficiary);progress=(progress-.5)*2
		var at=from.lerp(to,smoothstep(0,1,progress))
		draw_line(from,to,Color("fff1bb",sin(progress*PI)*.28),2.5,true)
		draw_circle(at,7,Color("ffe1a0",sin(progress*PI)*.25),true,-1,true)
		draw_circle(at,3.4,Color("fff9df",sin(progress*PI)*.95),true,-1,true)
	combat_vfx.draw(self)
	for value in floats:
		var pos=_floating_position(value)
		var size=36 if value.get("big",false) else 28
		var a=clampf(float(value.life)/.2,0,1)
		var pop=1.0+.12*maxf(0,1-(1.1-float(value.life))/.12)
		_basis(Transform2D(0,Vector2.ONE*pop,0,pos)*Transform2D(0,-pos))
		for offset in [Vector2(-1.5,0),Vector2(1.5,0),Vector2(0,-1.5),Vector2(0,2)]:_text(value.label,pos+offset,size,Color("292247",a))
		_text(value.label,pos,size,Color(value.color,a))
		var cue=str(value.get("cue",""))
		if not cue.is_empty():
			var cue_at=pos+Vector2(2,-size-5)
			for offset in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:_text(cue,cue_at+offset,14,Color("292247",a))
			_text(cue,cue_at,14,Color(value.color,a))
		_basis()
	if burst_timer>0.0:
		var ribbon=Rect2(563,186,314,53) if SKIN.is_chibi() else Rect2(477,268,486,59)
		T.plate(self,ribbon,T.tone(T.SHELL),T.tone(T.BRASS),12)
		draw_line(ribbon.position,ribbon.position+Vector2(ribbon.size.x,0),Color(GOLD,.6),1,true)
		var label_size=30
		while label_size>16 and font.get_string_size(burst_text,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size).x>ribbon.size.x-48:label_size-=1
		_text(burst_text,ribbon.position+Vector2(24,40),label_size,CREAM)
	if SKIN.is_chibi() and run.phase!="shop" and battle_entry_age>=.2:Q_BATTLE.draw_status_detail(self)

func _hud_limits() -> Dictionary:
	return PROGRESSION.display_limits(run)

func _draw_hud() -> void:
	if SKIN.is_chibi():_draw_chibi_hud();return
	var limits=_hud_limits()
	_text("整备" if run.phase=="shop" else "对战",Vector2(62,66),25,T.tone(T.PAPER))
	T.rule(self,Vector2(62,94),Vector2(1378,94),.19)
	_text("%02d"%int(run.round),Vector2(190,66),27,CREAM)
	_text("轮",Vector2(235,65),14,T.tone(T.MUTED))
	for n in range(int(limits.wins)):
		var pos=Vector2(301+n*25,49)
		var color=GOLD if n<int(run.wins) else Color(T.tone(T.PAPER),.27)
		var points=PackedVector2Array([pos+Vector2(0,-6),pos+Vector2(5,0),pos+Vector2(0,6),pos-Vector2(5,0)])
		if n<int(run.wins):draw_colored_polygon(points,color)
		else:draw_polyline(PackedVector2Array(Array(points)+[points[0]]),color,1,true)
	for n in range(int(limits.losses)):_heart(Vector2(540+n*23,49),T.tone(T.ALERT) if n<int(limits.losses)-int(run.losses) else Color(T.tone(T.PAPER),.22),6)
	_coin(_wallet_position(),12)
	_text(str(int(run.gold)),_wallet_position()+Vector2(23,9),25,CREAM)
	_button(Rect2(1243,24,62,60),"影像","ghosts")
	_button(Rect2(1326,24,62,60),"菜单 · Esc","menu")

func _draw_arena() -> void:
	if SKIN.is_chibi():
		Q_BATTLE.draw(self);_draw_overtime();return
	var active=run.phase in ["battle","result","ending"] and not combat.is_empty()
	var frame_data=_vitals_frame() if active else {}
	for side in range(2):
		var leader=run.leader if side==0 else opponent.leader
		var center=_actor_center(side)
		var attack=(.48-float(attack_left[side]))/.48 if attack_left[side]>0 else 1.0
		var shift=0.0
		if attack<.22:shift=-sin(attack/.22*PI/2)*11
		elif attack<.5:shift=lerpf(-11,58,(attack-.22)/.28)
		elif attack<1:shift=58*pow(1-(attack-.5)/.5,2)
		shift*=1 if side==0 else -1
		var skeletal=native_rigs_enabled and leader in ["jiyan","yinlin","verina","encore","sanhua","camellya"]
		if skeletal:shift=0.0
		else:T.contact(self,center+Vector2(shift,160),101,.20)
		var rect=Rect2(center.x-96+shift,175,192,220)
		var hurt=float(motion.hit[side])/.22
		if not skeletal:rect.position.x+=sin(hurt*TAU*2)*hurt*9
		_draw_character(leader,rect,side==1,side)
		var origin=Vector2(242 if side==0 else 967,154)
		if SKIN.is_chibi():_chibi_portrait(leader,Rect2(origin.x,origin.y-31,32,32),1,true)
		else:draw_texture_rect(_ensure_portrait(leader),Rect2(origin.x,origin.y-31,32,32),false)
		_text(C.characters[leader].name,origin+Vector2(43,-5),23,CREAM)
		var state=frame_data.sides[side] if active else {"hp":102,"max_hp":102,"shield":0,"stamina":10,"energy":0,"concerto":0,"mark":0,"burn":0}
		_bar(Rect2(origin.x,origin.y+13,243,8),motion.smooth("hp"+str(side),float(state.hp)/float(state.max_hp)),T.tone(T.PAPER))
		_text(str(int(ceil(state.hp))),origin+Vector2(254,22),16,T.tone(T.PAPER))
		_bar(Rect2(origin.x,origin.y+32,243,3),motion.smooth("stamina"+str(side),float(state.stamina)/10.0),Color("85b7a4"))
		var crew_build=run if side==0 else opponent
		for n in range(crew_build.get("supports",[]).size()):
			_crew_portrait(str(crew_build.supports[n]),origin+Vector2(244+n*34,-4),14,.9)
		if state.shield>0:
			draw_arc(center+Vector2(0,24),75,-PI*.84,PI*.84,42,Color(.56,.81,.84,.55),2,true)
			if SKIN.is_chibi():T.glyph(self,"shield",Rect2(origin+Vector2(166,42),Vector2.ONE*18))
			_text(("" if SKIN.is_chibi() else "◇ ")+str(int(state.shield)),origin+Vector2(188 if SKIN.is_chibi() else 178,58),16,CREAM)
		if state.mark>0:draw_circle(center+Vector2(-29,164),6,Color("b08aca"))
		if state.burn>0:draw_circle(center+Vector2(-13,164),6,Color("dd8d59"))
		var statuses=state.get("statuses",[])
		for n in range(mini(5,statuses.size())):
			var status=statuses[n];var pos=origin+Vector2(n*56,59)
			var tint={"charge":Color("f2c666"),"haste":Color("8bcdb6"),"frost":Color("92cfe5"),"freeze":Color("baeafa"),"noise":GOLD,"coord":Color("bc99d0"),"photo":Color("9ad7a8"),"heavy":Color("e0a681"),"burst":Color("84c8dc")}.get(status.id,GOLD)
			draw_circle(pos+Vector2(2,0),3,tint)
			_text(str(status.get("label","")).substr(0,2)+str(status.get("stacks",1)),pos+Vector2(8,5),14,CREAM)
			if Rect2(pos-Vector2(4,10),Vector2(55,24)).has_point(mouse) and float(status.get("remaining",0))>0:
				_text("%.1f 秒"%status.remaining,pos+Vector2(3,28),14,CREAM)

	if active:
		_text("%.1f"%minf(combat_time,float(combat.duration)),Vector2(693,170),26,T.tone(T.MUTED))
		_draw_overtime()
	_draw_battle_controls()

func _draw_overtime() -> void:
	if not _showing_battle() or combat.is_empty():return
	var frame=_vitals_frame()
	var rate=float(frame.get("fatigue_rate",0))
	if rate<=0:return
	var tint=Color("ffc5b4") if SKIN.is_chibi() else Color("c98579")
	_text("疲劳 %.1f / 秒"%rate,Vector2(649,184 if SKIN.is_chibi() else 207),19,tint)
	for side in range(2):
		var at=Vector2(633+side*100,211 if SKIN.is_chibi() else 234)
		_text(("我方" if side==0 else "对方")+" -%.1f"%float(frame.sides[side].get("fatigue",0)),at,15,tint)

func _draw_battle_controls() -> void:
	if run.phase=="battle":
		_button(Rect2(1349,844,56,32),"▶" if paused else "Ⅱ","pause")
		_button(Rect2(1349,884,56,32),"×"+str(int(speed)),"speed")
		_button(Rect2(1349,924,56,32),"»","skip")

func _draw_board(build: Dictionary,origin: Vector2,side: int) -> void:
	if SKIN.is_chibi() or (run.phase=="shop" and side==0):TERMINAL.placement_grid(self,origin,Vector2i(I.WIDTH,I.HEIGHT),CELL,paint_alpha)
	if run.phase in ["battle","result","ending"] and not SKIN.is_chibi():
		draw_rect(Rect2(origin,Vector2(I.WIDTH,I.HEIGHT)*CELL),Color(T.tone(T.SHADOW),.16))
		var owned=inventory.coverage(build.bags)
		for y in range(I.HEIGHT):
			for x in range(I.WIDTH):
				if Vector2i(x,y) not in owned:draw_circle(origin+(Vector2(x,y)+Vector2.ONE*.5)*CELL,1,Color(T.tone(T.PAPER),.18))
	if side==0 and not dragging.is_empty() and C.is_tag(dragging.kind,"bag"):
		for y in range(I.HEIGHT):
			for x in range(I.WIDTH):
				var point=origin+(Vector2(x,y)+Vector2(.5,.5))*CELL
				if _board_screen_rect().has_point(_board_to_screen(point)):draw_circle(point,1.1,Color(T.tone(T.PAPER),.24))
	var bags=build.bags.filter(func(b):return side!=0 or dragging.get("uid","")!=b.uid)
	var focus=str(hovered.get("item",{}).get("uid","")) if side==0 else ""
	var pocket_pulses={}
	for bag in bags:pocket_pulses[bag.uid]=maxf(float(flashes.get(str(side)+bag.uid,0.0)),float(motion.pulses.get(str(side)+bag.uid,0.0))/.28)
	TERMINAL.surface(self,origin,bags,CELL,focus,paint_alpha,pocket_pulses)
	if dragging.is_empty() and ((side==0 and hovered.get("origin","") in ["board","pocket"]) or (side==1 and hovered.get("origin","")=="enemy")):
		var focus_item=hovered.item
		if C.is_tag(focus_item.kind,"bag"):
			for item in build.items:
				for source in inventory.pocket_bonus(item,build).sources:
					if source.uid==focus_item.uid:POCKET_VIEW.benefit(self,origin,source.cells,CELL,source.kind)
		else:
			for source in inventory.pocket_bonus(focus_item,build).sources:POCKET_VIEW.benefit(self,origin,source.cells,CELL,source.kind)
	var forge_preview={}
	if side==0 and not forge_output.is_empty():forge_preview=_forge_placement_preview()
	var inline_preview=inline_craft.hit(_craft_view_model(),mouse) if side==0 else {}
	if run.phase=="shop" and (dragging.is_empty() or side!=0):
		_draw_coord_links(forge_preview.get("run",build),origin)
	for item in build.items:
		if not dragging.is_empty() and dragging.uid==item.uid and side==0:continue
		if side==0 and not dragging.is_empty() and C.is_tag(dragging.kind,"bag"):
			var old_bag=run.bags.filter(func(b):return b.uid==dragging.uid)
			if not old_bag.is_empty() and inventory.occupied(item).all(func(v):return v in inventory.occupied(old_bag[0])):continue
		_draw_piece(item,origin,.23 if item.uid in forge_preview.get("consumed",[]) or item.uid in inline_preview.get("consumed",[]) else 1.0,side)
	if _showing_battle():
		for item in build.items:
			_draw_star_markers(_battle_star_markers(item,build,side),origin,true)
	if FEATURES.CONCERTO_ENABLED and side==0 and run.round==1 and run.phase=="shop" and not bool(run.get("relay_guide_complete",false)):
		var weapon=inventory.primary_weapon(build)
		if not weapon.is_empty():_draw_stars(weapon,build.items,origin)

func _bag_handle(bag: Dictionary) -> Rect2:
	# Representative visible top edge for keyboard/review callers, never a badge.
	var first:Vector2i=inventory.cells(bag)[0]
	for cell in inventory.cells(bag):
		if cell.y<first.y or (cell.y==first.y and cell.x<first.x):first=cell
	var rect=Rect2(BOARD+(Vector2(bag.x,bag.y)+Vector2(first))*CELL+Vector2(4,.5),Vector2(CELL-8,3))
	return Rect2(_board_to_screen(rect.position),rect.size*_board_transform().get_scale())

func _edge_bag(at:Vector2) -> Dictionary:
	if screen!="game" or run.get("phase","")!="shop" or _blocking_overlay() or relay_mode or not _board_screen_rect().grow(CELL*.5).has_point(at):return {}
	var local=_board_transform().affine_inverse()*at-BOARD
	var form_uid=TERMINAL.form_hit(local,run.bags,CELL)
	if not form_uid.is_empty():
		for bag in run.bags:
			if bag.uid==form_uid:return bag
	var cell=Vector2i((local/CELL).floor())
	for bag in run.bags:
		var owned=inventory.occupied(bag)
		if cell not in owned:continue
		for edge in GRID._edge_records(owned):
			if edge.count!=1:continue
			if Geometry2D.get_closest_point_to_segment(local,edge.a*CELL,edge.b*CELL).distance_to(local)<=3.5:return bag
	return {}

func _draw_relay(build: Dictionary,origin: Vector2,side: int) -> void:
	if not FEATURES.CONCERTO_ENABLED:return
	var path=RELAY_VIEW.path(self,build)
	var selected=hovered.get("item",{}).get("uid","")
	var inspecting=hovered.get("origin","")==("board" if side==0 else "enemy") and path.any(func(v):return v.uid==selected)
	var firing=not RELAY_VIEW.active_sequence(self,build).is_empty()
	if not (side==0 and relay_mode) and not inspecting and not (run.phase=="battle" and firing):return
	if side==0 and relay_mode and not relay_draft.is_empty():
		path=[]
		for uid in relay_draft:
			for item in build.items:
				if item.uid==uid:path.append(item)
	for n in range(path.size()):
		var item=path[n]
		var center=_item_rect(item,origin).get_center()
		if item.get("leader_outro",false):
			center=origin+Vector2(-27,27)
			draw_circle(center,16,Color(T.tone(T.SHADOW),paint_alpha))
			_chibi_portrait(build.leader,Rect2(center-Vector2(12,12),Vector2(24,24)),1,true) if SKIN.is_chibi() else draw_texture_rect(_ensure_portrait(build.leader),Rect2(center-Vector2(12,12),Vector2(24,24)),false,Color(1,1,1,paint_alpha))
		if n>0:
			var from=_item_rect(path[n-1],origin).get_center()
			draw_line(from,center,Color(.91,.78,.47,.5*paint_alpha),2,true)
			var direction=from.direction_to(center)
			var arrow=from.lerp(center,.65)
			draw_line(arrow-direction.rotated(.6)*8,arrow,Color(GOLD,paint_alpha),2,true)
			draw_line(arrow-direction.rotated(-.6)*8,arrow,Color(GOLD,paint_alpha),2,true)
		var badge=center+Vector2(17,0) if item.get("leader_outro",false) else origin+(Vector2(item.x,item.y)+Vector2(inventory.cells(item)[0]))*CELL+Vector2(10,10)
		draw_circle(badge,7.5,Color(T.tone(T.SHADOW),paint_alpha))
		_text(str(n+1),badge+Vector2(-3,4),11,GOLD)
		var pulse=float(motion.pulses.get(str(side)+item.uid,0))/.28
		if pulse>0:draw_arc(center,18+(1-pulse)*13,0,TAU,32,Color(GOLD,pulse),2,true)

func _piece_position(item:Dictionary,origin:Vector2,side:int,preview:bool=false)->Vector2:
	var shake=float(motion.rejections.get(str(side)+item.uid,0))/.3
	var at=origin+Vector2(item.x,item.y)*CELL+Vector2(sin(shake*TAU*3)*shake*5,0)
	if not preview:at.y+=motion.landing_y(str(side)+item.uid)
	return at

func _piece_pose(item:Dictionary,at:Vector2,fitted:Dictionary,side:int,preview:bool=false)->Transform2D:
	var glow_rect=Rect2(at,_item_rect(item,Vector2.ZERO).size)
	var pose=Transform2D.IDENTITY
	var full_art=bool(C.items[item.kind].get("combat_v15",false))
	if (full_art or (SKIN.is_chibi() and C.is_tag(item.kind,"echo"))) and not preview:
		var sway=float(item_sways.get(str(side)+item.uid,0))/.38
		var heavy=C.items[item.kind].get("weapon_type","") in ["broadblade","gauntlet"]
		var swing=sin((1-sway)*TAU)*sway*(.20 if heavy and SKIN.is_chibi() else .14)
		var center=at+fitted.center
		var direction=1 if side!=1 else -1
		var offset=Vector2(sin((1-sway)*PI)*sway*13*direction,0)
		pose=Transform2D(swing,Vector2.ONE,0,center+offset)*Transform2D(0,-center)
	if not preview and item_selection_age<ITEM_SELECTION_DURATION and item.uid==detail_item.get("uid","") and detail_origin==("board" if side==0 else "enemy" if side==1 else ""):
		var target=_selection_rect(glow_rect)
		var selection_pose=Transform2D(0,Vector2.ONE*(target.size.x/glow_rect.size.x),0,target.get_center())*Transform2D(0,-glow_rect.get_center())
		pose=selection_pose*pose
	return pose

func _piece_elevation(item:Dictionary,side:int)->float:
	if not SKIN.is_chibi():return 0.0
	if side==-1:return 7.0 if dragging.get("uid","")==item.uid and not C.is_tag(item.kind,"bag") else 0.0
	return maxf(0,-motion.landing_y(str(side)+item.uid))

func _item_fx_clock()->float:
	return review.time if review.active else combat_time if run.get("phase","") in ["battle","result","ending"] else motion.elapsed

func _draw_piece(item: Dictionary,origin: Vector2,alpha: float = 1.0,side: int = -1,preview: bool = false,valid: bool = true) -> void:
	alpha*=paint_alpha
	if side==0:alpha*=fusion_view.output_alpha(str(item.get("uid","")))
	if SKIN.is_chibi() and side==0:
		for event in motion.events:
			if event.kind=="fusion" and event.uid==item.uid:alpha*=smoothstep(0,.12,float(event.age))
	var at=_piece_position(item,origin,side,preview)
	var over=hovered.get("item",{}).get("uid","")==item.uid
	var pulse=float(motion.pulses.get(str(side)+item.uid,0.0))/.28
	var cells=inventory.cells(item)
	if preview:
		# Occupied space belongs to the placement interaction, never to the art.
		var shadow=Color("75bfac") if valid else Color("df8177")
		GRID.footprint(self,at,cells,CELL,Color(shadow,alpha*.38),false)
	var ready=false
	if _ensure_icon(item.kind):
		var glow_rect=_item_rect(item,origin);glow_rect.position+=at-origin-Vector2(item.x,item.y)*CELL
		if not preview:QUALITY.draw(self,item.kind,glow_rect,alpha*.85,_item_fx_clock())
		var fitted=_projection_for(item.kind,int(item.rotation),CELL)
		var brightness=1.05 if over else 1.0
		var tint=Color(brightness,brightness,brightness,alpha).lerp(Color(C.tint(item.kind),alpha),pulse*.12)
		var full_art=bool(C.items[item.kind].get("combat_v15",false))
		var pose=_piece_pose(item,at,fitted,side,preview)
		var saved_basis=draw_basis
		if full_art or C.is_tag(item.kind,"echo"):
			ITEM_SHADOW.draw(self,icons[item.kind],pose*Transform2D(0,at)*Transform2D(fitted.transform),saved_basis,fitted.bounds.size,alpha,_piece_elevation(item,side))
		if full_art:
			draw_set_transform_matrix(saved_basis*pose*Transform2D(0,at)*Transform2D(fitted.transform))
			draw_texture(icons[item.kind],Vector2.ZERO,tint)
		else:
			draw_set_transform_matrix(saved_basis*pose)
			PROJECTION.draw(self,icons[item.kind],cells,at,CELL,fitted,tint)
		if not preview:
			draw_set_transform_matrix(saved_basis*pose*Transform2D(0,at)*Transform2D(fitted.transform))
			var clip_uv=[] if full_art else PROJECTION._clip_patches(icons[item.kind].get_size(),cells,CELL,fitted).map(func(p):return p.uv)
			QUALITY.draw_surface(self,item.kind,icons[item.kind],_item_fx_clock(),alpha,clip_uv)
			GLINTS.draw(self,item.kind,icons[item.kind].get_size(),_item_fx_clock(),alpha,clip_uv)
		draw_set_transform_matrix(saved_basis)
		if side>=0 and _showing_battle() and not combat.is_empty():
			var frame=_current_frame()
			if frame.progress[side].has(item.uid):
				ready=bool(frame.get("waiting",[{},{}])[side].get(item.uid,false))
				COOLDOWN.draw(self,icons[item.kind],cells,at,CELL,fitted,pose,full_art,_cooldown_progress(side,item.uid),alpha)
	else:_missing_art(_item_rect(item,origin))
	var marker=_piece_marker(item,origin)
	# Small level and primary-weapon marks remain inside the occupied cells.
	for n in range(int(item.get("level",0))):
		draw_circle(marker+Vector2(-21+n*8,-2),2.3,Color("846b36",alpha))
	if not str(item.get("tuning","")).is_empty():draw_circle(marker+Vector2(-32,-2),3,Color("397f86",alpha))
	if side>=0 and C.is_tag(item.kind,"weapon"):
		var build=run if side==0 else opponent
	if ready:
		var warm=.45+.25*sin(combat_time*5.0)
		draw_circle(marker+Vector2(0,-10),7,Color(.95,.67,.3,warm*.25))
		draw_arc(marker+Vector2(0,-10),4,-PI*.7,PI*.7,16,Color(.95,.67,.3,warm),1.8,true)
	if side>=0 and _showing_battle() and not combat.is_empty():
		var marks=int(_current_frame().get("weapon_marks",[{},{}])[side].get(item.uid,0))
		for n in range(marks):draw_circle(marker+Vector2(-7+n*7,-20),2.6,Color("d4ace6"))
		var meter=_current_frame().get("combo_meters",[{},{}])[side].get(item.uid,{})
		if not meter.is_empty():
			var ink=Color("93d8ec") if meter.kind in ["shield","counter"] else Color("f8d78a") if meter.kind=="charge" else Color("9bdfc4")
			var meter_rect=_item_rect(item,origin)
			var start=meter_rect.get_center()+Vector2(-float(meter.total-1)*4.5,meter_rect.size.y*.5-5)
			for n in int(meter.total):
				var pip_at=start+Vector2(n*9,0)
				draw_circle(pip_at,3.9,Color("41365e",.9),true,-1,true)
				draw_circle(pip_at,2.5,ink if n<int(meter.count) else Color("8d7fac",.65),true,-1,true)

# Both animation and result rows consume the current producer's actual seconds.
# Legacy saved battles migrate to result-only summaries with no replay events.
static func _advance_seconds(event:Dictionary)->float:
	return BATTLE_FEEDBACK.advance_seconds(event)

func _cooldown_progress(side: int,uid: String) -> float:
	var current=_current_frame()
	var progress=float(current.progress[side].get(uid,1.0))
	var index=mini(int(combat_time/.1),combat.frames.size()-1)
	if index+1>=combat.frames.size():return progress
	var next=float(combat.frames[index+1].progress[side].get(uid,progress))
	# A reset belongs to the next activation, never a backward pre-attack wipe.
	if next<progress:next=1.0
	var shown=lerpf(progress,next,clampf((combat_time-float(current.time))/.1,0,1))
	for cue in advance_cues:
		if int(cue.event.side)==side and str(cue.event.target_uid)==uid:
			var build=run if side==0 else opponent
			for item in build.items:
				if item.uid==uid:
					var cooldown=float(C.items[item.kind].cooldown)*(1.0-inventory.modifiers(item,build.items,build).speed)
					if cooldown>0:shown-=_advance_seconds(cue.event)/cooldown
	return clampf(shown,0,1)

func _piece_marker(item: Dictionary,origin: Vector2) -> Vector2:
	var last=Vector2i.ZERO
	for cell in inventory.cells(item):
		if cell.y>last.y or (cell.y==last.y and cell.x>last.x):last=cell
	return origin+(Vector2(item.x,item.y)+Vector2(last)+Vector2.ONE)*CELL-Vector2(12,12)

func _display_name(kind: String) -> String:
	var regions={}
	for kind_name in POCKETS.PROFILES:regions[kind_name]=POCKETS.profile(kind_name).name
	return regions.get(kind,C.items[kind].name)

func _warm_projections() -> void:
	# Compact echoes have a costlier one-time fit. Warm all orientations before
	# the first visible frame; every display size shares this normalized pose.
	for kind in ["feilian","inferno","thundering","puppet"]:
		if not icons.has(kind):continue
		for rotation_value in range(4):_projection_for(kind,rotation_value,CELL)

func _descriptor_for(kind: String,rotation_value: int) -> Dictionary:
	_ensure_icon(kind)
	var turn=posmod(rotation_value,4)
	var key=kind+":"+str(turn)
	if not descriptor_cache.has(key):
		if descriptor_cache.size()>=96:descriptor_cache.erase(descriptor_cache.keys()[0])
		var hint: Dictionary=C.items[kind].get("draw_hint",{})
		var angle=SKIN.item_angle(kind)+turn*PI/2.0
		if SKIN.is_chibi():
			descriptor_cache[key]=ART_GEOMETRY.descriptor(kind,turn,icons[kind].get_image())
			return descriptor_cache[key]
		if C.items[kind].get("combat_v15",false):
			var selected_art=ART.entries.get(kind,{})
			var b=selected_art.get("icon_body_bounds",selected_art.get("icon_bounds",C.items[kind].get("icon_body_bounds",C.items[kind].get("icon_bounds",[]))))
			var size=Vector2(icons[kind].get_width(),icons[kind].get_height())
			var used=Rect2(b[0],b[1],b[2],b[3]) if b.size()==4 else Rect2(Vector2.ZERO,size)
			var center=size*.5;var low=Vector2(INF,INF);var high=Vector2(-INF,-INF)
			for point in [used.position,Vector2(used.end.x,used.position.y),used.end,Vector2(used.position.x,used.end.y)]:
				var v=(point-center).rotated(angle);low=low.min(v);high=high.max(v)
			descriptor_cache[key]={"angle":angle,"image_center":center,"bounds":Rect2(low,high-low),"body":used,"size":size}
			if absf(sin(angle*2.0))>.001:
				descriptor_cache[key]=PROJECTION.descriptor(icons[kind].get_image(),angle,false)
				descriptor_cache[key].body=used
		else:descriptor_cache[key]=PROJECTION.descriptor(icons[kind].get_image(),angle,false)
	return descriptor_cache[key]

func _projection_for(kind: String,rotation_value: int,pitch: float) -> Dictionary:
	var turn=posmod(rotation_value,4)
	var key=kind+":"+str(turn)+":"+str(readable_icons_enabled)
	var desc=_descriptor_for(kind,turn)
	if pitch<=0 or not is_finite(pitch):return PROJECTION.fit([],desc,0)
	if not projection_cache.has(key):
		if projection_cache.size()>=96:projection_cache.erase(projection_cache.keys()[0])
		var cells=inventory.cells({"kind":kind,"rotation":turn})
		# Preserve the complete silhouette, including thin tips, wings and feet.
		if C.items[kind].get("combat_v15",false):
			var hi=Vector2.ONE
			for cell in cells:hi=hi.max(Vector2(cell)+Vector2.ONE)
			var room=hi*CELL-Vector2.ONE*CELL*.09
			var definition=C.items[kind] if readable_icons_enabled and not SKIN.is_chibi() else {}
			projection_cache[key]=ITEM_DISPLAY.fit(definition,desc,room,hi*CELL*.5)
			projection_cache[key]["padding"]=CELL*.045
		else:projection_cache[key]=PROJECTION.fit(cells,desc,CELL,CELL*.045)
	if is_equal_approx(pitch,CELL):return projection_cache[key]
	# Uniform scaling preserves complete silhouette containment.
	# Smaller thumbnails and flights therefore cause no fresh search mid-animation.
	var fitted=projection_cache[key].duplicate()
	var ratio=pitch/CELL
	fitted.position*=ratio
	fitted.scale*=ratio
	fitted.center*=ratio
	fitted.bounds=Rect2(fitted.bounds.position*ratio,fitted.bounds.size*ratio)
	fitted.padding*=ratio
	if fitted.has("strict_scale"):fitted.strict_scale*=ratio
	fitted.transform=Transform2D(fitted.angle,Vector2(fitted.get("aspect",Vector2.ONE))*fitted.scale,0,fitted.position)
	return fitted

func _shape_contour(item: Dictionary) -> PackedVector2Array:
	var key=item.kind+str(item.rotation)
	if shape_cache.has(key): return shape_cache[key]
	var result=PackedVector2Array()
	for cell in inventory.cells(item):
		var pos=Vector2(cell)*CELL
		var square=PackedVector2Array([pos,pos+Vector2(CELL,0),pos+Vector2(CELL,CELL),pos+Vector2(0,CELL)])
		result=square if result.is_empty() else Geometry2D.merge_polygons(result,square)[0]
	var inset=Geometry2D.offset_polygon(result,-3.0,Geometry2D.JOIN_ROUND)
	if not inset.is_empty():result=inset[0]
	shape_cache[key]=result
	return result

func _effect_star_state(item:Dictionary,items:Array,pos:Vector2i,build:Dictionary)->String:
	for marker in _effect_star_markers(item,items,build):
		if marker.cell==pos:return marker.state
	return "unlit"

func _effect_star_markers(item:Dictionary,items:Array,build:Dictionary)->Array:
	var targets=inventory.star_links(item,items,build).map(func(other):return {"uid":other.uid,"cells":inventory.occupied(other)})
	var link=RECRUITMENT.link_model(inventory,build)
	if link.get("source_uid","")!=item.get("uid",""):link={}
	return STAR_FEEDBACK.remote_markers(inventory.stars(item),targets,CELL,link)

func _draw_stars(item: Dictionary,items: Array,origin: Vector2,active_only: bool = false,preview_build:Dictionary={},emphasis: bool = false) -> void:
	var build=preview_build if not preview_build.is_empty() else opponent if origin==ENEMY_BOARD else run
	var anchors=_star_pose(item,origin)
	var link=RECRUITMENT.link_model(inventory,build)
	if not active_only and link.get("mode","")=="star" and link.get("source_uid","")==item.get("uid",""):
		var a=origin+(Vector2(item.x,item.y)+Vector2.ONE*.5)*CELL
		var b=origin+(Vector2(link.target_cells[0])+Vector2.ONE*.5)*CELL
		draw_line(a,b,Color("cbb8ff",.38),3,true)
		draw_line(a,b,Color("f2dcff",.8),1.2,true)
	_draw_star_markers(_effect_star_markers(item,items,build),origin,active_only,emphasis,_star_click_age(item,"enemy" if origin==ENEMY_BOARD else "board") if not active_only else -1.0,anchors)
	if not active_only and item.get("uid","") in [link.get("source_uid",""),link.get("target_uid","")]:
		RECRUITMENT_ART.guard_thread(self,link,origin,CELL)
	draw_set_transform_matrix(draw_basis)

func _star_pose(item:Dictionary,origin:Vector2)->Transform2D:
	var side=0 if origin==BOARD else 1 if origin==ENEMY_BOARD else -1
	var at=_piece_position(item,origin,side)
	var logical=origin+Vector2(item.x,item.y)*CELL
	var fitted=_projection_for(item.kind,int(item.rotation),CELL)
	return _piece_pose(item,at,fitted,side)*Transform2D(0,at-logical)

func _battle_star_markers(item:Dictionary,build:Dictionary,side:int)->Array:
	var targets=star_activations.targets(side,str(item.uid))
	if targets.is_empty():return []
	return _effect_star_markers(item,build.items,build).filter(func(v):return v.state=="lit" and v.target_uid in targets)

func _drag_star_markers(preview:Dictionary)->Array:
	if not preview.get("ok",false):return []
	# One gesture inspects one item's outgoing slots, including its grey slots.
	# Incoming relationships remain real gameplay but do not add a second map.
	return _effect_star_markers(preview.piece,preview.run.items,preview.run)

func _draw_star_markers(markers:Array,origin:Vector2,active_only:bool=false,emphasis:bool=false,click_age:float=-1.0,anchors:Transform2D=Transform2D.IDENTITY)->void:
	for index in markers.size():
		var marker=markers[index]
		var pos:Vector2i=marker.cell
		if pos.x<0 or pos.x>=I.WIDTH or pos.y<0 or pos.y>=I.HEIGHT:
			continue
		var on=marker.state=="lit"
		# The committed arrival already draws this slot once with its own clock.
		if not active_only and origin==BOARD and on and _placement_star_markers().any(func(p):return p.cell==marker.cell):continue
		if active_only and not on:
			continue
		var center:Vector2=anchors*(origin+marker.center)
		if SKIN.is_chibi():
			var state:String=marker.state
			if not active_only:Q_STAR.cell(self,Rect2(center-Vector2.ONE*CELL*.5,Vector2.ONE*CELL),state,1.4 if emphasis and on else 1.0)
			var star_size=14 if active_only else 16 if on else 14
			if emphasis and on:star_size=17
			Q_STAR.draw(self,center,star_size,state,motion.elapsed,1.0,click_age,index)
			continue
		if not active_only:
			draw_rect(Rect2(center-Vector2.ONE*CELL*.5,Vector2.ONE*CELL),Color(GOLD,.16 if on else .06))
		_star(center,(6 if active_only else 10)+(3 if emphasis and on else 0),GOLD if on else Color("a8a37d"),on)

func _draw_shop() -> void:
	if SKIN.is_chibi():_draw_chibi_shop();return
	_text("补给",Vector2(1070,200),23,T.tone(T.PAPER))
	var free=RECRUITMENT.refresh_cost(run)==0
	_button(Rect2(1328,162,48,48),"刷新","reroll",free or run.gold>=1)
	_text("免费" if free else "1",Vector2(1285,193),14,T.tone(T.MUTED))
	for n in range(6):
		var rect=_offer_rect(n)
		var offer=run.shop[n]
		T.rule(self,rect.position+Vector2(8,rect.size.y+1),rect.end-Vector2(5,-1),.10)
		if offer.is_empty():
			_text("—",rect.position+Vector2(133,47),19,Color(T.tone(T.MUTED),.35))
			continue
		var t=clampf((reroll_age-n*.028)/.18,0,1)
		var shift=Vector2(pow(1-t,3)*18,0)
		var over=motion.hover("offer"+str(n),rect.has_point(mouse))
		if over>0.01:T.fade(self,rect,Color(T.tone(T.PAPER),over*.09),Color(T.tone(T.PAPER),0))
		var kind=offer.kind
		var selected=detail_origin=="shop" and detail_offer_index==n and item_selection_age<ITEM_SELECTION_DURATION
		if n==5:
			var icon_rect=Rect2(rect.position+Vector2(8,6)+shift,Vector2(72,65))
			_draw_icon(kind,_selection_rect(icon_rect) if selected else icon_rect,0,t)
			_text(POCKETS.profile(kind).name,rect.position+Vector2(95,35)+shift,17,T.tone(T.PAPER))
			_text({"pouch":"盾 +2 / 格","strip":"冷却 −10%","corner":"声骸 +15%","travel":"武器 +8%"}.get(kind,POCKETS.profile(kind).effect),rect.position+Vector2(95,58)+shift,13,POCKETS.profile(kind).color.darkened(.4) if SKIN.is_chibi() else POCKETS.profile(kind).color)
		else:
			var icon_rect=Rect2(rect.position+Vector2(4,4-over*2)+shift,Vector2(202,72))
			_draw_icon(kind,_selection_rect(icon_rect) if selected else icon_rect,0,t*(.22 if not dragging.is_empty() and drag_origin=="shop" and drag_offer_index==n else 1.0))
		_text(str(inventory.purchase_price(run,n)),rect.position+Vector2(235,48)+shift,23,T.tone(T.PAPER))
		_coin(rect.position+Vector2(218,40)+shift,5)
		var lock_rect=Rect2(rect.position+Vector2(267,23),Vector2(30,35))
		_button(lock_rect,"","lock:"+str(n),true,false)
		var locked=offer.get("locked",false)
		var lc=lock_rect.get_center()
		var tint=GOLD if locked else Color(T.tone(T.PAPER),.30+over*.25)
		if SKIN.is_chibi():T.glyph(self,"lock",lock_rect.grow(-5),1.0 if locked else .45)
		else:
			draw_arc(lc-Vector2(0,4),4,PI,TAU,16,tint,1,true)
			draw_rect(Rect2(lc+Vector2(-6,-4),Vector2(12,10)),tint,false,1)
			if locked:draw_circle(lc+Vector2(0,1),1,tint)
	_button(Rect2(1326,787,48,48),"图鉴","catalogue")
	if SKIN.is_chibi():_chibi_tool_caption("物品图鉴",Vector2(1203,805),16)
	else:_text("物品图鉴",Vector2(1203,819),16,T.tone(T.DARK))

func _offer_rect(index: int) -> Rect2:
	return QL.offer(index) if SKIN.is_chibi() else Rect2(1074,234+index*87,300,80)

func _draw_stash() -> void:
	var rect=_stash_mat_rect()
	var stash_view=_stash_display_preview()
	var shown=stash_view.get("run",run).stash
	var displaced=stash_view.get("displaced",[]).map(func(v):return v.uid)
	_text("储物",Vector2(334,729) if SKIN.is_chibi() else Vector2(337,756),21 if SKIN.is_chibi() else 16,T.tone(T.PAPER) if SKIN.is_chibi() else T.tone(T.DARK))
	if SKIN.is_chibi():
		TERMINAL.placement_grid(self,QL.STASH.position,Vector2i(STASH_PAGE_SIZE,1),QL.STASH.size.y,1.0,QL.STASH.size.x/STASH_PAGE_SIZE,"stash")
	if not dragging.is_empty():T.fade(self,rect,Color(GOLD,.18),Color(GOLD,.04))
	if _stash_pages()>1:
		var y=699.0 if SKIN.is_chibi() else 729.0
		_button(Rect2(776,y,32,32),"‹","stash_prev",_stash_current_page()>0)
		_text("%d / %d"%[_stash_current_page()+1,_stash_pages()],Vector2(819,y+23),17,T.tone(T.PAPER))
		_button(Rect2(894,y,32,32),"›","stash_next",_stash_current_page()+1<_stash_pages())
	for n in range(_stash_current_page()*STASH_PAGE_SIZE,(_stash_current_page()+1)*STASH_PAGE_SIZE):
		var r=_stash_rect(n)
		if n<shown.size():
			var item=shown[n]
			if item.uid in displaced:continue
			if not dragging.is_empty() and item.uid==dragging.uid:continue
			if stash_transfer.in_flight(item.uid):continue
			var selected=detail_origin=="stash" and item.uid==detail_item.get("uid","") and item_selection_age<ITEM_SELECTION_DURATION
			_draw_icon(item.kind,_selection_rect(r.grow(-3)) if selected else r.grow(-3),int(item.rotation),fusion_view.output_alpha(item.uid),false,true)
		elif not SKIN.is_chibi():
			var at=r.get_center()
			draw_line(at-Vector2(3,0),at+Vector2(3,0),Color(T.tone(T.PAPER),.23),1,true)
			draw_line(at-Vector2(0,3),at+Vector2(0,3),Color(T.tone(T.PAPER),.23),1,true)
	if not (run.get("pending_gifts",[])+run.get("pending_rearrange",[])).is_empty():
		_button(Rect2(857,861,128,43),"领取 "+str(run.get("pending_gifts",[]).size()+run.get("pending_rearrange",[]).size()),"claim_gifts")

func _stash_display_preview()->Dictionary:
	if dragging.is_empty() or _shop_press_pending():return {}
	if _stash_mat_rect().has_point(mouse) and drag_origin in ["board","bag"]:
		var stored=inventory.stash_preview(run,dragging)
		return stored if stored.ok else {}
	if C.is_tag(dragging.kind,"bag") or not _drag_over_board():return {}
	var preview=_item_drop_preview()
	return preview if preview.ok else {}

func _draw_battle_center() -> void:
	# V60 has no energy gauge; both skins show the actual buff/status frames.
	pass

func _chase_summary_rows() -> Array:
	var grouped={}
	for ev in combat.get("events",[]):
		if int(ev.side)!=0 or ev.kind not in ["coordinated","cooldown_advance"] or not ev.has("source_uid"):continue
		if ev.kind=="cooldown_advance" and _advance_seconds(ev)<=0:continue
		var uid=str(ev.source_uid)
		if not grouped.has(uid):grouped[uid]={"uid":uid,"chases":0,"marks":0,"advance":0.0}
		if ev.kind=="coordinated":
			grouped[uid].chases+=1;grouped[uid].marks+=int(ev.consumed_marks)
		else:grouped[uid].advance+=_advance_seconds(ev)
	return grouped.values().slice(0,3)

func _star_trigger_count() -> int:
	return BATTLE_FEEDBACK.stars(combat.get("events",[]),0)

func _result_contributions() -> Array:
	return BATTLE_FEEDBACK.result_contributions(combat.get("events",[]),0,run.get("items",[]))

func _result_fatigue() -> String:
	var totals=combat.get("totals",[])
	if totals.size()<2:return ""
	var own=float(totals[0].get("fatigue",0));var other=float(totals[1].get("fatigue",0))
	return "疲劳  我方 -%.1f · 对方 -%.1f"%[own,other] if own+other>0 else ""

func _draw_contribution(row:Dictionary,at:Vector2,chibi:bool) -> void:
	var tint=SKIN.PLUM if chibi else T.tone(T.PAPER)
	if chibi:T.surface(self,Rect2(at,Vector2(394,54)),"button")
	_draw_icon(row.kind,Rect2(at+Vector2(8,4),Vector2(46,46)),0)
	_text(C.items[row.kind].name,at+Vector2(61,21),15,tint)
	var x=61.0;var y=28.0
	for spec in [["damage","attack","伤害"],["shield","shield","获盾"],["heal","healing","治疗"]]:
		if float(row[spec[0]])<=0:continue
		ABILITY_ICONS.draw(self,spec[1],Rect2(at+Vector2(x,y),Vector2.ONE*20))
		_text(spec[2]+" "+String.num(float(row[spec[0]]),1),at+Vector2(x+23,y+16),14,tint)
		if chibi:x+=105
		else:y+=21

func _result_title() -> String:
	if run.phase=="ending":return "通关" if PROGRESSION.cleared(run) else "结束"
	var winner=int(combat.get("winner",0))
	return "胜利" if winner==1 else "平局" if winner==0 else "败北"

func _result_summary() -> String:
	if not combat.has("totals"):return ""
	var line="输出 %.1f"%float(combat.totals[0].damage)
	if not combat.get("legacy_result",false) and not combat.get("events",[]).is_empty():
		line+=" · 挡伤 %.1f"%BATTLE_FEEDBACK.absorption(combat.events,0)
	return line

func _draw_result() -> void:
	var winner=int(combat.get("winner",0));var won=winner==1
	var title=_result_title();var line=_result_summary()
	var fatigue=_result_fatigue()
	var rows=_result_contributions()
	if SKIN.is_chibi():
		T.surface(self,Rect2(559,166,322,232 if not fatigue.is_empty() else 220),"panel")
		T.glyph(self,"victory" if won else "defeat",Rect2(690,189,60,60))
		_text(title,Vector2(683,271),30,SKIN.PLUM)
		_text(line,Vector2(598,300),16,SKIN.PLUM)
		if not fatigue.is_empty():_text(fatigue,Vector2(588,321),14,SKIN.PLUM)
		for n in rows.size():_draw_contribution(rows[n],Vector2(116+n*404,895),true)
		_button(Rect2(603,339 if not fatigue.is_empty() else 324,234,42),"返回选择" if run.phase=="ending" else "继续","home" if run.phase=="ending" else "next",true,true,GOLD)
		_button(Rect2(620,413,200,41),"战斗记录","battle_review",BATTLE_REVIEW.available(combat))
		return
	T.plate(self,Rect2(106,823,1228,120),Color(T.tone(T.SHELL),.86),Color(T.tone(T.EDGE),.35),6)
	T.rule(self,Vector2(116,817),Vector2(1324,817),.28)
	_text(title,Vector2(121,866),32,GOLD if won else T.tone(T.PAPER))
	_text(line,Vector2(124,894),15,T.tone(T.MUTED))
	if not fatigue.is_empty():_text(fatigue,Vector2(124,921),13,T.tone(T.MUTED))
	for n in rows.size():_draw_contribution(rows[n],Vector2(355+n*242,839),false)
	_button(Rect2(1095,895,228,39),"返回选择" if run.phase=="ending" else "继续","home" if run.phase=="ending" else "next",true,true,GOLD)

func _draw_drag() -> void:
	if _shop_press_pending():
		var rect=_shop_icon_rect(drag_offer_index);rect.position+=mouse-drag_press_at+Vector2(0,-2.5)
		_draw_icon(dragging.kind,rect,0)
		return
	if SKIN.is_chibi():T.glyph(self,"rotate",Rect2(mouse+Vector2(22,17),Vector2.ONE*22),.8)
	var pos=_drag_placement_cell()
	var next=dragging.duplicate(true)
	next.x=pos.x
	next.y=pos.y
	var near_board=_drag_over_board()
	var bag_preview={}
	var item_preview={}
	var pocket_sources:Array=[]
	if near_board and not C.is_tag(next.kind,"bag"):item_preview=_item_drop_preview()
	if C.is_tag(next.kind,"bag"):
		var preview_run=run
		if drag_origin=="shop":
			preview_run=run.duplicate(true);preview_run.stash.append(next)
		bag_preview=inventory.bag_transaction(preview_run,next)
	if near_board:
		_basis(_board_transform())
		var valid=false
		if C.is_tag(next.kind,"bag"):
			var transaction=bag_preview
			valid=transaction.ok
			GRID.footprint(self,BOARD+Vector2(next.x,next.y)*CELL,inventory.cells(next),CELL,Color(.45,.78,.62,.16) if valid else Color(.9,.35,.3,.32),true)
			if valid:
				for original in run.items:
					if transaction.items.all(func(i):return i.uid!=original.uid):
						var rect=_item_rect(original,BOARD)
						GRID.footprint(self,BOARD+Vector2(original.x,original.y)*CELL,inventory.cells(original),CELL,Color(.89,.42,.35,.20),false)
						draw_line(rect.get_center(),_board_transform().affine_inverse()*_stash_mat_rect().get_center(),Color(.85,.52,.45,.4),1,true)
		else:
			valid=item_preview.ok
			if valid:
				var relation=item_preview.run
				_draw_coord_links(relation,BOARD)
				pocket_sources=inventory.pocket_bonus(item_preview.piece,relation).sources
				for source in pocket_sources:
					POCKET_VIEW.benefit(self,BOARD,source.cells,CELL,source.kind)
			GRID.footprint(self,BOARD+Vector2(next.x,next.y)*CELL,inventory.cells(next),CELL,Color(T.tone(T.JADE),.25) if valid else Color(T.tone(T.ALERT),.3),false)
		_basis()
	if not item_preview.is_empty():_draw_transfer_preview(item_preview)
	if _stash_mat_rect().has_point(mouse) and drag_origin in ["board","bag"]:
		_draw_transfer_preview(inventory.stash_preview(run,dragging))
	var blocked_stash=_stash_drop_projection()
	if blocked_stash.has_area():draw_rect(blocked_stash,Color("df8177",.3))
	_basis(_held_pose())
	var held=_held_source_piece();held.x=0;held.y=0
	if C.is_tag(next.kind,"bag"):
		TERMINAL.surface(self,Vector2.ZERO,[held],CELL,held.uid,.94)
		# A solid cloth mat can hide the board's rejection shadow beneath it.
		# Keep the same invalid placement visible on the held Q mat as well.
		if SKIN.is_chibi() and near_board and not bag_preview.ok:
			GRID.footprint(self,Vector2.ZERO,inventory.cells(held),CELL,Color("e77773",.38),false)
		var originals=run.bags.filter(func(v):return v.uid==dragging.uid)
		if not originals.is_empty() and (not _stash_mat_rect().has_point(mouse) or not inventory.stash_preview(run,dragging).ok):
			var owned_cells=inventory.occupied(originals[0])
			var carried_ids=run.items.filter(func(v):return inventory.occupied(v).all(func(c):return c in owned_cells)).map(func(v):return v.uid)
			for item in run.items:
				if item.uid not in carried_ids:continue
				var carried=item.duplicate(true);carried.x-=originals[0].x;carried.y-=originals[0].y
				_draw_piece(carried,Vector2.ZERO)
	else:_draw_piece(held,Vector2.ZERO,1.0)
	_basis()
	if near_board and item_preview.get("ok",false):
		_basis(_board_transform())
		_draw_star_markers(_drag_star_markers(item_preview),BOARD,false,false,_star_click_age(dragging,drag_origin))
		for source in pocket_sources:
			var last=source.cells[-1]
			var label="+"+str(int(source.value)) if source.stat=="shield" else ("−" if source.stat=="speed" else "+")+str(snappedf(float(source.value)*100,.1))+"%"
			_text(label,BOARD+(Vector2(last)+Vector2(.08,.94))*CELL,10,SKIN.PLUM)
		_basis()

func _item_drop_preview()->Dictionary:
	if dragging.is_empty():return {"ok":false,"displaced":[],"error":""}
	var next=dragging.duplicate(true);var pos=_drag_placement_cell();next.x=pos.x;next.y=pos.y
	return inventory.placement_preview(run,next,drag_offer_index if drag_origin=="shop" else -1)

func _stash_drop_projection() -> Rect2:
	if dragging.is_empty() or not _stash_mat_rect().has_point(mouse):return Rect2()
	var preview=run.duplicate(true)
	var valid=drag_origin=="stash"
	if drag_origin in ["board","bag"]:valid=inventory.stash(preview,dragging)
	elif drag_origin=="shop":valid=not inventory.purchase_at(preview,drag_offer_index,dragging,"stash").is_empty()
	return Rect2() if valid else _stash_mat_rect()

func _drag_visual_origin() -> Vector2:
	return _held_pose().origin

func _occupied_center(piece:Dictionary) -> Vector2:
	var cells=inventory.cells(piece)
	var center=Vector2.ZERO
	for cell in cells:center+=Vector2(cell)+Vector2.ONE*.5
	return center/maxi(1,cells.size())*CELL

func _clear_held_pose() -> void:
	carry_replacement=false
	drag_source={};drag_source_center=Vector2.ZERO;drag_center_offset=Vector2.ZERO
	drag_target_angle=0.0;drag_turn_remaining=0.0;drag_turn_from=0.0;drag_turn_age=DRAG_TURN_DURATION

func _start_held_pose() -> void:
	carry_replacement=false
	var held=forge_output if not forge_output.is_empty() else dragging
	if held.is_empty():return
	_start_star_click(held,drag_origin)
	# Freeze the source pose. Logical quarter turns affect placement immediately;
	# the complete source image and any carried items remain one rigid body.
	drag_source=held.duplicate(true)
	drag_source_center=_occupied_center(held)
	var grip=(Vector2(drag_offset)+drag_fraction)*CELL
	drag_center_offset=(drag_source_center-grip)*_board_transform().get_scale().x
	drag_target_angle=0.0;drag_turn_remaining=0.0;drag_turn_from=0.0;drag_turn_age=DRAG_TURN_DURATION

func _held_source_piece() -> Dictionary:
	var held=forge_output if not forge_output.is_empty() else dragging
	return (drag_source if drag_source.get("uid","")==held.get("uid","") and not drag_source.is_empty() else held).duplicate(true)

func _held_center_screen() -> Vector2:
	return mouse+drag_center_offset

func _held_pose() -> Transform2D:
	var scale_value=_board_transform().get_scale().x
	return Transform2D(drag_target_angle+drag_turn_remaining,Vector2.ONE*scale_value,0,_held_center_screen())*Transform2D(0,-drag_source_center)

func _drag_placement_cell() -> Vector2i:
	var held=forge_output if not forge_output.is_empty() else dragging
	if held.is_empty():return _board_cell(mouse)
	# Snap the final occupied center, not the old grabbed cell. Both the visible
	# ghost and the release transaction call this while the art is still turning.
	var center=(_board_transform().affine_inverse()*_held_center_screen()-BOARD)/CELL
	return Vector2i((center-_occupied_center(held)/CELL).round())

func _drag_over_board() -> bool:
	var held=forge_output if not forge_output.is_empty() else dragging
	if held.is_empty():return false
	# Pointer-addressed destinations take precedence even when a far-end grip
	# leaves the item center or part of its footprint over the board.
	if _stash_mat_rect().has_point(mouse) or _sell_rect().has_point(mouse):return false
	var shop=QL.SHOP if SKIN.is_chibi() else Rect2(1046,178,350,605)
	if shop.has_point(mouse):return false
	var board=_board_screen_rect()
	if board.has_point(mouse) or board.has_point(_held_center_screen()):return true
	var target=_drag_placement_cell()
	var domain=Rect2i(Vector2i.ZERO,Vector2i(I.WIDTH,I.HEIGHT))
	return inventory.cells(held).any(func(cell):return domain.has_point(target+cell))

func _start_star_click(item:Dictionary,origin:String)->void:
	if C.is_tag(item.kind,"bag"):return
	star_click_uid=str(item.get("uid",""));star_click_origin=origin;star_click_elapsed=0.0

func _star_click_age(item:Dictionary,origin:String)->float:
	return star_click_elapsed if not star_click_uid.is_empty() and star_click_uid==str(item.get("uid","")) and star_click_origin==origin else -1.0

func _open_item_details(item:Dictionary,origin:String) -> void:
	var from_held=not dragging.is_empty() and dragging.get("uid","")==item.get("uid","") and drag_origin==origin
	if not from_held or _star_click_age(item,origin)<0:_start_star_click(item,origin)
	if origin!="recipe":detail_history=[]
	if origin!="recipe" and overlay!="item_details":detail_parent_overlay=overlay if overlay in ["catalogue","opponent"] else ""
	detail_anchor=_detail_source_rect(item,origin)
	detail_item=item.duplicate(true);detail_origin=origin;detail_page=0
	detail_offer_index=drag_offer_index if origin=="shop" else -1
	item_selection_age=0.0
	dragging={};_clear_held_pose();hovered={};overlay="item_details"
	motion.modal_value=0;motion.modal_target=0;motion.last_overlay=""
	# The initiating press already owns its cue; opening a view must not replay it.

func _item_star_snapshot(item:Dictionary,origin:String)->Dictionary:
	var local=item.duplicate(true);local.x=0;local.y=0
	var markers=STAR_FEEDBACK.markers(inventory.stars(local),[],1)
	var count=-1
	if origin in ["board","enemy"]:
		var build=opponent if origin=="enemy" else run
		# A legacy remote link can merge two slots at one target coordinate.
		# Reuse the board projection instead of indexing it by the original slots.
		markers=[];var represented={}
		for actual in _effect_star_markers(item,build.get("items",[]),build):
			var marker=actual.duplicate(true)
			marker.cell-=Vector2i(item.x,item.y);marker.center=Vector2(marker.cell)+Vector2.ONE*.5
			markers.append(marker)
			if marker.state=="lit" and not str(marker.target_uid).is_empty():represented[marker.target_uid]=true
		count=represented.size()
	return {"cells":inventory.cells(local),"markers":markers,"matched_count":count,"click_age":_star_click_age(item,origin),"categories":preload("res://scripts/battle/star_filters.gd").for_kind(item.kind)}

func _blocking_overlay()->bool:
	return not overlay.is_empty() and overlay!="item_details"

func _detail_source_rect(item:Dictionary,origin:String)->Rect2:
	if origin in ["board","bag","pocket","enemy"]:
		var side=1 if origin=="enemy" else 0
		var rect=_item_rect(item,BOARD if side==0 else ENEMY_BOARD)
		return _board_transform(side)*rect
	if origin=="shop":
		var index=drag_offer_index
		if index<0:index=detail_offer_index
		if index>=0 and index<6:return _offer_rect(index)
	if origin=="stash":
		for index in run.stash.size():
			if run.stash[index].uid==item.get("uid",""):return _stash_rect(index)
	return Rect2(mouse-Vector2(12,12),Vector2(24,24))

func _shop_recipe_partners()->Array:
	if detail_origin!="shop":return []
	return preload("res://scripts/crafting/craft_handler.gd").shop_partners(run,detail_offer_index,inventory)

func _detail_card_rect()->Rect2:
	var height=ITEM_PANEL.detail_height(self,detail_item)
	var x=detail_anchor.end.x+12
	if x+368>1432:x=detail_anchor.position.x-380
	return Rect2(Vector2(clampf(x,8,1064),clampf(detail_anchor.position.y-20,8,952-height)),Vector2(368,height))

func _close_item_details()->void:
	overlay=detail_parent_overlay
	motion.modal_value=1.0 if not overlay.is_empty() else 0.0
	motion.modal_target=motion.modal_value;motion.last_overlay=overlay

func _item_body_at(at:Vector2,side:int=0)->Dictionary:
	var build=run if side==0 else opponent
	var items=build.get("items",[])
	for index in range(items.size()-1,-1,-1):
		var item=items[index]
		if item_hit.contains(self,item,at,side):return item
	return {}

func _selection_rect(rect:Rect2) -> Rect2:
	# A single selection response; rendering only, so hit cells stay unchanged.
	var t=clampf(item_selection_age/ITEM_SELECTION_DURATION,0.0,1.0)
	var lift=sin(t*PI)
	var scale_value=1.0+lift*.015
	return Rect2(rect.get_center()+Vector2(0,-2.5*lift)-rect.size*scale_value*.5,rect.size*scale_value)

func _draw_detail_icon(item:Dictionary,rect:Rect2) -> void:
	_draw_icon(item.kind,rect,0)

func _battle_item_side(item:Dictionary,origin:String) -> int:
	if screen!="game" or run.get("phase","") not in ["battle","result","ending"] or origin not in ["board","enemy"]:return -1
	var side=0 if origin=="board" else 1
	var build=run if side==0 else opponent
	return side if build.items.any(func(v):return v.uid==item.get("uid","") and v.kind==item.kind) else -1

func _item_waiting(item:Dictionary,origin:String) -> bool:
	var side=_battle_item_side(item,origin)
	return side>=0 and bool(_current_frame().get("waiting",[{},{}])[side].get(item.get("uid",""),false))

func _item_battle_rows(item:Dictionary,origin:String) -> Array:
	var side=_battle_item_side(item,origin)
	if side<0:return []
	var stats=BATTLE_FEEDBACK.contribution(combat.get("events",[]),side,str(item.uid),combat_time)
	var rows=[]
	for spec in [["stars","★ 本场触发"],["damage","本场伤害"],["heal","实际治疗"],["shield","获得护盾"],["advance","推进冷却"]]:
		if float(stats[spec[0]])>0:rows.append([spec[1],String.num(stats[spec[0]],1)+( " 秒" if spec[0]=="advance" else " 次" if spec[0]=="stars" else "")])
	return rows

func _draw_overlay() -> void:
	if overlay=="history":
		_basis();paint_alpha=1;paint_offset=Vector2.ZERO;buttons=[]
		history_buttons=HISTORY_VIEW.draw(self,{"rows":history_rows,"page":history_page,"selected":history_selected,"record":history_record,"mouse":mouse,"age":age},font,_chibi_portrait,_draw_history_board)
		return
	if overlay=="item_details":
		paint_alpha=1.0;paint_offset=Vector2.ZERO
		if detail_parent_overlay=="catalogue":buttons=[];_draw_catalogue()
		elif detail_parent_overlay=="opponent":buttons=[];_draw_opponent_view()
		ITEM_PANEL.details(self)
		return
	var previous_buttons=buttons.duplicate()
	buttons=[]
	var p=1-pow(1-motion.modal_value,5)
	paint_alpha=p
	paint_offset=Vector2(116*(1-p),0)
	var displayed=overlay if not overlay.is_empty() else motion.last_overlay
	if displayed in ["item_details","item_recipes"]:
		if displayed=="item_details":ITEM_PANEL.details(self)
		else:ITEM_PANEL.recipes(self)
		paint_alpha=1.0;paint_offset=Vector2.ZERO
		if overlay.is_empty():buttons=[]
		return
	if displayed in ["crew","catalogue"]:
		if displayed=="crew":_draw_crew_overlay()
		else:_draw_catalogue()
		paint_alpha=1.0;paint_offset=Vector2.ZERO
		if overlay.is_empty():buttons=[]
		return
	if displayed=="forge":
		_draw_forge()
		paint_alpha=1.0;paint_offset=Vector2.ZERO
		if overlay.is_empty():buttons=[]
		return
	if displayed=="opponent":
		_draw_opponent_view()
		paint_alpha=1.0
		paint_offset=Vector2.ZERO
		if overlay.is_empty():buttons=[]
		return
	draw_rect(Rect2(0,0,1440,960),Color(T.tone(T.SHADOW),.68*p))
	var tall=displayed in ["catalogue","crew","crew_skill","crew_original"]
	_panel(Rect2(390,220 if tall else 260,660,590 if tall else 452),CREAM,Color("98aa7b"),2,24)
	if displayed=="menu":
		_text("暂停",Vector2(630,338),32,INK)
		_button(Rect2(515,369,410,57),"继续游戏","close",true,true,GREEN)
		_button(Rect2(515,434,410,57),"对战记录","history",run.get("phase","")!="battle")
		_button(Rect2(515,499,410,57),"返回选择","home")
		_button(Rect2(515,564,410,57),"静音" if not muted else "打开声音","sound")
		_button(Rect2(515,629,410,57),"退出游戏","quit")
	elif displayed=="ghosts":
		_text("异步影像",Vector2(630,332),32,INK)
		_text("本机影像池 · 可导入朋友的行囊",Vector2(527,373),21,T.tone(T.MUTED))
		_button(Rect2(515,414,410,58),"导出当前行囊","export")
		if game_mode!="async":_button(Rect2(515,495,410,58),"导入影像并挑战","import",run.phase=="shop")
		_button(Rect2(515,589,410,58),"返回","close")
	elif displayed=="material":
		var material=_piece_by_uid(material_uid)
		var target=_piece_by_uid(material_target)
		_text("声骸养成",Vector2(630,318),29,INK)
		if not material.is_empty():
			_draw_icon(material.kind,Rect2(453,352,77,77),0)
			_text(C.items[material.kind].name,Vector2(552,382),22,INK)
		var echoes=run.items.filter(func(i):return C.is_tag(i.kind,"echo"))
		material_page=clampi(material_page,0,maxi(0,ceili(echoes.size()/6.0)-1))
		for n in range(6):
			var index=material_page*6+n
			if index>=echoes.size():break
			var rect=Rect2(437+n*94,447,83,60)
			_button(rect,"","material_target:"+echoes[index].uid,true,false)
			_draw_icon(echoes[index].kind,rect.grow(-8),0)
			if echoes[index].uid==material_target:draw_line(rect.position+Vector2(28,rect.size.y),rect.position+Vector2(55,rect.size.y),T.tone(T.MUTED),1.5,true)
		if echoes.size()>6:
			_button(Rect2(909,405,38,27),"‹","material_prev",material_page>0)
			_button(Rect2(957,405,38,27),"›","material_next",(material_page+1)*6<echoes.size())
		if not target.is_empty():
			_text("目标 · "+C.items[target.kind].name,Vector2(457,545),23,INK)
			if material.get("kind","")=="tube":
				_text("等级 +"+str(int(target.get("level",0)))+" → +"+str(mini(2,int(target.get("level",0))+1))+"  · 技能数值 +15%",Vector2(457,585),20,T.tone(T.MUTED))
			else:
				_button(Rect2(453,566,248,48),"迅捷 · 冷却 -12%","tuning:fast",true,true,GOLD if material_choice=="fast" else T.tone(T.SHELL))
				_button(Rect2(719,566,268,48),"强效 · 技能 +20%","tuning:strong",true,true,GOLD if material_choice=="strong" else T.tone(T.SHELL))
		else:_text("先在行囊放入一个声骸",Vector2(550,551),22,INK)
		_button(Rect2(459,647,225,48),"取消","close")
		_button(Rect2(733,647,248,48),"确认并消耗材料","material_confirm",not target.is_empty() and not material.is_empty(),true,GREEN)
	elif displayed=="replacement":
		_text("更换扩容",Vector2(574,326),29,INK)
		var options=inventory.replacement_options(run,replacement_kind)
		for n in range(options.size()):
			var option=options[n]
			var bag=run.bags.filter(func(b):return b.uid==option.bag_uid)[0]
			var rect=Rect2(428+(n%5)*119,358+floori(n/5.0)*92,107,82)
			_button(rect,"","replacement_target:"+bag.uid+":"+str(option.rotation),true,true,GOLD if replacement_target==bag.uid else T.tone(T.SHELL))
			_draw_icon(bag.kind,rect.grow(-14),int(bag.rotation))
		var matches=run.bags.filter(func(b):return b.uid==replacement_target)
		if not matches.is_empty():
			var bag=matches[0]
			var old_cells=inventory.cells(bag).size()
			var new_cells=C.items[replacement_kind].shape.size()
			var quote=inventory.replacement_quote(run,bag.uid,replacement_kind)
			var payment="返还 "+str(int(quote.cashback)) if int(quote.cashback)>0 else "支付 "+str(int(quote.price))
			_text(_display_name(bag.kind)+" → "+_display_name(replacement_kind),Vector2(450,563),23,INK)
			_text("容量 "+str(inventory.coverage(run.bags).size())+" → "+str(inventory.coverage(run.bags).size()-old_cells+new_cells)+" · "+payment+" 贝币",Vector2(450,601),21,T.tone(T.MUTED))
		else:_text("先清空一个记录区",Vector2(460,559),23,INK)
		_button(Rect2(459,647,225,48),"取消","close")
		_button(Rect2(733,647,248,48),"确认更换","replacement_confirm",not matches.is_empty(),true,GREEN)
	elif displayed=="sell_bag":
		var matches=run.bags.filter(func(i):return i.uid==material_uid)
		_text("拆下扩容",Vector2(631,332),30,INK)
		if not matches.is_empty():
			var bag=matches[0]
			_draw_icon(bag.kind,Rect2(620,375,190,130),0)
			_text(_display_name(bag.kind)+" · 减少 "+str(inventory.cells(bag).size())+" 格容量",Vector2(510,552),23,INK)
			_text("空袋可拆下",Vector2(510,593),20,T.tone(T.MUTED))
		_button(Rect2(461,640,220,48),"保留","close")
		_button(Rect2(735,640,244,48),"确认拆下并卖出","sell_bag_confirm",true,true,Color("c89b78"))
	elif displayed=="crew":
		_draw_crew_overlay()
	elif displayed=="crew_skill":
		_draw_crew_skill()
	elif displayed=="crew_original":
		_draw_crew_original()
	paint_alpha=1.0
	paint_offset=Vector2.ZERO
	if overlay.is_empty():buttons=[]

func _draw_forge() -> void:
	FORGE_VIEW.draw(self)

func _forge_placement_preview() -> Dictionary:
	return FORGE.preview(run,forge_output.kind,forge_base,inventory,{"x":forge_output.x,"y":forge_output.y,"rotation":forge_output.rotation})

func _forge_output_input(event: InputEvent) -> void:
	if _preparation_frozen():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:forge_output={};_clear_held_pose();return
		if event.keycode==KEY_R:_rotate_drag();_update_forge_projection();return
	if event is InputEventMouseMotion:
		mouse=event.position
		_update_forge_projection()
	if event is InputEventMouseButton:
		mouse=event.position
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			_rotate_drag();_update_forge_projection()
		elif event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _drag_over_board():
			_update_forge_projection()
			var outcome=_commit_preparation(FORGE.preview(run,forge_output.kind,forge_base,inventory,{"x":forge_output.x,"y":forge_output.y,"rotation":forge_output.rotation}))
			if not outcome.ok:
				motion.reject("0forge-preview");return
			forge_output={};_clear_held_pose();forge_base=outcome.output.uid;forge_index=0;forge_cache_key=""
			_play_craft_result(outcome)

func _update_forge_projection() -> void:
	var cell=_drag_placement_cell()
	forge_output.x=cell.x;forge_output.y=cell.y

func _draw_forge_output() -> void:
	if SKIN.is_chibi():T.glyph(self,"rotate",Rect2(mouse+Vector2(22,17),Vector2.ONE*22),.8)
	var preview=_forge_placement_preview()
	if _drag_over_board():
		_basis(_board_transform())
		var color=T.tone(T.JADE) if preview.ok else T.tone(T.ALERT)
		GRID.footprint(self,BOARD+Vector2(forge_output.x,forge_output.y)*CELL,inventory.cells(forge_output),CELL,Color(color,.25),true)
		var old=inventory.primary_weapon(run)
		if preview.ok and old.uid==forge_base:
			for echo in run.items:
				if C.is_tag(echo.kind,"echo") and float(C.items[echo.kind].get("damage",0))>0 and inventory.adjacent(old,echo) and not inventory.adjacent(preview.output,echo):
					var from=_item_rect(preview.output,BOARD).get_center();var to=_item_rect(echo,BOARD).get_center()
					draw_dashed_line(from,from.lerp(to,.35),Color(T.tone(T.ALERT),.65),1.4,4,true)
					draw_dashed_line(from.lerp(to,.65),to,Color(T.tone(T.ALERT),.65),1.4,4,true)
	_basis(_held_pose())
	var held=_held_source_piece();held.x=0;held.y=0
	_draw_piece(held,Vector2.ZERO,.88)
	_basis()

func _draw_coord_links(build: Dictionary,origin: Vector2) -> void:
	pass # V60 feedback uses selected stars and real activation pulses.

func _battle_item_position(side: int,uid: String) -> Vector2:
	var build=run if side==0 else opponent
	for item in build.items:
		if item.uid==uid:return _board_to_screen(_item_rect(item,BOARD if side==0 else ENEMY_BOARD).get_center(),side)
	return _actor_center(side)

func _battle_mark_position(side: int,uid: String) -> Vector2:
	var build=run if side==0 else opponent
	for item in build.items:
		if item.uid==uid:return _board_to_screen(_piece_marker(item,BOARD if side==0 else ENEMY_BOARD)+Vector2(-7,-20),side)
	return _actor_center(side)

func _launch_chase(event: Dictionary) -> void:
	var side=int(event.side);var trigger_uid=str(event.get("trigger_uid",event.uid))
	_sound("attack","echo")
	motion.pulse(str(side)+trigger_uid)
	projectiles.append({"side":side,"from":_battle_item_position(side,trigger_uid),"life":COMBAT_VFX.TRAVEL,"color":Color("d4ace6"),"chase":true,"weapon":"echo"})
	pending_impacts.append({"delay":COMBAT_VFX.TRAVEL,"event":event.duplicate(true)})

func _draw_opponent_view() -> void:
	STAGE.backdrop(self,"camp",age,paint_alpha)
	_text("对手影像",Vector2(62,66),25,CREAM)
	T.rule(self,Vector2(62,94)+paint_offset,Vector2(1378,94)+paint_offset,.23*paint_alpha)
	_text(C.characters[opponent.leader].name,Vector2(60,169),33,CREAM)
	_text(_element_label(C.characters[opponent.leader].element),Vector2(62,203),16,C.ELEMENTS[C.characters[opponent.leader].element].lightened(.25))
	_text("装备",Vector2(337,193),23,T.tone(T.PAPER))
	_text(str(inventory.coverage(opponent.bags).size()),Vector2(909,193),17,T.tone(T.MUTED))
	T.rule(self,Vector2(337,211)+paint_offset,Vector2(989,211)+paint_offset,.24*paint_alpha)
	var basis=_board_transform(1)
	basis.origin+=paint_offset
	_basis(basis)
	_draw_board(opponent,ENEMY_BOARD,1)
	_draw_relay(opponent,ENEMY_BOARD,1)
	_basis()
	_draw_character(opponent.leader,_prep_actor_rect(),true,-1,1)
	for n in range(opponent.get("supports",[]).size()):
		var role_id=str(opponent.supports[n])
		_crew_portrait(role_id,Vector2(102+n*99,749),25)
		_text(C.roster[role_id].name.substr(0,4),Vector2(71+n*99,799),15,T.tone(T.DARK))
	_text("第 "+str(int(opponent.round))+" 轮",Vector2(1070,193),23,T.tone(T.PAPER))
	T.rule(self,Vector2(1070,211)+paint_offset,Vector2(1368,211)+paint_offset,.24*paint_alpha)
	var primary=inventory.primary_weapon(opponent)
	if not primary.is_empty():
		var def=C.items[primary.kind]
		_text("武器",Vector2(1070,292),17,T.tone(T.MUTED))
		_draw_icon(primary.kind,Rect2(1070,330,290,150),int(primary.rotation))
		_wrapped(def.name,Vector2(1070,526),290,23,CREAM,2)
		_text("基础伤害  %.1f"%float(def.get("damage",0)),Vector2(1070,597),17,T.tone(T.PAPER))
		_text("攻击间隔  %.1f 秒"%float(def.get("cooldown",0)),Vector2(1070,632),17,T.tone(T.PAPER))
	_button(Rect2(1128,838,223,55),"返回整备","close",true,true,GOLD)

func _update_bag_style_title()->void:
	if DisplayServer.get_name()!="headless" and SKIN.bag_style in ["storybook","patchwork_v129"]:
		get_window().title="索拉里斯大乱斗 · V138"
	if DisplayServer.get_name()!="headless" and SKIN.bag_style in ["flat","fold"]:
		get_window().title="索拉里斯大乱斗 · V109 · "+("01 薄袋平铺" if SKIN.bag_style=="flat" else "02 软布折口")+" · F7 切换"

func _input(event: InputEvent) -> void:
	if matching:return
	if _preparation_frozen():
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			mouse=event.position
			for button in buttons:
				if button.enabled and _button_contains(button,mouse) and button.action in ["battle","home","menu","close","quit"]:_action(button.action);break
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F7 and SKIN.bag_style in ["flat","fold"]:
		_action("bag_style");queue_redraw();return
	if review.active:
		_review_input(event);queue_redraw();return
	if overlay=="history":
		if event is InputEventMouseMotion:mouse=event.position
		elif event is InputEventMouseButton and event.pressed:
			mouse=event.position
			if event.button_index==MOUSE_BUTTON_LEFT:_history_action(HISTORY_VIEW.hit(history_buttons,mouse))
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:_history_action("next")
			elif event.button_index==MOUSE_BUTTON_WHEEL_UP:_history_action("previous")
		elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:_history_action("close")
		queue_redraw();return
	# New actions finish presentation only; the craft was already committed once.
	if fusion_view.active() and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)):
		fusion_view.finish()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F12:
		_capture_play_frame.call_deferred()
		return
	if recruitment_view.active:
		_recruitment_intent(recruitment_view.input_intent(event));queue_redraw();return
	if crew_setup_view.active:
		_crew_setup_intent(crew_setup_view.intent(event));queue_redraw();return
	if _inline_craft_input(event):
		queue_redraw();return
	if not forge_output.is_empty():
		_forge_output_input(event);queue_redraw();return
	if _stash_page_input(event):queue_redraw();return
	if overlay.is_empty() and motion.modal_value>0 and not event is InputEventMouseMotion:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		mouse=event.position
		if screen=="game" and run.phase=="shop" and overlay.is_empty():
			if not dragging.is_empty():
				_rotate_drag()
				queue_redraw()
				return
		return
	if event is InputEventMouseMotion:
		mouse=event.position
		if drag_pressed:drag_distance=maxf(drag_distance,mouse.distance_to(drag_press_at))
		_update_hover()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		mouse=event.position
		if event.pressed:
			if carry_replacement and not dragging.is_empty():
				carry_replacement=false;drag_pressed=false;queue_redraw();return
			_mouse_down()
			if not dragging.is_empty():
				drag_pressed=true;drag_press_at=mouse;drag_distance=0;drag_rotated=false
				drag_fraction=Vector2.ONE*.5
				if drag_origin in ["board","bag"]:
					var cell_position=(_board_transform().affine_inverse()*mouse-BOARD)/CELL
					drag_fraction=cell_position-cell_position.floor()
				_start_held_pose()
				_sound("bag_pick" if C.is_tag(dragging.kind,"bag") else "pick")
		else:
			_mouse_up()
	elif event is InputEventKey and event.pressed and not event.echo:
		if _keyboard_action(event.keycode):
			queue_redraw()
			return
		if event.keycode==KEY_R and not dragging.is_empty():
			_rotate_drag()
		elif event.keycode==KEY_ESCAPE:
			if not dragging.is_empty():
				dragging={};drag_pressed=false;_clear_held_pose()
			elif overlay=="item_details":
				_close_item_details()
			elif not overlay.is_empty():
				overlay=""
			elif bag_mode:
				bag_mode=false
			elif relay_mode:
				relay_mode=false
				relay_draft=[]
			elif screen=="game":
				overlay="menu"
		elif event.keycode==KEY_SPACE and screen=="game" and run.phase=="battle":
			paused=not paused
	queue_redraw()

func _keyboard_action(key: int) -> bool:
	if overlay.is_empty() and motion.modal_value>0:return true
	if not overlay.is_empty():
		if key==KEY_ENTER and overlay=="material":
			_action("material_confirm")
			return true
		return false
	if screen=="camp":
		if key>=KEY_1 and key<KEY_1+C.selectable_leaders().size():
			_action("choose:"+str(C.selectable_leaders()[key-KEY_1]))
			return true
		if key==KEY_ENTER:
			_action("camp:"+game_mode+":enter")
			return true
		return false
	if not dragging.is_empty():
		if key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var delta={KEY_LEFT:Vector2(-1,0),KEY_RIGHT:Vector2(1,0),KEY_UP:Vector2(0,-1),KEY_DOWN:Vector2(0,1)}[key]
			mouse+=delta*CELL*_board_transform().get_scale()
			return true
		if key==KEY_ENTER:
			carry_replacement=false
			_mouse_up()
			return true
		return false
	if run.phase=="shop":
		if key==KEY_R:
			_action("bag_mode");return true
		if key>=KEY_1 and key<=KEY_6:
			var index=key-KEY_1
			if index==5 and not run.shop[5].is_empty() and _needs_replacement(run.shop[5].kind):
				_begin_replacement(run.shop[5].kind)
				return true
			if _begin_shop_drag(index):
				var fitted=inventory.first_fit(dragging,run.items,run.bags)
				if not fitted.is_empty():dragging.rotation=fitted.rotation
				mouse=_board_to_screen(BOARD+Vector2(fitted.get("x",0),fitted.get("y",0))*CELL+Vector2.ONE*CELL*.5)
				drag_fraction=Vector2.ONE*.5;drag_pressed=false;_start_held_pose()
			return true
		if key==KEY_TAB and not run.stash.is_empty():
			drag_turn_remaining=0.0
			stash_cursor=posmod(stash_cursor,run.stash.size())
			dragging=run.stash[stash_cursor].duplicate(true)
			_reveal_stash(dragging.uid)
			stash_cursor+=1
			drag_origin="stash"
			drag_offset=Vector2i.ZERO
			var fitted=inventory.first_fit(dragging,run.items,run.bags)
			if not fitted.is_empty():dragging.rotation=fitted.rotation
			mouse=_board_to_screen(BOARD+Vector2(fitted.get("x",0),fitted.get("y",0))*CELL+Vector2.ONE*CELL*.5)
			drag_fraction=Vector2.ONE*.5;drag_pressed=false;_start_held_pose()
			return true
		if key==KEY_C:
			_sound("click");_action("forge")
			return true
		if key==KEY_F:
			_action("reroll")
			return true
		if key in [KEY_ENTER,KEY_B]:
			_start_battle()
			return true
	if run.phase=="battle":
		if key==KEY_ENTER:
			_action("skip")
			return true
		if key==KEY_F:
			_action("speed")
			return true
	if run.phase=="result" and key==KEY_ENTER:
		_action("next")
		return true
	if run.phase=="ending" and key==KEY_ENTER:
		_action("home")
		return true
	return false

func _mouse_down() -> void:
	if overlay=="item_details":
		if _detail_card_rect().has_point(mouse):
			for button in buttons:
				if button.action.begins_with("detail") and _button_contains(button,mouse) and button.enabled:
					_sound("click");motion.press(button.action)
					_action(button.action);return
			return
		_close_item_details()
		buttons=buttons.filter(func(button):return not button.action.begins_with("detail"))
	if dragging.is_empty():drag_turn_remaining=0.0
	if overlay.is_empty() and motion.modal_value>0:return
	for button in buttons:
		if _button_contains(button,mouse) and button.enabled:
			if not overlay.is_empty() and not button.get("modal",false):continue
			if button.action!="battle":_sound("click")
			motion.press(button.action)
			_action(button.action)
			return
	if overlay=="opponent":
		var hit=_item_body_at(mouse,1)
		if not hit.is_empty():
			_sound("click");_open_item_details(hit,"enemy")
		return
	if screen!="game" or not overlay.is_empty():return
	if run.phase!="shop":
		if battle_entry_age<1.0:return
		_update_hover()
		if hovered.has("item"):
			_sound("click");_open_item_details(hovered.item,hovered.origin)
		return
	for n in range(6):
		if _offer_rect(n).has_point(mouse) and not run.shop[n].is_empty():
			_begin_shop_drag(n)
			return
	for n in _stash_indices():
		if _stash_rect(n).has_point(mouse):
			dragging=run.stash[n].duplicate(true)
			drag_origin="stash"
			drag_offset=Vector2i.ZERO
			return
	var pos=_board_cell(mouse)
	if relay_mode:
		for item in run.items:
			if pos not in inventory.occupied(item):continue
			if C.is_tag(item.kind,"weapon"):
				relay_draft=[item.uid]
			elif not relay_draft.is_empty():
				var next=relay_draft+[item.uid]
				if next.size()==3 and not bool(run.get("relay_guide_complete",false)):
					_notify("先连接武器和声骸")
					return
				if _commit_preparation(PREPARATION.relay(run,next,inventory.valid_relay,next.size()==2)).ok:
					relay_draft=next
					_sound("drop")
					_notify("接力已设置 · 战斗中协奏满 60 自动触发")
					motion.pulse("0"+item.uid)
				else:_notify("接力需相邻：武器 → 声骸 → 信物")
			return
		return
	# Actual visible bodies have priority even across a logical cell/region edge.
	var body=_item_body_at(mouse)
	if not body.is_empty():
		dragging=body.duplicate(true);drag_origin="board"
		drag_offset=pos-Vector2i(int(body.x),int(body.y));return
	var edge_bag=_edge_bag(mouse)
	for bag in run.bags:
		if edge_bag.get("uid","")==bag.uid or (bag_mode and pos in inventory.occupied(bag)):
			drag_offset=pos-Vector2i(int(bag.x),int(bag.y))
			dragging=bag.duplicate(true)
			drag_origin="bag"
			return
	for item in run.items:
		if pos in inventory.occupied(item):
			dragging=item.duplicate(true)
			drag_origin="board"
			drag_offset=pos-Vector2i(int(item.x),int(item.y))
			return
	# Empty interior is also a natural grab surface; item bodies retain priority.
	for bag in run.bags:
		if pos in inventory.occupied(bag):
			drag_offset=pos-Vector2i(int(bag.x),int(bag.y))
			dragging=bag.duplicate(true);drag_origin="bag";return

func _update_relay_guide() -> void:
	if not FEATURES.CONCERTO_ENABLED:return
	if bool(run.get("relay_guide_complete",false)):return
	var primary=inventory.primary_weapon(run)
	if primary.is_empty():return
	if not inventory.star_links(primary,run.items,run).is_empty():
		_commit_preparation(PREPARATION.guide(run,primary,inventory.star_links(primary,run.items,run)))
		motion.pulse("0"+primary.uid)
		for echo in inventory.star_links(primary,run.items,run):motion.pulse("0"+echo.uid)
		_notify("声骸已靠近武器 · 点击「接力」可设置顺序")

func _needs_replacement(kind: String) -> bool:
	var total=inventory.coverage(run.bags).size()
	for item in run.stash:
		if C.is_tag(item.kind,"bag"):total+=inventory.cells(item).size()
	return total+inventory.cells({"kind":kind,"rotation":0}).size()>I.MAX_CAPACITY

func _begin_replacement(kind: String) -> void:
	replacement_kind=kind
	var options=inventory.replacement_options(run,kind)
	replacement_target=options[0].bag_uid if not options.is_empty() else ""
	replacement_rotation=int(options[0].rotation) if not options.is_empty() else 0
	overlay="replacement"

# A page is presentation only; absolute stash indices still identify owned items.
func _stash_pages(count:int=-1)->int:
	return maxi(1,ceili(float(run.get("stash",[]).size() if count<0 else count)/STASH_PAGE_SIZE))
func _stash_current_page(count:int=-1)->int:
	return clampi(stash_page,0,_stash_pages(count)-1)
func _stash_indices()->Array:
	var start=_stash_current_page()*STASH_PAGE_SIZE
	return range(start,mini(start+STASH_PAGE_SIZE,run.get("stash",[]).size()))
func _stash_rect(index:int)->Rect2:
	var slot=index-_stash_current_page()*STASH_PAGE_SIZE
	if slot<0 or slot>=STASH_PAGE_SIZE:return Rect2()
	return QL.stash(slot) if SKIN.is_chibi() else Rect2(345+slot*105,773,84,70)
func _set_stash_page(next:int)->void:
	var page=clampi(next,0,_stash_pages()-1)
	if page==_stash_current_page():stash_page=page;return
	stash_page=page;hovered={}
	if overlay=="item_details" and detail_origin=="stash":_close_item_details()
	queue_redraw()
func _reveal_stash(uid:String)->void:
	for n in run.get("stash",[]).size():
		if run.stash[n].uid==uid:
			_set_stash_page(n/STASH_PAGE_SIZE);return
func _sync_stash_view(previous_uids:Array)->void:
	stash_page=_stash_current_page()
	for n in range(run.get("stash",[]).size()-1,-1,-1):
		if run.stash[n].uid not in previous_uids:
			_reveal_stash(run.stash[n].uid);return
func _stash_page_input(event:InputEvent)->bool:
	if not event is InputEventMouseButton:return false
	# A paging click owns its release too; an already held item is not a new click.
	if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and stash_page_pressed:
		stash_page_pressed=false;return true
	if screen!="game" or run.get("phase","")!="shop" or _blocking_overlay() or not event.pressed:return false
	if event.button_index==MOUSE_BUTTON_LEFT:
		if overlay=="item_details" and _detail_card_rect().has_point(event.position):return false
		for button in buttons:
			if button.action not in ["stash_prev","stash_next"] or not _button_contains(button,event.position):continue
			mouse=event.position;stash_page_pressed=true
			if button.enabled:
				_sound("click");motion.press(button.action);_action(button.action)
			return true
		return false
	if event.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] or not _stash_mat_rect().has_point(event.position):return false
	mouse=event.position
	_set_stash_page(_stash_current_page()+(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1))
	return true

func _material_begin(item: Dictionary,target: Dictionary = {}) -> void:
	material_page=0
	material_uid=item.uid
	material_target=target.get("uid","")
	if material_target.is_empty():
		for echo in run.items:
			if C.is_tag(echo.kind,"echo"):
				material_target=echo.uid
				break
	material_choice="strong"
	overlay="material"

func _piece_by_uid(uid: String) -> Dictionary:
	for item in run.items+run.stash:
		if item.uid==uid:return item
	return {}

func _begin_shop_drag(index: int) -> bool:
	drag_pressed=false
	if index<0 or index>=run.shop.size() or run.shop[index].is_empty():return false
	dragging=inventory.make_piece(run.shop[index].kind,"shop-preview")
	drag_origin="shop"
	drag_offer_index=index
	drag_offset=Vector2i.ZERO
	drag_fraction=Vector2.ONE*.5
	_start_held_pose()
	hovered={}
	return true

func _rotate_drag() -> void:
	var held=forge_output if not forge_output.is_empty() else dragging
	if held.is_empty():return
	drag_rotated=true
	_sound("turn")
	held.rotation=posmod(int(held.rotation)+1,4)
	drag_target_angle+=PI*.5
	drag_turn_remaining-=PI*.5
	# Retarget from the pose visible at this exact input event, even mid-turn.
	drag_turn_from=drag_turn_remaining;drag_turn_age=0.0

func _mouse_up() -> void:
	if carry_replacement:return
	if dragging.is_empty():drag_pressed=false;return
	# Inspection depends on intent (motion/rotation), never on hold duration.
	var click=drag_pressed and not drag_rotated and maxf(drag_distance,mouse.distance_to(drag_press_at))<=6.0
	drag_pressed=false
	if click:
		var item=dragging.duplicate(true);var origin=drag_origin
		_open_item_details(item,origin)
		drag_offer_index=-1;drag_turn_remaining=0.0
		return
	var pos=_drag_placement_cell()
	var item=dragging.duplicate(true)
	item.x=pos.x;item.y=pos.y
	var in_board=_drag_over_board()
	var in_stash=_stash_mat_rect().has_point(mouse)
	var before_items=run.items.duplicate(true)
	var item_preview=_item_drop_preview() if in_board and not C.is_tag(item.kind,"bag") else {}
	var held_from=Rect2(_held_center_screen()-_item_rect(item,Vector2.ZERO).size*_board_transform().get_scale()*.5,_item_rect(item,Vector2.ZERO).size*_board_transform().get_scale())
	var placed=false
	if drag_origin=="shop":
		var destination="board" if in_board else "stash" if in_stash else ""
		if not destination.is_empty():
			var purchase=_commit_preparation(inventory.plan_purchase_at(run,drag_offer_index,item,destination))
			var purchased=purchase.get("value",{}) if purchase.ok else {}
			placed=not purchased.is_empty()
			if placed:
				item=purchased
				motion.emit("coin",_offer_rect(drag_offer_index).get_center(),GOLD,_wallet_position())
	else:
		if in_board:placed=_commit_preparation(inventory.plan_place(run,item)).ok
		elif _sell_rect().has_point(mouse):
			if C.is_tag(item.kind,"bag") and drag_origin=="bag":
				material_uid=item.uid;overlay="sell_bag";dragging={};_clear_held_pose()
				return
			placed=_commit_preparation(inventory.plan_sell(run,item)).ok
		elif in_stash and drag_origin in ["board","bag"]:placed=_commit_preparation(inventory.plan_stash(run,item)).ok
		elif in_stash and drag_origin=="stash":
			# Rotation is kept when returning an owned piece to storage.
			placed=_commit_preparation(PREPARATION.rotate_stored(run,item.uid,int(item.rotation))).ok
	if placed:
		if C.is_tag(item.kind,"bag"):
			dragging={}
		_update_relay_guide()
		motion.pulse("0"+item.uid);motion.land("0"+item.uid)
		motion.emit("land",mouse,C.tint(item.kind))
		if C.is_tag(item.kind,"bag") and in_board:motion.emit("link",mouse,GOLD,_board_to_screen(BOARD+Vector2(item.x,item.y)*CELL))
		if _sell_rect().has_point(mouse):motion.emit("coin",mouse,GOLD,_wallet_position())
		if drag_origin=="shop":_sound("purchase")
		elif _sell_rect().has_point(mouse):_sound("sell")
		if C.is_tag(item.kind,"bag") and (in_board or in_stash):_sound("bag_drop")
		elif drag_origin!="shop" and not _sell_rect().has_point(mouse):_sound("drop")
	elif in_board or in_stash:
		motion.reject("0"+item.uid);motion.emit("invalid",mouse,Color("d37a68"))
		rejection_piece=item.duplicate(true) if in_board else {}
		rejection_rect=_stash_mat_rect() if in_stash and not in_board else Rect2()
		rejection_left=.28;_sound("reject")
	dragging={};drag_offer_index=-1;_clear_held_pose()
	if placed:
		if in_board and not C.is_tag(item.kind,"bag"):
			_pick_displaced(item_preview.get("displaced",[]))
		if in_board or in_stash:_enqueue_stash_transfers(before_items)
		if in_stash and not C.is_tag(item.kind,"bag"):
			stash_transfer.enqueue([{"piece":item.duplicate(true),"from":held_from}])
	_update_hover()

# The committed stash owns displaced items; holding is a reversible UI gesture.
func _pick_displaced(displaced:Array)->void:
	var candidates=displaced.filter(func(p):return run.stash.any(func(v):return v.uid==p.uid))
	if candidates.is_empty():return
	var cell=_board_cell(mouse)
	candidates.sort_custom(func(a,b):
		var hit_a=cell in inventory.occupied(a);var hit_b=cell in inventory.occupied(b)
		return hit_a if hit_a!=hit_b else str(a.uid)<str(b.uid))
	dragging=inventory.find_piece(run,candidates[0].uid).duplicate(true)
	_reveal_stash(dragging.uid)
	drag_origin="stash";drag_offset=Vector2i.ZERO;drag_fraction=Vector2.ONE*.5
	drag_pressed=false;drag_rotated=false;_start_held_pose()
	drag_center_offset=Vector2.ZERO;carry_replacement=true
	hovered={};_sound("pick")

func _update_hover() -> void:
	var old=hovered.get("item",{}).get("uid","")+hovered.get("origin","")+hovered.get("leader","")
	hovered={}
	if not dragging.is_empty():return
	if not inline_craft.hit(_craft_view_model(),mouse).is_empty():return
	if screen=="camp":
		for n in range(C.selectable_leaders().size()):
			if _camp_tag_rect(n).has_point(mouse):hovered={"leader":C.selectable_leaders()[n]}
		if old!=hovered.get("leader",""):hover_time=0
		return
	if screen!="game":return
	if run.phase=="shop":
		if _prep_actor_rect().has_point(mouse):hovered={"leader":run.leader}
	else:
		for side in range(2):
			if Rect2(242 if side==0 else 967,116,213,93).has_point(mouse):hovered={"leader":run.leader if side==0 else opponent.leader}
	if run.phase=="shop":
		for n in range(6):
			if _offer_rect(n).has_point(mouse) and not run.shop[n].is_empty():
				hovered={"item":{"kind":run.shop[n].kind,"uid":"shop"+str(n),"rotation":0,"x":0,"y":0},"origin":"shop"}
		for n in _stash_indices():
			if _stash_rect(n).has_point(mouse):
				hovered={"item":run.stash[n],"origin":"stash"}
	var body_found=false
	for side in range(2):
		if side==0 and (overlay=="opponent" or (overlay=="item_details" and detail_parent_overlay=="opponent")):continue
		if side==1 and run.phase=="shop" and not (overlay=="opponent" or (overlay=="item_details" and detail_parent_overlay=="opponent")):continue
		var body=_item_body_at(mouse,side)
		if not body.is_empty():
			hovered={"item":body,"origin":"board" if side==0 else "enemy"};body_found=true;break
		var pos=_board_cell(mouse,side)
		var build=run if side==0 else opponent
		for item in build.get("items",[]):
			if pos in inventory.occupied(item):hovered={"item":item,"origin":"board" if side==0 else "enemy"}
	if run.phase=="shop" and not body_found and _board_screen_rect().grow(CELL*.5).has_point(mouse):
		var pos=_board_cell(mouse)
		var edge_bag=_edge_bag(mouse)
		for bag in run.bags:
			if edge_bag.get("uid","")==bag.uid or (pos in inventory.occupied(bag) and (bag_mode or hovered.is_empty())):
				hovered={"item":bag,"origin":"pocket"};break
	if old!=hovered.get("item",{}).get("uid","")+hovered.get("origin","")+hovered.get("leader",""):
		hover_time=0.0
		# Hover emphasizes an existing relation visually; only actual effects sound.

func _action(action: String) -> void:
	if matching:return
	if _preparation_frozen() and action not in ["battle","home","menu","close","quit"]:return
	if action.begins_with("mode:"):_switch_mode(action.trim_prefix("mode:"));return
	if action.begins_with("camp:"):_camp_action(action);return
	if action in ["stash_prev","stash_next"]:
		_set_stash_page(_stash_current_page()+(1 if action=="stash_next" else -1));return
	if action=="bag_style":
		SKIN.set_bag_style("fold" if SKIN.bag_style=="flat" else "flat")
		_update_bag_style_title();return
	if ITEM_PANEL.action(self,action):return
	if action.begins_with("catalogue_detail:"):
		var kind=action.trim_prefix("catalogue_detail:")
		catalogue_focus=C.items.keys().filter(func(k):return FEATURES.item_enabled(k)).find(kind)
		_open_item_details({"kind":kind,"rotation":0},"catalogue");return
	if not FEATURES.CONCERTO_ENABLED and action in ["relay_mode","relay_done","relay_clear","crew_swap"]:return
	if action.begins_with("crew_focus:"):
		crew_focus=action.trim_prefix("crew_focus:")
		selection_age=0.0
		return
	if action.begins_with("forge_place:"):
		var options=FORGE.options(run,forge_base,inventory)
		if options.is_empty():return
		var target=options[clampi(forge_index,0,options.size()-1)].target
		var result=_commit_preparation(FORGE.HANDLER.material_plan(run,target,forge_base,action.trim_prefix("forge_place:"),inventory))
		if result.ok:
			_sound("drop");forge_cache_key=""
			motion.land("0"+result.item.uid)
		_notify(result.reason)
		return
	if action.begins_with("forge_buy:"):
		var kind=action.trim_prefix("forge_buy:")
		if _commit_preparation(FORGE.plan_buy_material(run,kind,inventory)).ok:
			_sound("purchase");forge_cache_key=""
			_notify("材料已放入储物箱 · 点击「放到武器旁」继续")
		else:_notify("检查贝币、轮次和准备区")
		return
	if action.begins_with("crew_filter:"):
		crew_filter=action.trim_prefix("crew_filter:");crew_page=0;crew_focus="";return
	if action.begins_with("recruit:"):
		var role_id=action.trim_prefix("recruit:")
		if _commit_preparation(inventory.plan_recruit(run,role_id)).ok:
			crew_tab="formation"
			crew_focus=role_id
			_sound("purchase")
			motion.emit("land",Vector2(160,730),GOLD)
			toast_timer=0.0
		else:_notify("本轮已签约，或贝币不足")
		return
	if action.begins_with("crew_toggle:"):
		var role_id=action.trim_prefix("crew_toggle:")
		var selected=run.get("supports",[]).duplicate()
		if role_id in selected:selected.erase(role_id)
		elif selected.size()<2:selected.append(role_id)
		else:
			_notify("最多两名伙伴出战")
			return
		_commit_preparation(inventory.plan_set_supports(run,selected))
		return
	if action.begins_with("crew_skill:"):
		crew_focus=action.trim_prefix("crew_skill:")
		overlay="crew_skill"
		return
	if action.begins_with("choose:"):
		if selected_leader==action.split(":")[1]:return
		camp_previous_leader=selected_leader
		selected_leader=action.split(":")[1]
		selection_age=0.0
		return
	if action.begins_with("lock:"):
		var index=int(action.split(":")[1])
		if _commit_preparation(inventory.plan_toggle_lock(run,index)).ok:
			lock_animation[index]={"time":motion.elapsed,"locked":bool(run.shop[index].locked)}
		else:_notify("最多锁定两件商品")
		return
	if action.begins_with("replacement_target:"):
		replacement_target=action.split(":")[1]
		replacement_rotation=int(action.split(":")[2])
		return
	if action.begins_with("material_target:"):
		material_target=action.trim_prefix("material_target:")
		return
	if action.begins_with("tuning:"):
		material_choice=action.trim_prefix("tuning:")
		return
	match action:
		"battle_review":_open_battle_review()
		"history":_open_history()
		"camp_prev","camp_next":
			camp_page=1-camp_page
			selected_leader=str(C.selectable_leaders()[camp_page*3])
			selection_age=0.0
		"forge":
			dragging={};_clear_held_pose();relay_mode=false;bag_mode=false
			var kind=inventory.primary_weapon(run).get("kind","")
			if kind.is_empty() or ITEM_PANEL.INFO.recipes(kind).is_empty():kind=ITEM_PANEL.TREE.roots()[0]
			_open_item_details({"kind":kind,"rotation":0},"recipe")
			detail_parent_overlay="";ITEM_PANEL.action(self,"detail_recipes")
		"forge_base_prev","forge_base_next":
			var weapons=run.items.filter(func(v):return C.combinations.any(func(r):return FORGE.accepts_base(r,v.kind)))
			var index=weapons.map(func(v):return v.uid).find(forge_base)
			if not weapons.is_empty():forge_base=weapons[posmod(index+(1 if action.ends_with("next") else -1),weapons.size())].uid
			forge_index=0
		"forge_prev":forge_index=maxi(0,forge_index-1)
		"forge_next":forge_index+=1
		"forge_confirm":
			var choices=FORGE.options(run,forge_base,inventory)
			if choices.is_empty():return
			var target=choices[clampi(forge_index,0,choices.size()-1)].target
			var base=_piece_by_uid(forge_base)
			forge_output=inventory.make_piece(target,"forge-preview")
			for field in ["x","y","rotation"]:forge_output[field]=base[field]
			drag_offset=Vector2i.ZERO;drag_fraction=Vector2.ONE*.5
			_start_held_pose();_update_forge_projection()
			overlay="";hovered={};toast_timer=0

		"start":
			_transition()
			_clear_feedback()
			var started=_application().start(selected_leader,int(Time.get_unix_time_from_system())%2147483647,"full",run if not run.is_empty() else saved)
			if not started.ok:return
			run=started.run;opponent=started.opponent
			screen="game"
			combat={}
			bag_mode=false
			relay_mode=false
			relay_draft=[]

		"resume":
			_transition()
			_clear_feedback()
			var resumed=_application().resume(saved)
			run=resumed.run;opponent=resumed.opponent
			screen="game"
			if run.get("migrated_from",0)==2:_notify("旧行囊已换成新模块，物品可在准备区重新摆放")
			combat=run.get("combat",{})
			combat_time=float(combat.get("duration",0.0)) if run.phase in ["result","ending"] else 0.0
			_sync_recruitment()
			if game_mode=="async" and run.phase=="shop" and run.pvp.get("stage","idle")!="idle":call_deferred("_start_battle")
		"reroll":
			old_shop=run.shop.duplicate(true)
			var refresh_gold=int(run.gold)
			if _commit_preparation(inventory.plan_refresh(run,true)).ok:
				reroll_age=0.0
				if int(run.gold)<refresh_gold:_sound("purchase")
		"bag_mode":
			bag_mode=not bag_mode
			relay_mode=false
		"relay_mode","relay_done":
			relay_mode=not relay_mode
			bag_mode=false
			relay_draft=run.get("relay",[]).duplicate()
		"relay_clear":
			_commit_preparation(PREPARATION.relay(run,[],inventory.valid_relay));relay_draft=[]
			_notify("已恢复默认接力顺序")
		"claim_gifts":
			if inventory.has_method("claim_pending"):
				_commit_preparation(inventory.plan_claim_pending(run))
		"replacement_confirm":
			if _commit_preparation(inventory.plan_replace_bag(run,replacement_target,replacement_kind,replacement_rotation)).ok:
				overlay=""
				_sound("purchase")
				motion.emit("land",_board_to_screen(BOARD),GOLD)
			else:_notify("无法替换，请检查容量、连接和贝币")
		"material_next":material_page+=1
		"material_prev":material_page=maxi(0,material_page-1)
		"material_confirm":
			if inventory.apply_material(run,material_uid,material_target,material_choice):
				motion.pulse("0"+material_target)
				var target=_piece_by_uid(material_target)
				if not target.is_empty():motion.emit("fusion",_board_to_screen(_item_rect(target,BOARD).get_center()),GOLD)
				_application().checkpoint(run)
				overlay=""
				_sound("purchase")
			else:_notify("升级已满或材料与目标已改变")
		"sell_bag_confirm":
			var bag=run.bags.filter(func(i):return i.uid==material_uid)
			if not bag.is_empty() and _commit_preparation(inventory.plan_sell(run,bag[0])).ok:
				overlay=""
				_sound("sell")
			else:_notify("包袋内仍有物品")
		"catalogue_next":catalogue_page=mini(catalogue_page+1,ceili(C.items.keys().filter(func(k):return FEATURES.item_enabled(k)).size()/8.0)-1)
		"catalogue_prev":catalogue_page=maxi(0,catalogue_page-1)
		"crew":
			if RECRUITMENT.enabled(run):
				_open_crew_setup();return
			crew_tab="recruit" if int(run.round)>=2 and int(run.get("recruited_round",0))!=int(run.round) else "formation"
			crew_page=0
			overlay="crew"
		"crew_recruit":crew_tab="recruit"
		"crew_formation":crew_tab="formation"
		"crew_prev":crew_page=maxi(0,crew_page-1)
		"crew_next":crew_page+=1
		"crew_back":overlay="crew"
		"crew_original":
			crew_skill_kind="intro"
			crew_skill_page=0
			overlay="crew_original"
		"crew_original_intro":crew_skill_kind="intro";crew_skill_page=0
		"crew_original_outro":crew_skill_kind="outro";crew_skill_page=0
		"crew_text_prev":crew_skill_page=maxi(0,crew_skill_page-1)
		"crew_text_next":crew_skill_page+=1
		"crew_skill_back":overlay="crew_skill"
		"crew_swap":
			var selected=run.get("supports",[]).duplicate()
			selected.reverse()
			_commit_preparation(inventory.plan_set_supports(run,selected))
		"battle":_start_battle()
		"pause":paused=not paused
		"speed":speed=2.0 if speed==1.0 else (4.0 if speed==2.0 else 1.0)
		"skip":
			battle_entry_age=1.0
			skip_requested=true
			paused=false
			hit_pause=0.0
			combat_time=_replay_end()
		"next":
			if run.phase!="result":return
			_transition()
			_clear_feedback()
			var advanced=_application().advance(run,combat)
			if not advanced.ok and advanced.get("error","")=="history_save":_notify("记录保存失败")
			if advanced.ok and run.phase=="shop":
				opponent=advanced.opponent;combat={}
			elif advanced.ok and run.phase=="recruit":
				combat={};_sync_recruitment()

		"menu":overlay="menu"
		"catalogue":
			catalogue_page=0
			overlay="catalogue"
		"ghosts":overlay="ghosts"
		"opponent":
			if not opponent.is_empty():overlay="opponent"
		"close":overlay=""
		"home":
			if not _application().preserve_result(run):_notify("记录保存失败");return
			recruitment_view.clear();crew_setup_view.close()
			_transition()
			_clear_feedback()
			overlay=""
			screen="camp"
			camp_age=0.0;camp_previous_leader=""
			saved=storage.resume()
			_refresh_camp_saves()
			dragging={};_clear_held_pose()
		"sound":
			muted=not muted
			if is_instance_valid(audio):audio.set_muted(muted)
			_update_music()
		"quit":get_tree().quit()
		"export":
			exporting=true
			dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
			dialog.current_file=C.characters[run.leader].name+"-阵容.json"
			dialog.popup_centered(Vector2i(820,580))
		"import":
			if game_mode=="async":return
			exporting=false
			dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
			dialog.popup_centered(Vector2i(820,580))

func _start_battle() -> void:
	toast_timer=0.0
	if matching or run.phase!="shop" or run.items.is_empty() or not dragging.is_empty():
		return
	if game_mode=="async":
		var identity_error=""
		if run.pvp.stage=="idle":
			matching=true;queue_redraw()
			var identity_result=await online_client.ensure_identity()
			identity_error=str(identity_result.get("error","")) if not identity_result.ok else ""
			matching=false
			var owner_id=str(online_client.config.get("player_id","")) if identity_error.is_empty() and online_client.ready_for_online() else "guest-"+ASYNC_PROTOCOL.digest(storage.owner.to_utf8_buffer()).left(24)
			if not _application().prepare_match(run,owner_id).ok:_notify("进度保存失败，请重试");return
		# Requeue the same frozen bytes after restart; duplicate uploads are verified.
		var requires_queue=online_client.ready_for_online() and run.pvp.player_id==online_client.config.player_id
		if requires_queue and not online_client.enqueue(run):_notify("阵容暂存失败，请重试");return
		if run.pvp.stage=="pending":
			matching=true;queue_redraw()
			var selected=await online_client.find_opponent(inventory,run.duplicate(true)) if identity_error.is_empty() else {"ok":false,"error":identity_error}
			matching=false
			var enemy=selected.opponent if selected.ok else inventory.practice(int(run.round),int(run.seed)%31,str(run.get("pool_mode","full")),int(run.get("supply_version",0)))
			if not _application().lock_opponent(run,enemy,"player" if selected.ok else "bot",str(selected.get("error",""))).ok:_notify("对战保存失败，请重试");return
			opponent=run.opponent.duplicate(true)
		else:opponent=run.opponent.duplicate(true)
	var preparation_pose=_board_transform()
	_clear_feedback()
	battle_entry_from=preparation_pose;battle_entry_age=0.0
	transition_image=null;motion.transition_left=0.0
	relay_mode=false
	bag_mode=false
	var started=_application().begin(run,opponent)
	if not started.ok:return
	_sound("start")
	combat=started.combat;opponent=started.opponent
	combat_time=0.0
	for side in range(2):_rig_trigger(side,"ready",0)
	paused=false
	event_cursor=0
	flashes={}


func _replay_end() -> float:
	var end_time=float(combat.get("duration",0.0))
	for event in combat.get("events",[]):
		end_time=maxf(end_time,float(event.time)+.65)
	return end_time

func _current_frame() -> Dictionary:
	if combat.is_empty():return {}
	if review.active:return BATTLE_REVIEW.frame_at(combat,review.time)
	var index=mini(int(floor(combat_time/.1)),combat.frames.size()-1)
	return combat.frames[maxi(index,0)]

func _showing_battle()->bool:
	return run.get("phase","")=="battle" or review.active

func _open_history()->void:
	if review.active or not dragging.is_empty() or run.get("phase","")=="battle":return
	var current=run if screen=="game" else saved
	if not storage.archive_completed(current):_notify("记录保存失败");return
	history_rows=storage.battle_history(current);history_page=0;history_selected=0
	_history_select(0)
	history_parent_overlay=overlay;overlay="history";hovered={}
	motion.modal_value=1;motion.modal_target=1

func _history_select(index:int)->void:
	history_selected=clampi(index,0,maxi(0,history_rows.size()-1));history_record={}
	if history_rows.is_empty():return
	var row=history_rows[history_selected]
	if row.get("replayable",false):history_record=storage.battle_record(row.id)

func _draw_history_board(build:Dictionary,rect:Rect2)->void:
	# Draw the frozen layout at its real coordinates, independent of live motion.
	var saved_basis=draw_basis
	var scale=minf(rect.size.x/(I.WIDTH*CELL),rect.size.y/(I.HEIGHT*CELL))
	var extent=Vector2(I.WIDTH,I.HEIGHT)*CELL*scale
	_basis(saved_basis*Transform2D(0,Vector2.ONE*scale,0,rect.get_center()-extent*.5))
	TERMINAL.placement_grid(self,Vector2.ZERO,Vector2i(I.WIDTH,I.HEIGHT),CELL)
	TERMINAL.surface(self,Vector2.ZERO,build.get("bags",[]),CELL,"",1,{})
	for item in build.get("items",[]):
		if not _ensure_icon(item.kind):continue
		var at=Vector2(item.x,item.y)*CELL
		var fitted=_projection_for(item.kind,int(item.rotation),CELL)
		var full_art=bool(C.items[item.kind].get("combat_v15",false))
		if full_art or C.is_tag(item.kind,"echo"):
			ITEM_SHADOW.draw(self,icons[item.kind],Transform2D(0,at)*Transform2D(fitted.transform),draw_basis,fitted.bounds.size,1,0)
		if full_art:
			draw_set_transform_matrix(draw_basis*Transform2D(0,at)*Transform2D(fitted.transform))
			draw_texture(icons[item.kind],Vector2.ZERO)
		else:PROJECTION.draw(self,icons[item.kind],inventory.cells(item),at,CELL,fitted,Color.WHITE)
		draw_set_transform_matrix(draw_basis)
	_basis(saved_basis)

func _history_action(action:String)->void:
	if action.is_empty():return
	if action.begins_with("select:"):
		_history_select(int(action.trim_prefix("select:")));return
	match action:
		"close":
			overlay=history_parent_overlay;history_buttons=[];motion.modal_value=0;motion.modal_target=0
		"previous":
			history_page=maxi(0,history_page-1);_history_select(history_page*HISTORY_VIEW.PAGE_SIZE)
		"next":
			history_page=mini(maxi(0,ceili(history_rows.size()/float(HISTORY_VIEW.PAGE_SIZE))-1),history_page+1);_history_select(history_page*HISTORY_VIEW.PAGE_SIZE)
		"replay":
			if history_rows.is_empty():return
			var row=history_rows[history_selected]
			if not row.get("replayable",false):return
			if history_record.is_empty():_notify("这条回放暂时无法读取");return
			_open_archived_battle(history_record)

func _open_archived_battle(evidence:Dictionary)->void:
	if not history_return.is_empty():return
	history_return={"run":run,"opponent":opponent,"combat":combat,"screen":screen,"combat_time":combat_time,"battle_entry_age":battle_entry_age,"paused":paused,"event_cursor":event_cursor}
	run=evidence.builds[0].duplicate(true);run.phase="result"
	for key in ["gold","wins","losses"]:
		if not run.has(key):run[key]=0
	opponent=evidence.builds[1].duplicate(true);combat=evidence.combat.duplicate(true)
	screen="game";battle_entry_age=1;paused=true;transition_image=null;motion.transition_left=0
	_open_battle_review()
	if not review.active:_close_archived_battle()
	else:
		motion.modal_value=0;motion.modal_target=0
		_review_action("play")

func _close_archived_battle()->void:
	review.close();review_buttons=[];review_scrubbing=false;review_resume_after_scrub=false;review_tail=0;_clear_feedback()
	if is_instance_valid(audio):audio.stop_all()
	run=history_return.run;opponent=history_return.opponent;combat=history_return.combat;screen=history_return.screen
	combat_time=history_return.combat_time;battle_entry_age=history_return.battle_entry_age;paused=history_return.paused;event_cursor=history_return.event_cursor
	history_return={};overlay="history";motion.modal_value=1;motion.modal_target=1

func _open_battle_review()->void:
	if screen!="game" or run.get("phase","") not in ["result","ending"]:return
	if not review.open(combat,[run,opponent]):return
	overlay="";review_panel=true;review_side=0;review_metric="damage";review_focus=""
	review_all_events=true;review_timeline_side=-1;review_item_page=0;review_event_offset=0
	review_selected_event=-1;review_scrubbing=false;review_resume_after_scrub=false
	review_markers=[]
	for event in review.record.events:
		if event.kind in ["star_trigger","combo_ready"]:review_markers.append(float(event.time))
	_clear_feedback();combat_time=review.time;review_pose_time=review.time;review_tail=0
	_review_refresh_events()

func _review_refresh_events()->void:
	review_timeline=BATTLE_REVIEW.timeline(review.record,review.builds,review_side if not review_focus.is_empty() else review_timeline_side,review_focus)
	review_event_offset=clampi(review_event_offset,0,maxi(0,review_timeline.size()-REVIEW_VIEW.EVENT_COUNT))

func _review_seek(at:float)->void:
	review.seek(at);combat_time=review.time;review_pose_time=review.time;review_tail=0;_clear_feedback()
	if is_instance_valid(audio):audio.stop_all()

func _review_snapshot()->Dictionary:
	var transport={"panel":review_panel,"mouse":mouse,"time":review.time,"duration":review.duration,
		"speed":review.speed,"playing":review.playing,"markers":review_markers}
	# On-field replay never needs to aggregate the entire event log each frame.
	if not review_panel:return transport
	var rows=BATTLE_REVIEW.rows(review.record,review.builds,review_side,review.time)
	rows.sort_custom(func(a,b):return float(a[review_metric])>float(b[review_metric]) if not is_equal_approx(float(a[review_metric]),float(b[review_metric])) else a.uid<b.uid)
	var focus=rows.filter(func(r):return r.uid==review_focus)
	var totals={"damage":[0.0,0.0],"heal":[0.0,0.0],"shield":[0.0,0.0]}
	for side in 2:
		for row in BATTLE_REVIEW.rows(review.record,review.builds,side,review.time):
			for key in totals:totals[key][side]+=float(row[key])
	transport.merge({"side":review_side,"metric":review_metric,"focus":review_focus,
		"all_events":review_all_events,"timeline_side":review_timeline_side,"item_page":review_item_page,
		"event_offset":review_event_offset,"selected_event":review_selected_event,"rows":rows,
		"focus_row":focus[0] if not focus.is_empty() else {},"events":review_timeline,
		"leader":C.characters[review.builds[review_side].leader].name,"round":run.round,"mouse":mouse,
		"absorbed":BATTLE_FEEDBACK.absorption(review.record.events,review_side,review.time),
		"damage":totals.damage,"heal":totals.heal,"shield":totals.shield})
	return transport

func _review_action(action:String)->void:
	if not review.active:return
	if action.begins_with("side:"):
		review_side=int(action.trim_prefix("side:"));review_focus="";review_all_events=true
		if review_timeline_side>=0:review_timeline_side=review_side
		review_item_page=0;review_event_offset=0;_review_refresh_events();return
	if action.begins_with("metric:"):
		review_metric=action.trim_prefix("metric:");review_item_page=0;return
	if action.begins_with("item:"):
		var uid=action.trim_prefix("item:")
		review_focus="" if review_focus==uid else uid;review_all_events=review_focus.is_empty()
		review_event_offset=0;_review_refresh_events();return
	if action.begins_with("event:"):
		review_selected_event=int(action.trim_prefix("event:"))
		if review_selected_event>=0 and review_selected_event<review.record.events.size():_review_seek(float(review.record.events[review_selected_event].time))
		return
	match action:
		"close":
			if not history_return.is_empty():_close_archived_battle();return
			review.close();review_buttons=[];review_scrubbing=false;review_resume_after_scrub=false;review_tail=0
			_clear_feedback();combat_time=_replay_end()
			if is_instance_valid(audio):audio.stop_all()
		"play":
			if review.playing:review.playing=false;review_tail=0
			else:
				if review.time>=review.duration:_clear_feedback()
				review.play();combat_time=review.time;review_pose_time=review.time;review_tail=0;review_panel=false
		"panel":
			review_panel=not review_panel;review.playing=false;review_tail=0
			review_selected_event=-1
			if review_panel:
				for n in review_timeline.size():
					if float(review_timeline[n].time)<=review.time+.00001:review_event_offset=maxi(0,n-REVIEW_VIEW.EVENT_COUNT+1)
		"speed":
			var rates=[.5,1.0,2.0,4.0]
			review.speed=rates[(rates.find(review.speed)+1)%rates.size()]
		"step_back","step_next":
			review.step(-1 if action=="step_back" else 1);_review_seek(review.time)
		"all_events":
			review_focus="";review_all_events=true;review_event_offset=0;_review_refresh_events()
		"both":
			review_focus="";review_all_events=true;review_timeline_side=-1;review_event_offset=0;_review_refresh_events()
		"one_side":
			review_timeline_side=review_side;review_event_offset=0;_review_refresh_events()
		"items_prev":review_item_page=maxi(0,review_item_page-1)
		"items_next":
			var count=BATTLE_REVIEW.rows(review.record,review.builds,review_side,review.time).size()
			review_item_page=mini(maxi(0,ceili(count/float(REVIEW_VIEW.ROW_COUNT))-1),review_item_page+1)
		"events_prev":review_event_offset=maxi(0,review_event_offset-REVIEW_VIEW.EVENT_COUNT)
		"events_next":review_event_offset=mini(maxi(0,review_timeline.size()-REVIEW_VIEW.EVENT_COUNT),review_event_offset+REVIEW_VIEW.EVENT_COUNT)

func _review_input(event:InputEvent)->void:
	if event is InputEventMouseMotion:
		mouse=event.position
		if review_scrubbing:_review_seek((mouse.x-REVIEW_VIEW.TRACK.position.x)/REVIEW_VIEW.TRACK.size.x*review.duration)
	elif event is InputEventMouseButton:
		mouse=event.position
		if event.button_index==MOUSE_BUTTON_LEFT:
			if not event.pressed:
				if review_scrubbing and review_resume_after_scrub and review.time<review.duration:review.play()
				review_scrubbing=false;review_resume_after_scrub=false;return
			if REVIEW_VIEW.TRACK.grow(8).has_point(mouse):
				review_resume_after_scrub=review.playing
				review_scrubbing=true;_review_seek((mouse.x-REVIEW_VIEW.TRACK.position.x)/REVIEW_VIEW.TRACK.size.x*review.duration);return
			var action=REVIEW_VIEW.hit(review_buttons,mouse)
			if not action.is_empty():_sound("click");_review_action(action)
		elif event.pressed and review_panel and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var direction=1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1
			if REVIEW_VIEW.EVENTS.has_point(mouse):review_event_offset=clampi(review_event_offset+direction*3,0,maxi(0,review_timeline.size()-REVIEW_VIEW.EVENT_COUNT))
			elif REVIEW_VIEW.ITEMS.has_point(mouse):_review_action("items_next" if direction>0 else "items_prev")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:_review_action("close")
			KEY_SPACE:_review_action("play")
			KEY_LEFT:_review_action("step_back")
			KEY_RIGHT:_review_action("step_next")
			KEY_F:_review_action("speed")

func _vitals_frame() -> Dictionary:
	if combat.is_empty():return {}
	if review.active:return BATTLE_REVIEW.frame_at(combat,review.time)
	var display_time=combat_time if run.phase!="battle" or skip_requested else maxf(0,combat_time-COMBAT_VFX.TRAVEL)
	var index=clampi(floori((display_time+.00001)/.1),0,combat.frames.size()-1)
	return combat.frames[index]

func _play_event(event: Dictionary) -> void:
	if event.kind=="fatigue":return
	if event.kind=="cooldown_advance" and _advance_seconds(event)<=0:return
	if event.kind in ["heal","intro_heal","shield","dot"] and not event.get("arrived",false):
		pending_impacts.append({"delay":COMBAT_VFX.TRAVEL,"event":event.duplicate(true)})
		return
	var side=int(event.side)
	if event.kind not in ["dot","noise_tick"]:flashes[str(side)+event.uid]=1.0
	var center=_actor_center(side)
	var build=run if side==0 else opponent
	var origin=BOARD if side==0 else ENEMY_BOARD
	if event.kind=="crew_trigger":
		var index=build.get("supports",[]).find(str(event.get("role_id","")))
		if index>=0:motion.emit("trigger",_battle_crew_center(side,index),GOLD)
		return
	for item in build.items:
		if item.uid==event.uid and event.kind=="trigger":
			if C.is_tag(item.kind,"weapon") or C.is_tag(item.kind,"echo"):item_sways[str(side)+item.uid]=.38
			motion.pulse(str(side)+item.uid)
			var from=_board_to_screen(_item_rect(item,origin).get_center(),side)
			motion.emit("trigger",from,C.tint(item.kind))
			break
	if event.kind=="star_trigger":
		star_activations.record(event)
		var addresses={str(event.get("source_uid","")):true,str(event.get("trigger_uid","")):true}
		if not str(event.get("beneficiary_uid","")).is_empty():addresses[str(event.beneficiary_uid)]=true
		for uid in addresses:
			motion.pulse(str(side)+uid)
			motion.emit("trigger",_battle_item_position(side,uid),GOLD)
		_sound("star")
		return
	match event.kind:
		"combo_ready":
			motion.pulse(str(side)+str(event.uid))
			motion.emit("shield" if event.get("effect","")=="counter" else "trigger",_battle_item_position(side,str(event.uid)),Color("a6e4ef") if event.get("effect","")=="counter" else Color("aff1d1"))
		"intro","outro":
			var role_id=str(event.get("role_id",""))
			var rig_leader=_rig_leader_for_role(role_id)
			if not SKIN.is_chibi() and not rig_leader.is_empty() and event.kind=="intro" and native_rigs_enabled:
				var view=_get_portrait_rig(_support_rig_slot(side,rig_leader),rig_leader)
				view.rig.trigger("intro",combat_time)
			if C.roster.has(role_id):
				support_flights.append({"side":side,"role_id":role_id,"carrier_uid":str(event.get("carrier_uid","")),"kind":event.kind,"life":.95})
				motion.emit("burst",center+Vector2(-96 if side==0 else 96,-48),C.ELEMENTS.get(C.roster[role_id].element,GOLD))
				burst_text=("变奏 · " if event.kind=="intro" else "延奏 · ")+C.roster[role_id].name+" · "+event.label
				burst_timer=.8
				if support_flights.size()>4:support_flights.pop_front()
		"intro_attack":
			_sound("attack",_event_weapon(event))
			projectiles.append({"side":side,"from":_battle_item_position(side,str(event.uid)),"life":COMBAT_VFX.TRAVEL,"color":_impact_color(event),"weapon":_event_weapon(event),"strong":bool(event.get("charged",false)) or bool(event.get("prepared",false)) or event.kind in ["counter","heavy_hit"]})
			pending_impacts.append({"delay":COMBAT_VFX.TRAVEL,"event":event.duplicate(true)})
		"dot","noise_tick":
			var grouped=floats.filter(func(v):return v.get("kind","")=="dot" and v.side==1-side and float(v.life)>.7)
			if not grouped.is_empty():
				grouped[0].amount+=float(event.value);grouped[0].label="-%.1f"%grouped[0].amount
			else:
				floats.append({"kind":"dot","amount":float(event.value),"label":"-%.1f"%float(event.value),"position":_float_position(1-side),"side":1-side,"life":.8,"color":Color("a7c9a0")})
		"coordinated":
			if event.has("trigger_uid"):
				chase_cues.append({"life":.18,"event":event.duplicate(true)})
			else:_launch_chase(event)
		"cooldown_advance":
			advance_cues.append({"life":.18+COMBAT_VFX.TRAVEL,"event":event.duplicate(true)})
		"attack","relay_attack","copy","extra","counter","heavy_hit","noise_consume","derived","frost_hit":
			if event.kind!="derived":
				if build.items.any(func(p):return p.uid==str(event.uid) and C.is_tag(p.kind,"weapon")):_rig_trigger(side,"attack",float(event.time))
				attack_left[side]=.48;lunge[side]=1.0
			else:motion.pulse(str(side)+str(event.uid))
			projectiles.append({"side":side,"from":_battle_item_position(side,str(event.uid)),"life":COMBAT_VFX.TRAVEL,"color":_impact_color(event),"weapon":_event_weapon(event),"strong":bool(event.get("charged",false)) or bool(event.get("prepared",false)) or event.kind in ["counter","heavy_hit"]})
			pending_impacts.append({"delay":COMBAT_VFX.TRAVEL,"event":event.duplicate(true)})
			_sound("attack",_event_weapon(event))
		"heal","intro_heal":
			if event.value>0:
				_sound("heal")
				motion.emit("heal",center+Vector2(0,64),Color("7ab68b"))
				floats.append({"label":"+"+str(int(event.value)),"position":_float_position(side,"heal"),"kind":"heal","side":side,"life":1.1,"color":Color("76cb8c")})
		"shield":
			if event.value>0:
				motion.emit("shield",Q_BATTLE.shield_rect(side).get_center() if SKIN.is_chibi() else center+Vector2(0,34),Color("9dcdd5"))
				floats.append({"label":"◇"+str(int(event.value)),"position":_float_position(side,"shield"),"kind":"shield","side":side,"life":1.1,"color":Color("9bdbe1")})
		"relay":
			var part_names=event.label.split(" · ")[-1].split(" → ")
			var segment=int(event.get("segment",0))
			var part_name=part_names[mini(segment,part_names.size()-1)]
			for item in build.items:
				if item.uid==event.uid:
					motion.pulse(str(side)+item.uid)
					motion.emit("trigger",_board_to_screen(_item_rect(item,origin).get_center(),side),GOLD)
					part_name=C.items[item.kind].name
					break
			var roles=["武器","声骸","联动"]
			burst_text=roles[mini(segment,2)]+" · "+part_name
			if event.get("leader_outro",false):motion.emit("burst",center+Vector2(0,40),GOLD)
			burst_timer=.65
		"content_buff","tide","delay","weaken":
			for item in build.items:
				if item.uid==event.uid:
					motion.pulse(str(side)+item.uid)
					motion.emit("trigger",_board_to_screen(_item_rect(item,origin).get_center(),side),GOLD)
					break
			if event.kind=="tide":burst_text="焚潮";burst_timer=.65
		"supply":
			for item in build.items:
				if item.uid==event.uid:
					motion.emit("heal",_board_to_screen(_item_rect(item,origin).get_center(),side),Color("9bcea5"))
					break
		"burst":
			_rig_trigger(side,"intro",float(event.time))
			motion.emit("burst",center+Vector2(0,40),C.ELEMENTS[C.characters[build.leader].element])
			burst_text=event.label
			burst_timer=.85
			attack_left[side]=.48
			hit_pause=.085
			lunge[side]=1.3
	if floats.size()>16:floats.pop_front()
	if projectiles.size()>12:projectiles.pop_front()
	if gear_flights.size()>12:gear_flights.pop_front()
	if pending_impacts.size()>16:pending_impacts.pop_front()

func _event_weapon(event:Dictionary)->String:
	var build=run if int(event.side)==0 else opponent
	for item in build.items:
		if item.uid==event.get("uid",""):
			return "echo" if C.is_tag(item.kind,"echo") else str(C.items[item.kind].get("weapon_type","rectifier"))
	return "rectifier"

func _impact_cue(event:Dictionary) -> String:
	if event.kind=="counter":return "反击"
	if event.get("charged",false) or event.kind=="heavy_hit":return "重击"
	if event.get("prepared",false):return "强化"
	return "追击" if event.kind=="derived" else ""

func _impact_color(event:Dictionary) -> Color:
	if event.kind=="counter":return Color("9ce4ed")
	if event.kind=="derived":return Color("bca9e3")
	return C.ELEMENTS.get(event.get("element","neutral"),GOLD)

func _apply_impact(event: Dictionary) -> void:
	if event.kind in ["heal","intro_heal","shield","dot"]:
		var arrived=event.duplicate(true);arrived["arrived"]=true;_play_event(arrived);return
	var side=int(event.side)
	_rig_trigger(1-side,"hit",_portrait_clock())
	var victim=_actor_center(1-side)
	motion.hit[1-side]=.22
	var weapon_type=_event_weapon(event)
	if float(event.value)>0:
		combat_vfx.spawn(victim+Vector2(0,-20),side,weapon_type,_impact_color(event),event.get("critical",false) or event.get("charged",false) or event.get("prepared",false) or event.kind in ["heavy_hit","noise_consume","counter"])
	if (event.get("critical",false) or event.get("charged",false) or event.get("prepared",false) or event.kind in ["relay_attack","heavy_hit","noise_consume"]) and hit_pause_cooldown<=0:
		hit_pause=.055
		hit_pause_cooldown=.22
	var pos=_float_position(1-side,"burst" if not _impact_cue(event).is_empty() else "damage")
	floats.append({"cue":_impact_cue(event),"label":"-"+str(int(event.value))+("!" if event.get("critical",false) else ""),"position":pos,"side":1-side,"life":1.1,"color":_impact_color(event).lightened(.3),"big":event.get("critical",false) or event.get("charged",false) or event.get("prepared",false) or event.kind in ["heavy_hit","noise_consume","counter"]})
	if floats.size()>16:floats.pop_front()

func _float_position(side:int,kind:String="damage") -> Vector2:
	var center=_actor_center(side)
	var recovery=kind in ["heal","shield"]
	var direction=1 if side==0 else -1
	var base=center+Vector2((104 if not recovery else -144)*direction,-27)
	if side==1:base.x-=29
	base.x=clampf(base.x,40,1300)
	var offsets=[0.0,48.0,-48.0,96.0]
	for column in 2:
		for offset in offsets:
			var candidate=base+Vector2(column*112*direction*(-1 if recovery else 1),offset)
			candidate.x=clampf(candidate.x,40,1300)
			var occupied=false
			for value in floats:
				if value.life<.12:continue
				var at=_floating_position(value)
				var gap=64 if kind=="burst" or not str(value.get("cue","")).is_empty() else 36
				if absf(at.x-candidate.x)<100 and absf(at.y-candidate.y)<gap:occupied=true;break
			if not occupied:return candidate
	# Bounded overflow: replace labels crossing this lane instead of stacking or
	# sending new numbers up into the HUD. Simulation and totals are untouched.
	floats=floats.filter(func(value):return absf(_floating_position(value).x-base.x)>=100 or absf(_floating_position(value).y-base.y)>=(64 if kind=="burst" or not str(value.get("cue","")).is_empty() else 36))
	return base

func _floating_position(value:Dictionary)->Vector2:
	var t=maxf(0,1.1-float(value.life))
	return value.position+Vector2(0,-36*t)

func _file_selected(path: String) -> void:
	if exporting:
		if _application().export_build(run,path):
			_notify("影像已导出")
		else:
			_notify("导出失败，请换个位置")
	else:
		var imported=_application().import_opponent(run,path)
		if imported.status=="invalid":
			_notify("这份影像无效或无法读取")
		elif imported.status=="inactive":
			_notify("装备待重排，暂不参与对战")
		elif imported.status=="version":
			_notify("影像版本不同")
		elif imported.status=="round":
			_notify("影像轮次相差过大，最多相差一轮")
		else:
			opponent=imported.opponent
			_notify("已换为导入影像")
	overlay=""
	_application().checkpoint(run)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if not history_return.is_empty():_close_archived_battle()
		if not run.is_empty():_application().checkpoint(run)
		get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(audio):audio.stop_all()
	if is_instance_valid(music):music.stop_all()

func _update_music()->void:
	if not is_instance_valid(music):return
	var phase=str(run.get("phase","shop")) if screen=="game" else "camp"
	if phase=="recruit":phase="shop"
	music.set_context(phase,muted,phase=="battle" and (paused or _blocking_overlay()))

func _notify(message: String) -> void:
	toast=message
	toast_timer=2.5

func _sound(key: String,weapon:String="") -> void:
	if not is_instance_valid(audio):return
	audio.set_muted(muted)
	audio.play_event("drop" if key=="collect" else key,weapon)

func _stop_fusion_audio()->void:
	if is_instance_valid(audio):audio.stop_fusion()

func audio_diagnostics()->Dictionary:
	return audio.diagnostics() if is_instance_valid(audio) else {}

func _basis(value: Transform2D=Transform2D.IDENTITY) -> void:
	draw_basis=value
	draw_set_transform_matrix(value)

func _board_transform(side: int=0) -> Transform2D:
	var logical=BOARD if side==0 else ENEMY_BOARD
	var shop=run.get("phase","")=="shop"
	# The complete placement domain owns the coordinate system, never its contents.
	# Bag moves, rotation and capacity changes cannot translate or scale this pose.
	if shop:
		var pitch=QL.PITCH if SKIN.is_chibi() else PREPARATION_PITCH
		var origin=QL.ORIGIN if SKIN.is_chibi() else PREPARATION_ORIGIN
		return Transform2D(0,Vector2.ONE*(pitch/CELL),0,origin-logical*(pitch/CELL))
	var area=Q_BATTLE.BOARDS[side] if SKIN.is_chibi() else Rect2(116 if side==0 else 796,390,528,396)
	var scale_value=minf(area.size.x/I.WIDTH,area.size.y/I.HEIGHT)/CELL
	var center=area.get_center()
	var target=center-Vector2(I.WIDTH,I.HEIGHT)*CELL*scale_value*.5
	var pose=Transform2D(0.0,Vector2.ONE*scale_value,0.0,target-logical*scale_value)
	if not shop and battle_entry_age<1.0:
		if side==0:pose=battle_entry_from.interpolate_with(pose,smoothstep(.2,.65,battle_entry_age))
		else:pose.origin.x+=690*(1-smoothstep(.65,1.0,battle_entry_age))
	return pose

func _board_to_screen(pos: Vector2,side: int=0) -> Vector2:
	return _board_transform(side)*pos

func _board_screen_rect(side: int=0) -> Rect2:
	# The faint visible lattice and pointer acceptance share the complete domain.
	if run.get("phase","")=="shop":return QL.BOARD if SKIN.is_chibi() else Rect2(PREPARATION_ORIGIN,Vector2(I.WIDTH,I.HEIGHT)*PREPARATION_PITCH)
	var origin=BOARD if side==0 else ENEMY_BOARD
	var pose=_board_transform(side)
	return Rect2(pose*origin,Vector2(I.WIDTH,I.HEIGHT)*CELL*pose.get_scale())

func _board_cell(pos: Vector2,side: int=0) -> Vector2i:
	var logical=_board_transform(side).affine_inverse()*pos
	var origin=BOARD if side==0 else ENEMY_BOARD
	return Vector2i(floori((logical.x-origin.x)/CELL),floori((logical.y-origin.y)/CELL))

func _wallet_position() -> Vector2:
	return Vector2(1108,51) if SKIN.is_chibi() else Vector2(1053,49)

func _stash_mat_rect() -> Rect2:
	return QL.STASH if SKIN.is_chibi() else Rect2(335,772,650,72)

func _sell_rect() -> Rect2:
	return QL.SELL if SKIN.is_chibi() else Rect2(559,853,66,58)

func _actor_center(side: int) -> Vector2:
	return Q_BATTLE.center(side) if SKIN.is_chibi() else Vector2(126 if side==0 else 1314,287)

func _draw_prep_host() -> void:
	var leader=C.characters[run.leader]
	if SKIN.is_chibi():
		_draw_character(run.leader,_prep_actor_rect(),false)
		T.surface(self,QL.NAME,"button_primary")
		_text(leader.name,QL.NAME.position+Vector2(47,29),23,SKIN.LIGHT)
		_star(QL.NAME.position+Vector2(17,21),15,SKIN.HONEY,true)
		return
	_text(leader.name,Vector2(60,169),33,CREAM)
	_text(_element_label(leader.element),Vector2(62,203),16,C.ELEMENTS[leader.element].darkened(.35) if SKIN.is_chibi() else C.ELEMENTS[leader.element].lightened(.25))
	var pose=_prep_actor_rect()
	_draw_character(run.leader,pose,false)
	T.rule(self,Vector2(60,693),Vector2(258,693),.22)

func _weapon_label(value: String) -> String:
	return {"broadblade":"长刃","sword":"迅刀","pistol":"佩枪","gauntlet":"臂铠","rectifier":"音感仪"}.get(value,value)

func _crew_portrait(role_id: String,center: Vector2,radius: float,alpha: float=1.0) -> void:
	if SKIN.is_chibi():
		if role_id.is_empty():
			T.surface(self,Rect2(center+paint_offset-Vector2.ONE*radius,Vector2.ONE*radius*2),"portrait_frame",alpha*paint_alpha)
			_text("+",center+Vector2(-9,9),28,SKIN.BLUEBERRY)
		else:_chibi_portrait(role_id,Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),alpha,true)
		return
	if not role_id.is_empty():
		var texture=_ensure_portrait(role_id)
		if crew_portraits.size()>12:crew_portraits.erase(crew_portraits.keys()[0])
		if texture:crew_portraits[role_id]=texture
	draw_circle(center+paint_offset,radius+3,Color(T.tone(T.SHELL),alpha*paint_alpha))
	if crew_portraits.has(role_id):
		var points=PackedVector2Array()
		var uv=PackedVector2Array()
		for n in range(40):
			var direction=Vector2.from_angle(n*TAU/40.0)
			points.append(center+direction*radius+paint_offset)
			uv.append(Vector2.ONE*.5+direction*.5)
		draw_polygon(points,PackedColorArray([Color(1,1,1,alpha*paint_alpha)]),uv,crew_portraits[role_id])
	else:
		_text("+",center+Vector2(-9,9),28,Color(CREAM,alpha))
	draw_arc(center+paint_offset,radius+3,-PI*.8,PI*.65,44,Color(T.tone(T.BRASS),alpha*paint_alpha),1.5,true)

func _draw_crew_slots() -> void:
	if RECRUITMENT.enabled(run):
		_draw_recruitment_slots();return
	var selected=run.get("supports",[])
	for n in range(2):
		var center=QL.crew_center(n) if SKIN.is_chibi() else Vector2(102+n*99,749)
		var role_id=str(selected[n]) if n<selected.size() else ""
		_crew_portrait(role_id,center,36 if SKIN.is_chibi() else 25)
		if SKIN.is_chibi():
			var h=motion.hover("crew-slot:"+str(n),Rect2(center-Vector2.ONE*40,Vector2.ONE*80).has_point(mouse))
			if h>.01:draw_arc(center,39,0,TAU,48,Color(SKIN.HONEY,h*.8),2,true)
		_button(Rect2(center-Vector2.ONE*(40 if SKIN.is_chibi() else 31),Vector2.ONE*(80 if SKIN.is_chibi() else 62)),"","crew",true,false)
		if not role_id.is_empty() and C.roster.has(role_id):
			var ready=preload("res://scripts/party/crew_abilities.gd").ready(role_id,run)
			draw_circle(center+Vector2(22,20),3,GREEN if ready else T.tone(T.ALERT))
			_text(C.roster[role_id].name.substr(0,4),center+Vector2(-31,50),15,T.tone(T.DARK))
	_button(QL.RECRUIT if SKIN.is_chibi() else Rect2(59,852,202,45),"招募","crew",run.phase=="shop")

func _sync_recruitment()->void:
	if screen!="game" or run.get("phase","")!="recruit" or recruitment_view.active or font==null:return
	overlay="";dragging={};drag_pressed=false;hovered={};forge_output={}
	transition_image=null;motion.transition_left=0;motion.modal_value=0
	crew_setup_view.close();recruitment_view.open(RECRUITMENT_PRESENTER.draft(inventory,run),font,body_font)

func _recruitment_intent(intent:Dictionary)->void:
	match intent.get("kind",""):
		"click":_sound("click")
		"confirm":
			var result=_application().confirm_recruit(run,intent.role_id,intent.get("reward",""))
			if result.ok:
				opponent=result.get("opponent",{})
				recruitment_arrival_ability=RECRUITMENT.profile(intent.role_id,run).get("ability_id","")
				recruitment_view.confirm_fact();_sound("fusion_land")
				phase_age=0;reroll_age=0;combat={};forge_cache_key=""

func _open_crew_setup(preferred:String="")->void:
	if run.get("phase","")!="shop" or not dragging.is_empty():return
	overlay="";hovered={};transition_image=null;motion.transition_left=0;motion.modal_value=0
	if not preferred.is_empty():crew_setup_view.tab=preferred
	crew_setup_view.open(RECRUITMENT_PRESENTER.setup(inventory,run),font,body_font)

func _crew_setup_intent(intent:Dictionary)->void:
	match intent.get("kind",""):
		"click":_sound("click")
		"close":crew_setup_view.close();_sound("click")
		"configure":
			var before_gold=int(run.gold)
			var result=_application().configure_crew(run,intent.config)
			if result.ok:
				_sound("purchase" if int(run.gold)<before_gold else "drop")
				forge_cache_key=""
				if intent.config.has("supply"):
					crew_setup_view.close();reroll_age=0
				else:crew_setup_view.refresh(RECRUITMENT_PRESENTER.setup(inventory,run))
			else:crew_setup_view.rejection=.8

func _draw_recruitment_slots()->void:
	var team=run.get("supports",[])
	var pending=run.get("recruitment",{}).get("return_pending",[]).size()>0 or not str(run.get("recruitment",{}).get("star_pending","")).is_empty()
	for n in 2:
		var center=QL.crew_center(n)
		var role=str(team[n]) if n<team.size() else ""
		_crew_portrait(role,center,36)
		var rect=Rect2(center-Vector2.ONE*40,Vector2.ONE*80)
		if rect.has_point(mouse):draw_arc(center,39,0,TAU,48,Color(SKIN.HONEY,.75),2,true)
		_button(rect,"","crew",true,false)
		if not role.is_empty():
			RECRUITMENT_ART.emblem(self,RECRUITMENT.profile(role,run).get("icon_id",RECRUITMENT.profile(role,run).get("ability_id","")),Rect2(center+Vector2(14,14),Vector2.ONE*29))
			_text(C.roster[role].name,center+Vector2(-31,56),14,SKIN.PLUM)
		else:_text(str(3+n*3),center+Vector2(22,32),14,SKIN.HONEY)
	_button(QL.RECRUIT,"队伍","crew",run.phase=="shop")
	if pending:
		var at=QL.RECRUIT.end+Vector2(-12,-QL.RECRUIT.size.y+7)
		draw_circle(at,6+sin(age*4),SKIN.HONEY)

func _crew_status(role_id: String) -> String:
	var abilities=preload("res://scripts/party/crew_abilities.gd")
	return "已有组合 · "+abilities.profile(role_id).name if abilities.ready(role_id,run) else "暂无搭配"

func _battle_crew_center(side:int,index:int)->Vector2:
	return Vector2((170 if side==0 else 1206)+index*64,351)

func _draw_battle_crew(side:int,build:Dictionary)->void:
	var abilities=preload("res://scripts/party/crew_abilities.gd")
	for n in build.get("supports",[]).size():
		var role=str(build.supports[n]);var power=float(flashes.get(str(side)+"crew:"+role,0))
		var center=_battle_crew_center(side,n)+Vector2(0,-power*4)
		if power>0:draw_circle(center,28+power*4,Color(GOLD,.25*power))
		_crew_portrait(role,center,23*(1+power*.08))
		if RECRUITMENT.enabled(build):RECRUITMENT_ART.emblem(self,RECRUITMENT.profile(role,build).get("icon_id",RECRUITMENT.profile(role,build).get("ability_id","")),Rect2(center+Vector2(11,8),Vector2.ONE*24))
		else:ABILITY_ICONS.draw(self,abilities.profile(role).get("icon","charge"),Rect2(center+Vector2(11,8),Vector2.ONE*22))
		_text(C.roster[role].name.substr(0,4),center+Vector2(-25,42),12,SKIN.LIGHT)

func _draw_crew_bust(role_id: String,texture: Texture2D,target: Rect2,tint: Color) -> void:
	if SKIN.is_chibi():
		_chibi_portrait(role_id,Rect2(target.position-paint_offset,target.size),tint.a/maxf(paint_alpha,.001));return
	if not portrait_lighting_enabled:
		draw_texture_rect(texture,target,false,tint)
		return
	var key="bust:"+role_id
	var source=Rect2(Vector2.ZERO,texture.get_size())
	portrait_light.prepare(key,texture,source,false)
	portrait_light.silhouette(self,texture,source,target,tint.a*.7)
	portrait_light.surface(self,key,texture,target,tint)

func _draw_crew_overlay() -> void:
	STAGE.backdrop(self,"camp",age,paint_alpha)
	if SKIN.is_chibi():T.surface(self,Rect2(Vector2(65,248)+paint_offset,Vector2(355,500)),"panel",paint_alpha)
	_text("伙伴",Vector2(62,66),25,INK)
	T.rule(self,Vector2(62,94)+paint_offset,Vector2(1378,94)+paint_offset,.23*paint_alpha)
	_button(Rect2(75,141,155,42),"招募","crew_recruit",true,true,GOLD if crew_tab=="recruit" else T.tone(T.SHELL))
	_button(Rect2(247,141,155,42),"编队","crew_formation",true,true,GOLD if crew_tab=="formation" else T.tone(T.SHELL))
	var abilities=preload("res://scripts/party/crew_abilities.gd")
	var ids=abilities.ordered(SUP.candidates(run),run) if crew_tab=="recruit" else run.get("roster",[])
	if crew_tab=="recruit":
		var filters=[["","全部"],["stamina_relay","交替回耐"],["weapon_echo","武器接力"],["charged_guard","蓄力护盾"],["shield_counter","挡伤反击"],["heal_charge","治疗充能"],["frost_hunt","冻结回耐"],["noise_break","附噪破盾"],["echo_heal","声骸治疗"]]
		for n in filters.size():_button(Rect2(452+n*100,143,96,40),filters[n][1],"crew_filter:"+filters[n][0],true,true,GOLD if crew_filter==filters[n][0] else T.tone(T.SHELL))
		if not crew_filter.is_empty():ids=ids.filter(func(id):return abilities.profile(id).id==crew_filter)
	crew_page=clampi(crew_page,0,maxi(0,ceili(ids.size()/3.0)-1))
	var page=ids.slice(crew_page*3,crew_page*3+3)
	if crew_focus not in page:crew_focus=str(page[0]) if not page.is_empty() else ""
	var available=int(run.round)>=2 and int(run.get("recruited_round",0))!=int(run.round)
	if C.roster.has(crew_focus):
		var role=C.roster[crew_focus]
		var portrait_rect=Rect2(442,202,581,620)
		if not SKIN.is_chibi():
			var body=_ensure_portrait(crew_focus,"body")
			if crew_busts.size()>6:crew_busts.erase(crew_busts.keys()[0])
			if body:crew_busts[crew_focus]=body
		if SKIN.is_chibi():_chibi_portrait(crew_focus,portrait_rect)
		elif crew_busts.has(crew_focus):
			var texture: Texture2D=crew_busts[crew_focus]
			var ratio=minf(portrait_rect.size.x/texture.get_width(),portrait_rect.size.y/texture.get_height())
			var size=texture.get_size()*ratio
			_draw_crew_bust(crew_focus,texture,Rect2(portrait_rect.get_center()-size*.5+paint_offset+Vector2(15*pow(1-clampf(selection_age/.22,0,1),3),0),size),Color(1,1,1,paint_alpha))
		else:_crew_portrait(crew_focus,portrait_rect.get_center(),120)
		_text(role.name,Vector2(88,314),43,INK)
		_text(_element_label(role.element)+" / "+_weapon_label(role.weapon_type),Vector2(91,360),18,C.ELEMENTS.get(role.element,GOLD).darkened(.35) if SKIN.is_chibi() else C.ELEMENTS.get(role.element,GOLD).lightened(.2))
		T.rule(self,Vector2(90,388)+paint_offset,Vector2(397,388)+paint_offset,.25*paint_alpha)
		var spec=abilities.profile(crew_focus)
		ABILITY_ICONS.draw(self,spec.icon,Rect2(Vector2(91,411)+paint_offset,Vector2.ONE*29))
		_text(spec.name,Vector2(130,434),24,INK)
		_wrapped(spec.trigger,Vector2(91,482),302,18,INK,2)
		_wrapped(spec.effect,Vector2(91,550),302,20,INK,2)
		_text("触发间隔 %.0f 秒"%float(spec.period),Vector2(91,610),16,T.tone(T.MUTED))
		_text("已有搭配" if abilities.ready(crew_focus,run) else "暂无搭配",Vector2(91,655),16,GREEN if abilities.ready(crew_focus,run) else T.tone(T.MUTED))
		var partners=abilities.matches(crew_focus,run.items+run.bags,run).slice(0,4)
		for p in partners.size():_draw_icon(partners[p].kind,Rect2(91+p*74,667,68,52),int(partners[p].rotation))
		if crew_tab=="recruit":
			var cost=SUP.price(role)
			_button(Rect2(89,838,308,55),"签约 · "+str(cost)+" 贝币","recruit:"+crew_focus,available and int(run.gold)>=cost,true,GOLD)
		else:
			var selected=run.get("supports",[]);var active=crew_focus in selected
			_text(_crew_status(crew_focus),Vector2(91,795),17,T.tone(T.DARK))
			_button(Rect2(89,838,308,55),"出战中 · 休整" if active else "加入出战","crew_toggle:"+crew_focus,active or selected.size()<2,true,GOLD if active else T.tone(T.SHELL))
	for n in range(page.size()):
		var role_id=str(page[n]);var center=Vector2(1247,320+n*117)
		_crew_portrait(role_id,center,36)
		_button(Rect2(center-Vector2(42,42),Vector2(84,84)),"","crew_focus:"+role_id,true,false)
		if role_id==crew_focus:draw_arc(center+paint_offset,43,0,TAU,48,Color(GOLD,paint_alpha),2,true)
		_text(C.roster[role_id].name,center+Vector2(-36,65),16,T.tone(T.DARK) if n==2 else T.tone(T.PAPER))
		ABILITY_ICONS.draw(self,abilities.profile(role_id).icon,Rect2(center+Vector2(24,-39),Vector2.ONE*22))
	if ids.is_empty():_text("尚未签约伙伴" if crew_tab=="formation" else "暂无可签约伙伴",Vector2(90,420),24,T.tone(T.MUTED))
	if crew_tab=="recruit" and not available:_text("第 2 轮开放" if int(run.round)<2 else "本轮合约已签",Vector2(91,789),17,T.tone(T.DARK))
	elif FEATURES.CONCERTO_ENABLED and crew_tab=="formation" and run.get("supports",[]).size()==2:_button(Rect2(434,841,203,48),"交换变奏顺序","crew_swap")
	if ids.size()>3:
		_button(Rect2(1173,721,42,34),"‹","crew_prev",crew_page>0)
		_button(Rect2(1265,721,42,34),"›","crew_next",(crew_page+1)*3<ids.size())
	_button(Rect2(1128,838,223,55),"返回整备","close")

func _draw_catalogue() -> void:
	STAGE.backdrop(self,"camp",age,paint_alpha)
	if SKIN.is_chibi():
		# Keep the scenery behind the featured item, and quiet surfaces under text.
		for rect in [Rect2(54,180,348,718),Rect2(1008,198,376,546)]:
			T.surface(self,Rect2(rect.position+paint_offset,rect.size),"panel",paint_alpha)
	_text("物品图鉴",Vector2(62,66),25,INK)
	T.rule(self,Vector2(62,94)+paint_offset,Vector2(1378,94)+paint_offset,.23*paint_alpha)
	var kinds=C.items.keys().filter(func(k):return FEATURES.item_enabled(k))
	for n in range(8):
		var index=catalogue_page*8+n
		if index>=kinds.size():break
		var kind=kinds[index];var rect=Rect2(68+(n%2)*166,197+floori(n/2.0)*145,153,128)
		var over=rect.has_point(mouse-paint_offset)
		_draw_icon(kind,Rect2(rect.position+Vector2(7,3),Vector2(139,92)),0,1 if catalogue_focus==index or over else .7,over)
		_button(rect,"","catalogue_detail:"+kind,true,false)
		_text(C.items[kind].name.substr(0,9),rect.position+Vector2(4,118),15,T.tone(T.DARK) if n>=4 else INK)
		if catalogue_focus==index:draw_line(rect.position+Vector2(4,128)+paint_offset,rect.end+paint_offset,GOLD,1.5,true)
	if not kinds.is_empty():
		var selected=kinds[clampi(catalogue_focus,catalogue_page*8,mini(kinds.size()-1,catalogue_page*8+7))]
		var def=C.items[selected]
		_draw_icon(selected,Rect2(476,215,531,392),0)
		_text(def.name,Vector2(1018,249),27,INK)
		T.rule(self,Vector2(1018,279)+paint_offset,Vector2(1361,279)+paint_offset,.25*paint_alpha)
		ITEM_PANEL.rows(self,INFO.rows({"kind":selected}).slice(0,11),Vector2(1018,320),336,32,15,SKIN.PLUM.lerp(SKIN.CREAM,.12) if SKIN.is_chibi() else T.MUTED)
		ITEM_PANEL.chips(self,selected,Vector2(1018,682))
		_button(Rect2(1054,766,264,42),"物品详情","catalogue_detail:"+selected)

	_button(Rect2(106,846,46,40),"‹","catalogue_prev",catalogue_page>0)
	var pages=maxi(1,ceili(kinds.size()/8.0))
	_text(str(catalogue_page+1)+" / "+str(pages),Vector2(186,874),18,T.tone(T.PAPER))
	_button(Rect2(299,846,46,40),"›","catalogue_next",catalogue_page<pages-1)
	_button(Rect2(1128,838,223,55),"返回整备","close")

func _draw_crew_skill() -> void:
	if not C.roster.has(crew_focus):return
	var role=C.roster[crew_focus]
	_crew_portrait(crew_focus,Vector2(460,284),27)
	_text(role.name,Vector2(507,296),27,INK)
	_text("变奏 · "+str(role.get("intro_name","入场")),Vector2(428,351),23,INK)
	var intro=str(role.get("intro_original","原作说明缺失"))
	_wrapped(intro.substr(0,120)+("…" if intro.length()>120 else ""),Vector2(428,386),572,17,T.tone(T.MUTED))
	_text("延奏 · "+str(role.get("outro_name","交还")),Vector2(428,488),23,INK)
	var outro=str(role.get("outro_original","原作说明缺失"))
	_wrapped(outro.substr(0,140)+("…" if outro.length()>140 else ""),Vector2(428,523),572,17,T.tone(T.MUTED))
	_wrapped("本作改编 · "+str(role.get("support_desc","变奏接力")).trim_prefix("本作改编 · "),Vector2(428,650),572,18,INK)
	_button(Rect2(427,752,223,40),"完整原作说明","crew_original",true,true,T.tone(T.SHELL))
	_button(Rect2(818,752,187,40),"返回伙伴","crew_back",true,true,T.tone(T.SHELL))

func _crew_original_lines() -> Array:
	var key=crew_focus+":"+crew_skill_kind
	if not crew_text_cache.has(key):
		var body=str(C.roster.get(crew_focus,{}).get(crew_skill_kind+"_original","原作说明缺失")).replace("\r","")
		var lines: Array=[]
		var current=""
		for letter in body:
			if letter=="\n":lines.append(current);current="";continue
			if font.get_string_size(current+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x>572:
				lines.append(current);current=""
			current+=letter
		lines.append(current)
		crew_text_cache[key]=lines
	return crew_text_cache[key]

func _draw_crew_original() -> void:
	if not C.roster.has(crew_focus):return
	var role=C.roster[crew_focus]
	_crew_portrait(crew_focus,Vector2(460,284),27)
	_text(role.name+" · 原作技能",Vector2(507,296),26,INK)
	_button(Rect2(427,319,178,38),"变奏","crew_original_intro",true,true,GOLD if crew_skill_kind=="intro" else T.tone(T.SHELL))
	_button(Rect2(621,319,178,38),"延奏","crew_original_outro",true,true,GOLD if crew_skill_kind=="outro" else T.tone(T.SHELL))
	_text(str(role.get(crew_skill_kind+"_name","")),Vector2(428,394),22,INK)
	var lines=_crew_original_lines()
	var pages=maxi(1,ceili(lines.size()/13.0))
	crew_skill_page=clampi(crew_skill_page,0,pages-1)
	for n in range(13):
		var index=crew_skill_page*13+n
		if index>=lines.size():break
		_text(str(lines[index]),Vector2(428,430+n*22),17,T.tone(T.MUTED))
	_button(Rect2(619,763,38,30),"‹","crew_text_prev",crew_skill_page>0)
	_text(str(crew_skill_page+1)+" / "+str(pages),Vector2(674,786),17,INK)
	_button(Rect2(744,763,38,30),"›","crew_text_next",crew_skill_page<pages-1)
	_button(Rect2(851,760,157,35),"返回技能","crew_skill_back",true,true,T.tone(T.SHELL))

func _draw_support_flights() -> void:
	for flight in support_flights:
		var side=int(flight.side)
		var progress=1.0-float(flight.life)/.95
		var fade=sin(progress*PI)
		var center=_actor_center(side)+Vector2(-168 if side==0 else 168,-24)
		var role_id=str(flight.role_id)
		var color=C.ELEMENTS.get(C.roster.get(role_id,{}).get("element","neutral"),GOLD)
		var rig_leader=_rig_leader_for_role(role_id)
		if not rig_leader.is_empty() and native_rigs_enabled:
			var previous_alpha=paint_alpha
			paint_alpha*=fade*.85
			_draw_character(rig_leader,Rect2(center-Vector2(85,100),Vector2(170,220)),side==1,-1,_support_rig_slot(side,rig_leader))
			paint_alpha=previous_alpha
		elif SKIN.is_chibi():_chibi_portrait(role_id,Rect2(center-Vector2(75,90),Vector2(150,180)),fade)
		elif _ensure_portrait(role_id,"body")!=null:
			crew_busts[role_id]=_ensure_portrait(role_id,"body")
			var texture: Texture2D=crew_busts[role_id]
			var ratio=minf(115.0/texture.get_width(),170.0/texture.get_height())
			var size=texture.get_size()*ratio
			_draw_crew_bust(role_id,texture,Rect2(center-size*.5+Vector2((1-progress)*(-20 if side==0 else 20),0),size),Color(1,1,1,fade*.85))
		_crew_portrait(role_id,center+Vector2(0,-110),25,fade)
		var build=run if side==0 else opponent
		var origin=BOARD if side==0 else ENEMY_BOARD
		var target=_actor_center(side)
		if flight.kind=="intro":
			for item in build.items:
				if item.uid==flight.carrier_uid:target=_board_to_screen(_item_rect(item,origin).get_center(),side)
		var points=PackedVector2Array()
		for n in range(19):
			var t=n/18.0
			points.append(center.lerp(target,t)+Vector2(0,-sin(t*PI)*35))
		draw_polyline(points,Color(color,fade*.55),2,true)
		draw_circle(points[mini(18,int(progress*19))],4,Color(color,fade))

func _prep_actor_rect() -> Rect2:
	return QL.ACTOR if SKIN.is_chibi() else Rect2(12,254,300,414)

func _item_rect(item: Dictionary,origin: Vector2) -> Rect2:
	var shape=inventory.cells(item)
	var size=Vector2i.ZERO
	for v in shape:
		size.x=maxi(size.x,v.x+1)
		size.y=maxi(size.y,v.y+1)
	return Rect2(origin+Vector2(float(item.x),float(item.y))*CELL,Vector2(size)*CELL)

func _panel(rect: Rect2,fill: Color,border: Color,width: int = 2,corner: int = 12) -> void:
	var tint=T.tone(T.SHELL) if fill==CREAM else fill
	T.plate(self,Rect2(rect.position+paint_offset,rect.size),Color(tint,tint.a*paint_alpha),Color(T.tone(T.EDGE),paint_alpha),6)

func _button(rect: Rect2,label: String,action: String,enabled: bool = true,visible: bool = true,color: Color = T.SHELL) -> void:
	var visual_rect=Rect2(rect.position+paint_offset,rect.size)
	var circular=SKIN.is_chibi() and action=="battle"
	var entry={"rect":visual_rect,"action":action,"enabled":enabled,"modal":not overlay.is_empty(),"circle":circular}
	buttons.append(entry)
	var hover=motion.hover(action+"@"+str(rect.position),_button_contains(entry,mouse) and enabled)
	if not visible:return
	var down=float(motion.presses.get(action,0.0))/.16
	var tools={"bag_mode":"move","relay_mode":"relay","sell_area":"sell","catalogue":"book","reroll":"refresh","menu":"menu","ghosts":"ghost","opponent":"ghost"}
	if SKIN.is_chibi() and action in ["bag_mode","forge","catalogue"]:
		_draw_chibi_utility(rect,label,action,hover,down);return
	if tools.has(action):
		STAGE.tool(self,visual_rect,tools[action],hover,down,(action=="bag_mode" and bag_mode) or (action=="relay_mode" and relay_mode),enabled)
		if hover>.7 or action=="bag_mode":
			var caption={"bag_mode":"整理口袋","relay_mode":"接力","sell_area":"卖出","catalogue":"图鉴","reroll":"刷新 · F","menu":"菜单 · Esc","ghosts":"影像","opponent":"对手"}[action]
			var length=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			var caption_pos=rect.position+Vector2((rect.size.x-length)/2,rect.size.y+22 if action=="bag_mode" else -9)
			if SKIN.is_chibi() and action in ["bag_mode","sell_area","catalogue"]:_chibi_tool_caption(caption,caption_pos,14)
			else:_text(caption,caption_pos,14,GOLD if action=="bag_mode" and bag_mode else CREAM)
		return
	if SKIN.is_chibi():
		_draw_chibi_button(rect,label,action,enabled,color,hover,down);return
	if action=="quit" and screen=="camp":
		var at=visual_rect.get_center()
		for angle in [PI*.25,PI*.75]:
			var d=Vector2.from_angle(angle)
			draw_line(at-d*12,at+d*12,Color(T.tone(T.PAPER),.8+hover*.2),2,true)
		return
	if action in ["crew_recruit","crew_formation","crew_original_intro","crew_original_outro"]:
		var selected=color==GOLD
		var at=visual_rect.position
		var length=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		_text(label,rect.position+Vector2((rect.size.x-length)/2,rect.size.y*.5+7),20,GOLD if selected else T.tone(T.MUTED))
		if selected or hover>.01:draw_line(at+Vector2(13,visual_rect.size.y),visual_rect.end-Vector2(13,0),Color(GOLD,paint_alpha*(1 if selected else hover*.5)),2,true)
		return
	var primary=(color==GOLD or action=="battle") and enabled
	var fill=T.tone(T.PAPER) if primary else T.tone(T.SHADOW)
	var text_color=T.tone(T.DARK) if primary else T.tone(T.PAPER)
	if not enabled:text_color=Color(T.tone(T.MUTED),.42)
	var pressed=visual_rect
	pressed.position.y+=down*1.5
	# Original-style low profile action strips, with an inset confirmation glyph.
	var face=StyleBoxFlat.new();face.bg_color=Color(fill,(1.0 if primary else .40+hover*.14)*paint_alpha)
	face.set_corner_radius_all(2)
	face.border_color=Color(GOLD if primary else T.tone(T.PAPER),(.8 if primary else .25+hover*.3)*paint_alpha)
	face.set_border_width_all(1)
	draw_style_box(face,pressed)
	if primary:
		var mark=pressed.position+Vector2(pressed.size.x-25,pressed.size.y*.5)
		draw_circle(mark,11,Color(T.tone(T.DARK),paint_alpha))
		draw_polyline(PackedVector2Array([mark+Vector2(-3,-4),mark+Vector2(2,0),mark+Vector2(-3,4)]),Color(T.tone(T.PAPER),paint_alpha),1.5,true)
	elif hover>.01:
		draw_line(pressed.position+Vector2(1,pressed.size.y-1),pressed.position+Vector2(1+(pressed.size.x-2)*hover,pressed.size.y-1),Color(GOLD,paint_alpha*.85),1.5,true)
	var text_size=23 if action=="battle" else (20 if rect.size.y>=45 else 16)
	var value="开战" if action=="battle" else label
	var length=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
	_text(value,rect.position+Vector2((rect.size.x-length-(24 if primary else 0))/2,rect.size.y/2+text_size*.35+down*1.5),text_size,text_color)

func _chibi_tool_caption(value:String,pos:Vector2,size:int) -> void:
	var face=body_font if body_font else font
	var width=face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	T.surface(self,Rect2(pos+paint_offset-Vector2(8,size+5),Vector2(width+16,size+12)),"panel",paint_alpha)
	_text(value,pos,size,SKIN.PLUM)

func _text(value: String,pos: Vector2,size: int,color: Color) -> void:
	color=T.tone(color)
	if SKIN.is_chibi():
		var paper=_on_paper(pos+paint_offset-Vector2(0,size*.5))
		if Color(color,1) in QUALITY.COLORS and paper:color=Color(color.darkened(.35),color.a)
		elif not paper:
			if Color(color,1)==SKIN.PLUM:color=Color(SKIN.LIGHT,color.a)
			elif Color(color,1)==T.tone(T.MUTED):color=Color(SKIN.LIGHT.lerp(SKIN.BLUEBERRY,.32),color.a)
			elif Color(color,1)==T.tone(T.BRASS):color=Color(SKIN.HONEY,color.a)
	var face=body_font if size<=19 and body_font else font
	draw_string(face,pos+paint_offset,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(color,color.a*paint_alpha))

func _wrapped(value: String,pos: Vector2,width: float,size: int,color: Color,max_lines: int=0) -> void:
	var line=""
	var row=0
	for letter in value:
		if font.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			if max_lines>0 and row>=max_lines-1:
				while font.get_string_size(line+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:line=line.left(-1)
				_text(line+"…",pos+Vector2(0,row*(size+5)),size,color)
				return
			_text(line,pos+Vector2(0,row*(size+5)),size,color)
			line=""
			row+=1
		line+=letter
	_text(line,pos+Vector2(0,row*(size+5)),size,color)

func _draw_icon(kind: String,rect: Rect2,rotation_value: int,alpha: float = 1.0,selected: bool = false,ambient:bool=false) -> void:
	if C.is_tag(kind,"bag"):
		TERMINAL.thumbnail(self,Rect2(rect.position+paint_offset,rect.size),kind,rotation_value,alpha*paint_alpha)
		return
	if rect.size.x<=6 or rect.size.y<=6:return
	if not _ensure_icon(kind):_missing_art(rect);return
	# Shop/stash/catalogue show the original silhouette, independently of its
	# storage shape. Only a board-placement preview shows the occupied cells.
	QUALITY.draw(self,kind,Rect2(rect.position+paint_offset,rect.size),alpha*paint_alpha,_item_fx_clock() if ambient else -1.0)
	var desc=_descriptor_for(kind,rotation_value)
	var bounds: Rect2=desc.bounds
	var room=rect.size-Vector2.ONE*6
	var icon_transform: Transform2D
	if C.items[kind].get("combat_v15",false):
		var definition=C.items[kind] if readable_icons_enabled and not SKIN.is_chibi() else {}
		icon_transform=ITEM_DISPLAY.fit(definition,desc,room,rect.get_center()+paint_offset).transform
	else:
		var scale_value=minf(room.x/maxf(1,bounds.size.x),room.y/maxf(1,bounds.size.y))
		var position=rect.get_center()+paint_offset-(bounds.get_center()+Vector2(desc.image_center).rotated(desc.angle))*scale_value
		icon_transform=Transform2D(desc.angle,Vector2.ONE*scale_value,0,position)
	var tint=Color(1.04,1.04,1.04,alpha*paint_alpha) if selected else Color(1,1,1,alpha*paint_alpha)
	if C.is_tag(kind,"weapon") or C.is_tag(kind,"echo"):
		ITEM_SHADOW.draw(self,icons[kind],icon_transform,draw_basis,desc.bounds.size*icon_transform.get_scale().abs(),alpha*paint_alpha)
	draw_set_transform_matrix(draw_basis*icon_transform)
	draw_texture(icons[kind],Vector2.ZERO,tint)
	if ambient and maxf(rect.size.x,rect.size.y)>=64:
		QUALITY.draw_surface(self,kind,icons[kind],_item_fx_clock(),alpha*paint_alpha)
		GLINTS.draw(self,kind,icons[kind].get_size(),_item_fx_clock(),alpha*paint_alpha)
	draw_set_transform_matrix(draw_basis)

func _rig_leader_for_role(role_id: String) -> String:
	for leader in C.characters:
		if str(C.characters[leader].get("roster_id",""))==role_id:return leader
	return ""

func _support_rig_slot(side: int,leader: String) -> int:
	return 2+side+2*C.characters.keys().find(leader)

func _get_portrait_rig(slot: int,leader: String=""):
	if leader.is_empty():
		leader=str((opponent if slot==1 else run).get("leader","jiyan"))
	if not portrait_rigs.has(slot):
		var view=RIG_VIEW.new();view.character_id=leader;view.name="PortraitRig"+str(slot);add_child(view)
		portrait_rigs[slot]=view
	portrait_rigs[slot].configure(leader)
	return portrait_rigs[slot]

func _rig_trigger(side: int,clip: String,at: float) -> void:
	var build=run if side==0 else opponent
	if native_rigs_enabled and not SKIN.is_chibi() and build.get("leader","") in ["jiyan","yinlin","verina","encore","sanhua","camellya"]:_get_portrait_rig(side,str(build.leader)).rig.trigger(clip,at)

func _portrait_clock() -> float:
	if review.active:return review_pose_time
	return combat_time if screen=="game" and run.get("phase","") in ["battle","result","ending"] else age

func _draw_character(leader: String,rect: Rect2,flip: bool,side: int = -1,rig_slot: int = -1) -> void:
	if SKIN.is_chibi():
		_chibi_portrait(leader,rect,1,false,flip,side);return
	if not leader_illustrations.has(leader):
		var original=_ensure_portrait(leader,"body")
		if original:
			leader_illustrations[leader]=original
			leader_art_bounds[leader]=SKIN.bounds(SKIN.portrait_path(leader))
			portrait_light.prepare(leader,original,leader_art_bounds[leader])
	if not leader_illustrations.has(leader):return
	var texture=leader_illustrations[leader]
	var source_rect=leader_art_bounds[leader]
	var image_size=source_rect.size
	var scale_value=minf(rect.size.x/image_size.x,rect.size.y/image_size.y)
	var target_size=image_size*scale_value
	var anchor=Vector2(rect.get_center().x,rect.end.y)
	var skeletal=native_rigs_enabled and leader in ["jiyan","yinlin","verina","encore","sanhua","camellya"]
	var lean=0.0 if side<0 or skeletal else lunge[side]*.05*(1 if side==0 else -1)
	var tint=Color.WHITE if side<0 else Color.WHITE.lerp(Color("ffd2bb"),float(motion.hit[side])/.22*.7)
	tint.a*=paint_alpha
	var pose=Transform2D(lean,Vector2(-1 if flip else 1,1),0,anchor+paint_offset)
	var target=Rect2(Vector2(-target_size.x*.5,-target_size.y),target_size)
	if portrait_lighting_enabled:
		var foot=pose*portrait_light.local_foot(leader,target)
		portrait_light.contact(self,foot+Vector2(0,2),target_size,tint.a)
	draw_set_transform_matrix(draw_basis*pose)
	var light_key=leader
	if skeletal:
		var view=_get_portrait_rig(rig_slot if rig_slot>=0 else maxi(0,side),leader)
		view.sample(_portrait_clock(),1.35 if screen=="camp" else .8)
		texture=view.get_texture()
		# Fit by the unchanged art bounds, then retain margin for moving tips.
		source_rect=Rect2(source_rect.position+Vector2.ONE*RIG_VIEW.MARGIN,source_rect.size).grow(40)
		target=target.grow(40*scale_value)
		light_key=leader+":animated"
		portrait_light.prepare(light_key,texture,source_rect,false)
	if portrait_lighting_enabled:
		portrait_light.silhouette(self,texture,source_rect,target,tint.a,flip)
		portrait_light.surface(self,light_key,texture,target,tint,flip)
	else:draw_texture_rect_region(texture,target,source_rect,tint)
	draw_set_transform_matrix(draw_basis)

func _clear_feedback() -> void:
	star_activations.clear()
	placement_stars.clear()
	stash_transfer.clear()
	battle_entry_age=1.0
	item_selection_age=ITEM_SELECTION_DURATION
	star_click_uid="";star_click_origin="";star_click_elapsed=Q_STAR.CLICK_DURATION
	for view in portrait_rigs.values():view.reset()
	capacity_pan=Vector2.ZERO;capacity_pan_left=0.0
	hit_pause=0.0
	hit_pause_cooldown=0.0
	attack_left=[0.0,0.0]
	gear_flights.clear()
	chase_cues.clear();advance_cues.clear();forge_output.clear()
	support_flights.clear()
	pending_impacts.clear()
	combat_vfx.clear()
	skip_requested=false
	hovered={}
	hover_time=0.0
	motion.events.clear()
	item_sways.clear()
	motion.pulses.clear()
	motion.landings.clear()
	motion.rejections.clear()
	motion.bars.clear()
	motion.hit=[0.0,0.0]
	floats.clear()
	projectiles.clear()
	flashes.clear()
	lunge=[0.0,0.0]
	burst_timer=0.0

func _transition() -> void:
	phase_age=0.0
	if DisplayServer.get_name()!="headless" and is_inside_tree():
		transition_image=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	motion.transition()

func _draw_effects(foreground_only: bool=false) -> void:
	for event in motion.events:
		if (event.kind in ["forge_feed","fusion"])!=foreground_only:continue
		if event.age<0:continue
		var t=clampf(event.age/event.duration,0,1)
		var fade=1-t
		var color=Color(event.color,fade)
		var pos=event.pos
		match event.kind:
			"forge_feed":
				var q=t*t*t
				var at=pos.lerp(event.to,q)+Vector2(0,-sin(q*PI)*38)
				_draw_icon(event.uid,Rect2(at-Vector2.ONE*(29*(1-q)+4),Vector2.ONE*(58*(1-q)+8)),0,1-q*.7)
			"fusion":
				var snap=sin(minf(1,t*3)*PI)*fade
				if SKIN.is_chibi():
					# Four short paper stars frame the result, leaving the icon unobscured.
					for n in 4:
						var ray=Vector2.from_angle(PI*.25+n*PI*.5)
						_star(pos+ray*(30+t*46),maxf(.5,7*fade),Color(event.color,fade),true)
				else:
					for n in range(8):
						var direction=Vector2.from_angle(n*TAU/8)
						draw_line(pos+direction*(15+t*60),pos+direction*(30+t*92),color,3*fade,true)
					draw_circle(pos,18+snap*28,Color(T.tone(T.PAPER),snap*.7))
					draw_line(pos-Vector2(75*fade,0),pos+Vector2(75*fade,0),Color(T.tone(T.PAPER),fade*.6),2+fade*3,true)

			"coin":
				for n in range(3):
					var q=clampf((t-n*.08)/.76,0,1)
					var point=pos.lerp(event.to,1-pow(1-q,3))+Vector2(0,-sin(q*PI)*(72+n*13))
					if q<1:_coin(point,7)
			"link":
				draw_line(pos,event.to,Color(event.color,fade*.5),1.5,true)
				draw_circle(pos.lerp(event.to,t),3,color)
			"shield":
				# Local shield feedback shares the visible badge anchor, not the torso.
				var pulse=sin(t*PI)*fade
				var size=23+12*pulse
				ABILITY_ICONS.draw(self,"shield",Rect2(pos-Vector2.ONE*size*.5,Vector2.ONE*size),fade)
				for direction in [-1,1]:
					var point=pos+Vector2(direction*(16+t*9),-8-t*5)
					var radius=3.5*pulse
					draw_line(point-Vector2(radius,0),point+Vector2(radius,0),Color(SKIN.LIGHT,pulse),1.5,true)
					draw_line(point-Vector2(0,radius),point+Vector2(0,radius),Color(SKIN.LIGHT,pulse),1.5,true)
			"burst":
				for n in range(7):
					var a=n*TAU/7+age*.3
					var point=pos+Vector2.from_angle(a)*(45+t*100)
					draw_line(point-Vector2.from_angle(a)*3,point+Vector2.from_angle(a)*(7+fade*8),color,1.5*fade,true)
				draw_circle(pos,50+t*130,Color(event.color,fade*.08))
				draw_arc(pos,50+t*130,0,TAU,64,Color(event.color,fade*.65),4*fade,true)
			"invalid":
				draw_arc(pos,18+t*18,0,TAU,24,color,2,true)
			_:
				var count=12 if event.kind=="fusion" else (5 if event.kind in ["land","heal","hit"] else 0)
				if event.kind in ["trigger","fusion"]:
					draw_arc(pos,15+t*(70 if event.kind=="fusion" else 25),0,TAU,32,Color(event.color,fade*.6),2*fade,true)
				for n in range(count):
					var angle=n*TAU/maxi(1,count)+.5
					var point=pos+Vector2.from_angle(angle)*(10+t*(80 if event.kind=="fusion" else 38))
					if event.kind=="heal":point.y-=t*25
					if event.kind=="heal":
						draw_line(point-Vector2(3,0),point+Vector2(3,0),color,1.2,true)
						draw_line(point-Vector2(0,3),point+Vector2(0,3),color,1.2,true)
					else:draw_line(point-Vector2.from_angle(angle)*2,point+Vector2.from_angle(angle)*(4+fade*6),color,1.3*fade,true)

func _bar(rect: Rect2,ratio: float,color: Color) -> void:
	if SKIN.is_chibi() and color==T.tone(T.PAPER):color=SKIN.LIGHT
	draw_rect(rect,T.tone(T.FELT))
	if ratio>.001:draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),color)

func _coin(pos: Vector2,radius: float) -> void:
	if T.glyph(self,"coin",Rect2(pos-Vector2.ONE*radius,Vector2.ONE*radius*2)):return
	draw_circle(pos,radius,Color(GOLD,.16))
	draw_arc(pos,radius,0,TAU,32,GOLD,1.2,true)
	var diamond=PackedVector2Array([pos+Vector2(0,-radius*.45),pos+Vector2(radius*.3,0),pos+Vector2(0,radius*.45),pos+Vector2(-radius*.3,0)])
	draw_colored_polygon(diamond,GOLD)

func _star(pos: Vector2,radius: float,color: Color,filled: bool) -> void:
	var points=PackedVector2Array()
	for n in range(10):
		var angle=-PI/2+n*PI/5
		points.append(pos+Vector2(cos(angle),sin(angle))*radius*(1 if n%2==0 else .44))
	if filled:draw_colored_polygon(points,color)
	points.append(points[0])
	draw_polyline(points,color.darkened(.25),1.5,true)

func _cup(pos: Vector2,color: Color,scale_value: float = 1.0) -> void:
	draw_set_transform_matrix(draw_basis*Transform2D(0,Vector2.ONE*scale_value,0,pos+paint_offset))
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-12),Vector2(10,-12),Vector2(8,1),Vector2(0,7),Vector2(-8,1)]),color)
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-10),Vector2(-2,-10),Vector2(-3,1),Vector2(-6,-1)]),color.lightened(.25))
	draw_line(Vector2(-9,-12),Vector2(9,-12),color.lightened(.4),2)
	draw_line(Vector2(0,5),Vector2(0,14),color,5)
	draw_line(Vector2(-8,15),Vector2(8,15),color,5)
	draw_arc(Vector2(-10,-5),6,PI/2,PI*1.5,8,color,3,true)
	draw_arc(Vector2(10,-5),6,-PI/2,PI/2,8,color,3,true)
	draw_set_transform_matrix(draw_basis)

func _heart(pos: Vector2,color: Color,radius: float) -> void:
	if T.glyph(self,"heart",Rect2(pos-Vector2.ONE*radius,Vector2.ONE*radius*2),color.a):return
	draw_circle(pos+Vector2(-radius*.45,-radius*.25),radius*.62,color)
	draw_circle(pos+Vector2(radius*.45,-radius*.25),radius*.62,color)
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-radius,-radius*.04),pos+Vector2(radius,-radius*.04),pos+Vector2(0,radius)]),color)

func _draw_chibi_button(rect:Rect2,label:String,action:String,enabled:bool,color:Color,hover:float,down:float)->void:
	var visual=Rect2(rect.position+paint_offset+Vector2(0,down*1.5-hover*2.0),rect.size)
	var face_tint=Color.WHITE*(1.0+hover*.10);face_tint.a=1.0
	var primary=action in ["battle","start","forge_confirm","replacement_confirm","material_confirm","sell_bag_confirm"]
	var alpha=paint_alpha*(1.0 if enabled else .42)
	if action=="quit" and screen=="camp" and overlay.is_empty():
		STAGE.tool(self,visual,"close",hover,down,false,enabled);return
	if action=="battle":
		# Only the rendered face grows; the registered circular target stays fixed.
		var hovered_face=visual.grow(3.0*clampf(hover,0.0,1.0) if enabled else 0.0)
		T.surface(self,hovered_face,"battle_button",alpha,face_tint)
		_text("开战",rect.position+Vector2(65,164+down*1.5-hover*2.0),31,Color(SKIN.LIGHT,1.0 if enabled else .45))
		return
	if rect.size.x>=100 and rect.size.x>rect.size.y*1.85 and not label.is_empty():
		ACTION_BUTTON.draw(self,font,Rect2(rect.position+paint_offset,rect.size),label,ACTION_BUTTON.style_for(action),hover,down,enabled,motion.elapsed,paint_alpha,draw_basis)
		return
	var surface_name="button_primary" if primary or action=="crew" else "button_round" if rect.size.x<=rect.size.y*1.85 else "button"
	T.surface(self,visual,surface_name,alpha,face_tint)
	if action=="pause":
		T.glyph(self,"play" if paused else "pause",visual.grow(-6),alpha);return
	var glyph_name={"battle":"launch","pause":"play" if paused else "pause","rotate":"rotate","forge_rotate":"rotate"}.get(action,"")
	var text_size=21 if action=="battle" else (18 if rect.size.y>=45 else 15)
	var value="开战" if action=="battle" else label
	var length=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
	if not str(glyph_name).is_empty() and rect.size.x>length+60:
		T.glyph(self,glyph_name,Rect2(visual.position+Vector2(12,(visual.size.y-24)*.5),Vector2.ONE*24),alpha)
	var caption=SKIN.PLUM if SKIN.ui_entry(surface_name).get("light_surface",false) else SKIN.LIGHT
	_text(value,rect.position+Vector2((rect.size.x-length)/2,rect.size.y/2+text_size*.35+down*1.5-hover*2.0),text_size,Color(caption,1.0 if enabled else .45))

func _button_contains(button:Dictionary,point:Vector2)->bool:
	return QL.inside_circle(button.rect,point) if button.get("circle",false) else button.rect.has_point(point)

func _shop_press_pending()->bool:
	return SKIN.is_chibi() and drag_origin=="shop" and not dragging.is_empty() and drag_pressed and not drag_rotated and maxf(drag_distance,mouse.distance_to(drag_press_at))<=6.0

func _shop_icon_rect(index:int)->Rect2:
	var t=clampf((reroll_age-index*.028)/.18,0,1)
	return Rect2(QL.offer(index).position+Vector2(3,4+pow(1-t,3)*14),Vector2(122,111))

func _draw_chibi_shop()->void:
	_text("商店",Vector2(1042,190),27,SKIN.PLUM)
	T.glyph(self,"sell",Rect2(993,158,34,34),1.0,SKIN.PLUM)
	for n in 6:
		var rect=QL.offer(n);var offer=run.shop[n]
		if offer.is_empty():
			_text("—",rect.position+Vector2(52,87),22,Color(SKIN.PLUM,.28));continue
		var t=clampf((reroll_age-n*.028)/.18,0,1)
		var over=motion.hover("offer"+str(n),rect.has_point(mouse))
		var icon_rect=_shop_icon_rect(n)
		inline_craft.draw_offer_hint(self,_craft_view_model(),_craft_paint(),n,icon_rect)
		var selected=detail_origin=="shop" and detail_offer_index==n and item_selection_age<ITEM_SELECTION_DURATION
		var icon_alpha=t*(0.0 if not dragging.is_empty() and drag_origin=="shop" and drag_offer_index==n else 1.0)
		if offer.has("bundle"):
			_draw_icon(offer.bundle[0],Rect2(icon_rect.position+Vector2(0,0),Vector2(83,83)),0,icon_alpha,false,true)
			_draw_icon(offer.bundle[1],Rect2(icon_rect.position+Vector2(42,35),Vector2(83,77)),0,icon_alpha,false,true)
			_text("+",icon_rect.position+Vector2(90,30),19,SKIN.PLUM)
		else:_draw_icon(offer.kind,_selection_rect(icon_rect) if selected else icon_rect,0,icon_alpha,false,true)
		var price=QL.price(n);var tag=price.grow_individual(0,-3,0,-3)
		var locked=bool(offer.get("locked",false))
		preload("res://scripts/ui/apricot_ui.gd").box(self,tag,Color("ffe2a7") if locked else Color("ac82a2").lightened(over*.10),Color("d5aa6f") if locked else Color("825b8d"),12)
		_coin(price.position+Vector2(15,18),12)
		_text(str(inventory.purchase_price(run,n)),price.position+Vector2(44,26),22,SKIN.PLUM if locked else SKIN.LIGHT)
		SHOP_PRESENTATION.draw_benefits(self,offer.kind,Rect2(rect.position+Vector2(0,116),Vector2(128,23)),font)
		var control=QL.offer_control(n)
		_button(control,"","lock:"+str(n),true,false)
		var lock_event=lock_animation.get(n,{})
		SHOP_PRESENTATION.draw_lock(self,control,bool(offer.get("locked",false)),motion.elapsed-float(lock_event.get("time",-100)),bool(lock_event.get("locked",false)),motion.hover("lock-face:"+str(n),control.has_point(mouse)))
	var free=RECRUITMENT.refresh_cost(run)==0
	_button(QL.REFRESH,"刷新","reroll",free or run.gold>=1)
	_text("免费" if free else "1 贝币",Vector2(1323 if free else 1312,724),17,SKIN.PLUM)
	_button(QL.CATALOGUE,"图鉴","catalogue")

func _draw_chibi_utility(rect:Rect2,label:String,action:String,hover:float,down:float)->void:
	var on_paper=action=="catalogue"
	var tint=SKIN.PLUM if on_paper else SKIN.LIGHT
	var shifted=rect.position+paint_offset+Vector2(0,down*2-hover*2)
	var icon={"bag_mode":"move","forge":"launch","catalogue":"book"}.get(action,"book")
	if hover>0.01:
		var wash=StyleBoxFlat.new();wash.bg_color=Color(SKIN.PLUM if on_paper else SKIN.LIGHT,hover*.12);wash.set_corner_radius_all(12)
		draw_style_box(wash,Rect2(shifted,rect.size))
	T.glyph(self,icon,Rect2(shifted+Vector2(4,9),Vector2.ONE*32),1.0,tint)
	_text(label,rect.position+Vector2(48,35+down*2-hover*2),23,tint)
	if action=="bag_mode" and bag_mode:draw_line(shifted+Vector2(46,45),shifted+Vector2(110,45),SKIN.HONEY,2,true)

func _register_paper_surface(rect:Rect2)->void:
	chibi_paper_surfaces.append(rect)
func _clear_paper_surfaces()->void:
	chibi_paper_surfaces.clear()
func _on_paper(point:Vector2)->bool:
	return chibi_paper_surfaces.any(func(rect):return rect.has_point(point))

func _draw_chibi_hud()->void:
	var limits=_hud_limits()
	_text("整备" if run.phase=="shop" else "对战",Vector2(112,67),36,SKIN.LIGHT)
	T.glyph(self,"ghost",Rect2(46,27,52,52),1.0,SKIN.LIGHT)
	draw_line(Vector2(225,35),Vector2(225,69),Color(SKIN.LIGHT,.45),1,true)
	_text("第 %d 回合"%int(run.round),Vector2(251,62),24,SKIN.LIGHT)
	for n in int(limits.wins):
		var pos=Vector2(384+n*28,51)
		var color=SKIN.HONEY if n<int(run.wins) else Color(SKIN.LIGHT,.65)
		var points=PackedVector2Array([pos+Vector2(0,-6),pos+Vector2(6,0),pos+Vector2(0,6),pos-Vector2(6,0)])
		if n<int(run.wins):draw_colored_polygon(points,color)
		else:draw_polyline(PackedVector2Array(Array(points)+[points[0]]),color,1,true)
	for n in int(limits.losses):_heart(Vector2(630+n*30,51),Color("eea0ae") if n<int(limits.losses)-int(run.losses) else Color(SKIN.LIGHT,.2),11)
	_coin(_wallet_position(),16)
	_text(str(int(run.gold)),_wallet_position()+Vector2(29,10),27,SKIN.LIGHT)
	_button(Rect2(1255,25,57,57),"菜单 · Esc","menu")
	_button(Rect2(1330,25,57,57),"影像","ghosts")

func _capture_play_frame() -> void:
	await RenderingServer.frame_post_draw
	var folder=OS.get_user_data_dir()+"/screenshots"
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp=Time.get_datetime_string_from_system().replace(":","-")
	var path=folder+"/"+stamp+"-"+str(Time.get_ticks_msec())+".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("PLAY_CAPTURE "+path)

# Presentation adapter: builds value snapshots and explicit paint callbacks.
# Never hands a game/session object to the inline craft view.
var _craft_query_key=""
var _craft_query_entries:Array=[]
var _craft_guidance_key=""
var _craft_guidance_data:Dictionary={}
var _craft_stamp=preload("res://scripts/ui/presentation_stamp.gd").new()
var _craft_frame_open=false
var _craft_frame_model:Dictionary={}
# Scene adapter: beam anchors share the actual icon pose, including selection and rotation.
func _craft_item_center(node:Dictionary,held:bool=false)->Vector2:
	if held:
		if _shop_press_pending():return _shop_icon_rect(drag_offer_index).get_center()+mouse-drag_press_at+Vector2(0,-2.5)
		var source=_held_source_piece()
		return _held_pose()*_projection_for(source.kind,int(source.rotation),CELL).center
	if node.origin=="shop":
		var rect=_shop_icon_rect(node.index) if SKIN.is_chibi() else _offer_rect(node.index)
		if detail_origin=="shop" and detail_offer_index==node.index and item_selection_age<ITEM_SELECTION_DURATION:rect=_selection_rect(rect)
		return rect.get_center()
	if node.origin=="stash":
		var rect=_stash_rect(node.index).grow(-3)
		for flight in stash_transfer.flights:
			if flight.piece.uid==node.piece.uid:
				return stash_transfer.pose(flight.from,rect,float(flight.age)).rect.get_center()
		if detail_origin=="stash" and node.piece.uid==detail_item.get("uid","") and item_selection_age<ITEM_SELECTION_DURATION:rect=_selection_rect(rect)
		return rect.get_center()
	var piece=node.piece
	var fitted=_projection_for(piece.kind,int(piece.rotation),CELL)
	var at=_piece_position(piece,BOARD,0)
	return _board_to_screen(_piece_pose(piece,at,fitted,0)*(at+fitted.center))

func _craft_view_model()->Dictionary:
	# A draw is read-only, so all its consumers share one coherent projection.
	# Input handlers run outside this boundary and always observe current state.
	if _craft_frame_open and not _craft_frame_model.is_empty():return _craft_frame_model
	var model=_build_craft_view_model()
	if _craft_frame_open:_craft_frame_model=model
	return model

func _build_craft_view_model()->Dictionary:
	var idle=screen=="game" and run.get("phase","")=="shop" and forge_output.is_empty() and not bag_mode and not fusion_view.active()
	var active=idle and overlay.is_empty() and motion.modal_value<=0 and dragging.is_empty()
	var guidance=idle and overlay in ["","item_details"] and not (overlay=="item_details" and detail_parent_overlay in ["catalogue","opponent"])
	var m={"active":active,"guidance_active":guidance,"key":"","entries":[],"relations":[],"matching_offers":[],"stash_rects":{},"stash_bounds":_stash_mat_rect(),"endpoints":{},"item_rects":{},"occupied":{},"focus":"","dragging":not dragging.is_empty(),"dragging_bag":not dragging.is_empty() and C.is_tag(dragging.kind,"bag"),"mouse":mouse,"elapsed":motion.elapsed,"board_origin":BOARD,"cell":CELL,"board_transform":Transform2D.IDENTITY,"board_bounds":Rect2()}
	if not active and not guidance:return m
	var state_key=_craft_stamp.key(run)
	m.board_transform=_board_transform();m.board_bounds=_board_screen_rect()
	for n in range(_stash_current_page()*STASH_PAGE_SIZE,(_stash_current_page()+1)*STASH_PAGE_SIZE):m.stash_rects[n]=_stash_rect(n)
	m.key=state_key+str(m.board_transform)+str(_stash_current_page())
	if active:
		if _craft_query_key!=state_key:
			_craft_query_key=state_key;_craft_query_entries=FORGE.display_options(run,inventory)
			for entry in _craft_query_entries:entry.cells=inventory.cells(entry.output)
		m.entries=_craft_query_entries
		for item in run.items:
			var box=_item_rect(item,BOARD)
			m.item_rects[item.uid]=Rect2(_board_to_screen(box.position),box.size*m.board_transform.get_scale())
			m.occupied[item.uid]=inventory.occupied(item)
	if not guidance or m.dragging_bag:return m
	var key=state_key+str(_stash_current_page())
	if m.dragging:key+=str(dragging)+str(_drag_placement_cell())+str(drag_offer_index)+drag_origin+str(_drag_over_board())
	if key!=_craft_guidance_key:
		_craft_guidance_key=key
		var state=run;var held_uid=""
		if m.dragging:
			var candidate=_item_drop_preview() if _drag_over_board() else {"ok":false}
			if candidate.ok:state=candidate.run;held_uid=candidate.piece.uid
			else:
				state=run.duplicate(true);held_uid=str(dragging.uid)
				state.items=state.items.filter(func(v):return v.uid!=held_uid)
				state.stash=state.stash.filter(func(v):return v.uid!=held_uid)
		# Rules remove a held instance, while the drawn stash may retain its empty slot.
		# Anchor identity therefore comes from the same display array used by _draw_stash.
		var displayed=_stash_display_preview().get("run",run).stash
		var display_slots={}
		for n in range(_stash_current_page()*STASH_PAGE_SIZE,mini((_stash_current_page()+1)*STASH_PAGE_SIZE,displayed.size())):
			display_slots[displayed[n].uid]=n
		_craft_guidance_data=FORGE.guidance(run,state,dragging,held_uid,drag_offer_index if m.dragging and drag_origin=="shop" else -1,inventory,display_slots.keys())
		for uid in _craft_guidance_data.nodes:
			var node=_craft_guidance_data.nodes[uid]
			if node.origin=="stash" and display_slots.has(uid):node.index=display_slots[uid]
	var data=_craft_guidance_data
	m.matching_offers=data.get("matching_offers",[]).duplicate()
	for relation in data.relations:
		var a=data.nodes[relation.base_uid];var b=data.nodes[relation.material_uid]
		for node in [a,b]:
			if node.origin=="shop" and node.index not in m.matching_offers:m.matching_offers.append(node.index)
		# Inventory eligibility still includes every page; links require two real visible anchors.
		if [a,b].any(func(node):return node.origin=="stash" and not _stash_rect(node.index).has_area() and not (m.dragging and node.piece.uid==data.held_uid)):continue
		m.relations.append(relation)
		for node in [a,b]:m.endpoints[node.piece.uid]=_craft_item_center(node,m.dragging and node.piece.uid==data.held_uid)
	if m.dragging:m.focus=data.held_uid
	else:
		for n in run.shop.size():
			if not run.shop[n].is_empty() and _offer_rect(n).has_point(mouse):m.focus="offer:"+str(n);break
		if m.focus.is_empty():
			for n in _stash_indices():
				if _stash_rect(n).has_point(mouse):m.focus=str(run.stash[n].uid);break
		if m.focus.is_empty() and hovered.get("origin","") in ["board","stash"]:m.focus=str(hovered.get("item",{}).get("uid",""))
		if m.focus.is_empty() and overlay=="item_details":m.focus="offer:"+str(detail_offer_index) if detail_origin=="shop" else str(detail_item.get("uid",""))
	return m

func _craft_paint()->Dictionary:
	return {"basis":_basis,"icon":_draw_icon,"text":_text,"star":_star,"piece":_draw_piece}

func _inline_craft_input(event:InputEvent)->bool:
	if _preparation_frozen():return false
	var intent=inline_craft.input(_craft_view_model(),event)
	if not intent.handled:return false
	if event is InputEventMouseButton:mouse=event.position
	if intent.get("pressed",false):hovered={};_sound("click")
	if intent.has("request"):
		var result=_commit_preparation(FORGE.ready_plan(run,intent.request,inventory))
		if result.ok:
			forge_cache_key="";hovered={};_play_craft_result(result)
		else:
			motion.emit("invalid",intent.request.rect.get_center(),Color("d37a68"));_sound("reject")
		inline_craft.cache_key=""
		inline_craft.refresh(_craft_view_model())
	return true

func _play_craft_result(result:Dictionary)->void:
	# Craft commits bypass preparation; consumed sources must not keep UI pulses.
	placement_stars.retain(_placement_star_snapshot())
	if result.get("destination","board")=="stash":_reveal_stash(result.output.uid)
	else:stash_page=_stash_current_page()
	var parts:Array=[]
	for item in result.changes.consumed:
		var fitted=_projection_for(item.kind,int(item.rotation),CELL)
		var pose=_board_transform()*Transform2D(0,BOARD+Vector2(item.x,item.y)*CELL)*Transform2D(fitted.transform)
		var center=pose*Vector2(fitted.image_center) if fitted.has("image_center") else _board_to_screen(_item_rect(item,BOARD).get_center())
		parts.append({"texture":SKIN.texture(SKIN.item_path(item.kind)),"pose":pose,"center":center})
	var destination=_stash_rect(int(result.stash_index)).get_center() if result.get("destination","board")=="stash" else _board_to_screen(_item_rect(result.output,BOARD).get_center())
	fusion_view.start(parts,destination,result.output.uid)


# Scene/controller adapter; all gameplay writes and saves are owned by application services.
func _application():return ASYNC_APPLICATION.new(inventory,storage,engine) if game_mode=="async" else APPLICATION.new(inventory,storage,engine)
func _preparation_frozen()->bool:
	return matching or (screen=="game" and game_mode=="async" and run.get("phase","")=="shop" and run.get("pvp",{}).get("stage","idle")!="idle")
func _switch_mode(value:String)->void:
	if screen!="camp" or value not in ["practice","async"] or matching:return
	game_mode=value;storage=online_storage if value=="async" else practice_storage
	online_client.active=value=="async"
	run={};opponent={};combat={};saved=storage.resume();overlay="";_refresh_camp_saves();queue_redraw()
func _refresh_camp_saves()->void:
	# Read once on entering the lobby, never during its rendering or animation.
	camp_saves={"practice":practice_storage.resume(),"async":online_storage.resume()}
func _camp_action(action:String)->void:
	if screen!="camp" or not overlay.is_empty():return
	var parts=action.split(":")
	if parts.size()!=3 or parts[1] not in ["practice","async"] or parts[2] not in ["enter","new","history","resume"]:return
	_switch_mode(parts[1])
	if parts[2]=="history":_action("history");return
	if parts[2]=="resume":
		if not saved.is_empty() and saved.get("phase","")!="ending":_action("resume")
		return
	_action("resume" if parts[2]=="enter" and not saved.is_empty() and saved.get("phase","")!="ending" else "start")

func _commit_preparation(plan:Dictionary)->Dictionary:
	var previous=run.get("stash",[]).map(func(v):return v.uid)
	var before_stars=_placement_star_snapshot() if run.get("phase","")=="shop" else []
	var result=_application().commit(run,plan)
	if result.ok:
		_sync_stash_view(previous)
		placement_stars.record(before_stars,_placement_star_snapshot() if run.get("phase","")=="shop" else [])
	return result

func _transfer_paint()->Dictionary:return {"basis":_basis,"icon":_draw_icon}
func _enqueue_stash_transfers(before:Array)->void:
	var transfers=[]
	for old in before:
		if old.uid==dragging.get("uid",""):continue
		if not run.stash.any(func(v):return v.uid==old.uid) or run.items.any(func(v):return v.uid==old.uid):continue
		var rect=_item_rect(old,BOARD)
		transfers.append({"piece":old.duplicate(true),"from":Rect2(_board_to_screen(rect.position),rect.size*_board_transform().get_scale())})
	stash_transfer.enqueue(transfers)
func _draw_stash_transfers()->void:
	if stash_transfer.flights.is_empty():return
	var shown=_stash_display_preview().get("run",run).stash
	var targets={}
	for flight in stash_transfer.flights:
		if dragging.get("uid","")==flight.piece.uid:continue
		for n in shown.size():
			if shown[n].uid==flight.piece.uid and _stash_rect(n).has_area():targets[flight.piece.uid]=_stash_rect(n).grow(-3);break
	stash_transfer.draw(self,targets,_transfer_paint())
func _draw_transfer_preview(preview:Dictionary)->void:
	var model={"basis":_board_transform(),"cell_size":CELL,"ghosts":[]}
	if preview.get("ok",false):
		for piece in preview.displaced:
			var ghost={"at":BOARD+Vector2(piece.x,piece.y)*CELL,"cells":inventory.cells(piece),"kind":piece.kind,"rotation":int(piece.rotation)}
			for n in preview.run.stash.size():
				if preview.run.stash[n].uid==piece.uid and _stash_rect(n).has_area():ghost.slot=_stash_rect(n).grow(-3);break
			model.ghosts.append(ghost)
	stash_transfer.draw_preview(self,model,_transfer_paint())

func _placement_star_snapshot()->Array:
	var result=[]
	for item in run.get("items",[]):
		for marker in _effect_star_markers(item,run.items,run):
			if marker.state!="lit":continue
			var fact=marker.duplicate(true);fact.source_uid=str(item.uid);result.append(fact)
	return result

func _placement_star_markers()->Array:
	return placement_stars.markers() if run.get("phase","")=="shop" else []

func _draw_placement_stars()->void:
	for marker in _placement_star_markers():
		if marker.cell.x<0 or marker.cell.x>=I.WIDTH or marker.cell.y<0 or marker.cell.y>=I.HEIGHT:continue
		var fade=1.0-smoothstep(placement_stars.FADE_START,placement_stars.DURATION,marker.age)
		Q_STAR.draw(self,BOARD+marker.center,17,"lit",motion.elapsed,fade,marker.age)
