extends RefCounted
## First approved Dango composition. All preparation input and drawing share it.
const SPACE=preload("res://scripts/inventory/item_space.gd")
# Fit the complete logical board into the existing panel with square cells.
const BOARD_AREA=Rect2(288,180,640,480)
const PITCH=minf(BOARD_AREA.size.x/SPACE.WIDTH,BOARD_AREA.size.y/SPACE.HEIGHT)
const GRID_SIZE=Vector2(SPACE.WIDTH,SPACE.HEIGHT)*PITCH
const ORIGIN=BOARD_AREA.position+(BOARD_AREA.size-GRID_SIZE)*.5
const BOARD=Rect2(ORIGIN,GRID_SIZE)
const BOARD_FRAME=Rect2(265,110,692,572)
const SHOP=Rect2(972,116,440,620)
const STASH_FRAME=Rect2(272,694,680,140)
const STASH=Rect2(288,742,640,74)
const BATTLE=Rect2(1190,750,200,200)
const REFRESH=Rect2(1310,630,76,76)
const CATALOGUE=Rect2(994,668,150,48)
const SORT=Rect2(480,860,132,52)
const FORGE=Rect2(690,860,132,52)
const SELL=Rect2(875,862,52,52)
const RECRUIT=Rect2(40,842,208,68)
const ACTOR=Rect2(10,336,253,326)
const NAME=Rect2(37,665,205,43)
static func offer(index:int)->Rect2:
	return Rect2(992+(index%3)*134,207+floori(index/3.0)*211,128,181)
static func price(index:int)->Rect2:
	return Rect2(offer(index).position+Vector2(0,142),Vector2(128,37))
static func offer_control(index:int)->Rect2:
	return Rect2(price(index).position+Vector2(96,0),Vector2(32,37))
static func stash(index:int)->Rect2:
	return Rect2(STASH.position+Vector2(index*(640.0/6.0),0),Vector2(640.0/6.0,74))
static func crew_center(index:int)->Vector2:return Vector2(87+index*105,767)
static func inside_circle(rect:Rect2,point:Vector2)->bool:
	return rect.get_center().distance_to(point)<=minf(rect.size.x,rect.size.y)*.5
