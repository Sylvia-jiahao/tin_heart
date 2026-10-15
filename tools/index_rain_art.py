"""Index generated PNG alpha bounds without altering any image."""
from pathlib import Path
import json,hashlib
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]/'assets/chapter02'
result={}
for path in ROOT.glob('*.png'):
    im=Image.open(path).convert('RGBA')
    transparent=im.getchannel('A').getextrema()[0]<255
    box=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox() if transparent else (0,0,*im.size)
    if box is None: raise ValueError(f'Empty asset: {path}')
    a,b,c,d=box
    a=max(0,a-3); b=max(0,b-3); c=min(im.width,c+3); d=min(im.height,d+3)
    result[path.stem]={'region':[a,b,c-a,d-b],'transparent':transparent,'source_size':list(im.size),'generator':'builtin image_gen','sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(ROOT/'asset_index.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('Indexed',len(result),'unaltered generated PNGs')
