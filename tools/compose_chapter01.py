"""Render two original Tin Heart scores with synthesized instruments, no external samples."""
from pathlib import Path
import json, wave, math
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/chapter01'
OUT.mkdir(parents=True,exist_ok=True)
SR=44100
RNG=np.random.default_rng(251)
def midi(note):
    names={'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}
    octave=int(note[-1]); pitch=names[note[0]]
    if '#' in note: pitch+=1
    if 'b' in note: pitch-=1
    return 12*(octave+1)+pitch
def freq(note): return 440*2**((midi(note)-69)/12)
def voice(note,duration,kind):
    t=np.arange(int(duration*SR),dtype=np.float64)/SR
    f=freq(note)*2**(RNG.uniform(-2.5,2.5)/1200)
    signal=np.zeros_like(t)
    if kind=='box':
        partials=[(1,1,2.0),(2,.24,.85),(3.006,.12,.55),(4.012,.06,.32)]
        for ratio,gain,decay in partials:
            signal+=gain*np.sin(2*np.pi*f*ratio*t)*np.exp(-t/decay)
        signal*=np.minimum(t/.006,1)
    elif kind=='piano':
        # Soft hammer attack, stretched string partials and gently beating unison strings.
        stiffness=.00007*(f/440)**.65
        for harmonic,gain in [(1,1),(2,.32),(3,.16),(4,.08),(5,.04),(6,.025)]:
            partial=f*harmonic*math.sqrt(1+stiffness*harmonic*harmonic)
            decay=(2.8*(220/f)**.22)/harmonic**.58
            signal+=gain*(.70*np.sin(2*np.pi*partial*t)+.30*np.sin(2*np.pi*partial*1.0009*t))*np.exp(-t/decay)
        signal*=1-np.exp(-t/.014)
    else:
        phase=2*np.pi*f*t+.03*np.sin(2*np.pi*4.7*t)
        signal=np.sin(phase)+.12*np.sin(phase*2)+.035*np.sin(phase*3)
        signal*=np.minimum(t/.32,1)*np.minimum((duration-t)/.55,1)
    signal*=np.clip((duration-t)/.35,0,1)
    return signal.astype(np.float32)
def render(name,bpm,meter,chords,melodies,instrument):
    beat=60/bpm; bars=32; length=bars*meter*beat
    total=round(length*SR)
    bridge=round(2*meter*beat*SR)
    audio=np.zeros((total+max(bridge,SR*10),2),np.float32)
    events=[]
    def add(note,bar,position,duration,gain,kind,pan=0):
        start=max(0,(bar*meter+position)*beat+RNG.uniform(-.006,.006))
        samples=voice(note,duration*beat,kind)*gain
        indices=np.arange(len(samples))+round(start*SR)
        audio[indices,0]+=samples*math.sqrt((1-pan)/2)
        audio[indices,1]+=samples*math.sqrt((1+pan)/2)
        events.append([note,bar,position,duration,gain,kind])
    for bar in range(bars):
        chord=chords[bar%len(chords)]
        root=chord[0]
        add(root,bar,0,meter+2,.16,instrument,-.16)
        if meter==4:
            for i,n in enumerate(chord[1:]+chord[1:]):
                add(n,bar,.5+i*.5,3,.052,instrument,(-.22 if i%2==0 else .22))
        else:
            for p in [1,2]:
                for n in chord[1:]: add(n,bar,p,3,.043,instrument,.18)
        phrase=melodies[bar%len(melodies)]
        for note,position,duration in phrase:
            gain=.15*(.90+.08*math.sin(bar*.8))
            add(note,bar,position,duration+4,gain,instrument,-.12)
        if 16<=bar<28 and bar%4 in [1,3]:
            add(chord[2],bar,meter-.5,4,.035,instrument,.30)
    dry=audio.copy()
    for delay,gain in [(.073,.14),(.119,.11),(.181,.09),(.239,.065),(.411,.05),(.683,.035)]:
        offset=round(delay*SR)
        audio[offset:]+=dry[:-offset,::-1]*gain
    # Append a two-bar bridge: release the old phrase over a soft entrance of the next.
    # Loop from bar 3, so the bridge preserves the complete 32-bar musical period.
    blend=np.linspace(0,1,bridge,dtype=np.float32)
    smooth=blend*blend*(3-2*blend)
    tail=audio[total:total+bridge].copy()
    head=audio[:bridge].copy()
    seam=tail*np.cos(smooth[:,None]*np.pi/2)+head*np.sin(smooth[:,None]*np.pi/2)
    audio=np.concatenate([audio[:total],seam])
    peak=float(np.max(np.abs(audio)))
    audio*=.78/max(peak,1e-6)
    pcm=np.round(np.clip(audio,-1,1)*32767).astype('<i2')
    with wave.open(str(OUT/(name+'.wav')),'wb') as wav:
        wav.setnchannels(2); wav.setsampwidth(2); wav.setframerate(SR); wav.writeframes(pcm.tobytes())
    meta={'file':name+'.wav','instrument':instrument,'bpm':bpm,'meter':meter,'bars':bars,'seconds':len(audio)/SR,'loop_period_seconds':length,'loop_begin_frame':bridge,'loop_end_frame':len(audio),'loop_crossfade_seconds':bridge/SR,'sample_rate':SR,'peak':float(np.max(np.abs(audio))),'rms':float(np.sqrt(np.mean(audio**2))),'loop_boundary_difference':float(np.max(np.abs(audio[bridge]-audio[-1]))),'events':events}
    print(name,round(length,2),'seconds, RMS',round(meta['rms'],4),'boundary',round(meta['loop_boundary_difference'],5))
    return meta

explore_chords=[['D3','F4','A4','E5'],['Bb2','F4','A4','D5'],['F3','A4','C5','E5'],['C3','E4','G4','D5'],['G2','D4','F4','A4'],['Bb2','D4','F4','A4'],['A2','E4','G4','C#5'],['A2','E4','A4','C#5']]
explore_melody=[
 [('A4',0,1),('D5',1.5,1),('F5',3,1)],
 [('E5',.5,1),('D5',2,1.5)],
 [('C5',0,1),('A4',1.5,1),('G4',3,1)],
 [('E5',0,1.5),('D5',2.5,1)],
 [('D5',.5,1),('A4',2,1.5)],
 [('F5',0,1),('E5',1.5,1),('D5',3,1)],
 [('C#5',.5,1),('B4',2,1)],
 [('A4',0,2.5)]
]
dance_chords=[['D3','F4','A4','D5'],['Bb2','D4','F4','A4'],['F3','A4','C5','F5'],['C3','E4','G4','C5'],['G2','Bb3','D4','G4'],['D3','F4','A4','D5'],['A2','E4','G4','C#5'],['A2','C#4','E4','A4']]
dance_melody=[
 [('D5',0,1),('F5',1,1),('A5',2,1)],
 [('G5',0,1.5),('F5',1.5,.5),('D5',2,1)],
 [('C5',0,.5),('F5',.5,.5),('A5',1,1),('G5',2,1)],
 [('E5',0,1.5),('D5',1.5,.5),('C5',2,1)],
 [('Bb4',0,1),('D5',1,1),('G5',2,1)],
 [('F5',0,1.5),('E5',1.5,.5),('D5',2,1)],
 [('C#5',0,1),('E5',1,1),('G5',2,1)],
 [('E5',0,1),('C#5',1,1),('A4',2,1)]
]
if __name__=='__main__':
    metadata={'method':'Original scores with synthesized instruments; two-bar equal-power tail/head loop bridges. No external recordings or samples.','tracks':[render('paper_castle_walk',72,4,explore_chords,explore_melody,'piano'),render('paper_dancer_waltz',100,3,dance_chords,dance_melody,'box')]}
    if (OUT/'score.json').exists():
        previous=json.loads((OUT/'score.json').read_text(encoding='utf-8'))
        metadata['tracks'] += [t for t in previous['tracks'] if t['file']=='storybook_prelude.wav']
    (OUT/'score.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
