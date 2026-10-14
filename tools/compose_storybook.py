from compose_chapter01 import render,OUT
import json
chords=[['F3','A4','C5','G5'],['C3','G4','C5','E5'],['D3','A4','D5','F5'],['Bb2','F4','Bb4','D5']]
melody=[[('C5',0,2),('G5',3,1)],[('E5',1,2)],[('F5',0,2),('A5',3,1)],[('D5',1,2)]]
track=render('storybook_prelude',64,4,chords,melody,'storybook')
track['description']='Original slow soft sustained prelude for the opening book, no samples.'
path=OUT/'score.json'
manifest=json.loads(path.read_text(encoding='utf-8'))
manifest['tracks']=[t for t in manifest['tracks'] if t['file']!=track['file']]+[track]
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
