extends SceneTree
const FORM=preload('res://scripts/ui/pockets/bag_form.gd')
const SLOT=preload('res://scripts/ui/pockets/bag_slots.gd')
const Q=preload('res://scripts/ui/items/item_quality.gd')
const FX=preload('res://scripts/ui/items/item_glints.gd')
const INV=preload('res://scripts/inventory/inventory.gd')
const CAP=preload('res://tests/fixtures/capacity_fixture_v111.gd')
const TERMINAL=preload('res://scripts/ui/pockets/terminal_grid.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('test')
func test():
 var inv=INV.new();var original=CAP.full_bags(inv);var bags=TERMINAL.form_bags(original);var snapshot=bags.duplicate(true)
 for pitch in [64.0,96.0]:
  for turn in 4:
   bags[0].rotation=turn
   ck(FORM.cached_patches(bags,pitch)==FORM.patches(bags,pitch),'cached complete geometry agrees with uncached rotation '+str(turn))
 var before=FORM.cached_patches(bags,96.0).duplicate(true)
 bags[0].cells=[Vector2i(7,6)]
 ck(FORM.cached_patches(bags,96.0)!=before,'moving bags invalidates actual layout')
 for n in 50:
  bags[0].uid='changing'+str(n);FORM.cached_patches(bags,96)
 ck(FORM.draw_geometry.size()<=FORM.GEOMETRY_LIMIT,'dragging cannot grow geometry cache without bound')
 for variant in 4:
  for feathered in [true,false]:
   var mesh=SLOT.slot_mesh(variant,feathered)
   ck(mesh==SLOT.slot_mesh(variant+4,feathered),'shared fixed mesh per shape and layers')
   ck(mesh.get_surface_count()==1,'slot layers batched in one surface')
 ck(Q.glow_texture()==Q.glow_texture(),'radial glow reused instead of regenerated')
 ck(FX.particles('w_sword',Vector2(500,200),1).is_empty(),'no low-quality particles')
 ck(FX.particles('satchel',Vector2(500,200),1).is_empty(),'bags have no rarity particles')
 var active=0
 for kind in FX.anchors:
  var entry=FX.anchors[kind];var size=Vector2(entry.size[0],entry.size[1])
  var all=[]
  for n in 8:
   var at=n*.23;var particles=FX.particles(kind,size,at)
   ck(particles==FX.particles(kind,size,at),'pause/seek deterministic '+kind)
   ck(particles.size()<=11,'bounded emitter count (V122 richer budget) '+kind)
   for p in particles:
    ck(Rect2(Vector2.ZERO,size).has_point(p.anchor),'emitter inside source texture')
    ck(p.position.distance_to(p.anchor)<maxf(size.x,size.y)*.06,'short edge drift, no rectangle orbit')
   all.append(particles)
  if all.any(func(p):return not p.is_empty()):active+=1
 ck(active==FX.anchors.size(),'all sampled high-quality items emit')
 print('RENDER_CACHE_V120 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
