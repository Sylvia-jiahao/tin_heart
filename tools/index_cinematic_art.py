from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]/'assets/cinematics'
index={}
for name in ['book_cover','book_spread','hand_lift','window_landing','desk_opening']:
    image=Image.open(root/(name+'.png')).convert('RGBA')
    bounds=image.getchannel('A').point(lambda x:255 if x>=205 else 0).getbbox()
    if name in ['window_landing','desk_opening']: bounds=(0,0,*image.size)
    x,y,right,bottom=bounds
    index[name]={'region':[x,y,right-x,bottom-y],'transparent':name not in ['window_landing','desk_opening']}
    print(name,image.size,bounds)
(root/'asset_index.json').write_text(json.dumps(index,indent=2),encoding='utf-8')
