extends Node2D
## Render-only: committed full silhouettes converge, then release local embers.
signal sound_cue(key:String)
signal stopped
const WHITE_SHADER="shader_type canvas_item; uniform float whiten=0.0; void fragment(){ vec4 c=COLOR; COLOR=vec4(mix(c.rgb,vec3(1.0),whiten),c.a); }"
const GLOW_SHADER="""shader_type canvas_item;
render_mode blend_add;
uniform float strength=0.0;
uniform float radius=12.0;
void fragment(){
	vec2 d=TEXTURE_PIXEL_SIZE*radius;
	float a=texture(TEXTURE,UV).a*.12;
	a+=(texture(TEXTURE,UV+vec2(d.x,0)).a+texture(TEXTURE,UV-vec2(d.x,0)).a+texture(TEXTURE,UV+vec2(0,d.y)).a+texture(TEXTURE,UV-vec2(0,d.y)).a)*.10;
	a+=(texture(TEXTURE,UV+d*.7).a+texture(TEXTURE,UV-d*.7).a+texture(TEXTURE,UV+vec2(d.x,-d.y)*.7).a+texture(TEXTURE,UV+vec2(-d.x,d.y)*.7).a)*.07;
	a+=(texture(TEXTURE,UV+vec2(d.x*1.8,0)).a+texture(TEXTURE,UV-vec2(d.x*1.8,0)).a+texture(TEXTURE,UV+vec2(0,d.y*1.8)).a+texture(TEXTURE,UV-vec2(0,d.y*1.8)).a)*.05;
	// strength already includes material fade. Fragment COLOR.a contains the
	// center texel alpha, which would erase the blur outside the silhouette.
	COLOR=vec4(vec3(1.0),a*strength);
}"""
const DURATION=1.25
const LAND_AT=.94
const SPARK_COUNT=18
var age=0.0
var landed=false
var output_uid=""
var parts:Array=[]
var destination=Vector2.ZERO
var shader:Shader
var glow_shader:Shader
var foreground:Node2D
func start(sources:Array,at:Vector2,uid:String)->void:
	finish();age=0;landed=false;output_uid=uid;destination=at
	if not active():return
	if shader==null:shader=Shader.new();shader.code=WHITE_SHADER
	if glow_shader==null:glow_shader=Shader.new();glow_shader.code=GLOW_SHADER
	for source in sources:
		var glow=Sprite2D.new();glow.centered=false;glow.texture=source.texture
		glow.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var halo=ShaderMaterial.new();halo.shader=glow_shader
		halo.set_shader_parameter("radius",4.0/maxf(.01,source.pose.get_scale().abs().x))
		glow.material=halo;glow.transform=source.pose;add_child(glow)
		var sprite=Sprite2D.new();sprite.centered=false;sprite.z_index=1
		sprite.texture=source.texture
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mat=ShaderMaterial.new();mat.shader=shader;sprite.material=mat
		sprite.transform=source.pose;add_child(sprite)
		parts.append({"sprite":sprite,"glow":glow,"pose":source.pose,"center":source.center,"at":source.center})
	# CanvasItem's own drawing appears below its children. A foreground child
	# keeps the landing sparks visible over the converging full silhouettes.
	foreground=Node2D.new();foreground.name="FusionEmbers";foreground.z_index=2
	add_child(foreground);foreground.draw.connect(_draw_effects)
	visible=true
func active()->bool:return not output_uid.is_empty()
func output_alpha(uid:String)->float:
	return smoothstep(LAND_AT,1.20,age) if uid==output_uid else 1.0
func advance(delta:float)->void:
	if not active():return
	age+=maxf(0.0,delta)
	if not landed and age>=LAND_AT:
		landed=true;sound_cue.emit("fusion_land")
	if age>=DURATION:finish(false);return
	var merge=smoothstep(.26,LAND_AT,age)
	var shrink=lerpf(1.0,.72,smoothstep(.82,1.06,age))
	for part in parts:
		var sprite:Sprite2D=part.sprite
		part.at=part.center.lerp(destination,merge)+Vector2(0,-sin(merge*PI)*12)
		sprite.transform=Transform2D(0,Vector2.ONE*shrink,0,part.at)*Transform2D(0,-part.center)*Transform2D(part.pose)
		sprite.material.set_shader_parameter("whiten",smoothstep(.03,.42,age))
		sprite.modulate.a=1-smoothstep(LAND_AT,1.06,age)
		part.glow.transform=sprite.transform
		part.glow.material.set_shader_parameter("strength",.70*smoothstep(.03,.35,age)*sprite.modulate.a)
	foreground.queue_redraw()
func finish(cancelled:bool=true)->void:
	if cancelled:stopped.emit()
	for child in get_children():child.free()
	parts=[];foreground=null;output_uid="";visible=false
func effect_projection()->Dictionary:
	var result={"gather":[],"sparks":[],"flash":{"radius":0.0,"alpha":0.0}}
	if not active():return result
	if age<LAND_AT:
		var glow=smoothstep(.28,.50,age)*(1-smoothstep(.76,LAND_AT,age))
		if glow<=0:return result
		for i in parts.size():
			for n in 3:
				var angle=float(n)*TAU/3.0+float(i)*1.7+age*.7
				var offset=Vector2.from_angle(angle)*(12+n*5)
				result.gather.append({"position":parts[i].at+offset,"radius":.9+float(n%2)*.3,"alpha":glow*.55})
		return result
	var t=clampf((age-LAND_AT)/(DURATION-LAND_AT),0,1)
	result.flash={"radius":26.0-8.0*t,"alpha":.85*(1-smoothstep(0,.42,t))}
	for n in SPARK_COUNT:
		# Fixed angular/radial variation gives an ember burst without borrowing
		# gameplay RNG or storing another simulation with its own clock.
		var angle=TAU*float(n)/SPARK_COUNT+.12*sin(float(n)*2.1)
		var direction=Vector2.from_angle(angle)
		var distance=4.0+(50.0+float(n%5)*7.0)*(1-pow(1-t,2))
		var at=destination+direction*distance+Vector2(0,11*t*t)
		result.sparks.append({"position":at,"tail":at-direction*(5+n%3*2)*(1-t),"radius":lerpf(1.6+float(n%4)*.4,.35,t),"alpha":pow(1-t,1.4)})
	return result
func _draw_effects()->void:
	var projection=effect_projection()
	var flash=projection.flash
	if flash.alpha>0:
		for n in range(3,0,-1):
			foreground.draw_circle(destination,flash.radius*float(n)/3.0,Color(1,1,1,flash.alpha*.10))
		foreground.draw_circle(destination,6,Color(1,1,1,flash.alpha*.75))
	for mote in projection.gather:
		foreground.draw_circle(mote.position,mote.radius*2.2,Color(1,1,1,mote.alpha*.12))
		foreground.draw_circle(mote.position,mote.radius,Color(1,1,1,mote.alpha))
	for spark in projection.sparks:
		foreground.draw_line(spark.tail,spark.position,Color(1,1,1,spark.alpha*.55),maxf(.6,spark.radius*.7),true)
		foreground.draw_circle(spark.position,spark.radius*2.2,Color(1,1,1,spark.alpha*.12))
		foreground.draw_circle(spark.position,spark.radius,Color(1,1,1,spark.alpha))
