extends RefCounted
## Automatic companion rules. Acquisition order never changes the base ability.
const C=preload('res://scripts/data/catalog.gd')
const ACTIVITY=preload('res://scripts/battle/item_activity.gd')
const ROLES={
 'role_1509':{'ability_id':'dual_charge','family':'charge','ability_name':'交错蓄能','period':3.0,'threshold':1.0,'value':2.0,'base_text':'武器和声骸各自然攻击一次，获得 2 充能；间隔 3 秒。','tradeoff':'需要武器和攻击型声骸。'},
 'role_1207':{'ability_id':'triple_charge','family':'charge','ability_name':'连击蓄能','period':3.0,'threshold':3.0,'value':2.0,'base_text':'累计 3 次武器自然攻击，获得 2 充能；间隔 3 秒。','tradeoff':'高攻速、多武器更容易触发。'},
 'role_1302':{'ability_id':'echo_relay','family':'relay','ability_name':'弦声接力','period':3.0,'threshold':2.0,'value':.9,'base_text':'累计 2 次武器自然攻击，推进剩余冷却最长的声骸 0.9 秒；间隔 3 秒。','tradeoff':'需要有攻击冷却的声骸。'},
 'role_1211':{'ability_id':'weapon_relay','family':'relay','ability_name':'回声接力','period':3.0,'threshold':2.0,'value':.9,'base_text':'累计 2 次声骸自然攻击，推进剩余冷却最长的武器 0.9 秒；间隔 3 秒。','tradeoff':'攻击型声骸越多，接力越频繁。'},
 'role_1209':{'ability_id':'timed_stamina','family':'stamina','ability_name':'定时补给','period':4.0,'threshold':0.0,'value':1.0,'base_text':'每 4 秒回复 1 耐力。','tradeoff':'耐力已满时不储存回复。'},
 'role_1410':{'ability_id':'spent_stamina','family':'stamina','ability_name':'循环补给','period':2.0,'threshold':4.0,'value':.8,'base_text':'实际累计消耗 4 耐力，回复 0.8 耐力；间隔 2 秒。','tradeoff':'按实际消耗计数，低耗耐时触发较慢。'},
 'role_1505':{'ability_id':'timed_heal','family':'guard','ability_name':'潮汐照护','period':4.0,'threshold':0.0,'value':2.0,'base_text':'每 4 秒治疗 2，溢出治疗的 50% 转为护盾。','tradeoff':'偏持续生存，不能立即抵消爆发。'},
 'role_1607':{'ability_id':'echo_heal','family':'guard','ability_name':'幽梦照护','period':3.0,'threshold':3.0,'value':3.0,'base_text':'累计 3 次声骸自然攻击，治疗 3，溢出治疗的 50% 转为护盾；间隔 3 秒。','tradeoff':'需要攻击型声骸。'},
 'role_1506':{'ability_id':'weapon_noise','family':'affliction','ability_name':'余光印记','period':6.0,'threshold':4.0,'value':1.0,'base_text':'累计 4 次武器自然攻击，给对方施加 1 光噪；间隔 6 秒。','tradeoff':'光噪需要时间持续造成伤害。'},
 'role_1110':{'ability_id':'weapon_frost','family':'affliction','ability_name':'霜迹印记','period':4.0,'threshold':2.0,'value':2.0,'base_text':'累计 2 次武器自然攻击，给对方施加 2 霜渐；间隔 4 秒。','tradeoff':'减速与冻结提供节奏优势，不直接增加伤害。'},
 'role_1106':{'ability_id':'reclaim','family':'economy','ability_name':'旧物新用','period':0.0,'threshold':0.0,'value':0.0,'base_text':'加入时获得 2 金币。每回合首次合成，返还一件合资格的低阶材料。','tradeoff':'返还品质不超过蓝色、售价不超过 6 的最低价普通材料。'},
 'role_1504':{'ability_id':'bargain','family':'economy','ability_name':'顺路补货','period':0.0,'threshold':0.0,'value':0.0,'base_text':'加入时获得 2 金币。每回合多一次免费刷新。','tradeoff':'收益用于后续购买，不直接增加战斗数值。'}
}
const BONDS={
 'charge':{'bond_name':'蓄能追击','bond_text':'充能武器自然攻击额外造成 3 伤害；间隔 4 秒。','period':4.0,'threshold':1.0,'value':3.0},
 'relay':{'bond_name':'交错接力','bond_text':'武器和声骸各自然攻击一次，推进剩余冷却最长的武器 0.6 秒；间隔 3 秒。','period':3.0,'threshold':1.0,'value':.6},
 'stamina':{'bond_name':'耐力护航','bond_text':'实际累计消耗 6 耐力，获得 3 护盾；间隔 3 秒。','period':3.0,'threshold':6.0,'value':3.0},
 'guard':{'bond_name':'守护反击','bond_text':'护盾实际累计抵挡 12 敌方伤害，回击 3 伤害；间隔 3 秒。','period':3.0,'threshold':12.0,'value':3.0},
 'affliction':{'bond_name':'印记追击','bond_text':'武器自然攻击已带光噪或霜渐的敌人时，额外造成 3 伤害；间隔 4 秒。','period':4.0,'threshold':1.0,'value':3.0},
 'economy':{'bond_name':'同行工坊','bond_text':'满编时额外获得 3 金币。此后每回合首次合成返还 1 金币。','period':0.0,'threshold':0.0,'value':1.0}
}
const SHORTS={
 'dual_charge':'武器、声骸各攻击一次\n+2充能 · 间隔3秒',
 'triple_charge':'3次武器攻击 → +2充能\n间隔3秒',
 'echo_relay':'2次武器攻击 · 间隔3秒\n推进最慢声骸0.9秒',
 'weapon_relay':'2次声骸攻击 · 间隔3秒\n推进最慢武器0.9秒',
 'timed_stamina':'每4秒回复1耐力',
 'spent_stamina':'累计消耗4耐力 → 回复0.8\n间隔2秒',
 'timed_heal':'每4秒治疗2\n溢出的一半转为护盾',
 'echo_heal':'3次声骸攻击 → 治疗3\n溢出半数转盾 · 间隔3秒',
 'weapon_noise':'4次武器攻击 → 施加1光噪\n间隔6秒',
 'weapon_frost':'2次武器攻击 → 施加2霜渐\n间隔4秒',
 'reclaim':'入队+2金币\n每轮首次合成返还低阶材料',
 'bargain':'入队+2金币\n每回合多一次免费刷新'
}
const BOND_SHORTS={
 'charge':'充能武器攻击+3伤害\n间隔4秒',
 'relay':'武器、声骸各攻击一次\n最慢武器推进0.6秒 · 间隔3秒',
 'stamina':'累计消耗6耐力 → +3护盾\n间隔3秒',
 'guard':'累计挡下12伤害 → 回击3伤害\n间隔3秒',
 'affliction':'武器命中带光噪或霜渐的敌人\n额外3伤害 · 间隔4秒',
 'economy':'满编额外+3金币\n每回合首次合成+1金币'
}
static func enabled(build:Dictionary)->bool:
 return int(build.get('recruitment',{}).get('version',0))==115
