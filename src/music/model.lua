local music_model={schema="Composition-Music-1",song_schema="Composition-Song-1",max_source_notes=2500,max_result_notes=20000}
local function music_number(value)
 return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function music_list(value,name,limit)
 assert(type(value)=="table",name..": Liste fehlt.")
 local count=0
 for key in pairs(value) do
  assert(type(key)=="number" and key%1==0 and key>=1 and key<=#value,name..": ungültige Liste.")
  count=count+1
 end
 assert(count==#value and count<=limit,name..": technische Größenbegrenzung überschritten.")
 return value
end
function music_model.capture(items,tempo,num,den,source_limit)
 assert(music_number(tempo) and tempo>=20 and tempo<=400,"Tempo außerhalb des unterstützten JSON-Bereichs (20–400 BPM).")
 assert(music_number(num) and num%1==0 and num>=1 and num<=32 and music_number(den) and den%1==0 and den>=1 and den<=64,"Taktart nicht unterstützt.")
 source_limit=source_limit or music_model.max_source_notes
 assert(music_number(source_limit) and source_limit>=1 and source_limit<=20000,"Ungültiges Quellnotenlimit.")
 local snapshot={schema=music_model.schema,representation="performance",tempo=tempo,time_signature={num,den},parts={},note_count=0}
 local parts,seen_items={},{ }; local first,last=math.huge,-math.huge
 for _,item in ipairs(items) do
  assert(type(item.guid)=="string" and item.guid~="","Quell-Item ohne Identität.")
  assert(not seen_items[item.guid],"Doppeltes Quell-Item im Musikkontext.");seen_items[item.guid]=true
  local id=(type(item.track_guid)=="string" and item.track_guid~="" and item.track_guid) or item.guid
  if not parts[id] then
   assert(#snapshot.parts<32,"Mehr als 32 Quellspuren; bitte einen kleineren Bereich auswählen.")
   parts[id]={id=id,name=item.track_name or "Instrument",events={}}
   snapshot.parts[#snapshot.parts+1]=parts[id]
  end
  for ordinal,note in ipairs(item.notes or {}) do
   snapshot.note_count=snapshot.note_count+1
   assert(snapshot.note_count<=source_limit,"Quellnotenlimit überschritten ("..source_limit..").")
   assert(music_number(note.start_qn) and music_number(note.duration_qn) and note.duration_qn>0,"Ungültige Quellzeiten.")
   assert(music_number(note.pitch) and note.pitch%1==0 and note.pitch>=0 and note.pitch<=127,"Ungültige Quelltonhöhe.")
   assert(music_number(note.velocity) and note.velocity%1==0 and note.velocity>=1 and note.velocity<=127,"Ungültige Quellvelocity.")
   assert(music_number(note.channel) and note.channel%1==0 and note.channel>=0 and note.channel<=15,"Ungültiger Quellkanal.")
   local event={id=item.guid..":"..ordinal,source_item=item.guid,source_ordinal=ordinal,
    at=note.start_qn,duration=note.duration_qn,pitch=note.pitch,velocity=note.velocity,channel=note.channel}
   parts[id].events[#parts[id].events+1]=event
   first=math.min(first,event.at); last=math.max(last,event.at+event.duration)
  end
 end
 assert(snapshot.note_count>0,"Keine MIDI-Noten als Ausgangsmaterial vorhanden.")
 snapshot.bounds={start_qn=first,end_qn=last}
 return snapshot
end
function music_model.validate_song(song,snapshot)
 assert(type(snapshot)=="table" and snapshot.schema==music_model.schema,"Gesicherter Musikkontext fehlt.")
 assert(type(song)=="table" and song.schema==music_model.song_schema,"Song-Antwort benötigt Composition-Song-1.")
 assert(music_number(song.bpm) and math.abs(song.bpm-snapshot.tempo)<0.000001,"Der Song darf das Projekttempo nicht ändern.")
 assert(type(song.timeSignature)=="table" and song.timeSignature[1]==snapshot.time_signature[1] and song.timeSignature[2]==snapshot.time_signature[2],"Der Song darf die Projekttaktart nicht ändern.")
 assert(song.tempoEvents==nil or #music_list(song.tempoEvents,"Tempoereignisse",0)==0,"Die vorhandene Tempokarte bleibt erhalten.")
 assert(type(song.title)=="string" and #song.title>0 and #song.title<=120,"Songtitel fehlt oder ist zu lang.")
 local tracks=music_list(song.tracks,"Spuren",32)
 assert(#tracks>0,"Song ohne Spuren.")
 local names,count,last={ },0,0
 for _,track in ipairs(tracks) do
  assert(type(track)=="table" and type(track.name)=="string" and #track.name>0 and #track.name<=120,"Ungültiger Spurname.")
  assert(not track.name:find("[|\r\n]") and track.name==track.name:match("^%s*(.-)%s*$") and not names[track.name],"Spurnamen müssen eindeutig und ohne Steuerzeichen sein.")
  names[track.name]=true
  assert(track.role==nil or type(track.role)=="string" and #track.role<=300,"Ungültige musikalische Rollenbeschreibung.")
  local notes=music_list(track.notes,"Noten",music_model.max_result_notes)
  assert(#notes>0,"Leere Songspuren können nicht übernommen werden; bitte im Ergebnis weglassen.")
  for _,note in ipairs(notes) do
   count=count+1
   assert(count<=music_model.max_result_notes,"Song hat mehr als 20000 Noten.")
   assert(type(note)=="table" and music_number(note[1]) and note[1]>=0 and music_number(note[2]) and note[2]>0,"Ungültige Songzeiten.")
   last=math.max(last,note[1]+note[2])
  end
 end
 assert(count>0,"Song enthält keine Noten.")
 local sections=music_list(song.sections,"Abschnitte",32)
 assert(#sections>0,"Song benötigt mindestens einen beschriebenen Abschnitt.")
 local ids,previous={},0
 for _,section in ipairs(sections) do
  assert(type(section)=="table" and type(section.id)=="string" and #section.id>0 and #section.id<=80 and not ids[section.id],"Abschnittskennungen fehlen oder sind doppelt.")
  assert(type(section.name)=="string" and #section.name>0 and #section.name<=120,"Abschnittsname fehlt.")
  assert(music_number(section.start_qn) and math.abs(section.start_qn-previous)<0.000001 and music_number(section.end_qn) and section.end_qn>section.start_qn and section.end_qn<=4096,"Abschnitte müssen den Song lückenlos ab QN 0 beschreiben (maximal 4096 QN).")
  assert(section.purpose==nil or type(section.purpose)=="string" and #section.purpose<=600,"Ungültige Abschnittsbeschreibung.")
  ids[section.id]=true;previous=section.end_qn
 end
 assert(last<=previous+0.000001,"Songnoten reichen über den beschriebenen Werkumfang hinaus.")
 local pedal=music_list(song.pedalEvents or {},"Pedalereignisse",20000)
 local controls=0
 for _,track in ipairs(tracks) do
  local pedal_at,pedal_value=-1,0
  for _,event in ipairs(pedal) do
   controls=controls+1
   assert(type(event)=="table" and music_number(event.at) and event.at>=0 and event.at<=previous,"Pedalereignis außerhalb des Songumfangs.")
   assert(music_number(event.value) and event.value%1==0 and event.value>=0 and event.value<=127,"Ungültiger Pedalwert.")
   if event.at>=pedal_at then pedal_at=event.at;pedal_value=event.value end
  end
  for _,event in ipairs(music_list(track.ccEvents or {},"Controllerereignisse",20000)) do
   controls=controls+1
   assert(type(event)=="table" and music_number(event.at) and event.at>=0 and event.at<=previous,"Controllerereignis außerhalb des Songumfangs.")
   assert(music_number(event.controller) and event.controller%1==0 and event.controller>=0 and event.controller<=127 and music_number(event.value) and event.value%1==0 and event.value>=0 and event.value<=127,"Ungültiger Controllerwert.")
   if event.controller==64 and event.at>=pedal_at then pedal_at=event.at;pedal_value=event.value end
  end
  assert(controls<=20000,"Zu viele Controllerereignisse im Song.")
  assert(music_number(pedal_value) and pedal_value>=0 and pedal_value<64,"Sustain-Pedal muss innerhalb des Songs wieder gelöst werden.")
  assert(track.pitchBend==nil or #music_list(track.pitchBend,"Pitch Bend",0)==0,"Pitch Bend ist im bestehenden Lua-JSON-Adapter nicht unterstützt.")
 end
 for _,relation in ipairs(music_list(song.relationships or {},"Beziehungen",64)) do
  assert(type(relation)=="table" and ids[relation.from] and ids[relation.to],"Formbeziehung verweist auf unbekannte Abschnitte.")
  assert(type(relation.description)=="string" and #relation.description<=600,"Ungültige Formbeziehung.")
 end
 return song
end
-- CS2-1 is a transport adapter; expanded operations retain the existing CS rules.
do
 local codec={max_notes=20000,max_controls=20000,max_bytes=2000000}
 music_model.compact=codec
 local function split(s,sep)
  local out,at={},1
  while true do local next_at=s:find(sep,at,true);if not next_at then out[#out+1]=s:sub(at);return out end
   out[#out+1]=s:sub(at,next_at-1);at=next_at+#sep
  end
 end
 local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
 local function num(s,lo,hi,integer)
  assert(type(s)=="string" and s~="" and not s:find("[^%d%.eE%+%-]"),"Ungültige Zahl.")
  local n=tonumber(s);assert(finite(n) and n>=lo and n<=hi and (not integer or n%1==0),"Zahl außerhalb des Bereichs.");return integer and math.floor(n) or n
 end
 -- Shortest round-tripping decimal, expanded if legacy CS cannot read exponent notation.
 function codec.number(n)
  assert(finite(n),"Nichtendlicher Zahlenwert.")
  local value
  for digits=1,17 do value=string.format("%."..digits.."g",n);if tonumber(value)==n then break end end
  local mantissa,exponent=value:match("^(.+)[eE]([%+%-]?%d+)$")
  if not exponent then return value end
  local sign="";if mantissa:sub(1,1)=="-" then sign="-";mantissa=mantissa:sub(2) end
  local before=mantissa:find(".",1,true) or #mantissa+1
  local digits=mantissa:gsub("%.","");local point=before-1+tonumber(exponent)
  if point<=0 then return sign.."0."..string.rep("0",-point)..digits end
  if point>=#digits then return sign..digits..string.rep("0",point-#digits) end
  return sign..digits:sub(1,point).."."..digits:sub(point+1)
 end
 function codec.input(items)
  local rows={"MIDI1: absolute QN; columns=start,duration,pitch,velocity,channel. ITEM refers to the matching ITEM number above."}
  for i,it in ipairs(items) do
   rows[#rows+1]="NOTES ITEM "..i
   local notes={}
   for _,n in ipairs(it.notes or {}) do
    -- Preserve the existing five-decimal source representation; remove only redundant zeros.
    local at=string.format("%.5f",n.start_qn):gsub("0+$",""):gsub("%.$","")
    local duration=string.format("%.5f",n.duration_qn):gsub("0+$",""):gsub("%.$","")
    notes[#notes+1]=at..","..duration..","..n.pitch..","..n.velocity..","..n.channel
   end
   rows[#rows+1]=table.concat(notes,";")
  end
  return table.concat(rows,"\n")
 end
 function codec.spec()
  return [[Gib die vollständige Fassung im Transportformat CS2|1 aus, keine Erläuterungen.
Erste Zeile CS2|1, letzte Zeile END. Dazwischen:
T|id|ART|QUELLE|NAME|PROGRAM|KANAL
N|id|start,dauer,pitch,velocity;...
P|figur|SPANNE|relativerStart,dauer,pitch,velocity;...
R|id|figur|START|ANZAHL
U|SOURCE_GUID
C|id|start|KANAL|cc|CONTROLLER|WERT
C|id|start|KANAL|program|PROGRAM
Die vorhandene Tempo-/Taktkarte bleibt bei Bearbeitungen erhalten; keine CSMETA-Zeilen ausgeben.
T deklariert eine Ergebnisstimme vor deren Verwendung. ART ist new, revised, target oder track; QUELLE ist die vollständige passende SOURCE_GUID/TRACK_GUID aus dem Kontext, für new ein -. NAME eindeutig ohne | oder Zeilenumbruch. PROGRAM 0..127, KANAL 0..15.
N enthält einzelne Noten mit ABSOLUTEM Start ab Projektbeginn. Eine optionale fünfte Zahl überschreibt den Kanal der T-Zeile für diese Note. Pitch 0..127, Velocity 1..127, Dauer positiv, QN nichtnegativ.
P definiert eine wiederverwendbare Figur vor R; alle Notenstarts liegen in [0,SPANNE). R setzt sie ANZAHL-mal bei START+j*SPANNE ein (j=0..ANZAHL-1), Kanal aus T oder fünfter Notenzahl. Noten dürfen über die Spanne hinaus klingen. Keine Verschachtelung. R ist eine exakte Wiederholung, keine Anweisung zu musikalischer Variation; Varianten mit eigenen Figuren oder N vollständig auskomponieren; bei ersetzenden Varianten die entsprechenden Basiseinsätze weglassen.
U kennzeichnet ein unverändertes Quell-Item. Jede T-Stimme braucht Noten. IDs kurz und eindeutig. Keine erzwungenen Figuren, Wiederholungen, festen Taktgruppen oder Songform. Betrachte alle Quellen als ganzes Werk. Maximal 64 Ergebnisstimmen, 128 Figuren sowie je 20000 expandierte Noten und Controller. Studio löst Figuren lokal auf, keine zweite KI-Übersetzung.]]
 end
 function codec.decode(text)
  local ok,result=pcall(function()
   assert(type(text)=="string" and #text<=codec.max_bytes,"Antwort zu groß.")
   local lines={};for line in text:gmatch("[^\r\n]+") do line=line:match("^%s*(.-)%s*$");if line~="" then lines[#lines+1]=line end end
   assert(lines[1]=="CS2|1" and lines[#lines]=="END","CS2-Kopf oder END fehlt; Antwort unvollständig.")
   local tracks,order,patterns,others,names={},{},{},{},{};local total,controls,pattern_count=0,0,0
   local function identity(id) assert(type(id)=="string" and #id>0 and #id<=32 and id:match("^[%w_%-]+$"),"Ungültige Kennung.");return id end
   local function notes(raw)
    assert(raw~="","Notenliste leer.");local result={}
    for _,token in ipairs(split(raw,";")) do
     local n=split(token,",");assert(#n==4 or #n==5,"Note braucht vier oder fünf Werte.")
     local v={num(n[1],0,1000000),num(n[2],0,1000000),num(n[3],0,127,true),num(n[4],1,127,true)}
     assert(v[2]>0,"Dauer muss positiv sein.");if n[5] then v[5]=num(n[5],0,15,true) end
     result[#result+1]=v;assert(#result<=codec.max_notes,"Zu viele Figurennoten.")
    end
    return result
   end
   local function emit(tr,n,offset)
    total=total+1;assert(total<=codec.max_notes,"Zu viele expandierte Noten.")
    local at=n[1]+offset;assert(finite(at) and at>=0 and at+n[2]<=1000000,"Notenzeit außerhalb des Bereichs.")
    tr.notes[#tr.notes+1]=codec.number(at)..","..codec.number(n[2])..","..n[3]..","..n[4]..","..(n[5] or tr.channel)
   end
   for index=2,#lines-1 do
    local fields=split(lines[index],"|");local kind=fields[1]
    if kind=="T" then
     assert(#fields==7 and #order<64,"Ungültige Stimmendeklaration.")
     local id=identity(fields[2]);assert(not tracks[id],"Doppelte Stimme.")
     assert(fields[3]=="new" or fields[3]=="revised" or fields[3]=="target" or fields[3]=="track","Unbekannte Operation.")
     assert(#fields[4]>0 and #fields[4]<=100 and (fields[3]~="new" or fields[4]=="-"),"Ungültige Quelle.")
     local name=fields[5];assert(#name>0 and #name<=120 and name==name:match("^%s*(.-)%s*$") and not name:find("[%z\1-\31]") and not names[name],"Ungültiger/doppelter Name.");names[name]=true
     tracks[id]={kind=fields[3],source=fields[4],name=name,program=num(fields[6],0,127,true),channel=num(fields[7],0,15,true),notes={}};order[#order+1]=id
    elseif kind=="N" then
     local tr=tracks[fields[2]];assert(#fields==3 and tr,"Unbekannte Stimme.")
     for _,n in ipairs(notes(fields[3])) do emit(tr,n,0) end
    elseif kind=="P" then
     pattern_count=pattern_count+1;assert(pattern_count<=128 and #fields==4,"Ungültige/zu viele Figuren.");local id=identity(fields[2]);assert(not patterns[id],"Doppelte Figur.")
     local span=num(fields[3],0,1000000);assert(span>0,"Figurenspanne muss positiv sein.")
     local ns=notes(fields[4]);for _,n in ipairs(ns) do assert(n[1]<span,"Figurenstart außerhalb der Spanne.") end
     patterns[id]={span=span,notes=ns}
    elseif kind=="R" then
     local tr,pattern=tracks[fields[2]],patterns[fields[3]];assert(#fields==5 and tr and pattern,"Stimme/Figur fehlt.")
     local at,count=num(fields[4],0,1000000),num(fields[5],1,codec.max_notes,true)
     assert(total+#pattern.notes*count<=codec.max_notes,"Expansion zu groß.")
     for repeat_index=0,count-1 do for _,n in ipairs(pattern.notes) do emit(tr,n,at+repeat_index*pattern.span) end end
    elseif kind=="U" then
     assert(#fields==2 and #fields[2]>0 and #fields[2]<=100,"Ungültige unveränderte Quelle.");others[#others+1]="CS|unchanged|"..fields[2]
    elseif kind=="C" then
     local tr=tracks[fields[2]];assert(tr,"Controller ohne Stimme.")
     local at,ch=num(fields[3],0,1000000),num(fields[4],0,15,true);local tail
     if fields[5]=="cc" then assert(#fields==7,"Ungültiger CC.");tail="cc|"..num(fields[6],0,127,true).."|"..num(fields[7],0,127,true)
     else assert(fields[5]=="program" and #fields==6,"Ungültiger Program Change.");tail="program|"..num(fields[6],0,127,true) end
     controls=controls+1;assert(controls<=codec.max_controls,"Zu viele Controller.")
     others[#others+1]="CSCTRL|"..tr.name.."|"..codec.number(at).."|"..ch.."|"..tail
    elseif kind=="CSMETA" then
     local at=num(fields[3],0,1000000)
     if fields[2]=="tempo" then assert(#fields==4,"Ungültiges Tempo.");others[#others+1]="CSMETA|tempo|"..codec.number(at).."|"..codec.number(num(fields[4],1,1000))
     else assert(fields[2]=="timesig" and #fields==5,"Ungültige Taktart.");others[#others+1]="CSMETA|timesig|"..codec.number(at).."|"..num(fields[4],1,32,true).."|"..num(fields[5],1,64,true) end
    else error("Unbekannte CS2-Zeile: "..tostring(kind)) end
   end
   local result={}
   for _,id in ipairs(order) do local tr=tracks[id];assert(#tr.notes>0,"Stimme ohne Noten.");result[#result+1]="CS|"..tr.kind.."|"..tr.source.."|"..tr.name.."|"..tr.program.."|"..table.concat(tr.notes,";") end
   for _,line in ipairs(others) do result[#result+1]=line end
   assert(#result>0,"Leere Komposition.")
   local expanded=table.concat(result,"\n");assert(#expanded<=codec.max_bytes,"Expandierte Antwort zu groß.");return expanded
  end)
  if ok then return result end
  return nil,"Kompakte Komposition ungültig: "..tostring(result)
 end
end

-- BEGIN MODULE EXPORTS
return {music_model=music_model}
