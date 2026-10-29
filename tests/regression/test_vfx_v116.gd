extends SceneTree
const G=preload('res://tests/fixtures/travel_fixture_v64.gd')
const V=preload('res://scripts/ui/battle/combat_vfx.gd')
const Q=preload('res://scripts/ui/items/item_quality.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 root.hide();root.unfocusable=true;AudioServer.set_bus_mute(0,true);call_deferred('run_tests')
func run_tests():
 ck(FileAccess.file_exists('res://scripts/ui/battle/vfx_sprites.gd'),'sampled VFX renderer integrated')
 if failures:print('VFX_V116 ',checks,' checks, ',failures,' failures');quit(1);return
 var fx=load('res://scripts/ui/battle/vfx_sprites.gd')
 var loading_start=Time.get_ticks_usec()
 for key in ['light_01','light_02','light_03','star_04','star_06','slash_01','slash_02','circle_03','muzzle_03','spark_04','twirl_01']:
  var t=fx.texture(key);ck(t!=null and t.get_width()==512,'original authored particle loaded '+key)
  if DisplayServer.get_name()!='headless' and t!=null:
   var pixels=t.get_image();var covered=0;var original=Image.load_from_file('res://assets/vfx/kenney/'+key+'.png')
   for y in range(0,512,16):
    for x in range(0,512,16):
     var pixel=pixels.get_pixel(x,y)
     ck(is_equal_approx(pixel.a,original.get_pixel(x,y).a),'authored coverage retained '+key)
     if pixel.a>.01:
      covered+=1
      ck(pixel.r==1 and pixel.g==1 and pixel.b==1,'luminous mask cannot paint dark mist '+key)
   ck(covered>0,'luminous mask retains visible coverage '+key)
 print('VFX mask cold load: ',(Time.get_ticks_usec()-loading_start)/1000.0,' ms; future draws reuse cached textures')
 ck(FileAccess.get_file_as_string('res://assets/vfx/kenney/LICENSE.txt').contains('CC0'),'third party license retained')
 var impacts=V.new()
 for kind in ['sword','broadblade','gauntlet','pistol','rectifier','echo']:
  impacts.spawn(Vector2(100,200),0,kind,Color.CYAN,true)
 ck(impacts.impacts.size()==6,'all actual impact families accepted')
 var snapshot=impacts.impacts.duplicate(true);impacts.update(0)
 ck(impacts.impacts==snapshot,'paused presentation does not age impact')
 impacts.update(.15);ck(impacts.impacts.size()==6,'impact remains visible after travel arrival')
 impacts.update(1);ck(impacts.impacts.is_empty(),'expired particles removed')
 for n in 100:impacts.spawn(Vector2.ZERO,0,'sword',Color.WHITE)
 ck(impacts.impacts.size()<=18,'dense combat effects bounded');impacts.clear()
 var g=G.new();root.add_child(g);await process_frame;g.set_process(false);g.set_process_input(false)
 var selected=g.run.items[0];g.detail_item=selected;g.detail_origin='board';g.item_selection_age=.1
 var before=g.run.duplicate(true);var pose=g._star_pose(selected,g.BOARD)
 ck(pose!=Transform2D.IDENTITY,'clicked stars visibly share item lift')
 for turn in 4:
  var p=selected.duplicate(true);p.rotation=turn
  var at=g._piece_position(p,g.BOARD,0)
  ck(g._star_pose(p,g.BOARD).is_equal_approx(g._piece_pose(p,at,g._projection_for(p.kind,turn,g.CELL),0)*Transform2D(0,at-g.BOARD-Vector2(p.x,p.y)*g.CELL)),'same body-star transform '+str(turn))
 var markers=g._effect_star_markers(selected,g.run.items,g.run)
 ck(markers.filter(func(m):return m.state=='lit').is_empty(),'no glow invents an empty-slot activation')
 ck(g.run==before,'presentation does not mutate inventory')
 var size=Vector2(260,70)
 for k in ['heron','weapon_21020076']:
  ck(Q.surface_bands(k,size,1)==Q.surface_bands(k,size,1),'paused deterministic aura '+k)
  var frames=range(20).map(func(n):return Q.surface_bands(k,size,n*.2))
  ck(frames.any(func(f):return not f.is_empty()) and frames.any(func(f):return f!=frames[0]),'animated surface light '+k)
 ck(Q.surface_bands('w_sword',size,1).is_empty(),'low quality stays quiet')
 g.queue_free();await process_frame;await create_timer(.2).timeout
 print('VFX_V116 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
