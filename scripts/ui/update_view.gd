extends RefCounted
const T=preload("res://scripts/ui/ui_theme.gd")
const Q=preload("res://scripts/ui/visual_skin.gd")
static func draw(p:Dictionary,u:Dictionary)->void:
 var safe=u.safe;var a=u.alpha;var r=Rect2(340,130,760,700)
 p.rect.call(Rect2(0,0,1440,960),Color(Q.PLUM,.62*a));p.surface.call(r,"detail_panel",a)
 p.text.call("游戏更新",Vector2(403,204),35,Q.PLUM)
 p.button.call(Rect2(883,157,168,54),u.get("dismiss_label","返回"),"updates:back")
 p.text.call("当前版本  "+u.version,Vector2(410,265),23,Q.PLUM)
 var messages={"idle":"检查是否有新的版本","checking":"正在检查更新…","current":"已是最新版本","available":"有新版本可以下载","downloading":"正在下载，可返回游戏继续游玩","verifying":"正在校验更新文件…","ready":"更新已准备好","installing":"正在准备重启，请稍候…","error":u.error_message,"unsupported":"此平台请通过原来的安装渠道更新。"}
 p.wrapped.call(messages.get(u.status,""),Vector2(410,322),610,23,Q.PLUM)
 if not u.available.is_empty():
  p.text.call(str(u.available.version),Vector2(410,385),27,Q.PLUM)
  var y=427
  for note in u.available.get("notes",[]).slice(0,4):
   p.wrapped.call(str(note),Vector2(415,y),610,19,Q.PLUM,2);y+=51
 if u.status in ["downloading","verifying"]:
  var from=Vector2(415,651);var to=Vector2(1025,651)
  p.line.call(from,to,Color("d7c8e8",a),13,true)
  var fraction=clampf(float(u.downloaded)/maxi(1,u.total),0,1)
  if fraction>0:p.line.call(from,from.lerp(to,fraction),Color("a78bd8",a),13,true)
  p.text.call("校验中…" if u.status=="verifying" else "%0.1f / %0.1f MB"%[u.downloaded/1048576.0,u.total/1048576.0],Vector2(415,687),18,Q.PLUM)
 elif u.status=="available" and u.artifact.get("kind","")!="web":
  p.text.call(("资源更新" if u.artifact.kind=="patch" else "完整客户端更新")+" · %.1f MB"%(float(u.artifact.bytes)/1048576.0),Vector2(415,665),20,Q.PLUM)
 elif u.status=="ready" and not safe:
  p.text.call("可以继续游玩，也可以结束未完成的对局后更新。",Vector2(415,630),19,Q.PLUM)
  var index=0
  for unfinished in u.get("unfinished",[]):
   p.button.call(Rect2(410+index*315,653,300,49),"结束"+unfinished.label+" · 第 %d 回合"%unfinished.round,"updates:end:"+unfinished.mode)
   index+=1
  if u.get("unfinished",[]).is_empty():p.text.call("返回主界面即可重启更新。",Vector2(415,674),20,Q.PLUM)
 elif u.status=="ready":p.text.call("重启后生效，存档与设置会保留。",Vector2(415,655),20,Q.PLUM)
 match u.status:
  "idle","current":p.button.call(Rect2(785,730,254,54),"检查更新","updates:check")
  "available":p.button.call(Rect2(785,730,254,54),"刷新到新版" if u.platform=="Web" else "下载更新","updates:download")
  "downloading","checking":p.button.call(Rect2(785,730,254,54),"取消","updates:cancel")
  "ready":p.button.call(Rect2(785,730,254,54),"刷新到新版" if u.platform=="Web" else "重启并更新","updates:restart",safe)
  "error":
   if u.get("full_download",false):p.button.call(Rect2(410,730,260,54),"打开下载目录","updates:files")
   p.button.call(Rect2(785,730,254,54),"重试","updates:retry")
