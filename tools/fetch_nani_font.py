"""Download the user-selected Nani font and its OFL from the author's repository."""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib, json

DEST=Path(__file__).resolve().parents[1]/'assets/fonts'
DEST.mkdir(parents=True,exist_ok=True)
FONT='https://raw.githubusercontent.com/max32002/nanifont/master/ttf/NaniFont-Regular.ttf'
LICENSE='https://raw.githubusercontent.com/max32002/nanifont/master/SIL_Open_Font_License_1.1.txt'
def read(url):
    with urlopen(Request(url,headers={'User-Agent':'TinHeartAssetFetcher/1.0'}),timeout=40) as response:
        return response.read()
font=read(FONT)
if font[:4] not in (b'\x00\x01\x00\x00',b'OTTO'): raise RuntimeError('Response is not a font.')
(DEST/'nani_regular.ttf').write_bytes(font)
(DEST/'nani_OFL.txt').write_bytes(read(LICENSE))
(DEST/'nani_source.json').write_text(json.dumps({'font':'何某手写体 / NaniFont Regular','selected_page':'https://font.sucai999.com/font/730.html','official_repository':'https://github.com/max32002/nanifont','license':'SIL Open Font License 1.1','download_url':FONT,'license_url':LICENSE,'retrieved':'2026-10-14','sha256':hashlib.sha256(font).hexdigest(),'bytes':len(font)},ensure_ascii=False,indent=2),encoding='utf-8')
print('Saved NaniFont Regular:',len(font),'bytes, original OFL retained',flush=True)
FALLBACK='https://raw.githubusercontent.com/lxgw/LxgwWenKai/main/fonts/TTF/LXGWWenKai-Regular.ttf'
fallback=read(FALLBACK)
(DEST/'wenkai_fallback.ttf').write_bytes(fallback)
(DEST/'wenkai_OFL.txt').write_bytes(read('https://raw.githubusercontent.com/lxgw/LxgwWenKai/main/OFL.txt'))
(DEST/'wenkai_source.json').write_text(json.dumps({'font':'LXGW WenKai Regular','purpose':'Fallback for characters missing in NaniFont, including 叠 and 摆','official_repository':'https://github.com/lxgw/LxgwWenKai','license':'SIL Open Font License 1.1','download_url':FALLBACK,'retrieved':'2026-10-14','sha256':hashlib.sha256(fallback).hexdigest()},ensure_ascii=False,indent=2),encoding='utf-8')
print('Saved handwriting fallback:',len(fallback),'bytes',flush=True)
