"""Check exported PCM at the actual loop points, not the beginning of the file."""
from pathlib import Path
import json, wave
import numpy as np

root=Path(__file__).resolve().parents[1]/'assets/audio/chapter01'
manifest=json.loads((root/'score.json').read_text(encoding='utf-8'))
for item in manifest['tracks']:
    with wave.open(str(root/item['file']),'rb') as stream:
        audio=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,2).astype(np.float32)/32768
    start=item['loop_begin_frame']; end=item['loop_end_frame']
    assert 0<start<end==len(audio)
    assert max(abs(audio).max(),0)<.95
    assert np.sqrt(np.mean(audio**2))>.03
    seam=float(np.max(np.abs(audio[start]-audio[end-1])))
    normal=float(np.quantile(np.abs(np.diff(audio,axis=0)),.999))
    assert seam<=normal*1.5, (item['file'],seam,normal)
    assert abs((end-start)/item['sample_rate']-item['loop_period_seconds'])<1e-4
    assert all(event[-1]==item['instrument'] for event in item['events'])
    print('PASS',item['file'],item['instrument'],'seam=',round(seam,6),'normal_99.9%=',round(normal,6),'loop_period=',item['loop_period_seconds'])
