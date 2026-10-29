extends SceneTree
const G=preload("res://tests/fixtures/travel_fixture_v64.gd")
const S=preload("res://scripts/storage/storage.gd")
class CountedStorage extends S:
 var writes=0
 func save(state:Dictionary)->bool:
  writes+=1;return super.save(state)
var game;var checks=0;var failures=0
func ck(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func pointer(at:Vector2,down:bool,button:int=MOUSE_BUTTON_LEFT):
 var e=InputEventMouseButton.new();e.position=at;e.pressed=down;e.button_index=button;game._input(e)
func move(at:Vector2):
 var e=InputEventMouseMotion.new();e.position=at;game._input(e)
func key(code:int):
 var e=InputEventKey.new();e.keycode=code;e.pressed=true;game._input(e)
func frame():
 game.queue_redraw();await process_frame;await process_frame
func setup(count:int):
 game.reset_slice();game.stash_page=0;game.buttons=[];game.motion.modal_value=0;game.motion.modal_target=0;game._clear_feedback();game.run.stash=[];game.run.gold=100
 for n in count:game.run.stash.append(game.inventory.make_piece("mat_43020011","stored"+str(n)))
func _initialize():call_deferred("run_tests")
func run_tests():
 root.size=Vector2i(1440,960);game=G.new();root.add_child(game);await process_frame
 game.set_process(false);game.set_process_input(false)
 var files=CountedStorage.new(game.storage.root_path+"pages/");game.storage=files
 setup(13);await frame()
 ck(game._stash_pages()==3 and game._stash_indices()==[0,1,2,3,4,5],"six visible slots across three pages")
 ck(not game._stash_rect(6).has_area(),"off-page index has no phantom screen rectangle")
 var before=game.run.duplicate(true)
 pointer(game._stash_mat_rect().get_center(),true,MOUSE_BUTTON_WHEEL_DOWN)
 ck(game._stash_current_page()==1 and game._stash_indices()==[6,7,8,9,10,11] and game.run==before,"wheel switches visual page without touching inventory")
 var at=game._stash_rect(6).get_center()
 pointer(at,true);pointer(at,false)
 ck(game.overlay=="item_details" and game.detail_item.uid=="stored6" and game.detail_origin=="stash","click page two inspects actual seventh item")
 pointer(game._stash_mat_rect().get_center(),true,MOUSE_BUTTON_WHEEL_DOWN)
 ck(game._stash_current_page()==2 and game.overlay.is_empty(),"paging closes now-hidden detail card")
 await frame()
 var prev=game.buttons.filter(func(b):return b.action=="stash_prev")
 ck(prev.size()==1,"header previous control is registered by actual renderer")
 if not prev.is_empty():
  pointer(prev[0].rect.get_center(),true);pointer(prev[0].rect.get_center(),false)
  ck(game._stash_current_page()==1,"header click changes page through controller")
 game.buttons=[];at=game._stash_rect(6).get_center();pointer(at,true)
 ck(game.dragging.uid=="stored6","grab uses absolute index on current page")
 var held=game.dragging.uid;var pivot=game._held_center_screen()
 pointer(at,true,MOUSE_BUTTON_RIGHT)
 ck(game.dragging.rotation==1 and game._held_center_screen().is_equal_approx(pivot),"stored item rotates around held center")
 pointer(game._stash_mat_rect().get_center(),true,MOUSE_BUTTON_WHEEL_DOWN)
 ck(game.dragging.uid==held and game.run==before and files.writes==0,"paging and inspection while holding cause no write, ownership or rotation change")
 pointer(game.mouse,false)
 ck(game.inventory.find_piece(game.run,held).rotation==1 and game.run.stash.size()==13 and files.writes==1,"drop updates only held instance rotation with one save and no duplication")
 # Last-page removal clamps to a real page, and each committed action saves once.
 game.dragging={};game._clear_held_pose();game._set_stash_page(2)
 ck(game._commit_preparation(game.inventory.plan_sell(game.run,game.run.stash[-1])).ok and game._stash_current_page()==1,"removing final page's only item clamps pagination")
 ck(game.storage.resume()==game.run,"paginated changes survive real isolated save")
 # New purchased arrivals are revealed, and cancellation after replacement keeps storage ownership.
 setup(6);game.run.shop[0]={"kind":"whiff","locked":false};await frame();game.buttons=[]
 pointer(game._offer_rect(0).get_center(),true);move(game._stash_mat_rect().get_center());pointer(game.mouse,false)
 ck(game.run.stash.size()==7 and game._stash_current_page()==1 and game._stash_rect(6).has_area(),"seventh purchase reveals its destination page")
 ck(game.stash_transfer.flights.size()==1 and game.stash_transfer.flights[0].piece.uid==game.run.stash[6].uid,"new arrival drops physically into visible page")
 setup(6);game.run.shop[0]={"kind":"whiff","locked":false};game.buttons=[]
 pointer(game._offer_rect(0).get_center(),true);move(game._board_to_screen(game.BOARD+Vector2(.5,.5)*game.CELL));pointer(game.mouse,false)
 ck(game.carry_replacement and game.drag_origin=="stash" and game._stash_current_page()==1,"replacement stays on mouse and its owned page is revealed")
 before=game.run.duplicate(true);key(KEY_ESCAPE)
 ck(game.dragging.is_empty() and game.run==before and game.inventory.validate_run(game.run),"replacement cancel retains every owned instance")
 # Recipe queries include off-page material, while visual lines never end on phantom slots.
 setup(7);game.run.stash[6]=game.inventory.make_piece("whiff","offpage-echo");game.run.shop=[{},{},{},{},{},{}]
 var model=game._craft_view_model();var matching=game.FORGE.guidance(game.run,game.run,{},"",-1,game.inventory)
 ck(matching.relations.any(func(r):return "offpage-echo" in r.uids),"recipe facts include off-page ingredient")
 ck(not model.relations.any(func(r):return "offpage-echo" in r.uids) and not model.endpoints.has("offpage-echo"),"hidden ingredient has no phantom beam")
 game.run.shop[0]={"kind":"w_sword","locked":false}
 model=game._craft_view_model()
 ck(0 in model.matching_offers,"off-page ingredient still highlights compatible shop offer")
 game.run.shop[0]={}
 game._set_stash_page(1);model=game._craft_view_model()
 ck(model.relations.any(func(r):return "offpage-echo" in r.uids) and model.endpoints.get("offpage-echo",Vector2.ZERO)==game._stash_rect(6).get_center(),"page reveal restores beam to actual icon center")
 # Craft fallback reveals page before choosing fusion endpoint.
 setup(6);game.run.items=[game.piece("w_sword","i1",0,0),game.piece("whiff","i2",2,1)];game.run.primary="i1";game.run.shop=[{},{},{},{},{},{}]
 var request=game.FORGE.ready_options(game.run,game.inventory)[0]
 var result=game.FORGE.commit_ready(game.run,request,game.inventory,game.storage.save)
 ck(result.ok,"full first page cannot block fusion")
 if result.ok:
  game._play_craft_result(result)
  ck(game._stash_current_page()==1 and game.fusion_view.destination==game._stash_rect(6).get_center(),"fusion converges on new visible destination page")
  before=game.run.duplicate(true);game.fusion_view.finish()
  ck(game.run==before,"finishing presentation cannot repeat crafting")
 # Holding over stash or an invalid drop keeps its visible hole; rule candidates may remove it.
 setup(7);game.run.shop=[{},{},{},{},{},{}]
 game.run.stash[1].kind="whiff";game.run.stash[6].kind="whiff";game.buttons=[]
 before=game.run.duplicate(true);pointer(game._stash_rect(0).get_center(),true)
 for position in [game._stash_mat_rect().get_center(),Vector2(1400,930)]:
  move(position);model=game._craft_view_model()
  ck(model.endpoints.get("stored1",Vector2.ZERO)==game._stash_rect(1).get_center(),"held gap keeps second item's endpoint at its displayed slot")
  ck(not model.endpoints.has("stored6"),"holding first item does not leak seventh item's endpoint onto page one")
  ck(game.run==before,"held endpoint projection never rewrites inventory")
 game._set_stash_page(1);model=game._craft_view_model()
 ck(model.endpoints.get("stored6",Vector2.ZERO)==game._stash_rect(6).get_center() and not model.endpoints.has("stored1"),"held item page change uses visible seventh item without compressed indices")
 game._set_stash_page(0)
 move(game._board_to_screen(game.BOARD+Vector2(.5,1.5)*game.CELL))
 var display=game._stash_display_preview()
 ck(display.get("ok",false) and display.run.stash[0].uid=="stored1","valid board preview really reflows the held slot")
 model=game._craft_view_model()
 ck(model.endpoints.get("stored1",Vector2.ZERO)==game._stash_rect(0).get_center(),"valid board preview endpoint follows actual reflow")
 ck(model.endpoints.get("stored6",Vector2.ZERO)==game._stash_rect(5).get_center(),"valid board preview may show seventh item only after visible reflow")
 ck(game.run==before,"valid preview reflow remains presentation only")
 key(KEY_ESCAPE)
 # A page button is its own complete UI gesture, never a new item press.
 setup(7);game.run.shop=[{},{},{},{},{},{}];await frame();key(KEY_TAB)
 pointer(game.mouse,true,MOUSE_BUTTON_RIGHT)
 var carried=game.dragging.duplicate(true);before=game.run.duplicate(true);var writes=files.writes
 var next_button=game.buttons.filter(func(b):return b.action=="stash_next")[0]
 pointer(next_button.rect.get_center(),true)
 ck(game.dragging==carried and not game.drag_pressed,"page button press preserves keyboard-held item without starting detail gesture")
 pointer(next_button.rect.get_center(),false)
 ck(game._stash_current_page()==1 and game.dragging==carried and game.overlay.is_empty(),"page button release preserves held UID and orientation without opening old detail")
 ck(game.run==before and files.writes==writes,"held pagination click saves nothing and changes no ownership")
 await frame();next_button=game.buttons.filter(func(b):return b.action=="stash_next")[0]
 pointer(next_button.rect.get_center(),true);pointer(next_button.rect.get_center(),false)
 ck(game._stash_current_page()==1 and game.dragging==carried and game.overlay.is_empty(),"disabled end-page arrow consumes gesture without dropping held item")
 var previous_button=game.buttons.filter(func(b):return b.action=="stash_prev")[0]
 pointer(previous_button.rect.get_center(),true);pointer(previous_button.rect.get_center(),false)
 ck(game._stash_current_page()==0 and game.dragging==carried and game.overlay.is_empty(),"previous arrow also preserves held item through complete gesture")
 key(KEY_ESCAPE)
 setup(130)
 for n in 130:game.run.stash[n].kind="w_sword" if n%2==0 else "whiff"
 var start=Time.get_ticks_usec();model=game._craft_view_model();var first=Time.get_ticks_usec()-start
 start=Time.get_ticks_usec()
 for n in 10:model=game._craft_view_model()
 ck(game._craft_guidance_data.relations.size()<=24,"paginated link query does not expand invisible duplicate pairs")
 ck(model.relations.all(func(r):return model.endpoints.has(r.base_uid) and model.endpoints.has(r.material_uid)),"every rendered relation has two visible anchors")
 print("STASH_GUIDANCE_130 first_us=",first," warm_us=",(Time.get_ticks_usec()-start)/10," full_relations=",game._craft_guidance_data.get("relations",[]).size())
 print("STASH_PAGES_V103 ",checks," checks, ",failures," failures")
 game.queue_free();await process_frame;await create_timer(1.0).timeout;quit(1 if failures else 0)
