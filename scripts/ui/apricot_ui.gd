extends RefCounted
## Shared V74 surfaces. Art, live text, ornaments and hit targets stay separate.
const T=preload("res://scripts/ui/ui_theme.gd")
const ICONS=preload("res://scripts/ui/ability_icons.gd")
const INK=Color("493665")
const MUTED=Color("857397")
const PEACH=Color("f8d9c2")
const LILAC=Color("e1d2f6")
const EDGE=Color("baa2df")
const GOOD=Color("3a8a75")
const COST=Color("a7743e")
const MISSING=Color("bd5874")

static func box(g,rect:Rect2,fill:Color,edge:Color=Color.TRANSPARENT,radius:int=12)->void:
	var style=StyleBoxFlat.new();style.bg_color=Color(fill,fill.a*g.paint_alpha)
	style.border_color=Color(edge,edge.a*g.paint_alpha);style.set_border_width_all(1 if edge.a>0 else 0)
	style.set_corner_radius_all(radius);style.anti_aliasing=true
	g.draw_style_box(style,Rect2(rect.position+g.paint_offset,rect.size))

static func panel(g,rect:Rect2)->void:
	T.surface(g,Rect2(rect.position+g.paint_offset,rect.size),"apricot_panel",g.paint_alpha)

static func header(g,rect:Rect2)->void:
	box(g,rect,LILAC,Color(EDGE,.5),12)
	# Low contrast woven diamonds: decoration only, never an item/star slot.
	var side=rect.size.y*.42
	for i in range(int((rect.size.x-24)/(side*2))):
		var p=rect.position+Vector2(18+side+i*side*2,rect.size.y*.5)+g.paint_offset
		g.draw_colored_polygon(PackedVector2Array([p-Vector2(side,0),p-Vector2(0,side),p+Vector2(side,0),p+Vector2(0,side)]),Color("f5eaff",g.paint_alpha*.26))

static func title(g,text:String,at:Vector2,icon:String="star",size:int=18)->void:
	ICONS.draw(g,icon,Rect2(at+Vector2(0,-size)+g.paint_offset,Vector2.ONE*(size+4)),g.paint_alpha)
	g._text(text,at+Vector2(size+11,0),size,INK)

static func button(g,rect:Rect2,label:String,id:String,enabled:bool=true,primary:bool=false)->void:
	if rect.size.x>=100 and rect.size.x>rect.size.y*1.85:
		g._button(rect,label,id,enabled)
		return
	g._button(rect,"",id,enabled,false)
	var hover=g.motion.hover("apricot:"+id,rect.has_point(g.mouse-g.paint_offset) and enabled)
	var down=clampf(float(g.motion.presses.get(id,0))/.16,0,1)
	var face=rect;face.position.y+=down*1.5-hover*1.5
	var fill=Color("8274d4") if primary else Color("ecdef7")
	fill=fill.lightened(hover*.10);fill.a=1 if enabled else .48
	box(g,Rect2(face.position+Vector2(0,2),face.size),Color("6c5392",.20),Color.TRANSPARENT,16)
	box(g,face,Color("a797eb") if primary else Color("cfb9e6"),Color("8d74b9",.8 if enabled else .3),16)
	box(g,face.grow(-2),Color("fff2ed",.8 if enabled else .25),Color.TRANSPARENT,14)
	box(g,face.grow(-4),fill,Color("b4a4ed",.9 if enabled else .2),12)
	var size=16 if rect.size.y<40 else 18
	var width=g.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	g._text(label,face.position+Vector2((face.size.x-width)*.5,face.size.y*.5+size*.34),size,Color("fff3e9") if primary else Color(INK,1 if enabled else .45))

static func stat(g,at:Vector2,width:float,label:String,value:String,icon:String="",tint:Color=INK)->void:
	box(g,Rect2(at,Vector2(width,29)),Color(PEACH,.7),Color.TRANSPARENT,12)
	if label=="间隔":
		var center=at+Vector2(20,14)+g.paint_offset
		g.draw_circle(center,9,Color(INK,g.paint_alpha),false,1.5,true)
		g.draw_polyline(PackedVector2Array([center+Vector2(0,-5),center,center+Vector2(4,1)]),Color(INK,g.paint_alpha),1.5,true)
	if not icon.is_empty():ICONS.draw(g,icon,Rect2(at+Vector2(8,3)+g.paint_offset,Vector2(23,23)),g.paint_alpha)
	g._text(label,at+Vector2(38 if not icon.is_empty() or label=="间隔" else 12,21),16,INK)
	var size=17
	while size>12 and g.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width*.58:size-=1
	var length=g.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	g._text(value,at+Vector2(width-length-12,21),size,tint)

static func lines(g,value:String,width:float,size:int)->Array:
	var result=[];var line="";var used=0.0;var at=0
	var font=g.body_font if g.body_font and size<=19 else g.font
	while at<value.length():
		var part=value[at];at+=1
		if part=="[" and value.find("]",at)>=at:
			var end=value.find("]",at);part="["+value.substr(at,end-at)+"]";at=end+1
		var w=size+3 if part.begins_with("[") else font.get_string_size(part,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		if part=="\n" or (used+w>width and not line.is_empty() and part not in ["。","，","；","：","、","！","？","%","）"]):result.append(line);line="";used=0
		if part!="\n":line+=part;used+=w
	if not line.is_empty():result.append(line)
	return result

static func rich(g,text:String,at:Vector2,size:int=16,color:Color=INK)->void:
	var x=at.x;var i=0
	var font=g.body_font if g.body_font and size<=19 else g.font
	while i<text.length():
		if text[i]=="[" and text.find("]",i)>i:
			var end=text.find("]",i);var key=text.substr(i+1,end-i-1)
			ICONS.draw(g,key,Rect2(Vector2(x,at.y-size+2)+g.paint_offset,Vector2.ONE*(size+1)),g.paint_alpha)
			x+=size+3;i=end+1
		else:
			g._text(text[i],Vector2(x,at.y),size,color);x+=font.get_string_size(text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x;i+=1

static func pages(g,paragraphs:Array,width:float,height:float,size:int=16)->Array:
	var result=[[]];var used=0.0
	for paragraph in paragraphs:
		var wrapped=lines(g,str(paragraph),width,size)
		var paragraph_height=wrapped.size()*(size+7)
		if paragraph_height<=height and used+paragraph_height>height and not result[-1].is_empty():result.append([]);used=0
		for line in wrapped:
			if used+size+7>height and not result[-1].is_empty():result.append([]);used=0
			result[-1].append({"text":line,"y":used});used+=size+7
		used+=7
	return result

static func text_page(g,content:Array,at:Vector2,size:int=16)->void:
	for row in content:rich(g,row.text,at+Vector2(0,row.y+size),size)

static func shop(g,rect:Rect2,alpha:float)->void:
	var saved=g.paint_alpha;g.paint_alpha=alpha
	panel(g,rect)
	header(g,Rect2(rect.position+Vector2(11,16),Vector2(rect.size.x-22,62)))
	for n in 11:
		var fill=Color("ebd9ec") if n%2 else Color("f8e4c9")
		box(g,Rect2(rect.position+Vector2(14+n*37,68),Vector2(37,25)),fill,Color("c7aeda",.42),12)
	for y in [217.0,428.0]:
		box(g,Rect2(rect.position.x+22,y,rect.size.x-44,173),Color("f4c9ad",.19),Color.TRANSPARENT,52)
	g.paint_alpha=saved
