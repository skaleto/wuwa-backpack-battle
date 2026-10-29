extends SceneTree
## Native display audit: hidden SubViewport, independent Storage, synthetic input only.
const C=preload('res://scripts/data/catalog.gd')
const D=preload('res://scripts/ui/items/item_description.gd')
const I=preload('res://scripts/ui/items/item_info.gd')
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const R=preload('res://scripts/party/recruitment_v115.gd')
const R114=preload('res://scripts/party/recruitment_v114.gd')
const P=preload('res://scripts/ui/party/recruitment_presenter.gd')
const ABILITIES=preload('res://scripts/party/crew_abilities_v115.gd')
const ART=preload('res://scripts/ui/party/recruitment_art.gd')
const CARD=preload('res://scripts/ui/party/recruitment_card_view.gd')
const CREW=preload('res://scripts/ui/party/crew_setup_view.gd')
const INVITE=preload('res://scripts/ui/party/recruitment_view.gd')
const CAPACITY=preload('res://tests/fixtures/capacity_fixture_v111.gd')
const OUT='res://build/qa/feedback-v116/ui/'
var checks=0
var failures=0
var viewport:SubViewport
var capture_viewport:SubViewport
var capture_sprite:Sprite2D
var capture_background:ColorRect
var g
var capture=false
var captures=[]
var display_audit={}
var layouts=[]
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize()->void:
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true)
 capture='--capture' in OS.get_cmdline_user_args()
 DirAccess.make_dir_recursive_absolute(OUT)
 call_deferred('run_tests')
func localized(value:String,label:String)->void:
 var internal=RegEx.new();internal.compile('[A-Za-z_]+')
 var icons=RegEx.new();icons.compile('\\[[a-z_]+\\]')
 ck(internal.search(icons.sub(value,'',true))==null,label+' '+value)
func fit_text(value:String,area:Rect2,size:int,face:Font,label:String,minimum:int=14)->void:
 if value.is_empty():return
 var fitted=ART.text_layout(face,value,area,size)
 ck(area.grow(.01).encloses(fitted.bounds),'text contained '+label)
 ck(fitted.font_size>=minimum,'readable text '+label+' '+str(fitted.font_size))
 layouts.append({'label':label,'text':value,'size':fitted.font_size,'height':fitted.bounds.size.y,'available_height':area.size.y})
func audit_items()->void:
 var before=C.items.duplicate(true);var count=0
 for kind in C.items:
  var prose=' '.join(D.effects(kind))
  localized(prose,'localized effect '+str(kind))
  for pair in I.star_rows(kind):localized(str(pair[0])+str(pair[1]),'localized star row '+str(kind))
  ck(I.effects(kind)==I.live_effects(kind) if I.V75.has_profile(kind) else true,'effect entry points agree '+str(kind))
  if str(kind).begins_with('crew_'):
   count+=1;display_audit[kind]={'name':C.items[kind].name,'effects':D.effects(kind),'stars':I.star_rows(kind),'rows':I.rows({'kind':kind})}
   ck(D.effects(kind).size()==(2 if kind=='crew_dew_vial_plus' else 1),'complete nonduplicated specialty '+str(kind))
 for recipe in C.combinations:
  localized(' '.join(D.changes(recipe.base,recipe.target)),'localized recipe '+str(recipe.target))
 ck(count==15,'all 15 specialty items audited')
 var grip=' '.join(D.effects('crew_pulse_grip'))
 ck(grip.contains('每6秒') and grip.contains('有武器时') and grip.contains('我方回复1.2点体力'),'grip describes actual condition, beneficiary and units')
 for kind in ['crew_relay_pin','crew_forge_spring','crew_relay_pin_plus','crew_forge_spring_plus']:
  ck(' '.join(D.effects(kind)).contains('剩余冷却最长的一件'),'advance selects one actual clock '+kind)
 for kind in ['crew_relay_spool','crew_pulse_sight','crew_supply_lens']:
  ck(' '.join(D.effects(kind)).contains('基础伤害最高的一件'),'damage selects one actual beneficiary '+kind)
 ck(' '.join(D.effects('crew_dew_vial_plus')).contains('25%') and ' '.join(D.effects('crew_dew_vial_plus')).contains('每6秒最多2点'),'overflow cap and window preserved')
 ck(' '.join(D.effects('crew_reserve_flask_plus')).contains('每6秒') and ' '.join(D.effects('crew_reserve_flask_plus')).contains('2点体力'),'upgrade uses executable stamina values')
 for kind in ['strip','corner','travel']:
  var prose=' '.join(D.effects(kind))+str(I.effects(kind))
  ck(prose.contains('接触') and prose.contains('同类不叠加'),'pocket shows contact and deduplication '+kind)
  ck(not prose.contains('完全放入') and not prose.contains('覆盖比例'),'pocket has no stale proportional wording '+kind)
 for value in [preload('res://scripts/inventory/pocket_rules.gd').profile('corner').effect,' '.join(D.effects('corner')),str(I.effects('corner'))]:
  ck(value.contains('接触') and value.contains('出手伤害') and value.contains('15%') and not value.contains('声骸效果'),'echo pocket describes actual attack damage scope')
 ck(' '.join(D.effects('pouch')).contains('每个已使用的口袋格'),'shield keeps actual occupied-cell description')
 ck(C.items==before,'display audit cannot mutate catalogue or hash inputs')
