"""Review sheet layout only. Original and generated game images stay unchanged."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / 'build/qa/wuwa-items-v128'
entries = json.loads((DOC / 'art-manifest.json').read_text())['entries']
spec = json.loads((ROOT / 'data/items/solaris.json').read_text())
sources = {str(s['id']): s for s in json.loads((DOC / 'sources.json').read_text())}
effects = json.loads((DOC / 'runtime-catalogue.json').read_text())['new_item_effects']
font = '/System/Library/Fonts/STHeiti Medium.ttc'
def f(size): return ImageFont.truetype(font, size)
out = Image.new('RGB', (2800, 2900), '#eee7f5')
d = ImageDraw.Draw(out)
d.text((65, 35), '鸣潮原作物品 → Q 版适配 · V128', font=f(64), fill='#443254')
d.text((69, 124), '16 件新增 · 10 种花草菌果 / 2 种矿物 / 2 种 BOSS 材料 / 2 种料理', font=f(30), fill='#796487')
d.text((69, 176), '每格左侧为原作图，右侧为游戏 Q 版；名称与造型来自原作，战斗效果与配方为本作改编。', font=f(27), fill='#796487')
def paste_fit(path, box):
    image = Image.open(path).convert('RGBA')
    image.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    out.paste(image, (box[0] + (box[2]-image.width)//2, box[1] + (box[3]-image.height)//2), image)
def lines(text, width, font):
    result=[]; line=''
    for char in text:
        if d.textlength(line+char,font=font) > width: result.append(line); line=char
        else: line += char
    if line: result.append(line)
    return result
order = ['mat_42310060','mat_42310070','mat_42310030','mat_42310220','mat_42300110','mat_42300020','mat_42310080','mat_42310100','mat_42300080','mat_42300090','mat_42500020','mat_42500040','mat_41400074','mat_41400054','provision_jinzhou_stew','provision_snow_lotus_pastry']
indexed = {e['kind']: e for e in entries}
for n,kind in enumerate(order):
    if kind not in indexed: continue
    e=indexed[kind]; item=spec['new_items'][kind]; profile=item['profile']
    x=55+(n%4)*687; y=250+(n//4)*650
    d.rounded_rectangle((x,y,x+665,y+625),radius=26,fill='#fff6e7',outline='#ccb9dc',width=2)
    d.text((x+28,y+20),item['name'],font=f(36),fill='#443254')
    d.text((x+28,y+72),f'原作 ID {e["source_id"]} · 本作占 {len(item["shape"])} 格',font=f(24),fill='#91729f')
    paste_fit(ROOT/sources[str(e['source_id'])]['reference_path'],(x+18,y+145,185,275))
    d.text((x+212,y+265),'→',font=f(42),fill='#b29ac9')
    paste_fit(ROOT/e['output_path'],(x+272,y+115,365,340))
    d.text((x+58,y+438),'原作参考',font=f(23),fill='#91729f')
    d.text((x+393,y+460),'Q 版',font=f(23),fill='#91729f')
    text=''.join(effects[kind]).replace('[star]','★').replace('常驻，不消耗。','')
    rows=lines(text,610,f(24))
    if len(rows)>4: rows=rows[:3]+[rows[3][:-1]+'…']
    for j,line in enumerate(rows):
        d.text((x+27,y+508+j*28),line,font=f(24),fill='#574061')
path=DOC/'original-to-chibi-overview.png';out.save(path);print(path)
