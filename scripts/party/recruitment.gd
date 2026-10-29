extends RefCounted
## Small version boundary: ongoing runs keep the abilities they selected.
const OLD=preload('res://scripts/party/recruitment_v114.gd')
const NEW=preload('res://scripts/party/recruitment_v115.gd')
static func current(run:Dictionary)->bool:return NEW.enabled(run)
static func rules(run:Dictionary):return NEW if current(run) else OLD
static func enabled(run:Dictionary)->bool:return NEW.enabled(run) or OLD.enabled(run)
static func initial()->Dictionary:return NEW.initial()
static func simulation_version(run:Dictionary)->String:
 var current_version=preload('res://scripts/data/catalog.gd').SIMULATION_VERSION
 return current_version+'-crew113' if run.get('recruitment_legacy',false) else current_version+'-crew114' if OLD.enabled(run) else current_version
static func profile(role:String,run:Dictionary={})->Dictionary:return rules(run).profile(role)
static func abilities(run:Dictionary)->Array:return rules(run).abilities(run)
static func has_ability(run:Dictionary,a:String)->bool:return a in abilities(run)
static func supply_allowed(run:Dictionary,a:String)->bool:return NEW.supply_allowed(run,a) if current(run) else OLD.has_ability(run,a)
static func bond_id(run:Dictionary,extra:String='')->String:return rules(run).bond_id(run,extra)
static func open_draft(inv,run:Dictionary,node:int)->bool:return rules(run).open_draft(inv,run,node)
static func card_models(inv,run:Dictionary)->Array:return rules(run).card_models(inv,run)
static func team_models(inv,run:Dictionary)->Array:return rules(run).team_models(inv,run)
static func plan_confirm(inv,run:Dictionary,role:String,reward:String='')->Dictionary:return rules(run).plan_confirm(inv,run,role,reward)
static func crew_setup_choices(inv,run:Dictionary)->Dictionary:
 return {'link':[],'volley':[],'guard':[],'artisan_return':[],'artisan_star':[],'supply':[]} if current(run) else OLD.crew_setup_choices(inv,run)
static func plan_configure(inv,run:Dictionary,config:Dictionary)->Dictionary:return {'ok':false} if current(run) else OLD.plan_configure(inv,run,config)
static func valid_link(inv,run:Dictionary)->Dictionary:return {} if current(run) else OLD.valid_link(inv,run)
static func link_model(inv,run:Dictionary)->Dictionary:return {} if current(run) else OLD.link_model(inv,run)
static func after_craft(inv,source:Dictionary,next:Dictionary,consumed:Array,output:Dictionary)->void:rules(source).after_craft(inv,source,next,consumed,output)
static func guarantee_special(inv,run:Dictionary,offers:Array)->void:rules(run).guarantee_special(inv,run,offers)
static func valid_state(inv,run:Dictionary)->bool:return rules(run).valid_state(inv,run)
static func refresh_cost(run:Dictionary,charge:bool=true)->int:return NEW.refresh_cost(run,charge) if current(run) else (1 if charge and int(run.get('refreshes',0))>0 else 0)