func audit_card(m:Dictionary,label:String)->void:
 fit_text(m.name,CARD.NAME,24,g.font,label+' name',20)
 fit_text(m.ability_name,CARD.ABILITY,18,g.font,label+' ability',16)
 var bonded=not str(m.get('bond_name','')).is_empty()
 fit_text(m.display_base,CARD.BASE_BONDED if bonded else CARD.BASE,18 if bonded else 21,g.body_font,label+' base',16)
 if bonded:
  fit_text('三人 · '+m.bond_name,CARD.BOND_TITLE,17,g.font,label+' bond name',16)
  fit_text(m.display_bond,CARD.BOND_TEXT,14,g.body_font,label+' bond',14)
 else:fit_text(m.display_tradeoff,CARD.TRADEOFF,15,g.body_font,label+' tradeoff',14)
 ck(not CARD.NAME.intersects(CARD.ABILITY),'name and ability rows separate '+label)
 ck(not CARD.BASE_BONDED.intersects(CARD.BOND_TITLE) and not CARD.BOND_TITLE.intersects(CARD.BOND_TEXT),'card text regions separate '+label)
func audit_layouts()->void:
 for spec in [[CREW.TITLE,'队伍搭配',36],[INVITE.TITLE,'伙伴招募',38]]:
  var safe=ART.decor_text_rect('title',spec[0])
  fit_text(spec[1],safe,spec[2],g.font,spec[1],30)
  # The cream ribbon is above the lower edge of the full decorative crop.
  ck(safe.end.y<spec[0].end.y-25,'title remains inside cream ribbon '+spec[1])
 for node in [3,6]:
  for role in ABILITIES.ROLES:
   var run=g.inventory.new_run('aemeath',116);run.round=node+1
   if node==6:run.supports=['role_1207'];run.roster=run.supports.duplicate();run.recruitment.done=[3]
   ck(R.open_draft(g.inventory,run,node),'audit opens current draft '+str(node));run.recruitment.candidates=[role]
   for m in P.draft(g.inventory,run).cards:audit_card(m,str(node)+' '+role)
  # Legacy invitation mechanics and reward labels still use the same fitted art.
  var legacy=g.inventory.new_run('aemeath',116);legacy.recruitment=R114.initial();legacy.round=node+1
  if node==6:legacy.supports=['role_1207'];legacy.roster=legacy.supports.duplicate();legacy.recruitment.done=[3]
  ck(R114.open_draft(g.inventory,legacy,node),'audit opens legacy draft '+str(node));legacy.recruitment.candidates=['role_1302','role_1505','role_1504']
  for m in P.draft(g.inventory,legacy).cards:audit_card(m,'legacy '+str(node)+' '+m.role_id)
 ck(CREW.empty_slot_label(3)=='第 3 回合结束后招募' and CREW.empty_slot_label(6)=='第 6 回合结束后招募','empty slot has explicit timing, no orphan number')
 for role in ABILITIES.ROLES:
  var m=ABILITIES.profile(role)
  fit_text(m.name+' · '+m.ability_name,Rect2(716,222,608,40),26,g.font,'team name '+role,24)
  fit_text(m.base_text,Rect2(648,284,675,73),22,g.body_font,'team base '+role,20)
  fit_text(m.bond_text,Rect2(648,747,680,88),21,g.body_font,'team bond '+role,20)
