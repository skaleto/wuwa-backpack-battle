extends RefCounted
## Window pixels only. The game's 1440×960 logical canvas stays unchanged.
static func fit(usable:Vector2i)->Vector2i:
 var requested=Vector2(ProjectSettings.get_setting("display/window/size/window_width_override",2560),ProjectSettings.get_setting("display/window/size/window_height_override",1440))
 if usable.x<=0 or usable.y<=0:return Vector2i(1024,576)
 # Leave room for the native title bar and borders, in addition to the taskbar.
 var room=Vector2(maxi(1,usable.x-64),maxi(1,usable.y-96))
 var factor=minf(1.0,minf(room.x/requested.x,room.y/requested.y))
 return Vector2i((requested*factor).floor())
static func configure(window:Window)->void:
 if DisplayServer.get_name() not in ["Windows","macOS","X11","Wayland"]:return
 if window.is_embedded() or window.mode!=Window.MODE_WINDOWED:return
 var usable=DisplayServer.screen_get_usable_rect(window.current_screen)
 if not usable.has_area():return
 window.size=fit(usable.size)
 window.position=usable.position+(usable.size-window.size)/2
