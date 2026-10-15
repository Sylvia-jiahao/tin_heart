"""Original deterministic synthesized chapter-two score and Foley. No samples."""
from pathlib import Path
import json, wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/chapter02'
OUT.mkdir(parents=True,exist_ok=True)
SR=44100
rng=np.random.default_rng(25102)

def write(name,signal):
    if signal.ndim==1: signal=np.column_stack([signal,signal])
    peak=float(np.max(np.abs(signal)))
    if peak>.78: signal=signal*.78/peak
    with wave.open(str(OUT/name),'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes(np.round(np.clip(signal,-1,1)*32767).astype('<i2').tobytes())
    return {'file':name,'seconds':len(signal)/SR,'peak':float(np.max(np.abs(signal))),'rms':float(np.sqrt(np.mean(signal**2)))}

def note(midi,seconds,gain=.1):
    t=np.arange(round(seconds*SR))/SR
    f=440*2**((midi-69)/12)
    y=sum(g*np.sin(2*np.pi*f*k*t)*np.exp(-t/(2.5/k)) for k,g in [(1,1),(2,.22),(3,.07)])
    y*=np.minimum(t/.02,1)*np.minimum((seconds-t)/.25,1)
    return y.astype(np.float32)*gain

period=48.0
n=round(period*SR)
music=np.zeros((n,2),np.float32)
def add(midi,start,duration,gain,pan=0):
    signal=note(midi,duration,gain)
    indices=(np.arange(len(signal))+round(start*SR))%n
    music[indices,0]+=signal*np.sqrt((1-pan)/2)
    music[indices,1]+=signal*np.sqrt((1+pan)/2)
for bar in range(16):
    root=[50,46,53,48][bar%4]
    for j,interval in enumerate([0,7,15]): add(root+interval,bar*3+j*.7,5,.065,(-.2 if j%2 else .2))
    if bar%2==0:
        for k,m in enumerate([69,74,72,69] if bar%4==0 else [65,67,69]): add(m,bar*3+k*.75,3,.055,-.12)
meta=write('rain_nocturne.wav',music)
meta.update(loop_begin_frame=0,loop_end_frame=n,sample_rate=SR,loop_period_seconds=period)
sounds=[meta]
for name,seconds,gain,width in [('rain.wav',8,.055,17),('wind.wav',8,.08,510)]:
    count=round(seconds*SR)
    noise=rng.normal(0,1,(count,2)).astype(np.float32)
    # Circular smoothing avoids an arbitrary noise seam at the loop boundary.
    kernel=np.ones(width)/width
    result=np.empty_like(noise)
    for c in range(2):
        padded=np.concatenate([noise[-width:,c],noise[:,c],noise[:width,c]])
        result[:,c]=np.convolve(padded,kernel,mode='same')[width:width+count]
    result*=gain/max(float(result.std()),1e-6)
    sounds.append(write(name,result))
for name,seconds,kind in [('splash.wav',.65,'water'),('step.wav',.14,'step'),('paper.wav',.5,'paper')]:
    t=np.arange(round(seconds*SR))/SR
    noise=rng.normal(0,1,len(t))
    y=np.convolve(noise,np.ones(9)/9,mode='same')*.13*np.exp(-t/(.12 if kind=='water' else .035))
    y+=np.sin(2*np.pi*(180 if kind=='water' else 110)*t)*.055*np.exp(-t/.06)
    y*=np.minimum(t/.003,1)
    sounds.append(write(name,y))
memory=np.zeros(round(7*SR),np.float32)
for start,midi in [(0,69),(.6,74),(1.2,77),(2.4,76),(3,74)]:
    y=note(midi,3,.12)
    p=round(start*SR)
    memory[p:p+len(y)]+=y
sounds.append(write('memory.wav',memory))
(OUT/'score.json').write_text(json.dumps({'tracks':[meta],'sounds':sounds,'source':'Original additive synthesis and seeded noise; no external samples.'},indent=2),encoding='utf-8')
print(json.dumps(sounds,indent=2))
