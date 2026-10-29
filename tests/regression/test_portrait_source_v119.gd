extends SceneTree
const SKIN=preload('res://scripts/ui/visual_skin.gd')
const PRESENTER=preload('res://scripts/ui/party/recruitment_presenter.gd')
var checks=0
var failures=0
func ck(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('test')
func test():
 # The presenter contract must give every consumer the same complete-width head.
 for role in ['role_1210','role_1212','role_1507','role_1509']:
  var model=PRESENTER.portrait(role);var bounds:Rect2=model.portrait_source
  ck(model.has('head_source'),'shared avatar source '+role)
  if not model.has('head_source'):continue
  var source:Rect2=model.head_source
  ck(is_equal_approx(source.position.x,bounds.position.x) and is_equal_approx(source.size.x,bounds.size.x),'complete hair and horn width '+role)
  ck(source.position.y==bounds.position.y and bounds.encloses(source),'top preserved, crop inside source '+role)
  ck(source.size.y>=bounds.size.y*.74,'chin and lower hair retained '+role)
 print('PORTRAIT_SOURCE_V119 ',checks,' checks, ',failures,' failures');quit(1 if failures else 0)
