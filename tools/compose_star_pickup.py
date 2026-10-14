"""Original short paper-star chime; synthesized directly, no external samples."""
from pathlib import Path
import wave
import numpy as np

root=Path(__file__).resolve().parents[1]/'assets/audio/sfx'
root.mkdir(parents=True,exist_ok=True)
sr=44100
audio=np.zeros((int(sr*.9),2),np.float64)
for start,freq,gain,pan in [(0,1174.659,.42,-.12),(.085,1760,.27,.12)]:
    offset=round(start*sr)
    t=np.arange(len(audio)-offset)/sr
    note=np.zeros_like(t)
    for ratio,amp,decay in [(1,1,.22),(2.002,.17,.12),(3.01,.055,.08)]:
        note+=amp*np.sin(2*np.pi*freq*ratio*t)*np.exp(-t/decay)
    note*=(1-np.exp(-t/.0035))*np.clip((.9-start-t)/.12,0,1)*gain
    audio[offset:,0]+=note*np.sqrt((1-pan)/2)
    audio[offset:,1]+=note*np.sqrt((1+pan)/2)
audio*=.65/max(np.max(np.abs(audio)),1e-6)
with wave.open(str(root/'paper_star_pickup.wav'),'wb') as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(sr)
    out.writeframes(np.round(audio*32767).astype('<i2').tobytes())
print('Original paper-star pickup chime: 0.9 seconds, peak 0.65')