static func profile(role:String)->Dictionary:
 if not ROLES.has(role):return {}
 var p=ROLES[role].duplicate(true)
 p.role_id=role;p.name=C.roster.get(role,{}).get('name',role)
 p.base_short=SHORTS[p.ability_id]
 p.supply_group={'charge':'volley','relay':'link','stamina':'supply','guard':'guard','affliction':'link','economy':'artisan' if role=='role_1106' else 'supply'}[p.family]
 p.icon_id=p.supply_group
 p.bond_name=BONDS[p.family].bond_name;p.bond_text=BONDS[p.family].bond_text;p.bond_short=BOND_SHORTS[p.family]
 return p
static func profiles()->Array:
 var result=[]
 for role in ROLES:result.append(profile(role))
 return result
static func full_team(build:Dictionary)->Dictionary:
 if not enabled(build):return {}
 var roles=[]
 for role in build.get('supports',[]):
  if ROLES.has(role) and role not in roles:roles.append(role)
 if roles.size()!=2:return {}
 var p=profile(roles[1]);var result=BONDS[p.family].duplicate(true)
 result.role_id=p.role_id;result.family=p.family;result.ability_id='full_'+p.family
 result.ability_name=result.bond_name
 return result
static func ready(role:String,build:Dictionary)->bool:
 var spec=profile(role)
 if spec.is_empty():return false
 var weapon=false;var echo=false;var clock_echo=false
 for p in build.get('items',[]):
  if not ACTIVITY.attacks(p):continue
  if C.is_tag(p.kind,'weapon'):weapon=true
  if C.is_tag(p.kind,'echo'):
   echo=true
   if ACTIVITY.has_clock(p):clock_echo=true
 match spec.ability_id:
  'dual_charge':return weapon and echo
  'echo_relay':return weapon and clock_echo
  'weapon_relay':return weapon and echo
  'echo_heal':return echo
  'triple_charge','weapon_noise','weapon_frost','spent_stamina','timed_stamina':return weapon
 return true
