extends SceneTree
var failures=0
func ck(ok:bool,label:String)->void:
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 ck(ProjectSettings.get_setting("display/window/size/window_width_override")==2560,"desktop requests QHD width")
 ck(ProjectSettings.get_setting("display/window/size/window_height_override")==1440,"desktop requests QHD height")
 ck(ProjectSettings.get_setting("display/window/stretch/mode")=="canvas_items","native resolution rendering, not a low-resolution framebuffer")
 ck(ProjectSettings.get_setting("display/window/size/viewport_width")==1440 and ProjectSettings.get_setting("display/window/size/viewport_height")==960,"logical layout and input coordinates remain stable")
 var path="res://scripts/ui/desktop_window.gd"
 if not ResourceLoader.exists(path):ck(false,"desktop sizing policy exists")
 else:
  var policy=load(path)
  ck(policy.fit(Vector2i(3840,2100))==Vector2i(2560,1440),"large displays get the requested size")
  for usable in [Vector2i(2560,1400),Vector2i(1920,1040),Vector2i(1280,720)]:
   var fitted=policy.fit(usable)
   ck(fitted.x<=usable.x-64 and fitted.y<=usable.y-96,"window and decorations fit the work area")
   ck(absf(float(fitted.x)/fitted.y-16.0/9.0)<.005,"fitted window retains widescreen aspect")
  ck(policy.fit(Vector2i.ZERO).x>0,"invalid work area has a safe fallback")
 print("DESKTOP RESOLUTION ",failures," failures");quit(1 if failures else 0)
