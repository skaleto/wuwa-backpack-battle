extends RefCounted
## Installation identity only. No hardware fingerprint and no cloud credentials.
## Callbacks keep persistence/network independent of gameplay and testable.
signal completed(result:Dictionary)
var read_config:Callable
var save_config:Callable
var request_session:Callable
var busy=false
var last_result:Dictionary={}
func configure(read:Callable,save:Callable,request:Callable)->void:
 read_config=read;save_config=save;request_session=request
func ensure(endpoint:String,deadline:int)->Dictionary:
 if busy:
  while busy:
   if Time.get_ticks_msec()>=deadline:return {"ok":false,"error":"network"}
   await Engine.get_main_loop().process_frame
  return last_result.duplicate(true)
 busy=true
 var result=await _ensure(endpoint,deadline)
 last_result=result;busy=false;completed.emit(result)
 return result
func _ensure(endpoint:String,deadline:int)->Dictionary:
 var config:Dictionary=read_config.call()
 if config.get("url",endpoint)!=endpoint:return {"ok":false,"error":"identity_endpoint"}
 var device=config.get("device",{})
 if not device is Dictionary:return {"ok":false,"error":"invalid_identity"}
 if not device.is_empty() and (not _hex(device.get("installation_id"),32) or not _hex(device.get("secret"),64)):return {"ok":false,"error":"invalid_identity"}
 if device.get("bound",false) and float(config.get("expires_at",0))>Time.get_unix_time_from_system()+30 and not str(config.get("token","")).is_empty():return {"ok":true}
 if device.is_empty():
  device={"installation_id":Crypto.new().generate_random_bytes(16).hex_encode(),"secret":Crypto.new().generate_random_bytes(32).hex_encode(),"bound":false}
  config=config.duplicate(true);config.device=device;config.url=endpoint
  if not save_config.call(config):return {"ok":false,"error":"save_failed"}
 var headers:PackedStringArray=[]
 if not device.get("bound",false) and not str(config.get("player_id","")).is_empty():
  if str(config.get("token","")).is_empty():return {"ok":false,"error":"auth_expired"}
  headers.append("Authorization: Bearer "+str(config.token))
 var response:Dictionary=await request_session.call(endpoint+"/devices/session",{"installation_id":device.installation_id,"secret":device.secret},headers,deadline)
 if not response.get("ok",false):return {"ok":false,"error":response.get("error","network")}
 var data=response.get("data",{})
 if not data is Dictionary or not preload("res://scripts/online/async_pvp.gd").safe_id(data.get("player_id")) or not data.get("token") is String or str(data.token).is_empty() or not (data.get("expires_at") is float or data.get("expires_at") is int) or float(data.expires_at)<=Time.get_unix_time_from_system():return {"ok":false,"error":"invalid_session"}
 if not str(config.get("player_id","")).is_empty() and data.player_id!=config.player_id:return {"ok":false,"error":"identity_changed"}
 var next=config.duplicate(true);next.merge(data,true);next.device.bound=true;next.erase("activation")
 if not save_config.call(next):return {"ok":false,"error":"save_failed"}
 return {"ok":true}
func _hex(value:Variant,length:int)->bool:
 if not value is String or value.length()!=length:return false
 for c in value:
  if not c in "0123456789abcdef":return false
 return true
