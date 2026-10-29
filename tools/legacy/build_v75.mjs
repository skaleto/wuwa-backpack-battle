// Reproducible conversion of the user-approved 2026-10-15 numerical workbook.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {D,N,valid,tier,openRound,shopOpen,shopPrice,craftOnly,stars,baseText,supportText,globalRules} from './design_v75/numbers.mjs';
const root=new URL('../',import.meta.url);
if (JSON.parse(await fs.readFile(new URL('data/catalog.json',root),'utf8')).design_version>75) throw new Error('Historical V75 builder: use tools/legacy/build_v83.py for the current catalogue.');
const catalog=structuredClone(D.catalog);
const ordered=[...D.recipes].sort((a,b)=>D.depth(a.to)-D.depth(b.to)||D.sorted.indexOf(a.to)-D.sorted.indexOf(b.to));
const gate=k=>Math.max(openRound(k),...(D.incoming[k]?[gate(D.incoming[k].from),gate(D.incoming[k].mat)]:[]));
const mapCap={'治疗':'heal','护盾':'shield','光噪':'noise','霜渐':'frost','净化':'cleanse','急救':'emergency','一次护盾':'once_shield','生命':'hp','耐力':'stamina'};
const excluded=['cheongsam','magnifier'];
const spec={version:75,source:'approved workbook 2026-10-15',items:{},recipes:[],legacy:[...D.legacy],excluded,shop:{assist_probability:.7,slots:['weapon','echo','ordinary','free','assist'],tiers:{1:[1,0,0,0],2:[.75,.25,0,0],3:[.6,.3,.1,0],4:[.5,.3,.2,0],5:[.4,.3,.2,.1],6:[.35,.3,.2,.15],7:[.3,.3,.2,.2],8:[.3,.3,.2,.2]},bag_rounds:{pouch:1,strip:1,corner:1,travel:3}},globalRules};
for(const k of valid){
 const n=structuredClone(N[k]),x=catalog.items[k];
 const caps=D.caps(k).map(t=>mapCap[t]);
 for(const [c,v]of [['heal',n.healAmount],['shield',n.shieldAmount],['noise',n.noisePeriod],['frost',n.frostPeriod],['charge',n.charge],['haste',n.hasteEvery]])if(v&&!caps.includes(c))caps.push(c);
 Object.assign(n,{active:!excluded.includes(k),shop_price:shopPrice(k),craft_only:craftOnly(k),open_round:openRound(k),dependency_round:gate(k),shop_round:shopOpen(k),capabilities:caps,stars:stars(k),ownExtra:n.extra,starText:n.star,baseText:baseText(k),supportText:supportText(k),route:D.incoming[k]?.route??'通用',inputs:D.incoming[k]?[D.incoming[k].from,D.incoming[k].mat]:[],leaves:D.leaves(k),depth:D.depth(k),clocks:{heal:{period:n.healPeriod,amount:n.healAmount},shield:{period:n.shieldPeriod,amount:n.shieldAmount},noise:{period:n.noisePeriod,amount:n.noisePeriod?1:0},frost:{period:n.frostPeriod,amount:n.frostPeriod?1:0}}});
 spec.items[k]=n;
 // The V60 compatibility fields expose categories/base actions only. Full V75
 // effects execute in the V75 engine; source prose is never executable code.
 const baseTags=x.tags.filter(t=>['weapon','echo','consumable','craft_material','relic','golden','keepsake'].includes(t));
 if(baseTags.includes('keepsake')&&!excluded.includes(k)){baseTags.splice(baseTags.indexOf('keepsake'),1);if(!baseTags.includes('craft_material'))baseTags.push('craft_material');}
 x.tags=[...new Set([...baseTags,...caps,...(n.damage>0?['attack']:[])])];
 Object.assign(x,{v75:n,price:n.shop_price,damage:n.damage,heal:0,cooldown:n.cd,stamina:n.stamina,energy:0,concerto:0,round_min:n.shop_round,craft_tier:n.tier,rarity:n.tier,craft_only:n.craft_only,stars:n.stars,target:'',route:n.route,desc:'',demo_available:true});
 x.v60={active:n.active,activation:n.cd?'cooldown':'none',actions:n.damage?[{type:'damage',value:n.damage}]:[],special:{},rows:[]};
}
for(const k of D.legacy){catalog.items[k].craft_only=true;catalog.items[k].legacy_v75=true;}
ordered.forEach((p,i)=>{const n=spec.items[p.to];spec.recipes.push({id:'P'+String(i+1).padStart(3,'0'),base:p.from,materials:[p.mat],target:p.to,round_min:n.dependency_round,type:catalog.items[p.to].weapon_type??'item',input_tier:tier(p.from),fee:0,route:p.route,trade:p.trade});});
catalog.recipes=spec.recipes;
catalog.design_version=75;
assert.equal(spec.recipes.length,136);assert.equal(Object.keys(spec.items).length,197);
await fs.writeFile(new URL('data/compat/design/v75.json',root),JSON.stringify(spec,null,2)+'\n');
await fs.writeFile(new URL('data/catalog.json',root),JSON.stringify(catalog,null,2)+'\n');
console.log(`V75: ${Object.keys(spec.items).length} profiles; ${spec.recipes.length} recipes; ${spec.legacy.length} legacy profiles preserved.`);
