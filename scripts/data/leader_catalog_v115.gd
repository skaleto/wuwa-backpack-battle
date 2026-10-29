extends RefCounted
## New selection only; historical character definitions remain intact.
static func apply(source:Dictionary)->Dictionary:
 var data=source.duplicate(true)
 for row in [['jingran','role_1212','w_broadblade','charge',6,'充能'],['zani','role_1507','w_gauntlet','shield',6,'护盾'],['lynae','role_1509','w_pistol','max_hp',8,'生命上限']]:
  var role=data.roster[row[1]];var opening=row[5]+' +'+str(row[4])
  data.characters[row[0]]={'name':role.name,'sprite':0,'element':role.element,'starter':row[2],'starter_supply':'daily_tea','weapon_type':role.weapon_type,'core':'','passive':'开场'+opening,'burst':'','burst_damage':0,'roster_id':row[1],'avatar_path':role.avatar_path,'bust_path':role.bust_path,'route':'open','v60_opening':[{'type':row[3],'value':row[4]}],'v60_traits':[['开场',opening],['路线','由物品组合决定']],'adaptation_summary':'本作改编：开场'+opening,'source_page':role.source_page}
 data.selectable_leaders=['aemeath','hsin','jingran','zani','lynae']
 return data
