"""Review layout only; never modify generated game asset bytes."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
spec=json.loads((ROOT/'data/items/families.json').read_text())
font='/System/Library/Fonts/STHeiti Medium.ttc'
def f(size):return ImageFont.truetype(font,size)
families={'food':'配餐','tea':'茶饮','machinery':'机械','acoustics':'声学','defense':'护甲','breaker':'破盾','noise':'光噪','frost':'霜渐'}
out=Image.new('RGB',(2800,3260),'#eee7f5');d=ImageDraw.Draw(out)
d.text((82,42),'组合物品 · V127',font=f(74),fill='#403352')
d.text((85,143),'24 件新物品  /  8 组家族  /  36 条新增与重做配方',font=f(32),fill='#726181')
d.text((85,194),'原作材料参考 + 本作原创 Q 版配件  ·  游戏内使用透明原图，不带占格边框',font=f(25),fill='#847490')
def wrap(text,width,font):
 lines=[];line=''
 for char in text:
  if d.textlength(line+char,font=font)>width:lines.append(line);line=char
  else:line+=char
 if line:lines.append(line)
 return lines
for row,(family,label) in enumerate(families.items()):
 y=270+row*370
 d.text((44,y+23),label,font=f(36),fill='#725286')
 entries=[(k,v) for k,v in spec['new_items'].items() if v['profile']['family']==family]
 for col,(kind,item) in enumerate(entries):
  x=167+col*866;n=item['profile']
  d.rounded_rectangle((x,y,x+840,y+342),radius=26,fill='#fff6e7',outline='#d4c2df',width=2)
  im=Image.open(ROOT/f'assets/items/combinations/{kind}.png').convert('RGBA')
  im.thumbnail((290,270),Image.Resampling.LANCZOS)
  out.paste(im,(x+16+(290-im.width)//2,y+38+(270-im.height)//2),im)
  d.text((x+325,y+25),item['name'],font=f(32),fill='#443254')
  supply='商店基础件' if not n['craft_only'] else '合成分支'
  d.text((x+325,y+73),f'{len(item["shape"])} 格  ·  品质 {n["tier"]}  ·  {supply}',font=f(23),fill='#92749e')
  text=n['ownExtra']
  if n.get('starText') and n['starText'] not in text:text+=' '+n['starText']
  lines=wrap(text.replace('★','星位'),470,f(24))
  for i,line in enumerate(lines[:7]):d.text((x+325,y+115+i*29),line,font=f(24),fill='#5b4a65')
  shape=item['shape'];maxx=max(p[0] for p in shape);maxy=max(p[1] for p in shape)
  for sx,sy in shape:
   xx=x+815-(maxx-sx+1)*13;yy=y+320-(maxy-sy+1)*13
   d.rounded_rectangle((xx,yy,xx+11,yy+11),radius=3,fill='#b9a1d0')
d.text((90,3230),'完整效果、准确星位和全部合成路线：build/qa/families-v127/design.md',font=f(20),fill='#806f8a')
path=ROOT/'build/qa/families-v127/art/new-items-overview.png';out.save(path)
print(path)
