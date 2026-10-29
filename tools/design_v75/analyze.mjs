import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {D,N,valid,tier,openRound,shopOpen,shopPrice,craftOnly} from './numbers.mjs';
export const stage=process.env.V75_ANALYSIS_OUTPUT || '/tmp/recipe-numbers-20261015';
export const leaders=D.catalog.selectable_leaders.map(k=>({id:k,...D.catalog.characters[k]}));
export const ordered=[...D.recipes].sort((a,b)=>D.depth(a.to)-D.depth(b.to)||D.sorted.indexOf(a.to)-D.sorted.indexOf(b.to));
ordered.forEach((r,i)=>r.id='P'+String(i+1).padStart(3,'0'));
export const weapon=k=>D.items[k].tags.includes('weapon');
export const echo=k=>D.items[k].tags.includes('echo');
export const category=k=>weapon(k)?'武器':echo(k)?'声骸':'普通物品';
export const tiers={1:[1,0,0,0],2:[.75,.25,0,0],3:[.6,.3,.1,0],4:[.5,.3,.2,0],5:[.4,.3,.2,.1],6:[.35,.3,.2,.15],7:[.3,.3,.2,.2],8:[.3,.3,.2,.2]};
const excluded=new Set(['cheongsam','magnifier']);
export const types=['broadblade','sword','pistol','gauntlet','rectifier'];
const allOwners=new Set(Object.keys(D.catalog.roster));
export const reference={types:new Set(types),owners:allOwners};
export const initial=l=>({types:new Set([l.weapon_type]),owners:new Set([l.roster_id])});
function ownerIds(k){const x=D.items[k];return x.strict_signature?(x.signature_owner_ids??[]):[];}
export function permitted(k,ctx){return (!weapon(k)||ctx.types.has(D.items[k].weapon_type))&&(!D.items[k].strict_signature||ownerIds(k).some(q=>ctx.owners.has(q)));}
export function buyable(k,r,ctx){return !!N[k]&&!excluded.has(k)&&!craftOnly(k)&&shopOpen(k)<=r&&permitted(k,ctx);}
export function ancestors(k){const p=D.incoming[k];return p?[k,...ancestors(p.from),...ancestors(p.mat)]:[k];}
export function gate(k){return Math.max(...ancestors(k).map(openRound));}
// Exact minimum same-element recruits for crafting the whole dependency tree, not only buying its end item.
export function access(k,l){const nodes=[...new Set(ancestors(k))];const req=[];
 for(const t of new Set(nodes.filter(weapon).map(x=>D.items[x].weapon_type)))if(t!==l.weapon_type)req.push({text:({broadblade:'长刃',sword:'迅刀',pistol:'佩枪',gauntlet:'臂铠',rectifier:'音感仪'})[t],test:(_,x)=>x.weapon_type===t});
 for(const q of nodes.filter(x=>D.items[x].strict_signature)){if(ownerIds(q).includes(l.roster_id))continue;req.push({text:D.name(q)+'持有人',test:(id)=>ownerIds(q).includes(id)});}
 if(!req.length)return {cost:0,count:0,roles:[],round:gate(k)};
 const cand=Object.entries(D.catalog.roster).filter(([id,x])=>x.element===l.element&&id!==l.roster_id&&x.released!==false).map(([id,x])=>({id,cost:x.rarity===4?4:5,mask:req.reduce((m,t,i)=>m|(t.test(id,x)?2**i:0),0)})).filter(x=>x.mask);
 const full=2**req.length-1,possible=cand.reduce((a,b)=>a|b.mask,0);
 if(possible!==full)return {cost:null,count:null,roles:[],round:null,reason:req.filter((_,i)=>!(possible&2**i)).map(x=>x.text).join('、')};
 let dp=new Map([[0,{cost:0,roles:[]}]]);
 for(const a of cand){for(const[m,v]of [...dp]){const mask=m|a.mask,cost=v.cost+a.cost,prev=dp.get(mask);if(!prev||cost<prev.cost||(cost===prev.cost&&v.roles.length+1<prev.roles.length))dp.set(mask,{cost,roles:[...v.roles,a.id]});}}
 const x=dp.get(full);return {...x,count:x.roles.length,round:Math.max(gate(k),x.roles.length+1)};
}
const distCache=new Map();
export function ordinary(r,slot,ctx=reference){const key=[r,slot,[...ctx.types].sort().join(','),[...ctx.owners].sort().join(',')].join('|');if(distCache.has(key))return distCache.get(key);
 const eligible=valid.filter(k=>buyable(k,r,ctx)&&(slot===3||slot===4||category(k)===['武器','声骸','普通物品'][slot]));
 // Tier probability renormalized over eligible tiers, then equally among IDs inside each tier.
 const mix=tiers[Math.min(8,r)],groups=[1,2,3,4].map(t=>eligible.filter(k=>tier(k)===t));let norm=groups.reduce((s,g,i)=>s+(g.length?mix[i]:0),0);
 const result=groups.flatMap((g,i)=>g.map(k=>[k,mix[i]/norm/g.length]));assert(Math.abs(result.reduce((s,x)=>s+x[1],0)-1)<1e-8);distCache.set(key,result);return result;
}
export function missing(owned,r,ctx){const a=new Set();for(const p of D.recipes){if(!permitted(p.to,ctx)||gate(p.to)>r+1)continue;if((owned[p.from]??0)>0&&!(owned[p.mat]>0)&&buyable(p.mat,r,ctx))a.add(p.mat);if((owned[p.mat]??0)>0&&!(owned[p.from]>0)&&buyable(p.from,r,ctx))a.add(p.from);}return [...a];}
export function distributions(r,ctx=reference,owned={},assist=.7){const arr=[0,1,2,3].map(i=>ordinary(r,i,ctx)),miss=missing(owned,r,ctx),base=ordinary(r,4,ctx);if(!miss.length)return [...arr,base];const m=new Map(base.map(([k,p])=>[k,p*(1-assist)]));for(const k of miss)m.set(k,(m.get(k)??0)+assist/miss.length);return [...arr,[...m]];}
export function shelfProbability(k,r,ctx=reference,owned={},assist=.7){return 1-distributions(r,ctx,owned,assist).reduce((p,a)=>p*(1-(a.find(x=>x[0]===k)?.[1]??0)),1);}
export const bagProbability=(k,r)=>k==='satchel'?0:k==='travel'?(r>=3?.25:0):['pouch','strip','corner'].includes(k)?(r>=3?.25:1/3):0;
export const probabilities=D.sorted.map(k=>({id:k,values:[1,2,3,4,5,6,7,8].map(r=>D.kind(k)==='背包'?bagProbability(k,r):N[k]?shelfProbability(k,r):0)}));
export const accessRows=ordered.map(p=>({id:p.to,leaders:leaders.map(l=>access(p.to,l))}));
export const projections=ordered.map(p=>{const k=p.to,a=N[p.from],b=N[p.mat],n=N[k];const dmg=x=>x.id==='violet'?Math.floor((30-2)/5)*6:x.cd?Math.floor((30+1e-9)/x.cd)*x.damage:0;
 const wa=weapon(p.from),wb=weapon(p.mat);const inputAttack=wa&&wb?Math.max(dmg(a)+.25*dmg(b),dmg(b)+.25*dmg(a)):dmg(a)+dmg(b);
 const support=x=>({heal:x.healPeriod?Math.floor(30/x.healPeriod)*x.healAmount:0,shield:x.shieldPeriod?Math.floor(30/x.shieldPeriod)*x.shieldAmount:0});const ai=support(a),bi=support(b),ni=support(n),den=inputAttack;
 return {id:k,inputAttack,attack:dmg(n),change:den?(dmg(n)/den-1):null,inputHeal:ai.heal+bi.heal,heal:ni.heal,inputShield:ai.shield+bi.shield,shield:ni.shield,inputCells:D.items[p.from].shape.length+D.items[p.mat].shape.length,cells:D.items[k].shape.length,gate:gate(k),cost:D.cost(k),increment:D.cost(p.mat),risk:den&&dmg(n)<.8*den?'基础攻击下降>20%：必须靠机制或省格回本':den&&dmg(n)>1.5*den?'基础攻击提升>50%：检查是否过早/过便宜':'基础攻击变化在筛查区间内；仍需机制验证'};
});
// Procurement simulation: zero battle wins, no gifted core, real starters. No combat or grid solver.
function rng(seed){return ()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296;};}
function draw(a,rand){let x=rand();for(const[k,p]of a){x-=p;if(x<0)return k;}return a.at(-1)[0];}
const firstChoices=l=>D.recipes.filter(p=>(p.from===l.starter||p.mat===l.starter)&&gate(p.to)===1&&permitted(p.to,initial(l)));
export const earlyTargets=leaders.map(l=>({leader:l.id,choices:firstChoices(l).map(p=>p.to)}));
function once(l,mode,assist,paidMax,seed,reserve){const rand=rng(seed),ctx=initial(l),owned={[l.starter]:1,[l.starter_supply||'nutrition']:1};let cash=9,spent=0,refreshSpend=0,locks=Array(5).fill(null);const choices=firstChoices(l),fixed=choices.find(p=>p.mat==='mat_42310090')??choices[0];const options=mode==='指定分支'?[fixed]:choices;const needs=new Set(options.flatMap(p=>[p.from,p.mat]).filter(k=>k!==l.starter));
 let result={round:0,spent:0,refreshSpend:0,output:null};
 for(let r=1;r<=3;r++){if(r>1)cash+=8;const held=reserve[r-1];cash-=held;if(cash<0)throw new Error('reserve');
  for(let face=0;face<2+paidMax;face++){const ready=options.find(p=>owned[p.from]>0&&owned[p.mat]>0);if(ready)return {round:r,spent,refreshSpend,output:ready.to};if(face>=2){if(cash<1)break;cash--;refreshSpend++;}const ds=distributions(r,ctx,owned,assist);const shelf=locks.map((k,i)=>k??draw(ds[i],rand));locks.fill(null);
   // Immediate first craft; buy only one missing component, never a direct finished item.
   const buy=shelf.filter(k=>needs.has(k)&&!owned[k]).sort((a,b)=>shopPrice(a)-shopPrice(b));
   for(const k of buy){if(!owned[k]&&cash>=shopPrice(k)){cash-=shopPrice(k);spent+=shopPrice(k);owned[k]=(owned[k]??0)+1;break;}}
   const found=options.filter(p=>owned[p.from]>0&&owned[p.mat]>0).sort((a,b)=>D.cost(a.to)-D.cost(b.to))[0];
   if(found){return {round:r,spent,refreshSpend,output:found.to};}
   shelf.forEach((k,i)=>{if(needs.has(k)&&!owned[k]&&shopPrice(k)>cash)locks[i]=k;});
  }
  // Surviving consumables are not assumed: all uncrafted consumable supplies are consumed in combat.
  for(const k of Object.keys(owned))if(D.items[k].tags.includes('consumable'))delete owned[k];
 }
 return result;
}
export const simulation=[];
const trials=3000;
for(let li=0;li<leaders.length;li++)for(const config of [
 {label:'普通货架基线',mode:'任意起手分支',assist:0,paid:2,reserve:[5,2,2]},
 {label:'补件70%·灵活拿牌',mode:'任意起手分支',assist:.7,paid:2,reserve:[5,2,2]},
 {label:'补件70%·追指定分支',mode:'指定分支',assist:.7,paid:2,reserve:[5,2,2]},
 {label:'补件70%·不付费刷新',mode:'任意起手分支',assist:.7,paid:0,reserve:[5,2,2]},
 {label:'补件70%·紧预算',mode:'任意起手分支',assist:.7,paid:2,reserve:[7,4,4]}
]){const out=[];for(let i=0;i<trials;i++)out.push(once(leaders[li],config.mode,config.assist,config.paid,20261015+li*100000+i,config.reserve));const passed=out.filter(x=>x.round);const vals=[1,2,3].map(r=>out.filter(x=>x.round&&x.round<=r).length/trials);const err=p=>1.96*Math.sqrt(p*(1-p)/trials);const p3=vals[2],z=1.96,den=1+z*z/trials,center=(p3+z*z/(2*trials))/den,half=z*Math.sqrt(p3*(1-p3)/trials+z*z/(4*trials*trials))/den;simulation.push({leader:leaders[li].name,config:config.label,mode:config.mode,trials,rates:vals,error:err(vals[2]),low:center-half,high:center+half,meanSpend:passed.reduce((s,x)=>s+x.spent,0)/passed.length,meanRefresh:passed.reduce((s,x)=>s+x.refreshSpend,0)/passed.length,fail:out.length-passed.length,targets:(config.mode==='指定分支'?[firstChoices(leaders[li]).find(p=>p.mat==='mat_42310090')??firstChoices(leaders[li])[0]]:firstChoices(leaders[li])).map(p=>D.name(p.to)).join(' / ')});}
export const pairSupply=ordered.map(p=>{const round=gate(p.to),owned={[p.from]:1},prob=buyable(p.mat,round,reference)?shelfProbability(p.mat,round,reference,owned):0;return{id:p.to,round,p:prob,two:1-(1-prob)**2,four:1-(1-prob)**4,missing:missing(owned,round,reference).length};});
await fs.writeFile(stage+'/analysis.json',JSON.stringify({probabilities,accessRows,projections,simulation,earlyTargets,pairSupply},null,2));
console.log(JSON.stringify({recipes:ordered.length,stats:valid.length,simulation:simulation.map(x=>[x.leader,x.config,x.rates.map(p=>+(p*100).toFixed(1))]),unreachable:accessRows.filter(x=>x.leaders.every(y=>y.cost===null)).map(x=>D.name(x.id)),loss:projections.filter(x=>x.change!==null&&x.change<-.2).map(x=>[D.name(x.id),x.change]),gain:projections.filter(x=>x.change> .5).map(x=>[D.name(x.id),x.change])},null,2));
