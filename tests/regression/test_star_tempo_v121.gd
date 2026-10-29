extends SceneTree
const STAR=preload('res://scripts/ui/items/chibi_effect_star.gd')
const PLACEMENT=preload('res://scripts/ui/items/placement_star_feedback.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():
 ck(STAR.click_wave(.05).alpha>0,'click responds immediately')
 ck(STAR.click_wave(.13).scale>STAR.click_wave(.04).scale,'short wave still expands')
 ck(STAR.click_wave(.36).alpha==0,'click wave finishes within a short beat')
 for index in 10:
  var settled=STAR.core_motion(.39,index)
  ck(settled.scale==Vector2.ONE and settled.offset==Vector2.ZERO and settled.angle==0,'all independent cores settle before .4 seconds '+str(index))
 ck(STAR.core_motion(.08,0)!=STAR.core_motion(.08,3),'short timing preserves independent stagger')
 var f=PLACEMENT.new();var fact={'source_uid':'s','target_uid':'t','cell':Vector2i(1,0),'state':'lit'}
 f.record([],[fact]);f.update(.12);ck(f.markers().size()==1,'placement success has a readable short flash')
 f.update(.33);ck(f.markers().is_empty(),'placement flash disappears within .45 seconds')
 ck(STAR.click_wave(-1).alpha==0 and STAR.core_motion(-1).scale==Vector2.ONE,'no ambient looping added')
 print('STAR_TEMPO_V121 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
