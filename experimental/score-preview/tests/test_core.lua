local core=dofile('experimental/score-preview/score_preview_core.lua')
local function eq(a,b,label) assert(a==b,(label or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
eq(select(1,core.spell(70)),34,'B4 step')
eq(select(2,core.spell(70)),'b','Bb pitch')
eq(select(2,core.spell(63)),'b','Eb pitch')
eq(select(1,core.spell(63)),30,'Eb4 must occupy E4 step, not D4')
eq(select(1,core.spell(70)),34,'Bb4 occupies B4 step')
local seen={}
eq(core.notated_accidental(70,seen),nil,'Bb belongs to G-minor key signature')
eq(core.notated_accidental(63,seen),nil,'Eb belongs to G-minor key signature')
eq(core.notated_accidental(71,seen),'n','B natural cancels Bb')
eq(core.notated_accidental(71,seen),nil,'B natural repeated in same bar')
eq(core.notated_accidental(70,seen),'b','Bb restores signature after B natural')
eq(core.notated_accidental(66,seen),'#','F# must appear')
eq(core.notated_accidental(66,{}),'#','F# after barline must appear again')
local chord=core.group_onsets({
 {start=0,pitch=60},{start=0,pitch=64},{start=0.25,pitch=67}
})
eq(#chord,2,'two rhythmic onsets')
eq(#chord[1].notes,2,'two noteheads grouped into one chord')
eq(#chord[2].notes,1,'remaining single note')

eq(core.duration(0.24),0.25,'humanized duration')
eq(core.duration(1.49),1.5,'dotted quarter')
local input={
 {name='Manual I',start_qn=4,notes={{pitch=70,start_qn=4,end_qn=5},{pitch=76,start_qn=5,end_qn=5.5}}},
 {name='Manual II',start_qn=4,notes={{pitch=60,start_qn=4,end_qn=6}}},
 {name='Pedal',start_qn=4,notes={{pitch=40,start_qn=4,end_qn=8}}}
}
local snapshot=input[1].notes[1].start_qn
local m=core.build(input,{num=4,den=4,grid=0.25})
eq(m.original_events,4,'note count')
eq(m.bars,1,'one bar')
eq(#m.tracks,3,'staffs')
eq(m.tracks[1].clef,'treble','clef 1')
eq(m.tracks[2].clef,'bass','clef 2')
eq(#core.bar_notes(m.tracks[1],0,4),2,'bar 1 notes')
eq(input[1].notes[1].start_qn,snapshot,'unchanged source')
print('OK: notation score preview core, 4 notes, 3 staves, 4/4, G minor accidentals and chord grouping')