func audit_star_details()->void:
 g.run=g.inventory.new_run('aemeath',116);g.run.round=7;g.run.serial=30;g.run.shop=[{},{},{},{},{},{}]
 g.run.bags=CAPACITY.full_bags(g.inventory);g.run.stash=[]
 var grip=g.piece('crew_pulse_grip','i1',1,1)
 var first=g.piece('w_sword','i2',2,1);var second=g.piece('w_sword','i3',0,2)
 for count in 3:
  g.run.items=[grip] if count==0 else [grip,first] if count==1 else [grip,first,second]
  g.run.primary='' if count==0 else 'i2'
  ck(g.inventory.validate_run(g.run),'detail count fixture is legal '+str(count))
  var before=g.run.duplicate(true)
  g.opponent=g.inventory.snapshot(g.run,'qa-detail','详情验收')
  for origin in ['board','enemy']:
   var model=g._item_star_snapshot(grip,origin)
   ck(model.matched_count==count,'detail counts actual unique targets '+origin+' '+str(count))
   ck(model.markers.filter(func(m):return m.state=='lit').size()==count,'detail count agrees with visible markers '+origin+' '+str(count))
  var shop=g._item_star_snapshot(grip,'shop')
  ck(shop.matched_count==-1 and shop.markers.all(func(m):return m.state=='unlit'),'unowned detail does not claim actual targets')
  ck(g.run==before,'detail count query cannot mutate inventory')
 # A legal old-114 link may land on an already occupied star. The board merges
 # those coordinates; detail projection must not index it as the original size.
 g.run.recruitment=R114.initial();g.run.recruitment.done=[3,6];g.run.recruited_round=7
 g.run.roster=['role_1302','role_1207'];g.run.supports=g.run.roster.duplicate()
 for rotation in 4:
  var source=g.piece('weapon_21020024','i1',2,2);source.rotation=rotation
  var point=g.inventory.stars(source)[1];var target=g.piece('zig','i2',point.x,point.y)
  g.run.items=[source,target];g.run.primary='i1'
  g.run.recruitment.config={'link':{'mode':'star','source':'i1','target':'i2','star':0}}
  ck(g.inventory.validate_run(g.run),'old remote detail fixture is legal '+str(rotation))
  var before=g.run.duplicate(true)
  var model=g._item_star_snapshot(source,'board')
  ck(not model.is_empty(),'overlapping remote projection returns detail '+str(rotation))
  if not model.is_empty():
   ck(model.matched_count==1 and model.markers.size()==1 and model.markers[0].target_uid=='i2','overlapping remote link counts one actual target '+str(rotation))
   ck(model.markers[0].cell==point-Vector2i(source.x,source.y),'remote detail retains actual source-relative target position '+str(rotation))
   ck(model.cells==g.inventory.cells(source),'remote detail retains actual occupied shape '+str(rotation))
  ck(g.run==before,'remote projection is read-only '+str(rotation))
func set_team(roles:Array)->void:
 g.recruitment_view.clear();g.crew_setup_view.close();g.overlay=''
 g.run=g.inventory.new_run('aemeath',116);g.run.round=1 if roles.is_empty() else 4 if roles.size()==1 else 7
 g.run.roster=roles.duplicate();g.run.supports=roles.duplicate();g._open_crew_setup()
func set_draft(node:int,roles:Array)->void:
 g.recruitment_view.clear();g.crew_setup_view.close();g.overlay=''
 g.run=g.inventory.new_run('aemeath',116);g.run.round=node+1
 if node==6:g.run.roster=['role_1207'];g.run.supports=['role_1207'];g.run.recruitment.done=[3]
 ck(R.open_draft(g.inventory,g.run,node),'native draft '+str(node))
 g.run.recruitment.candidates=roles;g._sync_recruitment();g.recruitment_view.advance(1.5)
func shot(name:String)->void:
 var before=g.run.duplicate(true)
 g.queue_redraw();g.recruitment_view.queue_redraw();g.recruitment_view.foreground.queue_redraw();g.crew_setup_view.queue_redraw()
 for n in 3:await process_frame
 if capture:
  RenderingServer.force_draw(true);await process_frame
  ck(capture_viewport.get_texture().get_image().save_png(OUT+name+'.png')==OK,'capture '+name);captures.append(name)
 ck(g.run==before,'render is read-only '+name)
