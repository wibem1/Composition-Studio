-- Portable contracts for a complete work assembled from bounded transport windows.
local track_plan={window_qn=16,max_windows=64,plan_tokens=2048,window_tokens=8192}
do
local function number(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function list(t,limit)
 assert(type(t)=="table","Liste fehlt.")
 local count=0;for k in pairs(t) do assert(type(k)=="number" and k%1==0 and k>=1 and k<=#t,"Ungültige Liste.");count=count+1 end
 assert(count==#t and count<=limit,"Liste zu groß.");return t
end
local function text(s,limit) return type(s)=="string" and #s>0 and #s<=limit and not s:find("[%z\1-\8\11\12\14-\31]") end
function track_plan.windows(snapshot)
 local duration=snapshot.bounds.end_qn-snapshot.bounds.start_qn
 assert(number(duration) and duration>0 and duration<=track_plan.window_qn*track_plan.max_windows,"Trackumfang nicht unterstützt (maximal 1024 QN).")
 local windows={}
 for first=0,duration-0.0000001,track_plan.window_qn do windows[#windows+1]={start_qn=first,end_qn=math.min(duration,first+track_plan.window_qn)} end
 return windows,duration
end
function track_plan.validate(plan,duration)
 assert(type(plan)=="table" and plan.schema=="Composition-TrackPlan-1","Werkplanformat fehlt.")
 assert(text(plan.title,120) and text(plan.idea,2400),"Titel oder Werkidee fehlt.")
 local names={};assert(#list(plan.tracks,16)>0,"Werkplan ohne Stimmen.")
 for _,tr in ipairs(plan.tracks) do
  assert(type(tr)=="table" and text(tr.name,120) and not tr.name:find("[|\r\n]") and tr.name==tr.name:match("^%s*(.-)%s*$") and not names[tr.name],"Ungültige/doppelte Stimme.")
  assert(number(tr.program) and tr.program%1==0 and tr.program>=0 and tr.program<=127 and number(tr.channel) and tr.channel%1==0 and tr.channel>=0 and tr.channel<=15,"Ungültiges Instrument/Kanal.")
  assert(text(tr.role,300),"Stimmenrolle fehlt.");names[tr.name]=tr
 end
 local previous=0
 for _,s in ipairs(list(plan.sections,32)) do
  assert(type(s)=="table" and text(s.name,120) and text(s.direction,1200),"Abschnittsidee fehlt.")
  assert(number(s.start_qn) and math.abs(s.start_qn-previous)<0.000001 and number(s.end_qn) and s.end_qn>s.start_qn and s.end_qn<=duration,"Werkplan muss den gesamten Track lückenlos beschreiben.")
  previous=s.end_qn
 end
 assert(math.abs(previous-duration)<0.000001,"Werkplan verkürzt den Track.")
 return plan,names
end
function track_plan.validate_window(result,window,plan,snapshot,duration)
 local _,names=track_plan.validate(plan,duration)
 assert(type(result)=="table" and result.schema=="Composition-TrackWindow-1" and number(result.start_qn) and math.abs(result.start_qn-window.start_qn)<0.000001 and number(result.end_qn) and math.abs(result.end_qn-window.end_qn)<0.000001,"Falscher oder fehlender Ergebniszeitraum.")
 assert(text(result.continuity,1600),"Übergabe zum nächsten Abschnitt fehlt.")
 assert(result.bpm==snapshot.tempo and type(result.timeSignature)=="table" and result.timeSignature[1]==snapshot.time_signature[1] and result.timeSignature[2]==snapshot.time_signature[2],"Tempo/Taktart verändert.")
 assert(result.tempoEvents==nil and result.pedalEvents==nil,"Globale Ereignisse im Abschnitt nicht erlaubt.")
 local seen,count={},0
 for _,tr in ipairs(list(result.tracks,16)) do
  local ref=type(tr)=="table" and names[tr.name]
  assert(ref and not seen[tr.name] and tr.program==ref.program and tr.channel==ref.channel,"Stimmenidentität verändert.");seen[tr.name]=true
  assert(tr.pitchBend==nil,"Pitch Bend nicht unterstützt.")
  for _,n in ipairs(list(tr.notes,4000)) do
   count=count+1
   assert(type(n)=="table" and #n==4 and number(n[1]) and n[1]>=window.start_qn and n[1]<window.end_qn and number(n[2]) and n[2]>0 and n[1]+n[2]<=duration+0.000001,"Note außerhalb des Arbeitsfensters/Werks.")
   assert(number(n[3]) and n[3]%1==0 and n[3]>=0 and n[3]<=127 and number(n[4]) and n[4]%1==0 and n[4]>=1 and n[4]<=127,"Ungültige MIDI-Note.")
  end
  local pedal_at,pedal=-1,0
  for _,c in ipairs(list(tr.ccEvents or {},4000)) do
   assert(type(c)=="table" and number(c.at) and c.at>=window.start_qn and c.at<window.end_qn and number(c.controller) and c.controller%1==0 and c.controller>=0 and c.controller<=127 and number(c.value) and c.value%1==0 and c.value>=0 and c.value<=127,"Ungültiges Controllerereignis.")
   if c.controller==64 and c.at>=pedal_at then pedal_at=c.at;pedal=c.value end
  end
  assert(pedal<64,"Sustain muss innerhalb des Arbeitsfensters gelöst werden.")
 end
 assert(count<=4000 and (count>0 or result.rest==true),"Leerer Abschnitt muss ausdrücklich als Pause bezeichnet sein.")
 return result
end
function track_plan.assemble(plan,results,windows,snapshot)
 local _,duration=track_plan.windows(snapshot)
 track_plan.validate(plan,duration)
 assert(#list(results,track_plan.max_windows)==#windows,"Track noch nicht vollständig.")
 local score={schema="Composition-Song-1",title=plan.title,idea=plan.idea,bpm=snapshot.tempo,timeSignature=snapshot.time_signature,tracks={},sections={}}
 local by_name={};local count=0
 for _,ref in ipairs(plan.tracks) do
  local tr={name=ref.name,role=ref.role,program=ref.program,channel=ref.channel,notes={},ccEvents={}}
  by_name[tr.name]=tr;score.tracks[#score.tracks+1]=tr
 end
 for i,result in ipairs(results) do
  track_plan.validate_window(result,windows[i],plan,snapshot,duration)
  for _,part in ipairs(result.tracks) do
   local tr=by_name[part.name]
   for _,n in ipairs(part.notes) do tr.notes[#tr.notes+1]={n[1],n[2],n[3],n[4]};count=count+1 end
   for _,cc in ipairs(part.ccEvents or {}) do tr.ccEvents[#tr.ccEvents+1]={at=cc.at,controller=cc.controller,value=cc.value} end
  end
 end
 assert(count<=20000,"Gesamtergebnis überschreitet 20000 Noten.")
 for i,s in ipairs(plan.sections) do score.sections[#score.sections+1]={id="s"..i,name=s.name,start_qn=s.start_qn,end_qn=s.end_qn,purpose=s.direction} end
 for _,tr in ipairs(score.tracks) do assert(#tr.notes>0,"Geplante Stimme fehlt im Gesamtergebnis: "..tr.name) end
 return score
end
function track_plan.excerpt(snapshot,window)
 local out={schema=snapshot.schema,tempo=snapshot.tempo,time_signature=snapshot.time_signature,parts={}}
 for _,part in ipairs(snapshot.parts) do
  local copy={name=part.name,events={}}
  for _,n in ipairs(part.events) do
   local at=n.at-snapshot.bounds.start_qn
   if at<window.end_qn and at+n.duration>window.start_qn then copy.events[#copy.events+1]={at=at,duration=n.duration,pitch=n.pitch,velocity=n.velocity,channel=n.channel} end
  end
  out.parts[#out.parts+1]=copy
 end
 return out
end
end
-- BEGIN MODULE EXPORTS
return {track_plan=track_plan}
