extends RefCounted
## Approved V116 footprints and matching stars; combat/economy fields are unchanged.
const CHANGES={
	"weapon_21010046":{"shape":[[0,0],[1,0],[2,0],[3,0]],"stars":[[0,1],[1,1],[2,1]]},
	"weapon_21010056":{"shape":[[0,0],[1,0],[2,0],[3,0]],"stars":[[0,1],[1,1],[2,1]]},
	"weapon_21010066":{"shape":[[0,0],[1,0],[2,0],[3,0]],"stars":[[0,1],[1,1],[2,1]]},
	"weapon_21020064":{"shape":[[0,0],[1,0],[2,0]],"stars":[[0,2],[2,2],[0,1]]},
	"weapon_21020086":{"shape":[[0,0],[1,0],[2,0],[3,0]],"stars":[[0,2],[3,2],[1,-1],[3,-1]]},
	"weapon_21020107":{"shape":[[0,0],[1,0],[2,0],[3,0]],"stars":[[0,1],[1,1],[2,1]]},
	"weapon_21030015":{"shape":[[0,0],[1,0]],"stars":[[0,1],[1,1],[3,0]]},
	"weapon_21030024":{"shape":[[0,0],[1,0]],"stars":[[0,1],[1,1],[3,0]]},
	"weapon_21030026":{"shape":[[0,0],[1,0]],"stars":[[0,2],[1,2],[0,1]]},
	"weapon_21030034":{"shape":[[0,0],[1,0]],"stars":[]},
	"weapon_21030036":{"shape":[[0,0],[1,0]],"stars":[[0,2],[1,2],[0,1]]},
	"weapon_21030044":{"shape":[[0,0],[1,0]],"stars":[[0,2],[1,2],[0,1]]},
	"weapon_21030045":{"shape":[[0,0],[1,0]],"stars":[[0,2],[1,2],[0,1]]},
	"weapon_21030046":{"shape":[[0,0],[1,0]],"stars":[[0,2],[1,2],[0,1]]},
	"weapon_21030056":{"shape":[[0,0],[1,0]],"stars":[[0,2],[1,2],[0,1]]},
	"weapon_21030064":{"shape":[[0,0],[1,0]],"stars":[[0,1],[1,1],[3,0]]},
	"weapon_21030066":{"shape":[[0,0],[1,0]],"stars":[[0,1],[1,1],[1,-2]]},
	"weapon_21030074":{"shape":[[0,0],[1,0]],"stars":[]},
	"weapon_21030084":{"shape":[[0,0],[1,0]],"stars":[]},
	"weapon_21030094":{"shape":[[0,0],[1,0]],"stars":[]},
	"weapon_21030104":{"shape":[[0,0],[1,0]],"stars":[[1,2],[0,1],[1,1]]},
	"contract":{"shape":[[0,0]],"stars":[[1,0],[1,1]]},
	"contract_echo":{"shape":[[0,0]],"stars":[[1,0],[1,1],[-2,0]]},
	"contract_oath":{"shape":[[0,0]],"stars":[[-2,0],[-2,1],[1,0],[1,1]]},
	"judgment":{"shape":[[0,0]],"stars":[[0,1],[2,0],[-2,0]]},
	"field_notes":{"shape":[[0,0]],"stars":[]},
	"echo_butterfly":{"shape":[[0,0]],"stars":[[0,1],[1,1]]}
}
static func apply(source:Dictionary)->Dictionary:
 var data=source.duplicate(true)
 for kind in CHANGES:
  var item=data.items[kind];var spec=CHANGES[kind]
  item.shape=spec.shape.duplicate(true);item.stars=spec.stars.duplicate(true)
  if item.has("space"):item.space=item.shape.size()
  if item.has("v75"):
   for key in ["shape","stars"]:
    if item.v75.has(key):item.v75[key]=spec[key].duplicate(true)
   if item.v75.has("space"):item.v75.space=item.shape.size()
 return data