func native_scenes()->void:
 for size in [Vector2i(1440,960),Vector2i(1600,900)]:
  capture_viewport.size=size;capture_background.size=Vector2(size)
  # Stretch the clipped logical viewport, just like the project's keep-aspect window.
  # Applying a canvas transform directly would incorrectly reveal offstage curtains in bars.
  var factor=minf(float(size.x)/1440.0,float(size.y)/960.0)
  capture_sprite.scale=Vector2.ONE*factor
  capture_sprite.position=(Vector2(size)-Vector2(1440,960)*factor)*.5
  var prefix='%dx%d-'%[size.x,size.y]
  for n in 3:
   set_team([] if n==0 else ['role_1207'] if n==1 else ['role_1607','role_1302'])
   await shot(prefix+'team-'+str(n))
   ck(g.crew_setup_view.hits.all(func(hit):return hit.kind=='close'),'automatic team has no hidden configuration')
  for node in [3,6]:
   set_draft(node,['role_1302','role_1410','role_1106'] if node==3 else ['role_1607','role_1211','role_1506'])
   var before=g.run.duplicate(true);g.recruitment_view.select(1);g.recruitment_view.advance(.2)
   ck(g.run==before,'card selection read-only')
   await shot(prefix+'recruit-'+str(node))
  g.recruitment_view.clear();g.crew_setup_view.close();g.run=g.inventory.new_run('aemeath',116)
  for kind in display_audit.keys()+['strip','corner','travel','pouch']:
   g._open_item_details({'kind':kind,'rotation':0},'recipe');g.motion.modal_value=1;g.motion.modal_target=1;g.paint_alpha=1;g.detail_page=0
   await shot(prefix+kind)
   g._close_item_details()
  g.run=g.inventory.new_run('aemeath',116);g.run.round=7;g.run.serial=30;g.run.shop=[{},{},{},{},{},{}]
  g.run.bags=CAPACITY.full_bags(g.inventory);g.run.stash=[];g.run.primary='i2'
  g.run.items=[g.piece('crew_pulse_grip','i1',1,1),g.piece('w_sword','i2',2,1)]
  ck(g.inventory.validate_run(g.run),'native detail fixture is legal')
  g._open_item_details(g.run.items[0],'board');g.motion.modal_value=1;g.motion.modal_target=1
  await shot(prefix+'detail-one-target');g._close_item_details()
  g.run.recruitment=R114.initial();g.run.recruitment.done=[3,6];g.run.recruited_round=7
  g.run.roster=['role_1302','role_1207'];g.run.supports=g.run.roster.duplicate();g.run.primary='i1'
  g.run.items=[g.piece('weapon_21020024','i1',2,2),g.piece('zig','i2',5,3)]
  g.run.recruitment.config={'link':{'mode':'star','source':'i1','target':'i2','star':0}}
  ck(g.inventory.validate_run(g.run),'native remote detail fixture is legal')
  g._open_item_details(g.run.items[0],'board');g.motion.modal_value=1;g.motion.modal_target=1
  await shot(prefix+'detail-legacy-merged-target');g._close_item_details()
func contact_sheets()->void:
 var kinds=display_audit.keys()
 for page in 3:
  var sheet=Image.create(1920,560,false,Image.FORMAT_RGBA8)
  for n in 5:
   var source=Image.load_from_file(OUT+'1440x960-'+str(kinds[page*5+n])+'.png')
   sheet.blit_rect(source,Rect2i(16,0,384,560),Vector2i(n*384,0))
  ck(sheet.save_png(OUT+'specialty-details-'+str(page+1)+'.png')==OK,'specialty contact sheet '+str(page))
func run_tests()->void:
 audit_items()
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 capture_viewport=SubViewport.new();capture_viewport.size=viewport.size;capture_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(capture_viewport)
 capture_background=ColorRect.new();capture_background.color=Color.BLACK;capture_background.size=Vector2(viewport.size);capture_viewport.add_child(capture_background)
 capture_sprite=Sprite2D.new();capture_sprite.centered=false;capture_sprite.texture=viewport.get_texture();capture_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;capture_viewport.add_child(capture_sprite)
 g=G.new();viewport.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 audit_layouts()
 audit_star_details()
 await native_scenes()
 if capture:contact_sheets()
 var report={'checks':checks,'failures':failures,'catalogue_hash':C.catalogue_hash,'specialty_audit':display_audit,'layout_audit':layouts,'images':captures,'hidden_unfocusable':true,'isolated_storage':g.storage.root_path,'real_pointer_untouched':true}
 if capture:FileAccess.open(OUT+'result.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 g.queue_free();await process_frame;await process_frame
 print('FEEDBACK_UI_V116 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
