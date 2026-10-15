"""Produce review thumbnails only; generated production PNGs remain untouched."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
paths=sorted((ROOT/'assets/chapter02').glob('*.png'))
out=ROOT.parent/'chapter02_qa'
out.mkdir(exist_ok=True)
for batch in range(0,len(paths),15):
    selected=paths[batch:batch+15]
    sheet=Image.new('RGB',(1200,((len(selected)+4)//5)*220),'#bdc5c6')
    draw=ImageDraw.Draw(sheet)
    for k,path in enumerate(selected):
        im=Image.open(path).convert('RGBA')
        im.thumbnail((230,190))
        x=(k%5)*240+(240-im.width)//2
        y=(k//5)*220+(195-im.height)//2
        sheet.paste(im,(x,y),im)
        draw.text(((k%5)*240+6,(k//5)*220+199),path.stem,fill='black')
    sheet.save(out/f'assets_{batch//15+1}.png')
print(len(paths),'source images reviewed in contact sheets')
